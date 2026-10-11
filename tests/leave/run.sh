#!/usr/bin/env bash
# Regression suite for `bye` and `byebye` in bash/.bashrc.d/40-aliases.sh
# (org/machines/transport-2026-10/rules.md: him-3, bigfed-3, bigfed-1; built
# 2026-10-10 at the pilot's seeding, pilot/seeding.md there).
#
# Sandboxed and caged (tests/cage.sh): a fake HOME with the two host files and
# one rotation repository; `systemctl` stubbed to record its arguments and act
# on nothing; the gauge stubbed to answer from STUB_LEAVE_RC / STUB_LEAVE_TEXT;
# `uname` stubbed to name the machine; `ps` stubbed to print STUB_PS_TEXT. The
# log goes to LEAVE_LOG_DIR in the sandbox. Nothing real is suspended, powered
# off, read or written. Last line follows the tests/gsync convention:
# "passed: N  failed: M"; exit 0 iff nothing failed.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$CFG_ROOT/tests/cage.sh"
cage leave "$@"

SB="$(mktemp -d "${TMPDIR:-/tmp}/leave-tests.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
must() { "$@" || { echo "SETUP-FAIL: $*"; exit 1; }; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export HOME="$SB/home"
HOSTS="$HOME/Desktop/configs/git/hosts"
mkdir -p "$HOSTS" "$SB/stub" "$SB/pilot"
printf '[gsync]\n\trole = writer\n' > "$HOSTS/bigfed.inc"
printf '[gsync]\n\treaderRepo = nousowl\n' > "$HOSTS/fedxps.inc"
must git init -q -b main "$HOME/Desktop/nousowl"
printf '#!/bin/sh\ncat "%s/host"\n' "$SB" > "$SB/stub/uname"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/systemctl.log"\nexit 0\n' "$SB" > "$SB/stub/systemctl"
cat > "$SB/stub/sync-check" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${STUB_LEAVE_LOG:-/dev/null}"
[ -n "${STUB_LEAVE_TEXT:-}" ] && printf '%b\n' "$STUB_LEAVE_TEXT"
exit "${STUB_LEAVE_RC:-0}"
STUB
printf '#!/bin/sh\nprintf "  PID COMMAND\\n"; [ -n "${STUB_PS_TEXT:-}" ] && printf "%%b\\n" "$STUB_PS_TEXT"; exit 0\n' > "$SB/stub/ps"
chmod +x "$SB"/stub/*
export STUB_LEAVE_LOG="$SB/gauge.log" LEAVE_LOG_DIR="$SB/pilot"
PATH="$SB/stub:/usr/bin:/bin"; hash -r   # never the real ~/bin: the gauge there must not be reachable

source "$CFG_ROOT/bash/.bashrc.d/50-git-sync.sh"
source "$CFG_ROOT/bash/.bashrc.d/40-aliases.sh"
REPOS_DESKTOP=("$HOME/Desktop/nousowl")
be() { printf '%s\n' "$1" > "$SB/host"; _GSYNC_ROLE=""; }
reset() { : > "$SB/systemctl.log"; : > "$SB/gauge.log"; unset STUB_LEAVE_RC STUB_LEAVE_TEXT STUB_PS_TEXT; rm -f "$HOME/Desktop/nousowl/.git/objects/maintenance.lock"; }
OKTEXT='[ OK ] nousowl: up to date\n[ OK ] readings: up to date\n[ OK ] teaching: up to date\n[ OK ] personal: up to date\n[ OK ] opuscula: up to date\n[ OK ] adelotype-data: up to date -- the known item log stays stranded on bigfed\n[ OK ] finances: up to date\n[ OK ] adelotype: up to date\n\nall clear'
FAILTEXT='[ OK ] readings: up to date\n[FAIL] nousowl: stranded on bigfed: docs/a.md | docs/b.md\n       fix: edit each listed path on fedxps\n\n1 needing attention, 0 unknown'
WARNTEXT="[WARN] nousowl: nousowl's view unread: ssh: connect to host nousowl port 22: No route to host\n       fix: ssh -o BatchMode=yes nousowl true\n\n0 needing attention, 1 unknown"

echo "== bye on fedxps, the gauge all clear =="
reset; be fedxps; export STUB_LEAVE_RC=0 STUB_LEAVE_TEXT="$OKTEXT"
out="$(bye 2>&1)"; rc=$?
check "bye: exit 0"                                   [ "$rc" -eq 0 ]
check "bye: the gauge was asked for sync"             contains "$(cat "$SB/gauge.log")" "sync"
check "bye: systemctl suspend, once"                  [ "$(cat "$SB/systemctl.log")" = "suspend" ]
check "bye: the gauge's lines shown"                  contains "$out" "[ OK ] nousowl: up to date"
check "bye: the log file is this machine's"           [ -f "$SB/pilot/log-fedxps.md" ]
check "bye: no log for the other machine"             [ ! -e "$SB/pilot/log-bigfed.md" ]
check "bye: the log has its header"                   contains "$(head -1 "$SB/pilot/log-fedxps.md")" "fedxps's lines"
check "bye: the line reads OK, 8 folders"             contains "$(tail -1 "$SB/pilot/log-fedxps.md")" "| OK, 8 folders | bye |"
check "bye: the line is dated today"                  contains "$(tail -1 "$SB/pilot/log-fedxps.md")" "| $(date '+%Y-%m-%d')"
n_before=$(wc -l < "$SB/pilot/log-fedxps.md")
out="$(bye 2>&1)"
check "bye again: the header is not repeated"         [ "$(grep -c "fedxps's lines" "$SB/pilot/log-fedxps.md")" -eq 1 ]
check "bye again: one more line"                      [ "$(wc -l < "$SB/pilot/log-fedxps.md")" -eq $((n_before + 1)) ]

echo "== byebye on bigfed, the gauge all clear =="
reset; be bigfed; export STUB_LEAVE_RC=0 STUB_LEAVE_TEXT="$OKTEXT"
out="$(byebye 2>&1)"; rc=$?
check "byebye: exit 0"                                [ "$rc" -eq 0 ]
check "byebye: systemctl poweroff, once"              [ "$(cat "$SB/systemctl.log")" = "poweroff" ]
check "byebye: logged to bigfed's file"               contains "$(tail -1 "$SB/pilot/log-bigfed.md")" "| OK, 8 folders | byebye |"

echo "== the gauge refuses =="
reset; be bigfed; export STUB_LEAVE_RC=1 STUB_LEAVE_TEXT="$FAILTEXT"
out="$(byebye 2>&1)"; rc=$?
check "FAIL: exit 1"                                  [ "$rc" -eq 1 ]
check "FAIL: nothing powered off"                     [ ! -s "$SB/systemctl.log" ]
check "FAIL: the gauge's FAIL line shown"             contains "$out" "[FAIL] nousowl: stranded on bigfed"
check "FAIL: the SKIP line names -f"                  contains "$out" "byebye -f leaves regardless"
check "FAIL: logged as refused"                       contains "$(tail -1 "$SB/pilot/log-bigfed.md")" "| byebye, refused |"
check "FAIL: the reading is the FAIL line"            contains "$(tail -1 "$SB/pilot/log-bigfed.md")" "[FAIL] nousowl: stranded on bigfed"
check "FAIL: a | in the gauge's line does not break the table" [ "$(tail -1 "$SB/pilot/log-bigfed.md" | tr -cd '|' | wc -c)" -eq 4 ]
reset; be fedxps; export STUB_LEAVE_RC=2 STUB_LEAVE_TEXT="$WARNTEXT"
out="$(bye 2>&1)"; rc=$?
check "WARN (could not determine): exit 1"            [ "$rc" -eq 1 ]
check "WARN: nothing suspended"                       [ ! -s "$SB/systemctl.log" ]
check "WARN: logged as refused with the WARN line"    contains "$(tail -1 "$SB/pilot/log-fedxps.md")" "[WARN] nousowl: nousowl's view unread"

echo "== -f and -i =="
reset; be bigfed; export STUB_LEAVE_RC=1 STUB_LEAVE_TEXT="$FAILTEXT"
out="$(byebye -f 2>&1)"; rc=$?
check "-f under FAIL: exit 0"                         [ "$rc" -eq 0 ]
check "-f under FAIL: powered off"                    [ "$(cat "$SB/systemctl.log")" = "poweroff" ]
check "-f under FAIL: logged as forced"               contains "$(tail -1 "$SB/pilot/log-bigfed.md")" "| byebye, forced |"
reset; be bigfed; export STUB_LEAVE_RC=0 STUB_LEAVE_TEXT="$OKTEXT"
out="$(byebye -i 2>&1)"
check "-i: passed to systemctl"                       [ "$(cat "$SB/systemctl.log")" = "poweroff -i" ]
out="$(byebye -f -i 2>&1)"
check "-f -i: both honoured"                          [ "$(tail -1 "$SB/systemctl.log")" = "poweroff -i" ]
reset; be bigfed
out="$(byebye -x 2>&1)"; rc=$?
check "unknown flag: usage, exit 1"                   [ "$rc" -eq 1 ]
check "unknown flag: nothing done"                    [ ! -s "$SB/systemctl.log" ]
check "unknown flag: usage names byebye"              contains "$out" "Usage: byebye"
out="$(bye -x 2>&1)"
check "unknown flag: usage names bye"                 contains "$out" "Usage: bye"

echo "== bigfed-1: maintenance on the writer =="
reset; be bigfed; export STUB_LEAVE_RC=0 STUB_LEAVE_TEXT="$OKTEXT"
export STUB_PS_TEXT=' 4242 git maintenance run --auto --no-quiet'
out="$(byebye 2>&1)"; rc=$?
check "git maintenance running: refused"              [ "$rc" -eq 1 ]
check "git maintenance running: named with its pid"   contains "$out" "git maintenance is running (pid 4242)"
check "git maintenance running: nothing powered off"  [ ! -s "$SB/systemctl.log" ]
check "git maintenance running: logged"               contains "$(tail -1 "$SB/pilot/log-bigfed.md")" "| FAIL git maintenance running | byebye, refused |"
unset STUB_PS_TEXT
mkdir -p "$HOME/Desktop/nousowl/.git/objects"; : > "$HOME/Desktop/nousowl/.git/objects/maintenance.lock"
out="$(byebye 2>&1)"; rc=$?
check "stale lock, no process: refused"               [ "$rc" -eq 1 ]
check "stale lock: the lock named with its repair"    contains "$out" "maintenance.lock stands with no git maintenance running"
out="$(byebye -f 2>&1)"; rc=$?
check "stale lock: -f leaves, exit 0"                 [ "$rc" -eq 0 ]
check "stale lock: -f powered off"                    [ "$(tail -1 "$SB/systemctl.log")" = "poweroff" ]
reset; be fedxps; export STUB_LEAVE_RC=0 STUB_LEAVE_TEXT="$OKTEXT" STUB_PS_TEXT=' 4242 git maintenance run --auto'
: > "$HOME/Desktop/nousowl/.git/objects/maintenance.lock"
out="$(bye 2>&1)"; rc=$?
check "bye (a suspend) ignores the maintenance check" [ "$rc" -eq 0 ]
check "bye: suspended regardless of the lock"         [ "$(cat "$SB/systemctl.log")" = "suspend" ]
out="$(byebye 2>&1)"; rc=$?
check "byebye on the same machine refuses it"         [ "$rc" -eq 1 ]

echo "== no gauge; no log directory =="
reset; be fedxps; rm "$SB/stub/sync-check"; hash -r
out="$(bye 2>&1)"; rc=$?
check "no gauge: acts, exit 0"                        [ "$rc" -eq 0 ]
check "no gauge: suspended"                           [ "$(cat "$SB/systemctl.log")" = "suspend" ]
check "no gauge: one hint"                            contains "$out" "no sync-check on PATH"
check "no gauge: logged as unchecked"                 contains "$(tail -1 "$SB/pilot/log-fedxps.md")" "| unchecked (no sync-check on PATH) | bye |"
printf '#!/usr/bin/env bash\nprintf "%%b\\n" "$STUB_LEAVE_TEXT"; exit "${STUB_LEAVE_RC:-0}"\n' > "$SB/stub/sync-check"; chmod +x "$SB/stub/sync-check"; hash -r
reset; be bigfed; export STUB_LEAVE_RC=0 STUB_LEAVE_TEXT="$OKTEXT" LEAVE_LOG_DIR="$SB/nowhere"
out="$(byebye 2>&1)"; rc=$?
check "no log directory: acts, exit 0"                [ "$rc" -eq 0 ]
check "no log directory: nothing written anywhere"    [ ! -e "$SB/nowhere" ]
export LEAVE_LOG_DIR="$SB/pilot"

echo "== the re-source trap: a shell still holding the old byebye alias =="
# Every open shell on both machines holds `alias byebye='systemctl poweroff'`
# from the file as it was; `reload` there must define the function and keep
# everything after it (the file's sysupgrade note has the mechanism).
r="$(bash --norc --noprofile -ic 'alias byebye="systemctl poweroff"; source "'"$CFG_ROOT"'/bash/.bashrc.d/40-aliases.sh" 2>&1; echo "byebye=$(type -t byebye) bye=$(type -t bye) lsa=$(type -t lsa 2>/dev/null || echo MISSING)"' 2>&1 | tail -1)"
check "over the old alias: byebye is the function"    contains "$r" "byebye=function"
check "over the old alias: bye is defined"            contains "$r" "bye=function"
check "over the old alias: what follows survives"     contains "$r" "lsa=alias"

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
