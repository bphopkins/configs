#!/usr/bin/env bash
# Regression suite for the disk maintenance pair in bash/.bashrc.d/85-disk.sh
# (disk-check, disk-fix, and the _disk_* helpers). Written 2026-08-09 with the
# module itself.
#
# Hermetic: findmnt, systemctl, journalctl, df, sudo, and btrfs are
# PATH-stubbed under a $TMPDIR sandbox, and every btrfs number is read from a
# fake sysfs tree via the DISK_SYSFS override -- no privileges, no writes
# outside the sandbox, no network. The stub sudo logs every invocation and
# then execs its argument (which resolves to the stub btrfs), so the tests
# can assert both WHAT disk-fix ran and that disk-check ran nothing at all.
# Stub behavior is driven by exported STUB_* variables; reset_stubs() returns
# them all to the healthy defaults between test blocks. The final "live"
# section is the one exception to hermeticity: it runs the real disk-check on
# this machine (read-only by design) and asserts only that the printed tags
# are consistent with the exit status.
#
# Run from anywhere after any edit to 85-disk.sh (~2 s).
# Last line follows the tests/gsync convention: "passed: N  failed: M";
# exit 0 iff nothing failed. Requires bash 5+, GNU coreutils.
set -u
SB="$(mktemp -d "${TMPDIR:-/tmp}/disk-pair.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODULE="$CFG_ROOT/bash/.bashrc.d/85-disk.sh"

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
silently() { "$@" >/dev/null 2>&1; }
rc_in_contract() { [[ "$1" == [012] ]]; }

# --- stubs ------------------------------------------------------------------
mkdir -p "$SB/bin" "$SB/state"
export CALLLOG="$SB/calls.log"

cat > "$SB/bin/findmnt" <<'EOF'
#!/usr/bin/env bash
printf '%b' "${STUB_FINDMNT-}"
EOF

cat > "$SB/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
v="${STUB_SMARTD-active}"
echo "$v"
[[ "$v" == active ]]
EOF

cat > "$SB/bin/journalctl" <<'EOF'
#!/usr/bin/env bash
if [[ "${STUB_JOURNAL-}" == FAIL ]]; then
  echo "Failed to open system journal: Operation not permitted" >&2
  exit 1
fi
printf '%b' "${STUB_JOURNAL-}"
EOF

# Emits source/target/pcent/avail rows (the --output order the module asks
# for) under a header line the module strips with tail.
cat > "$SB/bin/df" <<'EOF'
#!/usr/bin/env bash
if [[ "${STUB_DF-}" == FAIL ]]; then echo "df: boom" >&2; exit 1; fi
printf 'Filesystem Mounted on Use%% Avail\n'
printf '%b' "${STUB_DF-/dev/root / 5% 900000000\n}"
EOF

cat > "$SB/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$CALLLOG"
if [[ "${1-}" == -v ]]; then exit "${STUB_SUDO_RC-0}"; fi
exec "$@"
EOF

# balance/scrub exit per STUB_*_RC; a real (second, filtered) balance changes
# the filesystem, so STUB_BALANCE_HOOK lets a test mutate the sysfs fixture
# at that point, the way an actual reclaim would.
cat > "$SB/bin/btrfs" <<'EOF'
#!/usr/bin/env bash
printf 'btrfs %s\n' "$*" >>"$CALLLOG"
case "${1-}" in
  balance)
    if [[ "$*" != *"-dusage=0"* && -n "${STUB_BALANCE_HOOK-}" ]]; then
      bash -c "$STUB_BALANCE_HOOK"
    fi
    exit "${STUB_BALANCE_RC-0}" ;;
  scrub) exit "${STUB_SCRUB_RC-0}" ;;
esac
exit 0
EOF

chmod +x "$SB/bin/"*
ORIG_PATH="$PATH"
PATH="$SB/bin:$PATH"

# --- sysfs fixtures ---------------------------------------------------------
SYSFS="$SB/sysfs"
export DISK_SYSFS="$SYSFS" DISK_STATE_DIR="$SB/state"

