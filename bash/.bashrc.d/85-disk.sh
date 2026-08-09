# Disk maintenance pair: disk-check (read-only gauge) and disk-fix (the
# actor). Born of the bigfed ENOSPC incident (2026-08): a TeX Live install
# died with "No space left on device" while df showed 91G free, because every
# byte of the device was committed to data chunks (~80% full) and btrfs had
# no unallocated room left to carve a new metadata chunk from. Deleting files
# cannot help in that state -- deletion frees space *inside* chunks without
# returning the chunks -- only a filtered balance does. Nothing was watching
# unallocated space, so nothing warned. These commands are the watcher and
# the remedy.
#
# Philosophy, decided 2026-08-09: automatic *watching* is fine (smartd, the
# kernel's own error counters -- passive, already running); automatic
# *writing* is not. So: no timers, no background actions, no root in the
# steady state. disk-check is unprivileged and never changes anything --
# safe to run on a filesystem already wedged with ENOSPC, since it allocates
# nothing. disk-fix takes sudo interactively, announces its plan first, and
# runs only what is actually due. Both consult the SAME threshold table
# below, so the check can never nag toward something the fixer won't do.
#
# Portability contract: plain Fedora -- util-linux, systemd, GNU coreutils,
# sysfs; btrfs-progs only where btrfs exists and only inside disk-fix. Every
# btrfs number comes unprivileged from /sys/fs/btrfs/<uuid>/ (verified on
# kernel 7.1). Machines that differ degrade gracefully: no btrfs -> the
# chunk checks report that and the rest still runs; smartd off -> reported,
# not crashed; several btrfs filesystems -> all of them checked.
#
# The thresholds are ABSOLUTE, not percentages, on purpose: the failure is
# absolute. btrfs needs GiB-scale unallocated room to carve new chunks
# regardless of device size, so the same rule serves a nearly-empty 1T
# laptop and a 91%-full desktop -- fullness changes when it fires, never
# what is deployed. `:=` so a test can pre-seed; the defaults are the policy
# and are meant to be uniform across machines.
: "${_DISK_UNALLOC_DUE_GIB:=16}"     # unallocated below this -> balance due
: "${_DISK_UNALLOC_CRIT_GIB:=4}"     # ...below this -> act now
: "${_DISK_META_FREE_CRIT_MIB:=512}" # with crit unalloc: ENOSPC imminent
: "${_DISK_SCRUB_DUE_DAYS:=90}"      # quarterly integrity verification
: "${_DISK_DF_FULL_PCT:=90}"         # plain fullness, any filesystem
: "${_DISK_SMART_LOOKBACK_DAYS:=14}" # journal window for smartd verdicts
: "${_DISK_BALANCE_DUSAGE:=50}"      # rewrite only chunks <= this % used

# Overridable for tests (fake sysfs tree, sandboxed state). The state dir is
# deliberately machine-local (~/.local/state, not the synced configs repo):
# scrub dates are per-machine facts.
: "${DISK_SYSFS:=/sys/fs/btrfs}"
: "${DISK_STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/disk-maint}"

# One verdict line, reboot-check style: colors only on a tty. Tag semantics
# mirror that command's split between "action needed" and "could not tell":
#   [ OK ] green   healthy, nothing to do
#   [DUE]  yellow  maintenance action due -- run disk-fix
#   [FAIL] red     something is actually wrong
#   [WARN] red     could not determine -- never silently assumed healthy
_disk_line() {
  local tag="$1" msg="$2" color="" reset=""
  if [[ -t 1 ]]; then
    reset=$'\e[0m'
    case "$tag" in
      OK)   color=$'\e[32m' ;;
      DUE)  color=$'\e[33m' ;;
      *)    color=$'\e[31m' ;;
    esac
  fi
  if [[ "$tag" == OK ]]; then
    printf '%s[ OK ]%s %s\n' "$color" "$reset" "$msg"
  else
    printf '%s[%s]%s %s\n' "$color" "$tag" "$reset" "$msg"
  fi
}

_disk_gib() { awk -v b="$1" 'BEGIN{printf "%.1fG", b/1073741824}'; }

# Mounted btrfs filesystems as "uuid<TAB>mountpoint", deduplicated by UUID:
# subvolume mounts of one filesystem (Fedora mounts / and /home from the
# same device) collapse to the first, which in mount order is nearest /.
_disk_btrfs_list() {
  local target uuid
  local -A seen=()
  while read -r target uuid; do
    [[ -n "${uuid:-}" ]] || continue
    [[ -n "${seen[$uuid]:-}" ]] && continue
    seen[$uuid]=1
    printf '%s\t%s\n' "$uuid" "$target"
  done < <(findmnt -t btrfs -rn -o TARGET,UUID 2>/dev/null)
}

