#!/usr/bin/env bash
# Regression suite for bin/sway-equalize: $mod+Ctrl+e, every row and column on
# the focused workspace back to the sizes sway gives windows opened fresh.
# Written 2026-10-06 with the script, and extended the same day by cases 12-16
# from an adversarial pass (configs DECISIONS.md, the entry of that date).
#
# Everything runs against a HEADLESS NESTED sway at the Samsung's 5120x1440,
# on a private socket, with a config written here and nothing of the real
# one: no include, no exec lines, no bar, no background, no swaynag, no
# Xwayland. The socket is asserted against this suite's own config before the
# first command, and the nested sway is ended by its pid, never by `swaymsg
# exit`. The clients are foot windows running sleep, started with
# `-o workers=0`: foot starts one render thread per CPU, sixteen on bigfed,
# and seventeen windows at that rate ran the cage out of tasks (measured
# 2026-10-06).
#
# The reference for "fresh" is sway itself: a workspace's geometry as its
# windows were opened, read before anything resizes them.
#
# Each workspace's windows are closed once no later case needs them. foot
# holds its buffers, and with every window left open the suite peaked at 475
# of the cage's 512 MiB; closed as it goes, at about 310 (measured
# 2026-10-06). Past the line the cage kills sway without a word, so a check
# at the end asks whether it lived.
#
# Caged: tests/cage.sh. Before it exits, the suite asserts that its cgroup
# holds no sway, foot, swaymsg, jq or sleep process.
#
# Run after any edit to bin/sway-equalize (~30 s). SWAY_EQUALIZE=<path> runs
# the suite against another copy of the script, which is how it was
# mutation-tested on 2026-10-06, nine breaks each failing the cases named:
# floor for round (5, 9, 10, 14, 15), the first level only (5, 11, 14, 15),
# no fullscreen guard (10), one tree read for every level (all but 7, 8 and
# 14), no title bar added back (13), no floor check (9, 12, 14, 16), refused
# moves not last (14), no lock (15), one pass per level (16). Last line
# follows the tests/gsync convention: "passed: N  failed: M"; exit 0 iff
# nothing failed. Requires sway, jq, foot.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$CFG_ROOT/tests/cage.sh"
cage sway-equalize "$@"

EQ="${SWAY_EQUALIZE:-$CFG_ROOT/bin/sway-equalize}"
SB="$(mktemp -d "${TMPDIR:-/tmp}/sway-equalize-tests.XXXXXX")"
export SWAYSOCK="$SB/sway.sock"
# A Unix socket path holds 107 bytes; sway and swaymsg cut a longer SWAYSOCK
# short without a word (measured 2026-09-30, tests/sway-split/run.sh).
[ "${#SWAYSOCK}" -le 107 ] || {
  rmdir "$SB"
  echo "sway-equalize tests: socket path over 107 bytes -- run with a shorter TMPDIR" >&2
  echo "passed: 0  failed: 1"; exit 2; }

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
is()   { [ "$1" = "$2" ] || { echo "     got:  $1"; echo "     want: $2"; return 1; }; }
isnt() { [ "$1" != "$2" ] || { echo "     unexpectedly equal: $1"; return 1; }; }

for b in sway swaymsg jq foot; do
  command -v "$b" >/dev/null 2>&1 || {
    rmdir "$SB"
    echo "sway-equalize tests: $b missing -- not running" >&2
    echo "passed: 0  failed: 1"; exit 2; }
done

# --- the nested sway --------------------------------------------------------
cat >"$SB/sway.conf" <<'CONF'
swaynag_command -
swaybg_command -
xwayland disable
default_border pixel 2
output HEADLESS-1 mode --custom 5120x1440@60Hz
CONF
WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
  sway -c "$SB/sway.conf" >"$SB/sway.log" 2>&1 &
spid=$!
cleanup() { kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null; rm -rf "$SB"; }
trap cleanup EXIT
for _ in $(seq 1 40); do swaymsg -t get_version >/dev/null 2>&1 && break; sleep 0.25; done
[ "$(swaymsg -t get_version 2>/dev/null | jq -r .loaded_config_file_name)" = "$SB/sway.conf" ] || {
  echo "sway-equalize tests: the socket does not answer with this suite's config -- stopping before any command" >&2
  echo "passed: 0  failed: 1"; exit 1; }

