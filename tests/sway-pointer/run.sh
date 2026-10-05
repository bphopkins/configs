#!/usr/bin/env bash
# Regression suite for bin/sway-pointer: one key for every pointing device,
# and the Waybar marker while they are off. Written 2026-10-03 with the script
# (configs DECISIONS.md, the entry of that date).
#
# No compositor is started and none is addressed. A stub swaymsg on PATH
# serves a saved device list and records every command the script sends; a
# stub notify-send records the notice. The device lists are the real ones sway
# gave on bigfed and on fedxps on 2026-10-03 (fixtures/), reshaped with jq per
# case: devices switched off, a device unplugged, a keyboard whose mouse-keys
# interface shares its name, an identifier with a comma and a semicolon in
# it. HOME and XDG_STATE_HOME point into the sandbox, so the real learned list
# is never read or written; SWAYSOCK is unset, so nothing here could reach a
# sway even if the stub were missing.
#
# Caged: tests/cage.sh, as every suite here, although this one starts only
# bash and jq.
#
# Run after any edit to bin/sway-pointer (~2 s). SWAY_POINTER=<path> runs the
# suite against another copy of the script, which is how it was
# mutation-tested. Last line follows the tests/gsync convention:
# "passed: N  failed: M"; exit 0 iff nothing failed. Requires jq.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$CFG_ROOT/tests/cage.sh"
cage sway-pointer "$@"

POINTER="${SWAY_POINTER:-$CFG_ROOT/bin/sway-pointer}"
HERE="$CFG_ROOT/tests/sway-pointer"
SB="$(mktemp -d "${TMPDIR:-/tmp}/sway-pointer-tests.XXXXXX")"
cleanup() { rm -rf "$SB"; }
trap cleanup EXIT

command -v jq >/dev/null 2>&1 || {
  echo "sway-pointer tests: jq missing -- not running" >&2
  echo "passed: 0  failed: 1"; exit 2; }
[ -x "$POINTER" ] || {
  echo "sway-pointer tests: $POINTER is not executable -- not running" >&2
  echo "passed: 0  failed: 1"; exit 2; }

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
is()    { [ "$1" = "$2" ] || { echo "     got:  $1"; echo "     want: $2"; return 1; }; }

# --- the stubs ----------------------------------------------------------------
mkdir -p "$SB/bin" "$SB/home" "$SB/state"
cat >"$SB/bin/swaymsg" <<'STUB'
#!/usr/bin/env bash
# stub swaymsg: the device list in STUB_INPUTS, the events in STUB_EVENTS, and
# every command appended to STUB_LOG and to STUB_ALL with a success reply.
case "$*" in
  "-t get_inputs")     [ -z "${STUB_FAIL:-}" ] || exit 1; cat "$STUB_INPUTS" ;;
  "-t subscribe -m "*) [ -z "${STUB_BLOCK:-}" ] || exec sleep 30; cat "$STUB_EVENTS" ;;
  "-- "*)              all="$*"; printf '%s\n' "${all#-- }" | tee -a "$STUB_ALL" >>"$STUB_LOG"
                       echo '[{"success": true}]' ;;
  *) echo "stub swaymsg: unexpected: $*" >&2; printf 'UNEXPECTED %s\n' "$*" >>"$STUB_ALL"; exit 99 ;;
esac
STUB
cat >"$SB/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFY_LOG"
STUB
chmod +x "$SB/bin/swaymsg" "$SB/bin/notify-send"
export PATH="$SB/bin:$PATH" HOME="$SB/home" XDG_STATE_HOME="$SB/state"
unset SWAYSOCK
export STUB_LOG="$SB/commands" STUB_ALL="$SB/all-commands" NOTIFY_LOG="$SB/notices" STUB_EVENTS="$SB/events"
: >"$STUB_ALL"
LEARNED="$SB/state/sway-pointer/learned"