# Chunk arithmetic for one filesystem, entirely from sysfs (unprivileged).
# Emits "total unallocated meta_free data_slack errors" (bytes; errors a
# count). Returns 1 if any needed file is unreadable -- the caller must
# treat that as "headroom unknown", never as healthy.
#   total       = sum of member device sizes (sectors * 512)
#   unallocated = total - raw bytes committed to chunks (disk_total sums
#                 include replication, e.g. DUP metadata counts twice, so
#                 this is exact for any profile)
#   meta_free   = logical room left inside existing metadata chunks
#   data_slack  = free space trapped inside allocated data chunks -- the
#                 upper bound on what a filtered balance can reclaim
#   errors      = lifetime read/write/flush/corruption/generation counters
_disk_fs_numbers() {
  local base="$DISK_SYSFS/$1" f v t
  local total=0 alloc=0 mt mu dt du errs=0 any=0
  for f in "$base"/devices/*/size; do
    [[ -r "$f" ]] || return 1
    read -r v <"$f" || return 1
    total=$((total + v * 512))
  done
  for t in data metadata system; do
    [[ -r "$base/allocation/$t/disk_total" ]] || return 1
    read -r v <"$base/allocation/$t/disk_total" || return 1
    alloc=$((alloc + v))
  done
  { read -r mt <"$base/allocation/metadata/total_bytes" &&
    read -r mu <"$base/allocation/metadata/bytes_used" &&
    read -r dt <"$base/allocation/data/total_bytes" &&
    read -r du <"$base/allocation/data/bytes_used"; } 2>/dev/null || return 1
  for f in "$base"/devinfo/*/error_stats; do
    [[ -r "$f" ]] || return 1
    any=1
    while read -r _ v; do errs=$((errs + v)); done <"$f"
  done
  ((any)) || return 1
  printf '%s %s %s %s %s\n' "$total" $((total - alloc)) $((mt - mu)) $((dt - du)) "$errs"
}

# Days since the recorded scrub for a UUID, from the state file disk-fix
# writes. Returns 1 when there is no (parseable) record. The record is
# disk-fix's own: a scrub run outside disk-fix is invisible here, and the
# nag persists until one goes through disk-fix -- by design, since the
# kernel's last-scrub record is not reliably readable without root.
_disk_scrub_age_days() {
  local f="$DISK_STATE_DIR/scrub-$1" rec when now
  [[ -r "$f" ]] || return 1
  read -r rec <"$f" || return 1
  when=$(date -d "$rec" +%s 2>/dev/null) || return 1
  now=$(date +%s)
  printf '%s\n' $(( (now - when) / 86400 ))
}