spawn() { # $1 = app id; returns once the window is in the tree
  swaymsg -q exec "foot -o workers=0 --app-id=$1 sleep 300"
  for _ in $(seq 1 40); do
    swaymsg -t get_tree | jq -e --arg a "$1" '[..|objects|select(.app_id?==$a)]|length>0' >/dev/null && return 0
    sleep 0.25
  done
  echo "     spawn $1 timed out" >&2; return 1
}
sw() { swaymsg -q -- "$1"; }
# Every tiled con on a workspace, in tree order: "WxH+X+Y".
geom() {
  swaymsg -t get_tree | jq -r --arg ws "$1" '
    [.. | objects | select(.type? == "workspace" and .name == $ws)][0]
    | [.nodes[] | .. | objects | select(.type? == "con")
       | "\(.rect.width)x\(.rect.height)+\(.rect.x)+\(.rect.y)"] | join(" ")'
}
# The widths of a workspace's tiled windows, in tree order.
widths() {
  swaymsg -t get_tree | jq -r --arg ws "$1" '
    [.. | objects | select(.type? == "workspace" and .name == $ws)][0]
    | [.nodes[] | .. | objects | select(.type? == "con" and .app_id != null) | .rect.width]
    | join(",")'
}
rect_of() { swaymsg -t get_tree | jq -c --arg a "$1" '.. | objects | select(.app_id? == $a) | .rect'; }
run_eq() { "$EQ"; rc=$?; }
# The heights of a workspace's tiled windows, in tree order.
heights() {
  swaymsg -t get_tree | jq -r --arg ws "$1" '
    [.. | objects | select(.type? == "workspace" and .name == $ws)][0]
    | [.nodes[] | .. | objects | select(.type? == "con" and .app_id != null) | .rect.height]
    | join(",")'
}
# The widths of the children of the container holding app id $1.
kids() {
  swaymsg -t get_tree | jq -r --arg a "$1" '
    [.. | objects | select(.nodes? and any(.nodes[]; .app_id? == $a))][0]
    | [.nodes[].rect.width] | join(",")'
}
# Close a workspace's windows, or every window, and wait until they are gone
# (the header says why).
close_ws() {
  swaymsg -q "[workspace=\"^$1\$\"] kill"
  for _ in $(seq 1 40); do
    [ "$(swaymsg -t get_tree | jq --arg ws "$1" '[.. | objects | select(.type? == "workspace" and .name == $ws) | .. | objects | select(.app_id? != null)] | length')" = 0 ] && return 0
    sleep 0.25
  done
  echo "     workspace $1 did not empty" >&2; return 1
}
close_all() {
  swaymsg -q '[app_id=".+"] kill'
  for _ in $(seq 1 40); do
    [ "$(swaymsg -t get_tree | jq '[.. | objects | select(.app_id? != null)] | length')" = 0 ] && return 0
    sleep 0.25
  done
  echo "     windows did not close" >&2; return 1
}

# --- cases --------------------------------------------------------------------
echo "== 1. a flat row of six, distorted by resize set, then equalized"
sw 'workspace 1'
for i in 1 2 3 4 5 6; do spawn r$i; done
fresh="$(geom 1)"
check "six fresh windows are 853 x5 and 855" is "$(widths 1)" "853,853,853,853,853,855"
sw '[app_id=r1] resize set width 600 px'
sw '[app_id=r3] resize set width 1200 px'
sw '[app_id=r6] resize set width 700 px'
sw '[app_id=r4] resize set width 650 px'
check "the row is distorted" isnt "$(geom 1)" "$fresh"
run_eq
check "exit 0" is "$rc" 0
check "the equalized row is the fresh row" is "$(geom 1)" "$fresh"

echo "== 2. run again on an equal row: nothing moves"
before="$(geom 1)"
run_eq
check "exit 0" is "$rc" 0
check "unchanged" is "$(geom 1)" "$before"

echo "== 3. the live row of 2026-10-06 (732 839 853 940 903 853)"
# Its five boundaries, set straight from the fresh row.
sw '[app_id=r1] resize shrink right 121 px'
sw '[app_id=r2] resize shrink right 135 px'
sw '[app_id=r3] resize shrink right 135 px'
sw '[app_id=r5] resize grow right 2 px'
sw '[app_id=r4] resize shrink right 48 px'
check "reproduced the live widths" is "$(widths 1)" "732,839,853,940,903,853"
run_eq
check "exit 0" is "$rc" 0
check "853 x5 and 855" is "$(widths 1)" "853,853,853,853,853,855"

echo "== 4. a floating window on the workspace is left alone"
spawn fl
sw '[app_id=fl] floating enable'
sw '[app_id=fl] resize set 400 300'
# foot snaps a floating window to whole cells a moment after a resize, so the
# baseline is taken once its rect has stopped moving.
fl_before="$(rect_of fl)"
for _ in $(seq 1 20); do sleep 0.25; now="$(rect_of fl)"; [ "$now" = "$fl_before" ] && break; fl_before="$now"; done
sw '[app_id=r2] resize set width 1500 px'
run_eq
check "exit 0" is "$rc" 0
check "the row is equal again" is "$(widths 1)" "853,853,853,853,853,855"
check "the floating window is untouched" is "$(rect_of fl)" "$fl_before"