run()     { local fx="$1"; shift; : >"$STUB_LOG"; : >"$NOTIFY_LOG"; STUB_INPUTS="$fx" "$POINTER" "$@"; }
cmds()    { LC_ALL=C sort "$STUB_LOG"; }
ncmds()   { grep -c . "$STUB_LOG" || true; }
notice()  { tr '\n' '|' <"$NOTIFY_LOG"; }
learned() { cat "$LEARNED" 2>/dev/null | tr '\n' ' '; }
forget()  { rm -f "$LEARNED"; }
expect()  { # TARGET ID...: the sorted commands for those identifiers
  local t="$1"; shift; printf 'input "%s" events '"$t"'\n' "$@" | LC_ALL=C sort; }

# --- fixtures and their reshapings ----------------------------------------------
BIG="$HERE/fixtures/bigfed.json" FED="$HERE/fixtures/fedxps.json"
MX_BT='1133:45079:MX_Master_Mouse' MX_RX='1133:16480:Logitech_MX_Master'
DONGLE='13364:53296:Keychron__Keychron_Link' KB='13364:53296:Keychron__Keychron_Link__Keyboard'
FED_MOUSE='1739:31251:DLL07BE:01_06CB:7A13_Mouse' FED_PAD='1739:31251:DLL07BE:01_06CB:7A13_Touchpad' FED_PS2='2:7:SynPS/2_Synaptics_TouchPad'
off()     { local fx="$1"; shift; jq '[.[] | if (.identifier as $i | $ARGS.positional | index($i)) != null then .libinput.send_events = "disabled" else . end]' "$fx" --args "$@"; }
without() { local fx="$1"; shift; jq '[.[] | select(.identifier as $i | ($ARGS.positional | index($i)) == null)]' "$fx" --args "$@"; }
with()    { jq --argjson extra "$2" '. + $extra' "$1"; }
save()    { cat >"$SB/$1.json"; echo "$SB/$1.json"; }

# A keyboard whose mouse-keys interface shares its name: two nodes, one
# identifier, acceleration on the mouse-keys facet only.
COMBO='[{"identifier":"1:2:Combo_KB","type":"keyboard","libinput":{"send_events":"enabled"}},
        {"identifier":"1:2:Combo_KB","type":"pointer","libinput":{"send_events":"enabled","accel_speed":0}}]'
# An identifier sway could produce: printable characters survive, only spaces
# and unprintables become underscores.
ODD='[{"identifier":"1:2:Odd,Name;Mouse","type":"pointer","libinput":{"send_events":"enabled","accel_speed":0,"natural_scroll":"disabled"}}]'
# A pointer that is not libinput's (a virtual pointer): no libinput object.
VIRT='[{"identifier":"0:0:wlr_virtual_pointer","type":"pointer"}]'

echo "== bigfed, everything on: the first press"
forget
F="$(save big-on <"$BIG")"
run "$F" toggle; rc=$?
check "exit 0" is "$rc" 0
check "three devices switched off, by quoted identifier" is "$(cmds)" "$(expect disabled "$MX_RX" "$MX_BT" "$DONGLE")"
check "the keyboard's wheel facet is not addressed" bash -c "! grep -qF '$KB' '$STUB_LOG'"
check "notice: Pointer: disabled" is "$(notice)" "-u low Pointer: disabled|"
check "the three are learned, sorted" is "$(learned)" "$MX_RX $MX_BT $DONGLE "

echo "== bigfed, everything off: the second press"
F="$(save big-off < <(off "$BIG" "$MX_RX" "$MX_BT" "$DONGLE"))"
run "$F" toggle
check "three devices switched on" is "$(cmds)" "$(expect enabled "$MX_RX" "$MX_BT" "$DONGLE")"
check "notice: Pointer: enabled" is "$(notice)" "-u low Pointer: enabled|"
check "learned list unchanged, no duplicates" is "$(learned)" "$MX_RX $MX_BT $DONGLE "

echo "== mixed: one off, two on -> all off"
F="$(save big-mixed < <(off "$BIG" "$MX_BT"))"
run "$F" toggle
check "all three switched off" is "$(cmds)" "$(expect disabled "$MX_RX" "$MX_BT" "$DONGLE")"