G=1073741824
U1=11111111-1111-1111-1111-111111111111
U2=22222222-2222-2222-2222-222222222222

# mkfs UUID TOTAL_G DATA_TOTAL_G DATA_USED_G META_TOTAL_G META_USED_G [WRITE_ERRS]
# Metadata is modeled DUP (disk_total = 2x logical), matching Fedora
# defaults; system chunks a fixed 16M. Unallocated works out to
#   TOTAL - DATA_TOTAL - 2*META_TOTAL - 16M.
mkfs() {
  local u="$1" total="$2" dt="$3" du="$4" mt="$5" mu="$6" errs="${7-0}"
  local base="$SYSFS/$u"
  rm -rf "$base"
  mkdir -p "$base/devices/dev0" "$base"/allocation/{data,metadata,system} "$base/devinfo/1"
  echo $(( total * G / 512 ))   > "$base/devices/dev0/size"
  echo $(( dt * G ))            > "$base/allocation/data/disk_total"
  echo $(( dt * G ))            > "$base/allocation/data/total_bytes"
  echo $(( du * G ))            > "$base/allocation/data/bytes_used"
  echo $(( mt * G * 2 ))        > "$base/allocation/metadata/disk_total"
  echo $(( mt * G ))            > "$base/allocation/metadata/total_bytes"
  echo $(( mu * G ))            > "$base/allocation/metadata/bytes_used"
  echo $(( 16 * 1048576 ))      > "$base/allocation/system/disk_total"
  printf 'write_errs %s\nread_errs 0\nflush_errs 0\ncorruption_errs 0\ngeneration_errs 0\n' "$errs" \
    > "$base/devinfo/1/error_stats"
}

fresh_scrub() { date -Iseconds > "$SB/state/scrub-$1"; }
old_scrub()   { date -Iseconds -d '-200 days' > "$SB/state/scrub-$1"; }
no_scrub()    { rm -f "$SB/state/scrub-$1"; }

reset_stubs() {
  export STUB_FINDMNT="/ $U1\n"
  unset STUB_SMARTD STUB_JOURNAL STUB_DF STUB_SUDO_RC \
        STUB_BALANCE_RC STUB_SCRUB_RC STUB_BALANCE_HOOK
}

# shellcheck source=/dev/null
source "$MODULE"

# run OUTVAR RCVAR cmd...: capture combined output and status, log cleared.
run() { local -n _o="$1" _r="$2"; shift 2; : >"$CALLLOG"; _r=0; _o="$("$@" 2>&1)" || _r=$?; }

# --- disk-check: healthy ----------------------------------------------------
reset_stubs
export STUB_FINDMNT="/ $U1\n/home $U1\n"
mkfs "$U1" 900 70 40 2 1
fresh_scrub "$U1"
run out rc disk-check
check "healthy: rc 0"                      [ "$rc" = 0 ]
check "healthy: headroom OK line"          contains "$out" "[ OK ] btrfs /: 826.0G unallocated"
check "healthy: metadata free shown"       contains "$out" "metadata 1.0G free"
check "healthy: no device errors line"     contains "$out" "no device errors recorded"
check "healthy: scrub age OK"              contains "$out" "scrubbed 0 days ago"
check "healthy: smartd OK"                 contains "$out" "smartd: active, no warnings"
check "healthy: fullness OK"               contains "$out" "all filesystems under 90%"
check "healthy: no FAIL anywhere"          lacks "$out" "[FAIL]"
check "healthy: no DUE anywhere"           lacks "$out" "[DUE]"
check "healthy: no WARN anywhere"          lacks "$out" "[WARN]"
check "healthy: subvolume mounts deduped"  lacks "$out" "/home"
check "healthy: check ran no sudo"         [ ! -s "$CALLLOG" ]