echo "== 5. nested: a row [a, column(b, c), d], distorted at both levels"
sw 'workspace 3'
spawn a; spawn b; spawn d
sw '[app_id=b] focus'; sw 'splitv'; spawn c
fresh="$(geom 3)"
sw '[app_id=a] resize set width 2400 px'
sw '[app_id=b] resize set height 300 px'
sw '[app_id=d] resize set width 1000 px'
check "distorted" isnt "$(geom 3)" "$fresh"
run_eq
check "exit 0" is "$rc" 0
check "the fresh geometry, at both levels" is "$(geom 3)" "$fresh"

echo "== 6. a fold in a row: [t1, tabbed(t2, t3)]"
sw 'workspace 4'
spawn t1; spawn t2
sw '[app_id=t2] focus'; sw 'splitv'; spawn t3
sw '[app_id=t3] focus'; sw 'layout tabbed'
fresh="$(geom 4)"
sw '[app_id=t1] resize set width 3500 px'
check "distorted" isnt "$(geom 4)" "$fresh"
run_eq
check "exit 0" is "$rc" 0
check "the fresh geometry" is "$(geom 4)" "$fresh"
close_ws 4

echo "== 7. a lone window, and an empty workspace: nothing to do"
sw 'workspace 5'; spawn solo
run_eq
check "a lone window: exit 0" is "$rc" 0
sw 'workspace 6'
run_eq
check "an empty workspace: exit 0" is "$rc" 0
close_ws 5

echo "== 8. only the focused workspace"
sw 'workspace 1'; sw '[app_id=r1] resize set width 1000 px'
other="$(geom 1)"
sw 'workspace 3'
run_eq
check "workspace 1 untouched from workspace 3" is "$(geom 1)" "$other"
close_ws 1; close_ws 3

echo "== 9. the floor check: 160,160,4800 needs the right edge moved first"
sw 'workspace 7'
spawn o1; spawn o2; spawn o3
sw '[app_id=o1] resize shrink right 1547 px'
sw '[app_id=o2] resize shrink right 3094 px'
check "set up 160,160,4800" is "$(widths 7)" "160,160,4800"
run_eq
check "exit 0" is "$rc" 0
check "1707,1707,1706" is "$(widths 7)" "1707,1707,1706"
close_ws 7

echo "== 10. a fullscreen window: its row is left as it is"
sw 'workspace 8'
spawn f1; spawn f2; spawn f3
sw '[app_id=f1] resize set width 3000 px'
tiled="$(widths 8)"
check "set up 3000,414,1706" is "$tiled" "3000,414,1706"
sw '[app_id=f2] fullscreen enable'
run_eq
check "exit 0" is "$rc" 0
sw '[app_id=f2] fullscreen disable'
check "the row, out of fullscreen, as it was" is "$(widths 8)" "$tiled"
run_eq
check "and equalized once fullscreen is off" is "$(widths 8)" "1707,1707,1706"
close_ws 8

echo "== 11. three levels: [x1, column(x2, row(x3, x4))], the inner row moved by the outer"
# Evening out the outer row changes the inner row's width, so the third
# level is right only if the tree is read again after the first.
sw 'workspace 9'
spawn x1; spawn x2
sw '[app_id=x2] focus'; sw 'splitv'; spawn x3
sw '[app_id=x3] focus'; sw 'splith'; spawn x4
fresh="$(geom 9)"
sw '[app_id=x1] resize set width 4000 px'
sw '[app_id=x3] resize set width 300 px'
sw '[app_id=x2] resize set height 400 px'
check "distorted" isnt "$(geom 9)" "$fresh"
run_eq
check "exit 0" is "$rc" 0
check "the fresh geometry, at all three levels" is "$(geom 9)" "$fresh"
close_ws 9

# --- breaks found by an adversarial pass, 2026-10-06 (cases 12-16) ------------
# Each case closes its own windows.

echo "== 12. a window already under the floor: 1300,75,2465,1280 and 370,45,665,360"
# Sway leaves a share under 100 px when a row it was shrunk in gains a window:
# 1733,100,3287 plus a fourth scales every share by 3/4. Without the floor
# check, the first step, 20 px leftward, would leave the 75 at 95: refused,
# nothing done, exit 1.
sw 'workspace 12'
spawn u1; spawn u2; spawn u3
sw '[app_id=u1] resize grow right 26 px'
sw '[app_id=u2] resize shrink right 1581 px'
sw '[app_id=u3] focus'; spawn u4
check "built 1300,75,2465,1280" is "$(widths 12)" "1300,75,2465,1280"
run_eq
check "exit 0" is "$rc" 0
check "1280 x4" is "$(widths 12)" "1280,1280,1280,1280"
# The same in a column, against MIN_SANE_H, 60 px (include/sway/tree/node.h).
sw 'workspace 13'
spawn v1; sw '[app_id=v1] focus'; sw 'splitv'; spawn v2; spawn v3
sw '[app_id=v1] resize grow down 13 px'
sw '[app_id=v2] resize shrink down 407 px'
sw '[app_id=v3] focus'; spawn v4
check "built 370,45,665,360" is "$(heights 13)" "370,45,665,360"
run_eq
check "exit 0" is "$rc" 0
check "360 x4" is "$(heights 13)" "360,360,360,360"
close_all