echo "== the Bluetooth mouse asleep at the press: its node gone, its identifier learned"
F="$(save big-no-bt < <(without "$BIG" "$MX_BT"))"
run "$F" toggle
check "two present and the absent one all switched off" is "$(cmds)" "$(expect disabled "$MX_RX" "$MX_BT" "$DONGLE")"
check "two present, three commands" is "$(ncmds)" 3
F="$(save big-no-bt-off < <(off "$(without "$BIG" "$MX_BT" | save big-no-bt-tmp)" "$MX_RX" "$DONGLE"))"
run "$F" toggle
check "asleep at the on-press too: switched on with the rest" is "$(cmds)" "$(expect enabled "$MX_RX" "$MX_BT" "$DONGLE")"

echo "== never seen, never learned: forgotten identifiers, garbage lines"
forget
mkdir -p "$(dirname "$LEARNED")"
printf '%s\n' '1:2:Old_Mouse' 'not an identifier' '1:2:bad"quote' '3:4:back\slash' '' >"$LEARNED"
F="$(save big-on2 <"$BIG")"
run "$F" toggle
check "a learned identifier is addressed, the garbage is not" is "$(cmds)" "$(expect disabled '1:2:Old_Mouse' "$MX_RX" "$MX_BT" "$DONGLE")"
check "the list is rewritten clean, sorted, unique" is "$(learned)" "$MX_RX $MX_BT $DONGLE 1:2:Old_Mouse "

echo "== fedxps: two touchpad nodes and the touchpad's mouse sibling"
forget
F="$(save fed-on <"$FED")"
run "$F" toggle
check "three devices switched off" is "$(cmds)" "$(expect disabled "$FED_MOUSE" "$FED_PAD" "$FED_PS2")"
check "no keyboard, switch or button addressed" is "$(ncmds)" 3
F="$(save fed-off < <(off "$FED" "$FED_MOUSE" "$FED_PAD" "$FED_PS2"))"
run "$F" toggle
check "and back on" is "$(cmds)" "$(expect enabled "$FED_MOUSE" "$FED_PAD" "$FED_PS2")"

echo "== a keyboard whose mouse-keys interface shares its name is left alone"
forget
F="$(save big-combo < <(with "$BIG" "$COMBO"))"
run "$F" toggle
check "the shared identifier is not addressed" bash -c "! grep -qF '1:2:Combo_KB' '$STUB_LOG'"
check "the three mice still are" is "$(cmds)" "$(expect disabled "$MX_RX" "$MX_BT" "$DONGLE")"
check "and it is not learned" bash -c "! grep -qF '1:2:Combo_KB' '$LEARNED'"

echo "== only a keyboard's wheel present: nothing to do"
forget
F="$(save kb-only < <(jq '[.[] | select(.identifier == "'"$KB"'")]' "$BIG"))"
run "$F" toggle; rc=$?
check "exit 0, no command" is "$rc $(ncmds)" "0 0"
check "notice: Pointer: absent" is "$(notice)" "-u low Pointer: absent|"
check "nothing learned" is "$(learned)" ""

echo "== an identifier with a comma and a semicolon, and a virtual pointer"
forget
F="$(save big-odd < <(with "$(with "$BIG" "$ODD" | save big-odd-tmp)" "$VIRT"))"
run "$F" toggle
check "the odd identifier is quoted whole" bash -c "grep -qxF 'input \"1:2:Odd,Name;Mouse\" events disabled' '$STUB_LOG'"
check "the virtual pointer, no libinput object, is not addressed" bash -c "! grep -qF 'wlr_virtual_pointer' '$STUB_LOG'"
check "four commands" is "$(ncmds)" 4

