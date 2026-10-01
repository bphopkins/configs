#!/usr/bin/env bash
# Regression suite for bin/sway-split: the split keys as toggles, and the Waybar
# marker that shows it. Written 2026-09-28 with the script (configs
# DECISIONS.md, the entry of that date).
#
# Everything runs against a HEADLESS NESTED sway on a private socket, with a
# config written here and nothing of the real one: no include, no exec lines,
# no bar, no background, no swaynag, no Xwayland -- a test that starts a
# compositor starts everything that compositor's config starts. The clients
# are foot windows running sleep. The script is driven through SWAYSOCK, so
# the live session is never addressed, and it signals nothing: its refresh is
# a sway tick event on the nested socket.
#
# Caged: tests/cage.sh. Before it exits, the suite asserts that its cgroup
# holds no sway, foot, swaymsg, jq or sleep process.
#
# Run after any edit to bin/sway-split (~10 s). SWAY_SPLIT=<path> runs the
# suite against another copy of the script, which is how it was
# mutation-tested. Last line follows the tests/gsync convention:
# "passed: N  failed: M"; exit 0 iff nothing failed. Requires sway, jq, foot.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$CFG_ROOT/tests/cage.sh"
cage sway-split "$@"

SPLIT="${SWAY_SPLIT:-$CFG_ROOT/bin/sway-split}"
SB="$(mktemp -d "${TMPDIR:-/tmp}/sway-split-tests.XXXXXX")"
export SWAYSOCK="$SB/sway.sock"
# A Unix socket path holds 107 bytes; sway and swaymsg cut a longer SWAYSOCK
# short without a word, and every run under that TMPDIR would share one
# socket, each new run taking over the last one's (measured 2026-09-30).
[ "${#SWAYSOCK}" -le 107 ] || {
  rmdir "$SB"
  echo "sway-split tests: socket path over 107 bytes -- run with a shorter TMPDIR" >&2
  echo "passed: 0  failed: 1"; exit 2; }
cleanup() { swaymsg exit >/dev/null 2>&1; sleep 0.5; rm -rf "$SB"; }
trap cleanup EXIT

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }

for b in sway swaymsg jq foot; do
  command -v "$b" >/dev/null 2>&1 || {
    echo "sway-split tests: $b missing -- not running" >&2
    echo "passed: 0  failed: 1"; exit 2; }
done

# --- the nested sway --------------------------------------------------------
cat >"$SB/sway.conf" <<'CONF'
swaynag_command -
swaybg_command -
xwayland disable
output HEADLESS-1 mode --custom 1280x720@60Hz
CONF
WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
  sway -c "$SB/sway.conf" >"$SB/sway.log" 2>&1 &
for _ in $(seq 1 40); do swaymsg -t get_version >/dev/null 2>&1 && break; sleep 0.25; done
swaymsg -t get_version >/dev/null 2>&1 || {
  echo "sway-split tests: the nested sway did not start" >&2
  echo "passed: 0  failed: 1"; exit 1; }

spawn() { # $1 = app id; returns once the window is in the tree
  swaymsg -q exec "foot --app-id=$1 sleep 300"
  for _ in $(seq 1 40); do
    swaymsg -t get_tree | jq -e --arg a "$1" '[..|objects|select(.app_id?==$a)]|length>0' >/dev/null && return 0
    sleep 0.25
  done
  return 1
}
sw()     { swaymsg -q -- "$1" 2>/dev/null; }
tree()   { swaymsg -t get_workspaces | jq -r '.[] | select(.focused) | .representation'; }
marker() { "$SPLIT" status | jq -r '.class // "none"'; }
toggle() { "$SPLIT" toggle; }
is()     { [ "$1" = "$2" ] || { echo "     got: $1   want: $2"; return 1; }; }

# --- toggle and status --------------------------------------------------------
echo "== a window in a row"
spawn A; spawn B
check "starts unset: no marker" is "$(marker)" none
toggle
check "toggle sets it: B alone in a column" is "$(tree)" "H[A V[B]]"
check "marker: below" is "$(marker)" below
toggle
check "toggle again cancels: the row is back" is "$(tree)" "H[A B]"
check "marker gone" is "$(marker)" none

echo "== the next window lands below, and the state is spent"
toggle; spawn C
check "C opens below B" is "$(tree)" "H[A V[B C]]"
check "no marker on C, which has a neighbour" is "$(marker)" none

echo "== a window in a column of two"
sw '[app_id=B] focus'
toggle
check "B wrapped inside the column" is "$(tree)" "H[A V[V[B] C]]"
check "marker: below" is "$(marker)" below
toggle
check "cancel restores the column" is "$(tree)" "H[A V[B C]]"

echo "== left alone when its neighbour closes"
sw '[app_id=C] kill'; sleep 0.5; sw '[app_id=B] focus'
check "B alone in the column: marker below" is "$(marker)" below
toggle
check "toggle cancels it" is "$(tree)" "H[A B]"

