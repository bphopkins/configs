#!/usr/bin/env bash
# Regression suite for the reboot-verdict layer in bash/.bashrc.d/40-aliases.sh
# (reboot-check, the _reboot_* helpers, and sysupgrade's status contract).
# Written 2026-08-08 alongside the fail-loud service-scan fix; the "svc dead"
# checks below fail against the pre-fix code, which read a failed scan as an
# empty result and printed a false "[ OK ]".
#
# Hermetic: dnf, systemctl, sudo, and flatpak are PATH-stubbed under a $TMPDIR
# sandbox -- no package operations, no privileges, no network. The stub dnf
# speaks the JSON contract from dnf5-needs-restarting(8); the stub systemctl
# emits LoadState before Id deliberately, because real systemd returns
# properties in its own canonical order, not the requested one -- a parser
# that zips by position must fail here. The final "live" section is the one
# exception to hermeticity: it runs the real reboot-check (read-only: rpmdb
# and systemd properties) and asserts only that the printed tag matches the
# exit status, plus -- when the real dnf JSON is obtainable -- that the
# contract the stubs encode still holds on this machine.
#
# Run from anywhere after any edit to the verdict functions, or when a dnf5
# update makes verdicts look wrong (~10 s, most of it the live section).
# Last line follows the tests/gsync convention: "passed: N  failed: M";
# exit 0 iff nothing failed. Requires bash 5+, GNU coreutils.
set -u
SB="$(mktemp -d "${TMPDIR:-/tmp}/reboot-verdict.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ALIASES="$CFG_ROOT/bash/.bashrc.d/40-aliases.sh"

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }

# --- stubs ------------------------------------------------------------------
mkdir -p "$SB/bin"

# dnf: upgrade/autoremove obey STUB_UPGRADE (ok|FAIL); needs-restarting emits
# STUB_MAIN -- or, with -s, STUB_SVC -- verbatim on stdout, or simulates a
# failure (error on stderr, exit 1, empty stdout: the measured real shape) or
# a degenerate blank line.
cat > "$SB/bin/dnf" <<'EOF'
#!/usr/bin/env bash
if [[ "${1-}" == upgrade || "${1-}" == autoremove ]]; then
  if [[ "${STUB_UPGRADE-ok}" == FAIL ]]; then echo "stub: $1 failed" >&2; exit 1; fi
  echo "stub: $1 ok"; exit 0
fi
v="${STUB_MAIN-}"
[[ " $* " == *" -s "* ]] && v="${STUB_SVC-}"
case "$v" in
  FAIL)  echo "stub: simulated needs-restarting failure" >&2; exit 1 ;;
  BLANK) echo ;;
  # PROMPT reproduces the 2026-08-09 hang: real dnf writes an OpenPGP
  # key-import prompt to STDOUT -- the same stream as --json, so the caller
  # must capture it and therefore can never display it -- then blocks in
  # read() on stdin. Record which we got, so reboot-check's `</dev/null`
  # guard is asserted rather than assumed; without it, dnf consumes the
  # caller's stdin and (on a terminal) waits forever with nothing on screen.
  PROMPT)
    printf 'Importing OpenPGP key 0x957F5868:\nIs this ok [y/N]: '
    if read -r _; then echo HAD_DATA > "${STUB_PROBE:-/dev/null}"
    else echo EOF > "${STUB_PROBE:-/dev/null}"; fi
    exit 1 ;;
  *)     printf '%s\n' "$v" ;;
esac
EOF

# systemctl: `--system|--user show -p ... -- unit...`. Units listed in
# STUB_SYS_LOADED / STUB_USER_LOADED (space-separated) report loaded, all
# others not-found; STUB_USER_BROKEN=1 makes the user manager unreachable
# (SSH-without-lingering). LoadState precedes Id on purpose -- see header.
cat > "$SB/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
scope="${1-}"; shift
loaded=" ${STUB_SYS_LOADED-} "
if [[ "$scope" == --user ]]; then
  [[ "${STUB_USER_BROKEN-}" == 1 ]] && { echo "Failed to connect to bus" >&2; exit 1; }
  loaded=" ${STUB_USER_LOADED-} "