# --- disk-check: chunk exhaustion ladder ------------------------------------
reset_stubs
mkfs "$U1" 100 88 60 2 1     # unalloc ~ 8.0G -> DUE
fresh_scrub "$U1"
run out rc disk-check
check "low unalloc: rc 1"                  [ "$rc" = 1 ]
check "low unalloc: DUE names disk-fix"    contains "$out" "[DUE] btrfs /: unallocated low, 8.0G (threshold 16G) -- run disk-fix"
check "low unalloc: reclaimable estimate"  contains "$out" "up to ~28.0G reclaimable"

mkfs "$U1" 100 95 60 2 1     # unalloc ~ 1.0G -> crit; meta free 1G -> not imminent
run out rc disk-check
check "crit unalloc: rc 1"                 [ "$rc" = 1 ]
check "crit unalloc: FAIL verdict"         contains "$out" "[FAIL] btrfs /: unallocated down to 1.0G"

mkfs "$U1" 100 95 60 2 2     # ...and metadata full -> the bigfed scenario
run out rc disk-check
check "imminent: names ENOSPC"             contains "$out" "ENOSPC imminent, run disk-fix now"

# --- disk-check: errors, scrub age, sensors, fullness -----------------------
reset_stubs
mkfs "$U1" 900 70 40 2 1 3
fresh_scrub "$U1"
run out rc disk-check
check "device errors: rc 1"                [ "$rc" = 1 ]
check "device errors: FAIL with count"     contains "$out" "[FAIL] btrfs /: 3 device errors on record"

mkfs "$U1" 900 70 40 2 1
old_scrub "$U1"
run out rc disk-check
check "old scrub: DUE with age"            contains "$out" "[DUE] btrfs /: last scrub 200 days ago"
no_scrub "$U1"
run out rc disk-check
check "no scrub record: DUE"               contains "$out" "no scrub on record -- run disk-fix"
check "no scrub record: rc 1"              [ "$rc" = 1 ]
echo "not a date" > "$SB/state/scrub-$U1"
run out rc disk-check
check "corrupt scrub record reads as none" contains "$out" "no scrub on record"

fresh_scrub "$U1"
export STUB_SMARTD=inactive
run out rc disk-check
check "smartd off: DUE with enable hint"   contains "$out" "smartd: not running"
check "smartd off: rc 1"                   [ "$rc" = 1 ]
reset_stubs
fresh_scrub "$U1"
export STUB_JOURNAL='Device: /dev/nvme0, FAILED SMART self-check\nDevice: /dev/nvme0, Warning\n'
run out rc disk-check
check "smartd warnings: FAIL with count"   contains "$out" "[FAIL] smartd: 2 warnings"
export STUB_JOURNAL=FAIL
run out rc disk-check
check "journal unreadable: WARN not OK"    contains "$out" "[WARN] smartd: active, but the system journal is unreadable"
check "journal unreadable: rc 2"           [ "$rc" = 2 ]

reset_stubs
export STUB_DF='/dev/root / 5% 900000000\n/dev/sdb1 /var 95% 1000000\n'
run out rc disk-check
check "df full: FAIL names mountpoint"     contains "$out" "[FAIL] fullness: /var is 95% full"
export STUB_DF=FAIL
run out rc disk-check
check "df failure: WARN not silence"       contains "$out" "[WARN] fullness: df failed"

# --- disk-check: degraded environments --------------------------------------
reset_stubs
export STUB_FINDMNT=""
run out rc disk-check
check "no btrfs: says so, still runs"      contains "$out" "no btrfs filesystems mounted"
check "no btrfs: rc 0 when rest healthy"   [ "$rc" = 0 ]
export STUB_FINDMNT="/ $U2\n"
run out rc disk-check
check "missing sysfs: WARN, never healthy" contains "$out" "[WARN] btrfs /: cannot read"
check "missing sysfs: rc 2"                [ "$rc" = 2 ]

# --- disk-fix ---------------------------------------------------------------
reset_stubs
mkfs "$U1" 900 70 40 2 1
fresh_scrub "$U1"
run out rc disk-fix
check "fix healthy: nothing to do"         contains "$out" "[ OK ] nothing to do"
check "fix healthy: rc 0"                  [ "$rc" = 0 ]
check "fix healthy: no sudo at all"        [ ! -s "$CALLLOG" ]