echo "== status and the marker"
F="$(save big-on3 <"$BIG")"
check "on: empty text" is "$(run "$F" status)" '{"text":""}'
F="$(save big-off2 < <(off "$BIG" "$MX_RX" "$MX_BT" "$DONGLE"))"
check "off: pointer off, class off" is "$(run "$F" status | jq -r '"\(.text)/\(.class)"')" "pointer off/off"
F="$(save big-mixed2 < <(off "$BIG" "$MX_BT"))"
check "mixed: no marker (not every device is off)" is "$(run "$F" status)" '{"text":""}'
F="$(save kb-only2 < <(jq '[.[] | select(.identifier == "'"$KB"'")]' "$BIG"))"
check "nothing present: no marker" is "$(run "$F" status)" '{"text":""}'

echo "== watch: once at start, once per event, ends with the stream"
printf '%s\n' '{"change":"libinput_config"}' '{"change":"added"}' >"$STUB_EVENTS"
F="$(save big-off3 < <(off "$BIG" "$MX_RX" "$MX_BT" "$DONGLE"))"
out="$(run "$F" watch)"; rc=$?
check "three marker lines, exit 0" is "$rc $(grep -c . <<<"$out")" "0 3"
check "each says pointer off" is "$(jq -r .text <<<"$out" | sort -u)" "pointer off"

echo "== watch, stopped the way Waybar stops it: nothing outlives the signal"
# Waybar signals the script alone (waybar/CLAUDE.md); the stream must go with
# it. The stub's subscriber blocks as a sleep, standing in for swaymsg.
F="$(save big-off4 < <(off "$BIG" "$MX_RX" "$MX_BT" "$DONGLE"))"
STUB_INPUTS="$F" STUB_BLOCK=1 "$POINTER" watch >"$SB/watch.out" 2>/dev/null &
wpid=$!
for _ in $(seq 1 40); do [ "$(pgrep -P "$wpid" | wc -l)" -ge 2 ] && break; sleep 0.1; done
kids="$(pgrep -P "$wpid" | tr '\n' ' ')"
check "the watcher runs with its subscriber and its loop" [ "$(wc -w <<<"$kids")" -ge 2 ]
kill -TERM "$wpid" 2>/dev/null
for _ in $(seq 1 40); do kill -0 "$wpid" 2>/dev/null || break; sleep 0.1; done
alive=""; for k in $kids; do kill -0 "$k" 2>/dev/null && alive="$alive $k"; done
check "the watcher exits on the signal" bash -c "! kill -0 '$wpid' 2>/dev/null"
check "and its subscriber and loop die with it" is "$alive" ""
[ -z "$alive" ] || kill -KILL $alive 2>/dev/null
check "it had printed the marker once before the signal" is "$(jq -r .text "$SB/watch.out" | tr '\n' '|')" "pointer off|"

echo "== the device list cannot be read"
F="$(save big-on4 <"$BIG")"
STUB_FAIL=1 run "$F" toggle; rc=$?
check "toggle exits 1 and sends nothing" is "$rc $(ncmds)" "1 0"
check "no notice" is "$(notice)" ""
STUB_FAIL=1 run "$F" watch >/dev/null; rc=$?
check "watch exits 1" is "$rc" 1

echo "== usage"
"$POINTER" >/dev/null 2>&1; rc=$?
check "no argument: exit 2" is "$rc" 2
"$POINTER" bogus >/dev/null 2>&1; rc=$?
check "unknown argument: exit 2" is "$rc" 2

echo "== the one shape every command ever sent has"
check "every command: input \"vendor:product:name\" events enabled|disabled" \
  bash -c "[ \"\$(grep -c . '$STUB_ALL')\" -gt 0 ] && ! grep -vqE '^input \"[0-9]+:[0-9]+:[^\" ]+\" events (enabled|disabled)\$' '$STUB_ALL'"
check "never a type, a wildcard, a reload or an exit" \
  bash -c "! grep -qiE 'type:|\\*|reload|exit|unexpected' '$STUB_ALL'"
say_count="$(grep -c . "$STUB_ALL")"
echo "     $say_count commands sent across the suite"

echo
echo "passed: $pass  failed: $fail"
[ "$fail" = 0 ]