# Read-only scorecard: one verdict line per subsystem, sub-second, never
# writes, never elevates. Exit: 0 healthy, 1 attention needed (any
# FAIL/DUE), 2 healthy-so-far-but-unknown (a WARN and nothing actionable).
disk-check() {
  local attention=0 unknown=0 found=0
  local uuid mnt nums total unalloc meta_free slack errs age

  while IFS=$'\t' read -r uuid mnt; do
    found=1
    if ! nums=$(_disk_fs_numbers "$uuid"); then
      _disk_line WARN "btrfs $mnt: cannot read $DISK_SYSFS/$uuid -- chunk headroom unknown"
      unknown=1
      continue
    fi
    read -r total unalloc meta_free slack errs <<<"$nums"

    # Chunk headroom -- the ENOSPC-with-free-space class itself.
    if (( unalloc < _DISK_UNALLOC_CRIT_GIB * 1073741824 )); then
      if (( meta_free < _DISK_META_FREE_CRIT_MIB * 1048576 )); then
        _disk_line FAIL "btrfs $mnt: unallocated down to $(_disk_gib "$unalloc") AND metadata nearly full ($(_disk_gib "$meta_free") free) -- ENOSPC imminent, run disk-fix now"
      else
        _disk_line FAIL "btrfs $mnt: unallocated down to $(_disk_gib "$unalloc") -- run disk-fix (up to ~$(_disk_gib "$slack") reclaimable by filtered balance)"
      fi
      attention=1
    elif (( unalloc < _DISK_UNALLOC_DUE_GIB * 1073741824 )); then
      _disk_line DUE "btrfs $mnt: unallocated low, $(_disk_gib "$unalloc") (threshold ${_DISK_UNALLOC_DUE_GIB}G) -- run disk-fix (up to ~$(_disk_gib "$slack") reclaimable)"
      attention=1
    else
      _disk_line OK "btrfs $mnt: $(_disk_gib "$unalloc") unallocated, metadata $(_disk_gib "$meta_free") free"
    fi

    # Lifetime device error counters -- any nonzero means the kernel has
    # seen I/O or checksum trouble on this filesystem. Zero is the only
    # healthy value.
    if (( errs > 0 )); then
      _disk_line FAIL "btrfs $mnt: $errs device errors on record -- inspect: sudo btrfs device stats $mnt"
      attention=1
    else
      _disk_line OK "btrfs $mnt: no device errors recorded"
    fi

    # Scrub age -- the manual approximation of scheduled verification: the
    # system knows it is overdue and says so instead of acting.
    if age=$(_disk_scrub_age_days "$uuid"); then
      if (( age > _DISK_SCRUB_DUE_DAYS )); then
        _disk_line DUE "btrfs $mnt: last scrub $age days ago (threshold $_DISK_SCRUB_DUE_DAYS) -- run disk-fix"
        attention=1
      else
        _disk_line OK "btrfs $mnt: scrubbed $age days ago"
      fi
    else
      _disk_line DUE "btrfs $mnt: no scrub on record -- run disk-fix"
      attention=1
    fi
  done < <(_disk_btrfs_list)

  ((found)) || _disk_line OK "btrfs: no btrfs filesystems mounted -- chunk checks not applicable"

  # smartd -- the continuous sensor. Its warnings go to the journal (mail
  # would need an MTA neither machine has), so this is the wire that reads
  # them back. --system fails loud when the journal is unreadable; without
  # it journalctl silently shows only the user's own journal and rc 0 --
  # a false OK.
  local out n
  if [[ "$(systemctl is-active smartd 2>/dev/null)" == active ]]; then
    if out=$(journalctl --system -u smartd -p warning --since="-${_DISK_SMART_LOOKBACK_DAYS}d" --no-pager -q 2>/dev/null); then
      n=$(grep -c . <<<"$out")
      if (( n > 0 )); then
        _disk_line FAIL "smartd: $n warnings in the last ${_DISK_SMART_LOOKBACK_DAYS} days -- inspect: journalctl -u smartd -p warning"
        attention=1
      else
        _disk_line OK "smartd: active, no warnings in the last ${_DISK_SMART_LOOKBACK_DAYS} days"
      fi
    else
      _disk_line WARN "smartd: active, but the system journal is unreadable -- drive-health verdicts unknown (not in the wheel group?)"
      unknown=1
    fi
  else
    _disk_line DUE "smartd: not running -- drive self-monitoring is off (sudo systemctl enable --now smartd; dnf install smartmontools if missing)"
    attention=1
  fi

  # Plain fullness -- the mundane failure is still the most common one.
  # Covers every local real filesystem (the ext4 /boot included),
  # deduplicated by source so a btrfs mounted at / and /home counts once.
  # (--output conflicts with -P by df's own rules; avail is 1K blocks.)
  local src tgt pct avail full=0 dfout
  if dfout=$(df --local --output=source,target,pcent,avail -x tmpfs -x devtmpfs -x efivarfs 2>/dev/null | tail -n +2) && [[ -n "$dfout" ]]; then
    local -A dfseen=()
    while read -r src tgt pct avail; do
      [[ -n "${src:-}" && -z "${dfseen[$src]:-}" ]] || continue
      dfseen[$src]=1
      pct=${pct%\%}
      if (( pct >= _DISK_DF_FULL_PCT )); then
        _disk_line FAIL "fullness: $tgt is ${pct}% full ($(_disk_gib $((avail * 1024))) left)"
        attention=1 full=1
      fi
    done <<<"$dfout"
    ((full)) || _disk_line OK "fullness: all filesystems under ${_DISK_DF_FULL_PCT}%"
  else
    _disk_line WARN "fullness: df failed -- usage unknown"
    unknown=1
  fi

  ((attention)) && return 1
  ((unknown)) && return 2
  return 0
}

