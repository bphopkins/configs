#!/usr/bin/env bash
# Regression suite for bin/screens-off: the sway branch (2026-10-03) and the
# GNOME branch (2026-09-06), against stubs. Written 2026-10-03 with the sway
# branch (configs DECISIONS.md, the entry of that date).
#
# No compositor is started and none is addressed; no session is locked and no
# display is touched. A stub swaymsg answers get_version for the sockets a case
# declares live and refuses the rest, serves get_outputs from a per-poll
# sequence of fixtures and get_tree from one, and records every exec body and
# the socket it went to; a stub gdbus serves a GNOME session's idle times and
# a stub loginctl its session list, and both record what they were asked. The
# socket files are real AF_UNIX sockets nothing listens on, so the script's own
# [ -S ] test is exercised. XDG_RUNTIME_DIR and SWAYSOCK point into the
# sandbox, DBUS_SESSION_BUS_ADDRESS at a path with no bus, and PATH leads with
# the stubs the suite itself writes, so nothing here can reach the live
# session.
#
# Caged: tests/cage.sh, as every suite here, although this one starts only
# bash, jq and python3.
#
# Run after any edit to bin/screens-off (~13 s: the two cases in which the
# displays never read off wait out the script's 5-s cap). SCREENS_OFF=<path>
# runs the suite against another copy of the script, which is how it was
# mutation-tested: seventeen breaks on 2026-10-03 (the -w flag, the kill, the
# watch before the lock, the socket test, any for all, inactive outputs
# counted, the manager session accepted, the bus default, GNOME first, a cap
# of 10, the dedup inverted, no pidfile, a liveness check that always passes,
# the inhibitor filter, a silent failure, lock-session 1, dpms for power),
# each failing the check meant for it; the unmutated script 43/43. Last line
# follows the tests/gsync convention:
# "passed: N  failed: M"; exit 0 iff nothing failed. Requires jq and python3.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$CFG_ROOT/tests/cage.sh"
cage screens-off "$@"

SO="${SCREENS_OFF:-$CFG_ROOT/bin/screens-off}"
HERE="$CFG_ROOT/tests/screens-off"
SB="$(mktemp -d "${TMPDIR:-/tmp}/screens-off-tests.XXXXXX")"
cleanup() { rm -rf "$SB"; }
trap cleanup EXIT

for t in jq python3; do command -v "$t" >/dev/null 2>&1 || {
  echo "screens-off tests: $t missing -- not running" >&2
  echo "passed: 0  failed: 1"; exit 2; }; done
[ -x "$SO" ] || {
  echo "screens-off tests: $SO is not executable -- not running" >&2
  echo "passed: 0  failed: 1"; exit 2; }

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
is()    { [ "$1" = "$2" ] || { echo "     got:  $1"; echo "     want: $2"; return 1; }; }
has()   { grep -qE -- "$2" <<<"$1" || { echo "     got:  $1"; echo "     want: a line matching $2"; return 1; }; }

