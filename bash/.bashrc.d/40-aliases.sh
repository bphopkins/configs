# Does this machine actually need a reboot? Answers the question a daily
# `sysupgrade` habit raises -- reboot on dnf's own hint, not on reflex.
#
# `dnf needs-restarting` (from dnf5-plugins) compares the install time of a set
# of core packages against boot time: the kernel, systemd, the Red Hat core-libs
# list <https://access.redhat.com/solutions/27943>, plus anything carrying a
# `reboot_suggested` advisory. That is precisely "do the upgrades themselves
# recommend a reboot", which is why nothing here second-guesses it.
#
# Read from --json, NOT from the exit status. The command exits 1 both for
# "reboot required" AND for its own failures -- `dnf -C needs-restarting` on a
# cold cache exits 1 with "no cache for repository" -- so an exit-code test
# reports a phantom reboot on any error. `reboot_required` is a documented JSON
# field; the human-readable text is neither a contract nor untranslated.
#
# The package array is sliced out by delimiter, not by line range, so the list
# stays correct if dnf5 ever stops pretty-printing (a `/"packages"/,/]/` range
# over minified JSON scrapes the sibling keys as package names -- verified).
#
# No `-C`: with any existing metadata cache this works offline (verified under
# `unshare -n`, both fresh and expired), while `-C` is exactly the cold-cache
# false positive above. Runs unprivileged -- it reads the rpmdb, so calling it
# outside `sysupgrade` never raises a sudo prompt.
#
# Both dnf calls take `</dev/null`, and it is load-bearing (added 2026-08-09
# after a real 6-minute silent hang). With a tty on stdin, dnf asks its
# OpenPGP key-import question and blocks in read() -- and a pty reproduction
# (2026-08-09, dnf5 5.4.2.1) showed the question text never even flushes
# through a captured stdout, so the hang has no visible sign anywhere: a
# question that was never displayed is indistinguishable from a crash.
# Closing stdin makes blocking structurally impossible (stronger than
# `--assumeno`, which depends on dnf honouring it for every prompt type).
# What then happens, measured same day: the question lands on stderr instead
# (the stream is not a contract either way), EOF declines it, and dnf simply
# SKIPS the unverifiable repo and succeeds -- the verdict silently loses that
# one repo's advisories, dnf's own choice. So the key prompt alone no longer
# even degrades the check; the hybrid fallback below is for the genuine hard
# failures (offline with a cold cache, missing plugin, corrupt cache).
#
# What triggered it: dnf5 keeps a per-repo OpenPGP keyring inside its metadata
# cache, distinct from the rpmdb's `gpg-pubkey` entries (rpmdb signs *packages*;
# this keyring verifies repo *metadata*, and only for repos with
# `repo_gpgcheck=1` -- here, tailscale alone). Clearing `~/.cache/libdnf5`
# destroys it, so the next *unprivileged* dnf run re-prompts even though
# `rpm -q gpg-pubkey` still lists the key. Root's cache is separate, which is
# why `sudo dnf upgrade` was unaffected and only the verdict step stalled.
#
# Hybrid fallback (2026-08-09): repo metadata is a real input to the full
# check (any package carrying a `reboot_suggested` advisory joins the
# important set -- documented in dnf5-needs-restarting(8)), and metadata
# access is also the only input here that CAN fail: the keyring prompt above,
# or a cold cache with no network. So when the full check yields no parseable
# verdict, it is retried with --disable-repo='*' (the canonical dnf5 spelling;
# --disablerepo is the compat alias), which loads no metadata at all -- no
# network, no keyring, works with zero cache -- and the core-package verdict
# is reported flagged as degraded. Exit codes stay verdict-matched (a degraded
# OK is still 0; rc 2 remains "no verdict at all"); honesty lives in the
# message instead, which shrinks its claim to its evidence ("no core updates
# since boot", never "nothing has changed") and carries its own remedy: run
# `dnf needs-restarting` in a terminal, where the cause -- usually the key
# prompt -- is visible and answerable once. A degraded REBOOT needs no
# hedging: advisories can only ever ADD packages to the important set, so
# "yes" is certain without them. Declined alternatives: --disable-repo='*'
# always (silently narrows the verdict against the intent above); rc 2 for a
# degraded no (scrambles the tag<->rc contract over a flagged, mostly-answered
# question); recognising the prompt by its text (not a contract -- see above).
#
# The service scan is different: the man page defines -s purely as "package
# or dependency updated since the service started" -- an rpmdb question with
# no advisory input -- so THAT call runs with --disable-repo='*'
# unconditionally: immune and ~1.2s faster at zero semantic cost. (Measured
# identical output 2026-08-09; the scan was empty that day, so the man-page
# definition, not the measurement, carries the semantic claim.)
#
# Both dnf calls also keep stderr's first line now and surface it in the
# degraded/[WARN] messages -- before 2026-08-09 a non-prompt failure (corrupt
# cache, missing plugin) produced a [WARN] that explained nothing.
#
# Join a list for display: first few names, then "+N more". Unit names lose
# their `.service` suffix -- 20-odd of those is a wall of text otherwise.
_reboot_list() { # $1 = how many to show, rest = items
  local show="$1" out
  shift
  local -a items=("${@%.service}")
  local n=${#items[@]} IFS=','
  out="${items[*]:0:show}"
  out="${out//,/, }"
  ((n > show)) && out+=", +$((n - show)) more"
  printf '%s' "$out"
}

# Ask a systemd manager which of these units it knows, one call for the lot.
#
# `show -p` is systemd's property interface -- the same data as its D-Bus API,
# emitted as Key=Value in blank-line-separated blocks. `list-units` was the
# obvious alternative and is the wrong one: it prints a human table, the kind of
# output systemctl(1) flags as unsuitable for programmatic consumption, so its
# columns are free to move in a way properties are not.
#
# Blocks are parsed order-independently, and that is not fastidiousness:
# systemd emits properties in its own canonical order, NOT the requested one
# (`-p LoadState -p Id` still comes back Id-first -- verified), so anything
# zipping by position would be silently wrong. `Id=` is echoed even for a unit
# the manager has never heard of, so every block self-identifies.
_reboot_loaded_in() { # $1 = --system|--user, rest = unit names
  local scope="$1"
  shift
  systemctl "$scope" show -p Id -p LoadState -- "$@" 2>/dev/null |
    awk 'BEGIN { RS = ""; FS = "\n" }
         {
           id = ""; loaded = 0
           for (i = 1; i <= NF; i++) {
             if ($i ~ /^Id=/) id = substr($i, 4)
             else if ($i == "LoadState=loaded") loaded = 1
           }
           if (loaded && id != "") print id
         }'
}

# Partition the stale-service list by systemd scope, printing "<scope>\t<unit>".
# Returns 2 when the scan itself could not run, printing (instead of data) the
# first line of dnf's stderr so the caller can say WHY -- the caller must
# surface that, never conflate it with "nothing stale".
#
# dnf reports a bare unit name and nothing else -- its --json carries only
# `type` and `unit`, with no scope -- yet names genuinely collide across the two
# managers: `systemd-tmpfiles-setup.service` and `uresourced.service` are loaded
# in system AND user scope on this machine. So scope is asked of systemd, and
# the system manager is asked FIRST, which resolves a collision to `system`.
#
# That is the conservative direction on purpose. Claiming a re-login suffices
# when it does not is the one genuinely wrong answer this function can give, so
# anything ambiguous -- a name in both managers, or in neither -- is treated as
# needing more than a logout. A machine with no user manager at all (an SSH
# session without lingering) simply classifies everything as system.
_reboot_stale_services() {
  local unit out err="" errf sys_loaded user_loaded
  local -a stale=()
  # Success is judged by stdout shape, never by exit status: `-s` overloads
  # exit 1 for "services need restarting" as well as for its own failures
  # (documented -- the same trap the header describes for the main check). On
  # success the contract is a JSON array, `[]` when nothing is stale; a failed
  # scan leaves stdout empty with errors on stderr (both measured 2026-08-08).
  # No array, no verdict. Repos are disabled outright -- rpmdb-only semantics,
  # see the header -- so this call can never touch network or keyring.
  errf="$(mktemp "${TMPDIR:-/tmp}/reboot-check.XXXXXX")" || errf=/dev/null
  out="$(dnf needs-restarting -s --json --disable-repo='*' 2>"$errf" </dev/null)"
  [[ "$errf" != /dev/null ]] && { err="$(head -n1 -- "$errf" | head -c 160)"; rm -f -- "$errf"; }
  if [[ "$out" != *\[* ]]; then
    printf '%s' "$err"
    return 2
  fi
  # dnf lists a unit once per stale dependency, hence sort -u.
  mapfile -t stale < <(grep -o '"unit"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$out" |
    sed 's/^.*:[[:space:]]*"//; s/"$//' | sort -u)
  ((${#stale[@]})) || return 0

  sys_loaded="$(_reboot_loaded_in --system "${stale[@]}")"
  user_loaded="$(_reboot_loaded_in --user "${stale[@]}")"
  for unit in "${stale[@]}"; do
    if grep -qxF -- "$unit" <<<"$sys_loaded"; then
      printf 'system\t%s\n' "$unit"
    elif grep -qxF -- "$unit" <<<"$user_loaded"; then
      printf 'session\t%s\n' "$unit"
    else
      printf 'system\t%s\n' "$unit"
    fi
  done
}

# Exit status: 0 nothing to do, 1 reboot, 2 could not tell, 3 re-login.
reboot-check() {
  local json seg verdict list noun count color="" reset="" degraded="" degnote="" err="" errf
  local -a pkgs=()
  errf="$(mktemp "${TMPDIR:-/tmp}/reboot-check.XXXXXX")" || errf=/dev/null
  json="$(dnf needs-restarting --json 2>"$errf" </dev/null)"
  if ! [[ "$json" =~ \"reboot_required\"[[:space:]]*:[[:space:]]*(true|false) ]]; then
    # No parseable verdict from the full check: degrade rather than give up.
    # See "Hybrid fallback" in the header.
    json="$(dnf needs-restarting --json --disable-repo='*' 2>>"$errf" </dev/null)"
    degraded=1
  fi
  [[ "$errf" != /dev/null ]] && { err="$(head -n1 -- "$errf" | head -c 160)"; rm -f -- "$errf"; }

  if [[ "$json" =~ \"reboot_required\"[[:space:]]*:[[:space:]]*true ]]; then
    verdict=yes
  elif [[ "$json" =~ \"reboot_required\"[[:space:]]*:[[:space:]]*false ]]; then
    verdict=no
  else
    verdict=unknown
  fi
  [[ -n "$degraded" && "$verdict" != unknown ]] &&
    degnote=" [degraded: advisories not consulted -- ${err:-no error output}; to see and fix the cause, run: dnf needs-restarting]"

  [[ -t 1 ]] && reset=$'\e[0m'

  case "$verdict" in
    yes)
      if [[ "$json" == *'"packages"'* ]]; then
        seg="${json//$'\n'/}"   # one line, so the slices below can't straddle
        seg="${seg#*\"packages\"}"
        seg="${seg#*\[}"
        seg="${seg%%\]*}"
        mapfile -t pkgs < <(grep -o '"[^"]*"' <<<"$seg" | tr -d '"')
      fi
      count=${#pkgs[@]}
      if ((count)); then
        ((count == 1)) && noun=package || noun=packages
        list=" -- $count core $noun updated since boot: $(_reboot_list 4 "${pkgs[@]}")"
      else
        list=" -- core updates landed since boot"
      fi
      [[ -n "$reset" ]] && color=$'\e[33m'
      printf '%s[REBOOT]%s Reboot recommended%s%s\n' "$color" "$reset" "$list" "$degnote"
      return 1
      ;;
    no)
      # Only now is the service scan worth its ~3s: if a reboot is already
      # recommended, whether a logout would ALSO have sufficed is moot. So the
      # common post-upgrade path never pays for this.
      local line svc
      local -a session=() system=()
      if ! svc="$(_reboot_stale_services)"; then
        # Fail loud, mirroring the main check. These verdicts fire rarely by
        # design, so a scan that died silently would be indistinguishable from
        # a clean machine indefinitely -- and "[ OK ]" would claim more than
        # was checked. Distinct message from the plugin-missing WARN below:
        # here dnf answered the core question and only this scan failed. On
        # failure $svc holds the helper's stderr excerpt, not data.
        [[ -n "$reset" ]] && color=$'\e[31m'
        printf '%s[WARN]%s No core updates since boot, but the service scan failed (%s) -- stale-service status unknown\n' \
          "$color" "$reset" "${svc:-no error output}"
        return 2
      fi
      while IFS= read -r line; do
        case "$line" in
          system*) system+=("${line#*$'\t'}") ;;
          session*) session+=("${line#*$'\t'}") ;;
        esac
      done <<<"$svc"

      if ((${#system[@]})); then
        # Not a kernel-level reboot, but not a logout either: these run outside
        # the session. Named as a reboot because that is the blunt fix and the
        # habit anyway; the surgical one is offered alongside.
        ((${#system[@]} == 1)) && noun=service || noun=services
        [[ -n "$reset" ]] && color=$'\e[33m'
        printf '%s[REBOOT]%s Reboot recommended -- %d system %s running stale code: %s (or: systemctl restart <unit>)%s\n' \
          "$color" "$reset" "${#system[@]}" "$noun" "$(_reboot_list 3 "${system[@]}")" "$degnote"
        return 1
      elif ((${#session[@]})); then
        ((${#session[@]} == 1)) && noun=service || noun=services
        [[ -n "$reset" ]] && color=$'\e[36m'
        printf '%s[RELOGIN]%s Re-login recommended -- nothing core changed, but %d session %s running stale code: %s%s\n' \
          "$color" "$reset" "${#session[@]}" "$noun" "$(_reboot_list 3 "${session[@]}")" "$degnote"
        return 3
      fi

      [[ -n "$reset" ]] && color=$'\e[32m'
      if [[ -n "$degraded" ]]; then
        # The claim shrinks to the evidence: core packages and services were
        # checked, advisories were not -- so "nothing has changed" would
        # overclaim, and the line says exactly what was verified.
        printf '%s[ OK ]%s No reboot needed -- no core updates or stale services since boot%s\n' \
          "$color" "$reset" "$degnote"
      else
        printf '%s[ OK ]%s No reboot needed -- nothing has changed since boot\n' \
          "$color" "$reset"
      fi
      return 0
      ;;
    *)
      # Both attempts failed -- and the fallback loads no repo metadata, so a
      # hidden key prompt cannot be the cause here: this is dnf itself broken
      # or absent. Say what stderr said instead of guessing.
      [[ -n "$reset" ]] && color=$'\e[31m'
      printf '%s[WARN]%s Reboot status unknown -- dnf needs-restarting failed even with repos disabled (%s; is dnf5-plugins installed?)\n' \
        "$color" "$reset" "${err:-no error output}"
      return 2
      ;;
  esac
}

# Daily driver: dnf, then flatpak, then a verdict on whether that actually
# earned a reboot. A function rather than an alias because an alias cannot run
# anything *after* the chain.
#
# The verdict runs unconditionally -- even a failed upgrade leaves the question
# "is this machine currently running stale core code?" worth answering, and the
# answer comes from the rpmdb, not from the run that just failed.
#
# Returns the *chain's* status, not the verdict's, so `sysupgrade && ...` keeps
# meaning "the upgrade succeeded" and isn't derailed by reboot-check's rc 1.
# Only dnf is consulted: flatpaks are sandboxed userspace, so they can never
# oblige a reboot -- at most restarting the app.
#
# The unalias is load-bearing, not defensive tidiness. `sysupgrade` was an alias
# until 2026-08-08, and aliases expand at PARSE time: in a shell that still has
# the old one in memory, `reload` expands the `sysupgrade` in the line below and
# this file dies with a syntax error -- taking every definition after it (reload,
# byebye, the navigation aliases) down silently. Must stay until both machines
# have started a fresh login shell, and costs nothing to keep. Own line so it is
# executed before the function definition below is parsed.
unalias sysupgrade 2>/dev/null || :
sysupgrade() {
  sudo dnf upgrade --refresh -y \
    && sudo dnf autoremove -y \
    && flatpak update -y \
    && flatpak uninstall --unused -y
  local rc=$?   # one line: a bare `local rc` would clobber $? with its own
  echo
  reboot-check
  return "$rc"
}

# Updates packages *within* a release; tlmgr refuses to cross a release
# boundary by design. For a new release year, do a parallel install instead.
# tlmgr is resolved through PATH so this never goes stale on a year bump; the
# absolute path is passed to sudo because secure_path would otherwise discard
# the TeX Live PATH entry.
alias tl-upgrade='sudo "$(command -v tlmgr)" update --self --all'

# Typo-proof re-source. Never type `source ~/.bash...` by hand again: tab can
# complete it to ~/.bash_history, and sourcing history REPLAYS every command
# in it. The `;` (not `&&`) keeps the confirmation even if a module returns
# nonzero; any real error prints above it.
alias reload='source ~/.bashrc; echo "~/.bashrc reloaded"'

# Power off now. `shutdown` on its own looks broken but isn't: it's a symlink
# to systemctl, and for SysV compat a bare invocation defaults to `+1`, so it
# SCHEDULES for one minute out rather than acting (cancel with `shutdown -c`).
# `poweroff` is the immediate verb. No sudo -- polkit authorizes power-off for
# an active local session. Block inhibitors are honoured, so this refuses while
# a dnf transaction is mid-flight and names the culprit; override with -i.
alias byebye='systemctl poweroff'

# Move+List Shortcuts
alias lsa='ls -a --group-directories-first'
alias home='cd ~ && lsa'
alias desktop='cd ~/Desktop && lsa'
alias configs='cd ~/Desktop/configs && lsa'
alias teaching='cd ~/Desktop/teaching && lsa'
alias logic='cd ~/Desktop/teaching/logic && lsa'

# Editing shortcuts
alias configure='cd ~/Desktop/configs && nvim'
alias dissertate='cd ~/Desktop/dissertation && nvim'
alias homepage='cd ~/Desktop/bphopkins.net && nvim'
alias teach='cd ~/Desktop/teaching && nvim'
alias nousowl='cd ~/Desktop/nousowl.net && nvim'
alias cc='claude --model "opus[1m]" --effort max'
# 'fable' alone resolves to claude-fable-5 (standard context); the bracketed
# form is the 1M-context variant, and is what settings.json already selects
# for a bare `claude`. Quoted because [1m] is a glob pattern.
alias ccf='claude --model "fable[1m]" --effort max'