mkfs "$U1" 100 88 60 2 1
fresh_scrub "$U1"
export STUB_BALANCE_HOOK="echo \$(( 42 * $G )) > '$SYSFS/$U1/allocation/data/disk_total'; echo \$(( 42 * $G )) > '$SYSFS/$U1/allocation/data/total_bytes'"
run out rc disk-fix
check "fix balance: announces plan"        contains "$out" "due: filtered data balance on /"
check "fix balance: dusage=0 first"        contains "$(cat "$CALLLOG")" "btrfs balance start -dusage=0 /"
check "fix balance: then filtered dusage"  contains "$(cat "$CALLLOG")" "btrfs balance start -dusage=50 /"
check "fix balance: reports reclaim"       contains "$out" "balance reclaimed 46.0G -- unallocated now 54.0G"
check "fix balance: rc 0"                  [ "$rc" = 0 ]

reset_stubs
mkfs "$U1" 100 88 84 2 1     # slack 4G: balance cannot save this disk
fresh_scrub "$U1"
run out rc disk-fix
check "fix full disk: honest FAIL"         contains "$out" "the filesystem is genuinely filling"
check "fix full disk: rc 1"                [ "$rc" = 1 ]

mkfs "$U1" 900 70 40 2 1
no_scrub "$U1"
run out rc disk-fix
check "fix scrub: runs btrfs scrub -Bd"    contains "$(cat "$CALLLOG")" "btrfs scrub start -Bd /"
check "fix scrub: reports clean"           contains "$out" "scrub clean -- recorded"
check "fix scrub: records a parseable date" silently date -d "$(cat "$SB/state/scrub-$U1")" +%s
check "fix scrub: rc 0"                    [ "$rc" = 0 ]

no_scrub "$U1"
export STUB_SCRUB_RC=3
run out rc disk-fix
check "fix scrub trouble: FAIL verdict"    contains "$out" "scrub did not come back clean"
check "fix scrub trouble: rc 1"            [ "$rc" = 1 ]
check "fix scrub trouble: no date recorded" [ ! -e "$SB/state/scrub-$U1" ]

reset_stubs
no_scrub "$U1"
export STUB_SUDO_RC=1
run out rc disk-fix
check "fix no root: rc 2"                  [ "$rc" = 2 ]
check "fix no root: WARN verdict"          contains "$out" "root required"
check "fix no root: nothing was run"       lacks "$(cat "$CALLLOG")" "btrfs"
reset_stubs
export STUB_FINDMNT="/ $U2\n"
run out rc disk-fix
check "fix blind: refuses, rc 2"           [ "$rc" = 2 ]

# --- live section (read-only) -----------------------------------------------
# The real disk-check on this machine: real sysfs, real journal, real df.
# Verdicts are machine-dependent, so assert only the tag/exit-status
# contract -- the same discipline as tests/reboot-verdict.
live_rc=0
live_out="$(env -u DISK_SYSFS -u DISK_STATE_DIR -u STUB_FINDMNT PATH="$ORIG_PATH" \
  bash -c "source '$MODULE'; disk-check" 2>&1)" || live_rc=$?
check "live: exit status in contract"      rc_in_contract "$live_rc"
check "live: printed at least one verdict" contains "$live_out" "["
if [[ "$live_out" == *"[FAIL]"* || "$live_out" == *"[DUE]"* ]]; then
  check "live: FAIL/DUE tag matches rc 1"  [ "$live_rc" = 1 ]
elif [[ "$live_out" == *"[WARN]"* ]]; then
  check "live: WARN tag matches rc 2"      [ "$live_rc" = 2 ]
else
  check "live: all-OK matches rc 0"        [ "$live_rc" = 0 ]
fi

echo "passed: $pass  failed: $fail"
(( fail == 0 ))