# --- the stubs ----------------------------------------------------------------
mkdir -p "$SB/bin" "$SB/rt"
cat >"$SB/bin/swaymsg" <<'STUB'
#!/usr/bin/env bash
# stub swaymsg: records every call in STUB_ALL; answers get_version for the
# sockets in STUB_LIVE and refuses the rest; serves get_outputs from
# STUB_OUTPUTS (fixture names, one per poll, the last repeating) and get_tree
# from STUB_TREE; logs each exec body to STUB_EXEC and its socket beside it.
printf '%s\n' "$*" >>"$STUB_ALL"
sock=""; if [ "$1" = -s ]; then sock=$2; shift 2; fi
case "$*" in
  "-t get_version")
    case " ${STUB_LIVE:-} " in *" $sock "*) echo '{"human_readable": "1.11 (stub)"}'; exit 0 ;; esac
    echo "stub swaymsg: nothing answers on $sock" >&2; exit 1 ;;
  "-q exec "*)
    all="$*"; printf '%s\n' "${all#-q exec }" >>"$STUB_EXEC"; printf '%s\n' "$sock" >>"$STUB_EXEC_SOCK" ;;
  "-t get_outputs")
    n=$(( $(cat "$STUB_POLLS" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$STUB_POLLS"
    set -- $STUB_OUTPUTS; if [ "$n" -le $# ]; then fx="${!n}"; else fx="${@: -1}"; fi
    cat "$STUB_FX/outputs-$fx.json" ;;
  "-t get_tree") cat "$STUB_FX/tree-${STUB_TREE:-plain}.json" ;;
  *) echo "stub swaymsg: unexpected: $*" >&2; printf 'UNEXPECTED swaymsg %s\n' "$*" >>"$STUB_ALL"; exit 99 ;;
esac
STUB
cat >"$SB/bin/gdbus" <<'STUB'
#!/usr/bin/env bash
# stub gdbus: Mutter is on the bus iff STUB_GNOME is set; GetIdletime answers
# from STUB_IDLE (ms, one per call, the last repeating; empty: no idle
# monitor); the bus address it was handed goes to STUB_DBUS.
printf 'gdbus %s\n' "$*" >>"$STUB_ALL"
printf '%s\n' "${DBUS_SESSION_BUS_ADDRESS-unset}" >>"$STUB_DBUS"
case "$*" in
  introspect*org.gnome.Mutter.DisplayConfig*)
    [ -n "${STUB_GNOME:-}" ] && exit 0; echo "stub gdbus: no Mutter on the bus" >&2; exit 1 ;;
  call*GetIdletime*)
    n=$(( $(cat "$STUB_IDLE_N" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$STUB_IDLE_N"
    set -- $STUB_IDLE; [ $# -gt 0 ] || { echo "stub gdbus: no idle monitor" >&2; exit 1; }
    if [ "$n" -le $# ]; then v="${!n}"; else v="${@: -1}"; fi
    printf '(uint64 %s,)\n' "$v" ;;
  *) printf 'UNEXPECTED gdbus %s\n' "$*" >>"$STUB_ALL"; exit 99 ;;
esac
STUB
cat >"$SB/bin/loginctl" <<'STUB'
#!/usr/bin/env bash
# stub loginctl: bigfed's session list as of 2026-10-03 with an SSH session
# added, the graphical one listed last; lock-session records its target.
printf 'loginctl %s\n' "$*" >>"$STUB_ALL"
case "$*" in
  "list-sessions --no-legend")
    printf '%s\n' "1 1000 bph - 1258 manager - no -" "7 1000 bph - 61234 user pts/3 no -" "5 1000 bph seat0 43922 user tty2 no -" ;;
  "show-session "*" -p Type --value")
    case "$2" in 1) echo unspecified ;; 7) echo tty ;; 5) echo wayland ;; *) exit 1 ;; esac ;;
  "lock-session "*) printf '%s\n' "$2" >>"$STUB_LOCK" ;;
  *) printf 'UNEXPECTED loginctl %s\n' "$*" >>"$STUB_ALL"; exit 99 ;;
esac
STUB
cat >"$SB/bin/swayidle" <<'STUB'
#!/usr/bin/env bash
# stub swayidle: records its arguments and its pid, then stays, as the real
# one would, until killed.
printf '%s\n' "$*" >"$STUB_IDLE_ARGS"; printf '%s\n' "$$" >"$STUB_IDLE_PID"; exec sleep 30
STUB
chmod +x "$SB/bin/"*
export PATH="$SB/bin:$PATH" XDG_RUNTIME_DIR="$SB/rt" STUB_FX="$HERE/fixtures"
export STUB_ALL="$SB/all" STUB_EXEC="$SB/exec" STUB_EXEC_SOCK="$SB/exec-sock" STUB_POLLS="$SB/polls" \
  STUB_LOCK="$SB/lock" STUB_DBUS="$SB/dbus" STUB_IDLE_N="$SB/idle-n" STUB_IDLE_ARGS="$SB/idle-args" STUB_IDLE_PID="$SB/idle-pid"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$SB/no-bus-here"
unset SWAYSOCK STUB_LIVE STUB_OUTPUTS STUB_TREE STUB_GNOME STUB_IDLE
: >"$SB/ever"