echo "== beside, after \$mod+Ctrl+r"
toggle; sw 'layout toggle split'
check "the column turned into a row of one" is "$(tree)" "H[A H[B]]"
check "marker: beside" is "$(marker)" beside
toggle
check "toggle cancels beside too" is "$(tree)" "H[A B]"

echo "== below and beside, one key each (2026-09-29)"
below()  { "$SPLIT" below; }
beside() { "$SPLIT" beside; }
below
check "below sets a column of one" is "$(tree)" "H[A V[B]]"
check "marker: below" is "$(marker)" below
beside
check "beside flips it to a row of one" is "$(tree)" "H[A H[B]]"
check "marker: beside" is "$(marker)" beside
below
check "below flips it back" is "$(tree)" "H[A V[B]]"
below
check "below again cancels" is "$(tree)" "H[A B]"
beside
check "beside from unset" is "$(tree)" "H[A H[B]]"
beside
check "beside again cancels" is "$(tree)" "H[A B]"
check "marker gone after the pair" is "$(marker)" none

echo "== a selected column: the next window below the whole column"
toggle; spawn D; sw '[app_id=B] focus'; sw 'focus parent'
check "column selected, not set: no marker" is "$(marker)" none
toggle
check "marker: below the column" is "$(marker)" below
spawn E
check "E opens below the column" is "$(tree)" "H[A V[V[B D] E]]"

echo "== a window alone on its workspace"
sw 'workspace 2'; spawn Z
check "lone window: no marker" is "$(marker)" none
toggle
check "toggle makes the workspace vertical" is "$(tree)" "V[Z]"
check "marker: below" is "$(marker)" below
toggle
check "toggle puts the workspace back to a row" is "$(tree)" "H[Z]"
check "marker gone" is "$(marker)" none
"$SPLIT" beside
check "beside on a lone window: the row it already has" is "$(tree)" "H[Z]"
check "no marker for it" is "$(marker)" none

echo "== a floating window: left alone"
sw 'floating enable'
# The floating layer, which the workspace's representation leaves out: a
# wrapped floating window shows only here (2026-09-30).
layer() { swaymsg -t get_tree | jq -c '[..|objects|select(.type=="floating_con")|{layout, n: (.nodes|length)}]'; }
before="$(tree)/$(marker)/$(layer)"
check "floating: no marker" is "$(marker)" none
toggle; toggle
check "two toggles leave a floating window as it was" is "$(tree)/$(marker)/$(layer)" "$before"
"$SPLIT" below
check "below leaves a floating window unwrapped" is "$(tree)/$(marker)/$(layer)" "$before"

# --- watch -----------------------------------------------------------------------
echo "== watch: the marker follows the state"
sw 'workspace 3'; spawn P; spawn Q
setsid "$SPLIT" watch >"$SB/watch.out" 2>/dev/null &
wpid=$!
last()  { tail -n 1 "$SB/watch.out" 2>/dev/null | jq -r '.class // "none"' 2>/dev/null; }
until_last() { # $1 = class; waits up to 3 s for the watcher's last line to say it
  for _ in $(seq 1 30); do [ "$(last)" = "$1" ] && return 0; sleep 0.1; done
  echo "     last line: $(tail -n 1 "$SB/watch.out" 2>/dev/null)"; return 1
}
check "prints the marker at start" until_last none
toggle
check "a toggle shows at once (its tick event)" until_last below
spawn R
check "a window landing below clears it" until_last none
kill -- -"$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null

echo "== watch exits when its reader goes away"
setsid bash -c '"$0" watch | head -n 1 >/dev/null' "$SPLIT" &
hpid=$!
sleep 0.5
for _ in 1 2 3; do swaymsg -t send_tick test >/dev/null; sleep 0.3; done
sleep 0.5
check "the whole watch pipeline is gone" bash -c "! pgrep -g $hpid >/dev/null"
kill -- -"$hpid" 2>/dev/null

echo "== watch stops its whole pipeline when it is told to stop"
setsid "$SPLIT" watch >/dev/null 2>&1 &
tpid=$!
sleep 0.5
kill -TERM "$tpid"             # the script alone, as Waybar signals it
sleep 0.5
check "SIGTERM to the script takes the event stream with it" bash -c "! pgrep -g $tpid >/dev/null"
kill -- -"$tpid" 2>/dev/null

# --- nothing left behind -------------------------------------------------------
echo "== the cage is clean"
swaymsg exit >/dev/null 2>&1
sleep 1
cg="$(sed -n 's/^0::\(.*\)$/\1/p' /proc/self/cgroup)"
left=""
for p in $(cat "/sys/fs/cgroup$cg/cgroup.procs" 2>/dev/null); do
  case "$(cat "/proc/$p/comm" 2>/dev/null)" in
    sway|foot|swaymsg|jq|sleep) left="$left $p:$(cat "/proc/$p/comm" 2>/dev/null)" ;;
  esac
done
check "no sway, foot, swaymsg, jq or sleep left in the cage" [ -z "$left" ]
[ -n "$left" ] && echo "     left:$left"

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