echo "== 13. a title bar in a column: a fresh column is left as it is"
# A child's reported rect omits its title bar (ipc-json.c), so read alone the
# heights were 455,480,480 and the column came out 497,472,471.
sw 'workspace 14'
spawn tb1; sw '[app_id=tb1] focus'; sw 'splitv'; spawn tb2; spawn tb3
sw '[app_id=tb1] border normal'
# deco_rect follows the border once sway has committed it (current, not pending)
for _ in $(seq 1 20); do
  [ "$(swaymsg -t get_tree | jq '.. | objects | select(.app_id? == "tb1") | .deco_rect.height')" != 0 ] && break; sleep 0.1
done
fresh="$(geom 14)"
run_eq
check "exit 0" is "$rc" 0
check "the fresh column is unchanged" is "$(geom 14)" "$fresh"
sw '[app_id=tb2] resize set height 900 px'
run_eq
check "distorted, then the fresh column again" is "$(geom 14)" "$fresh"
close_all

echo "== 14. a row sway cannot even out does not hold back the row beside it"
# An outer row of 14, equal; its first member a row squeezed to 176,14,176
# (b must grow from both sides, by less than its 86 px deficit from either),
# its second a row at 100,144,122. Both are one depth down, in one command
# list; a refused step ends a list (commands.c), so the second row's moves
# must come before any move sway would refuse.
sw 'workspace 15'
spawn pa; spawn qa
sw '[app_id=pa] focus'; sw 'splith'; spawn pb; spawn pc
sw '[app_id=pb] resize set width 100 px'
sw '[app_id=qa] focus'; sw 'splith'; spawn qb; spawn qc
sw '[app_id=qa] resize set width 700 px'
qrow="$(swaymsg -t get_tree | jq '[.. | objects | select(.nodes? and any(.nodes[]; .app_id? == "qa"))][0].id')"
sw "[con_id=$qrow] focus"
for i in $(seq 1 12); do spawn po$i; done
check "built 176,14,176 and 100,144,122" is "$(kids pa) $(kids qa)" "176,14,176 100,144,122"
run_eq
check "the second row is even" is "$(kids qa)" "122,122,122"
close_all

echo "== 15. two runs at once"
# Each run reads the tree and moves every edge; two at once both land. The
# second waits for the first (flock), then finds nothing to do.
sw 'workspace 16'
spawn d1; spawn d2; spawn d3
sw '[app_id=d3] focus'; sw 'splitv'; spawn d4
sw '[app_id=d4] focus'; sw 'splith'; spawn d5
fresh="$(geom 16)"
for i in 1 2 3 4; do
  sw "[app_id=d1] resize set width $((600 + 500 * i)) px"
  sw "[app_id=d4] resize set width $((200 + 100 * i)) px"
  "$EQ" & p1=$!; "$EQ" & p2=$!
  wait "$p1"; r1=$?; wait "$p2"; r2=$?
  check "pair $i: both exit 0" is "$r1 $r2" "0 0"
  check "pair $i: the fresh geometry" is "$(geom 16)" "$fresh"
done
close_all

echo "== 16. a window sway has collapsed to 0x0 (under 10 px, tree/arrange.c)"
# 100 of three shares becomes 9.4 of 32. Sway's first resize snaps every
# share in the row to its pixel width, the collapsed one's to 0, and sway
# then gives it the average share, so one plan made before that cannot land;
# each level is read again and moved again. The collapsed window sits second:
# first in the row, the plan's opening move is its own and lands in one pass
# (measured 2026-10-06), and the case would not see the passes at all.
sw 'workspace 17'
spawn z1; spawn z2; spawn z3
sw '[app_id=z2] resize set width 100 px'
sw '[app_id=z3] focus'
for i in $(seq 4 32); do spawn z$i; done
check "z2 is 0x0" is "$(swaymsg -t get_tree | jq -c '.. | objects | select(.app_id? == "z2") | [.rect.width, .rect.height]')" "[0,0]"
run_eq
check "exit 0" is "$rc" 0
check "160 x32 after one run" is "$(widths 17)" "$(printf '160,%.0s' $(seq 1 31))160"
close_all

# --- nothing left behind -------------------------------------------------------
echo "== the cage is clean"
check "the nested sway lived to the end (the cage kills it without a word)" kill -0 "$spid"
kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null
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