mksock() { python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$1"; }
LIVE="$SB/rt/sway-ipc.1000.222.sock"; STALE="$SB/rt/sway-ipc.1000.111.sock"
ENVSOCK="$SB/session.sock"; STALEENV="$SB/stale-env.sock"; PLAIN="$SB/plain.sock"
mksock "$LIVE"; mksock "$STALE"; mksock "$ENVSOCK"; mksock "$STALEENV"; : >"$PLAIN"

run()   { local f; for f in "$STUB_ALL" "$STUB_EXEC" "$STUB_EXEC_SOCK" "$STUB_LOCK" "$STUB_DBUS"; do : >"$f"; done
          rm -f "$STUB_POLLS" "$STUB_IDLE_N"
          "$SO" >"$SB/out" 2>"$SB/err"; echo $? >"$SB/rc"; cat "$STUB_EXEC" >>"$SB/ever"; }
rc()    { cat "$SB/rc"; }
out()   { cat "$SB/out"; }
err()   { cat "$SB/err"; }
execs() { cat "$STUB_EXEC"; }
socks() { sort -u "$STUB_EXEC_SOCK" | tr '\n' ' '; }
polls() { cat "$STUB_POLLS" 2>/dev/null || echo 0; }
asked() { grep -E -- "$1" "$STUB_ALL"; }
nasked(){ grep -cE -- "$1" "$STUB_ALL" || true; }
locked(){ tr '\n' ' ' <"$STUB_LOCK"; }

LOCK="swaylock -f"
WATCH="'$(readlink -f -- "$SO")' --watch"
WATCHER_ARGS="-w timeout 1 swaymsg \"output * power off\" resume swaymsg \"output * power on\"; kill \$PPID"
BOTH="$LOCK
$WATCH"
PIDFILE="$SB/rt/screens-off.watcher"

echo "== sway, from a session shell: \$SWAYSOCK answers"
SWAYSOCK="$ENVSOCK" STUB_LIVE="$ENVSOCK" STUB_OUTPUTS="on on dark" run
check "exit 0, silent" is "$(rc)|$(out)|$(err)" "0||"
check "the lock, then the watch call, verbatim" is "$(execs)" "$BOTH"
check "both to the socket that answered" is "$(socks)" "$ENVSOCK "
check "\$SWAYSOCK asked once, no socket walk" is "$(nasked 'get_version')" 1
check "polled until the third reading was dark" is "$(polls)" 3
check "GNOME never consulted" is "$(nasked 'gdbus|loginctl')" 0

echo "== sway, over SSH: nothing exported, the live socket found in XDG_RUNTIME_DIR"
STUB_LIVE="$LIVE" STUB_OUTPUTS="dark" run
check "exit 0" is "$(rc)" 0
check "the stale socket asked and refused, the live one taken" is "$(asked get_version | tr '\n' '|')" "-s $STALE -t get_version|-s $LIVE -t get_version|"
check "both commands to the live socket" is "$(socks)" "$LIVE "

echo "== a stale \$SWAYSOCK, kept by the user manager from an earlier session"
SWAYSOCK="$STALEENV" STUB_LIVE="$LIVE" STUB_OUTPUTS="dark" run
check "exit 0" is "$(rc)" 0
check "asked first, refused, then the walk" is "$(asked get_version | head -1)" "-s $STALEENV -t get_version"
check "commands to the live socket" is "$(socks)" "$LIVE "

echo "== \$SWAYSOCK naming a plain file"
SWAYSOCK="$PLAIN" STUB_LIVE="$LIVE" STUB_OUTPUTS="dark" run
check "never asked: not a socket" is "$(nasked "-s $PLAIN ")" 0
check "the live socket taken" is "$(socks)" "$LIVE "

echo "== --watch: the pid on file is the swayidle's own"
rm -f "$PIDFILE" "$STUB_IDLE_ARGS" "$STUB_IDLE_PID"
"$SO" --watch & wp=$!
sleep 0.4
check "the file names the process that became swayidle" is "$(cat "$PIDFILE" 2>/dev/null)|$(cat "$STUB_IDLE_PID" 2>/dev/null)" "$wp|$wp"
check "swayidle's arguments, verbatim" is "$(cat "$STUB_IDLE_ARGS" 2>/dev/null)" "$WATCHER_ARGS"
kill "$wp" 2>/dev/null; wait "$wp" 2>/dev/null

echo "== a watcher already armed: a second invocation adds none"
(exec -a 'swayidle -w timeout 1 swaymsg "output * power off" resume swaymsg "output * power on"; kill $PPID' sleep 30) & fake=$!
sleep 0.2; echo "$fake" >"$PIDFILE"
SWAYSOCK="$ENVSOCK" STUB_LIVE="$ENVSOCK" STUB_OUTPUTS="dark" run
check "exit 0: the lock alone, no second watcher" is "$(rc)|$(execs)" "0|$LOCK"
kill "$fake" 2>/dev/null; wait "$fake" 2>/dev/null; sleep 0.1
SWAYSOCK="$ENVSOCK" STUB_LIVE="$ENVSOCK" STUB_OUTPUTS="dark" run
check "the pid on file dead: a fresh watcher" is "$(execs)" "$BOTH"
echo "$$" >"$PIDFILE"
SWAYSOCK="$ENVSOCK" STUB_LIVE="$ENVSOCK" STUB_OUTPUTS="dark" run
check "the pid on file alive but not a watcher: a fresh watcher" is "$(execs)" "$BOTH"
echo "not-a-pid" >"$PIDFILE"
SWAYSOCK="$ENVSOCK" STUB_LIVE="$ENVSOCK" STUB_OUTPUTS="dark" run
check "garbage on file: a fresh watcher" is "$(execs)" "$BOTH"
rm -f "$PIDFILE"

echo "== the readings"
SWAYSOCK="$ENVSOCK" STUB_LIVE="$ENVSOCK" STUB_OUTPUTS="mixed mixed dark" run
check "one display still on is not dark: polled on" is "$(rc) $(polls)" "0 3"
SWAYSOCK="$ENVSOCK" STUB_LIVE="$ENVSOCK" STUB_OUTPUTS="inactive" run
check "an inactive output still reading power is ignored" is "$(rc) $(polls)" "0 1"

echo "== the displays never read off (5 s each)"
SWAYSOCK="$ENVSOCK" STUB_LIVE="$ENVSOCK" STUB_OUTPUTS="on" STUB_TREE=brave run
check "exit 1 after the cap: 50 polls" is "$(rc) $(polls)" "1 50"
check "stderr: still on after 5 s" has "$(err)" "^screens-off: the displays are still on after 5 s"
check "stderr names the window holding an inhibitor" has "$(err)" "inhibitors: Deontic logic seminar, live - Brave"
check "stderr says the watcher stays armed" has "$(err)" "watcher stays armed"
check "lock and watcher were still issued" is "$(execs)" "$BOTH"
check "nothing on stdout" is "$(out)" ""
SWAYSOCK="$ENVSOCK" STUB_LIVE="$ENVSOCK" STUB_OUTPUTS="on" STUB_TREE=plain run
check "no inhibitor: says so" has "$(err)" "no window holds an inhibitor"

echo "== GNOME: no sway answers, Mutter on the bus"
rm -f "$LIVE" "$STALE"
STUB_GNOME=1 STUB_IDLE="100 300 700" run
check "exit 0, silent" is "$(rc)|$(out)|$(err)" "0||"
check "waited for the seat: three idle readings, then the lock" is "$(nasked GetIdletime)" 3
check "locked the graphical session, not the manager's or the SSH one" is "$(locked)" "5 "
check "no swaymsg exec" is "$(execs)" ""
STUB_GNOME=1 STUB_IDLE="900" run
check "already quiet: one reading" is "$(nasked GetIdletime) $(locked)" "1 5 "
STUB_GNOME=1 STUB_IDLE="" run
check "no idle monitor: locks at once rather than spinning" is "$(rc) $(nasked GetIdletime) $(locked)" "0 1 5 "

echo "== the session bus address, over SSH"
STUB_GNOME=1 STUB_IDLE="900" run
check "an address in the environment passes through" is "$(head -1 "$STUB_DBUS")" "unix:path=$SB/no-bus-here"
(unset DBUS_SESSION_BUS_ADDRESS; STUB_GNOME=1 STUB_IDLE="900" run)
check "none in the environment: defaulted to the user's bus" is "$(head -1 "$STUB_DBUS")" "unix:path=/run/user/$(id -u)/bus"

echo "== neither desktop"
run
check "exit 1" is "$(rc)" 1
check "stderr says so" has "$(err)" "^screens-off: no live session"
check "nothing locked, nothing exec'd" is "$(locked)|$(execs)" "|"

echo "== precedence: a live sway while Mutter is also on the bus"
mksock "$LIVE"
STUB_GNOME=1 STUB_IDLE="900" STUB_LIVE="$LIVE" STUB_OUTPUTS="dark" run
check "sway taken, GNOME never consulted" is "$(rc) $(nasked 'gdbus|loginctl') $(socks)" "0 0 $LIVE "

echo "== the shape of every exec body ever sent"
shape_ok() { [ "$(grep -c . "$SB/ever")" -gt 0 ] && ! grep -vxF -e "$LOCK" -e "$WATCH" "$SB/ever"; }
check "only the bare lock and the watch call, nothing else" shape_ok
unexpected_none() { ! grep -q UNEXPECTED "$STUB_ALL"; }
check "no stub saw an unexpected call" unexpected_none
echo "     $(grep -c . "$SB/ever") exec bodies sent across the suite"

echo
echo "passed: $pass  failed: $fail"
[ "$fail" = 0 ]