fi
while (($#)) && [[ "$1" != -- ]]; do shift; done
shift || :
first=1
for u in "$@"; do
  ((first)) || echo
  first=0
  if [[ "$loaded" == *" $u "* ]]; then echo "LoadState=loaded"; else echo "LoadState=not-found"; fi
  echo "Id=$u"
done
EOF

cat > "$SB/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF

cat > "$SB/bin/flatpak" <<'EOF'
#!/usr/bin/env bash
echo "stub: flatpak $1"
EOF

chmod +x "$SB/bin/dnf" "$SB/bin/systemctl" "$SB/bin/sudo" "$SB/bin/flatpak"

# vrun [VAR=VAL...] CMD -- run CMD in a fresh shell under the stub PATH.
out='' rc=0
vrun() {
  local cmd="${!#}"
  out="$(env "${@:1:$#-1}" PATH="$SB/bin:$PATH" \
    bash -c "source '$ALIASES'; $cmd" 2>&1)"
  rc=$?
}

# JSON fixtures: the pretty-printed shape real dnf5 emits, plus a minified
# variant -- the parser must not depend on line structure.
MAIN_FALSE='[
  {
    "type":"reboot",
    "reboot_required":false,
    "packages":[],
    "documentation":"https://access.redhat.com/solutions/27943"
  }
]'
MAIN_TRUE_MIN='[{"type":"reboot","reboot_required":true,"packages":["kernel-core","glibc","systemd","openssl-libs","foo","bar"],"documentation":"x"}]'
MAIN_TRUE_NOPKG='[{"type":"reboot","reboot_required":true,"packages":[],"documentation":"x"}]'
MAIN_NO_FIELD='[{"type":"reboot","documentation":"x"}]'
svc_json() { # svc_json UNIT... -> services-mode JSON array
  local u first=1 j='['
  for u in "$@"; do ((first)) || j+=','; first=0; j+='{"type":"service","unit":"'"$u"'"}'; done
  printf '%s]' "$j"
}

# --- sourcing sanity --------------------------------------------------------
out="$(bash -c "source '$ALIASES'" 2>&1)"; rc=$?
check "sourcing: silent"                 [ -z "$out" ]
check "sourcing: rc=0"                   [ "$rc" -eq 0 ]

# --- verdicts from the core package check -----------------------------------
vrun STUB_MAIN="$MAIN_FALSE" STUB_SVC='[]' reboot-check
check "clean: [ OK ]"                    contains "$out" "[ OK ] No reboot needed"
check "clean: rc=0"                      [ "$rc" -eq 0 ]

vrun STUB_MAIN="$MAIN_TRUE_MIN" STUB_SVC='[]' reboot-check
check "core: [REBOOT]"                   contains "$out" "[REBOOT] Reboot recommended"
check "core: count and names"            contains "$out" "6 core packages updated since boot: kernel-core, glibc"
check "core: truncation"                 contains "$out" "+2 more"
check "core: rc=1"                       [ "$rc" -eq 1 ]

vrun STUB_MAIN="$MAIN_TRUE_NOPKG" STUB_SVC='[]' reboot-check
check "no pkg list: fallback wording"    contains "$out" "core updates landed since boot"
check "no pkg list: rc=1"                [ "$rc" -eq 1 ]

vrun STUB_MAIN=FAIL reboot-check
check "dnf dead: [WARN]"                 contains "$out" "Reboot status unknown"
check "dnf dead: names the likely fix"   contains "$out" "dnf5-plugins"
check "dnf dead: rc=2"                   [ "$rc" -eq 2 ]

vrun STUB_MAIN="$MAIN_NO_FIELD" reboot-check
check "schema drift: [WARN], no guess"   contains "$out" "Reboot status unknown"
check "schema drift: rc=2"               [ "$rc" -eq 2 ]

# --- a hidden dnf prompt must not hang (the 2026-08-09 fix) ------------------
# Feeding stdin "y" proves the guard structurally: with `</dev/null` the stub
# sees EOF, so dnf cannot consume the caller's input and cannot block. Drop the
# redirect from 40-aliases.sh and the probe reads HAD_DATA instead -- and on a
# real terminal that same code path waits for a keystroke forever.
PROBE="$SB/stdin-probe"
vrun STUB_MAIN=PROMPT STUB_PROBE="$PROBE" reboot-check <<<"y"
check "prompt: dnf got EOF, not our stdin" [ "$(cat "$PROBE" 2>/dev/null)" = EOF ]
check "prompt: [WARN], not a false verdict" contains "$out" "Reboot status unknown"
check "prompt: names the hidden-prompt case" contains "$out" "hidden prompt"
check "prompt: rc=2"                     [ "$rc" -eq 2 ]

# --- the service scan fails loud (the 2026-08-08 fix) -----------------------
vrun STUB_MAIN="$MAIN_FALSE" STUB_SVC=FAIL reboot-check
check "svc dead: WARN, not OK"           contains "$out" "service scan failed"
check "svc dead: core state still told"  contains "$out" "No core updates since boot"
check "svc dead: rc=2"                   [ "$rc" -eq 2 ]

vrun STUB_MAIN="$MAIN_FALSE" STUB_SVC=BLANK reboot-check
check "svc blank: WARN, not OK"          contains "$out" "service scan failed"
check "svc blank: rc=2"                  [ "$rc" -eq 2 ]

# --- stale-service scope classification -------------------------------------
vrun STUB_MAIN="$MAIN_FALSE" STUB_SVC="$(svc_json foo.service)" \
  STUB_SYS_LOADED="foo.service" reboot-check
check "system unit: [REBOOT]"            contains "$out" "1 system service running stale code: foo"
check "system unit: surgical alt named"  contains "$out" "systemctl restart"
check "system unit: rc=1"                [ "$rc" -eq 1 ]

vrun STUB_MAIN="$MAIN_FALSE" STUB_SVC="$(svc_json bar.service)" \
  STUB_USER_LOADED="bar.service" reboot-check
check "session unit: [RELOGIN]"          contains "$out" "1 session service running stale code: bar"
check "session unit: rc=3"               [ "$rc" -eq 3 ]

vrun STUB_MAIN="$MAIN_FALSE" STUB_SVC="$(svc_json both.service)" \
  STUB_SYS_LOADED="both.service" STUB_USER_LOADED="both.service" reboot-check
check "scope collision -> system"        contains "$out" "1 system service"
check "scope collision: rc=1"            [ "$rc" -eq 1 ]

vrun STUB_MAIN="$MAIN_FALSE" STUB_SVC="$(svc_json ghost.service)" reboot-check
check "unknown unit -> system"           contains "$out" "1 system service"
check "unknown unit: rc=1"               [ "$rc" -eq 1 ]

vrun STUB_MAIN="$MAIN_FALSE" STUB_SVC="$(svc_json baz.service)" \
  STUB_USER_LOADED="baz.service" STUB_USER_BROKEN=1 reboot-check
check "no user manager -> system"        contains "$out" "1 system service"
check "no user manager: rc=1"            [ "$rc" -eq 1 ]

vrun STUB_MAIN="$MAIN_FALSE" STUB_SVC="$(svc_json dup.service dup.service)" \
  STUB_SYS_LOADED="dup.service" reboot-check
check "duplicate reports deduped"        contains "$out" "1 system service"

vrun STUB_MAIN="$MAIN_FALSE" \
  STUB_SVC="$(svc_json u1.service u2.service u3.service u4.service u5.service)" \
  STUB_USER_LOADED="u1.service u2.service u3.service u4.service u5.service" reboot-check
check "5 session units: [RELOGIN]"       contains "$out" "5 session services"
check "5 session units: trunc, no .service" contains "$out" "u1, u2, u3, +2 more"
check "5 session units: rc=3"            [ "$rc" -eq 3 ]

# --- sysupgrade's status contract -------------------------------------------
vrun STUB_MAIN="$MAIN_TRUE_MIN" STUB_SVC='[]' sysupgrade
check "sysupgrade: dnf chain ran"        contains "$out" "stub: upgrade ok"
check "sysupgrade: flatpak ran"          contains "$out" "stub: flatpak update"
check "sysupgrade: verdict appended"     contains "$out" "[REBOOT]"
check "sysupgrade: rc is chain's, not verdict's" [ "$rc" -eq 0 ]

vrun STUB_MAIN="$MAIN_FALSE" STUB_SVC='[]' STUB_UPGRADE=FAIL sysupgrade
check "failed chain: verdict still runs" contains "$out" "[ OK ]"
check "failed chain: rc=1 from chain"    [ "$rc" -eq 1 ]

# --- the unalias guard ------------------------------------------------------
# The comment above sysupgrade calls its `unalias` line load-bearing: aliases
# expand at parse time, so a shell still holding the pre-2026-08-08 alias
# would hit a syntax error at `sysupgrade() {` and silently lose every
# definition after it. Recreate exactly that shell and prove the guard holds.
out="$(bash -c "shopt -s expand_aliases
alias sysupgrade='echo old-alias'
source '$ALIASES' 2>&1
declare -F sysupgrade >/dev/null && echo FUNC-OK
type -t reload >/dev/null && echo TAIL-OK" 2>&1)"
check "old-alias shell: sources clean"   lacks "$out" "syntax error"
check "old-alias shell: function wins"   contains "$out" "FUNC-OK"
check "old-alias shell: later defs live" contains "$out" "TAIL-OK"

# --- live: real reboot-check, read-only -------------------------------------
out="$(bash -c "source '$ALIASES'; reboot-check" 2>&1)"; rc=$?
tag_rc=-1
case "$out" in
  *"[ OK ]"*)    tag_rc=0 ;;
  *"[REBOOT]"*)  tag_rc=1 ;;
  *"[WARN]"*)    tag_rc=2 ;;
  *"[RELOGIN]"*) tag_rc=3 ;;
esac
check "live: recognizable verdict"       [ "$tag_rc" -ge 0 ]
check "live: rc matches printed tag"     [ "$rc" -eq "$tag_rc" ]
live_json="$(dnf needs-restarting --json 2>/dev/null)"
if contains "$live_json" reboot_required; then
  check "live: dnf JSON contract intact" lacks "$out" "Reboot status unknown"
else
  echo "note - real dnf --json unavailable here; contract-drift check skipped"
fi

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