# The actor. Consults the SAME thresholds as disk-check, announces the full
# plan, then runs only what is due -- nothing due means no sudo, no writes,
# exit 0. Actions, in order:
#   1. Filtered data balance (unallocated low): -dusage=0 (frees empty
#      chunks, instant) then -dusage=N (rewrites only mostly-empty chunks to
#      return their slack to the unallocated pool -- SSD writes proportional
#      to the slack reclaimed, so cheap exactly when it is most needed).
#      Never a full balance, never metadata (-musage), never defrag, never
#      deletes anything.
#   2. Scrub (none on record, or older than the threshold): read-only
#      verification of every checksum; negligible wear. The completion date
#      is recorded for disk-check's nag -- but only when the scrub comes
#      back clean, so a scrub that finds trouble keeps nagging.
# Exit: 0 all done (or nothing due), 1 an action failed or found trouble,
# 2 could not act (no root, or refusing to act on unreadable statistics).
disk-fix() {
  local uuid mnt nums total unalloc meta_free slack errs age
  local -a bal_mnts=() bal_uuids=() scrub_mnts=() scrub_uuids=()

  while IFS=$'\t' read -r uuid mnt; do
    if ! nums=$(_disk_fs_numbers "$uuid"); then
      _disk_line WARN "btrfs $mnt: cannot read $DISK_SYSFS/$uuid -- refusing to act on unknown numbers"
      return 2
    fi
    read -r total unalloc meta_free slack errs <<<"$nums"
    if (( unalloc < _DISK_UNALLOC_DUE_GIB * 1073741824 )); then
      bal_mnts+=("$mnt"); bal_uuids+=("$uuid")
    fi
    if age=$(_disk_scrub_age_days "$uuid"); then
      if (( age > _DISK_SCRUB_DUE_DAYS )); then
        scrub_mnts+=("$mnt"); scrub_uuids+=("$uuid")
      fi
    else
      scrub_mnts+=("$mnt"); scrub_uuids+=("$uuid")
    fi
  done < <(_disk_btrfs_list)

  if (( ${#bal_mnts[@]} == 0 && ${#scrub_mnts[@]} == 0 )); then
    _disk_line OK "nothing to do -- chunk headroom fine and scrubs current everywhere"
    return 0
  fi

  # Announce everything before touching anything.
  local m
  for m in "${bal_mnts[@]}"; do
    printf 'due: filtered data balance on %s (unallocated space low)\n' "$m"
  done
  for m in "${scrub_mnts[@]}"; do
    printf 'due: scrub on %s (none on record, or older than %s days)\n' "$m" "$_DISK_SCRUB_DUE_DAYS"
  done

  # Root is taken interactively and deliberately; primed once up front so a
  # long balance is not interrupted by a credential prompt mid-run.
  if ! sudo -v; then
    _disk_line WARN "root required -- rerun disk-fix in an interactive terminal"
    return 2
  fi

  local rc=0 i before after
  for i in "${!bal_mnts[@]}"; do
    mnt="${bal_mnts[$i]}" uuid="${bal_uuids[$i]}"
    before=""
    nums=$(_disk_fs_numbers "$uuid") && read -r _ before _ _ _ <<<"$nums"
    printf 'balancing %s (rewriting data chunks <=%s%% used) ...\n' "$mnt" "$_DISK_BALANCE_DUSAGE"
    if sudo btrfs balance start -dusage=0 "$mnt" &&
       sudo btrfs balance start -dusage="$_DISK_BALANCE_DUSAGE" "$mnt"; then
      if nums=$(_disk_fs_numbers "$uuid") && [[ -n "$before" ]]; then
        read -r _ after _ _ _ <<<"$nums"
        if (( after < _DISK_UNALLOC_DUE_GIB * 1073741824 )); then
          # The balance is not the problem here: the chunks are genuinely
          # full, i.e. the disk is genuinely filling up.
          _disk_line FAIL "btrfs $mnt: balance ran but unallocated is still $(_disk_gib "$after") -- the filesystem is genuinely filling; free or move data"
          rc=1
        else
          _disk_line OK "btrfs $mnt: balance reclaimed $(_disk_gib $((after - before))) -- unallocated now $(_disk_gib "$after")"
        fi
      else
        _disk_line WARN "btrfs $mnt: balance ran but the result could not be re-measured"
      fi
    else
      _disk_line FAIL "btrfs $mnt: balance failed -- inspect: sudo btrfs balance status $mnt"
      rc=1
    fi
  done

  for i in "${!scrub_mnts[@]}"; do
    mnt="${scrub_mnts[$i]}" uuid="${scrub_uuids[$i]}"
    printf 'scrubbing %s (read-only verification of every checksum) ...\n' "$mnt"
    if sudo btrfs scrub start -Bd "$mnt"; then
      if mkdir -p "$DISK_STATE_DIR" && date -Iseconds >"$DISK_STATE_DIR/scrub-$uuid"; then
        _disk_line OK "btrfs $mnt: scrub clean -- recorded"
      else
        _disk_line WARN "btrfs $mnt: scrub clean, but the date could not be recorded in $DISK_STATE_DIR -- the disk-check nag will persist"
      fi
    else
      # Nonzero covers both "could not run" and "ran and found errors";
      # either way no date is recorded, so the nag keeps pressing until a
      # scrub comes back clean.
      _disk_line FAIL "btrfs $mnt: scrub did not come back clean -- inspect: sudo btrfs scrub status -d $mnt"
      rc=1
    fi
  done

  return "$rc"
}
