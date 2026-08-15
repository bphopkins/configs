#!/usr/bin/env bash
# Regression suite for the Sway desktop configs: sway, waybar, swaylock, mako,
# wofi. Written 2026-08-13, after a session in which four separate SILENT,
# CATASTROPHIC failure modes were found the hard way. Each check below exists
# because of one of them:
#
#   1. `sway --validate` does NOT check the command body of a bindsym. A typo
#      there passes validation and fails silently at runtime, forever.
#   2. A CSS parse error makes Waybar EXIT. Sway does not bring it back, and the
#      journal logs "Using CSS file ..." and then nothing. The failure looks like
#      "the bar vanished", not "the stylesheet is wrong".
#   3. An unrecognised key makes swaylock EXIT -- which means NO LOCK AT ALL
#      rather than a visibly broken one. Fail-open, on the one component whose
#      whole job is to fail closed.
#   4. mako and wofi likewise silently mis-handle unknown keys.
#
# Nothing here writes outside $TMPDIR, elevates, or touches the network. The
# binding checks run a HEADLESS NESTED sway on a private socket, which works
# from a GNOME session too -- but the config copy it loads has `include
# /etc/sway/config.d/*` and every startup `exec` stripped first. That include
# runs sway-systemd's session.sh, which would reach out and set
# XDG_CURRENT_DESKTOP/XDG_SESSION_TYPE in the LIVE systemd user and D-Bus
# environment. Stripping it is load-bearing, not tidiness.
#
# Mutation-verified 2026-08-13 against a sandboxed copy of the config tree (the
# real repo is never written to). Each of these breaks was introduced alone and
# caught by exactly its own check: GTK3-invalid CSS value; an undocumented key in
# each of swaylock/mako/wofi; a duplicate bindsym chord; a TYPO IN A BINDING
# COMMAND; clock interval back to 60; malformed waybar JSON; the urgent colour
# drifting in one file; an idle `timeout` clause reintroduced into swayidle; and a
# package dropped from STOW_TARGETS. The unmutated copy passes clean.
#
# That exercise earned its keep twice -- see the long comment on the parse_error
# discriminator below, where BOTH obvious implementations of the binding check
# turned out to be silently wrong.
#
# Run from anywhere after editing any of those five configs (~10 s).
# Last line follows the tests/gsync convention: "passed: N  failed: M";
# exit 0 iff nothing failed. Requires bash 5+, sway, jq, python3 + python3-gi.
set -u

SB="$(mktemp -d "${TMPDIR:-/tmp}/desktop-cfg.XXXXXX")"
trap 'rm -rf "$SB"; [ -n "${NESTED_SOCK:-}" ] && SWAYSOCK="$NESTED_SOCK" swaymsg exit >/dev/null 2>&1; true' EXIT
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NESTED_SOCK=""

pass=0 fail=0 skip=0
check()   { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
skipit()  { echo "skip - $1"; ((skip+=1)); }
have()    { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- sway config

check "sway config validates" \
  sway --validate -c "$CFG_ROOT/sway/config"

# No two active bindings may claim the same chord. Rename detection off; the
# key is field 2 after stripping bindsym and any --flags.
dupes="$(grep -hE '^\s*bindsym' "$CFG_ROOT/sway/config" \
        | sed -E 's/^\s*bindsym\s+//; s/^(--[a-z-]+\s+)*//; s/\s.*$//' \
        | sort | uniq -d)"
check "no duplicate bindsym chords" [ -z "$dupes" ]
[ -n "$dupes" ] && echo "     duplicates: $dupes"

# Every binary an exec binding names must exist, since sway reports nothing when
# one does not. $term/$menu are resolved from their `set` lines.
missing=""
term_bin="$(sed -nE 's/^\s*set \$term\s+(\S+).*/\1/p'  "$CFG_ROOT/sway/config" | head -1)"
menu_bin="$(sed -nE 's/^\s*set \$menu\s+(\S+).*/\1/p'  "$CFG_ROOT/sway/config" | head -1)"
for b in $(grep -hE '^\s*bindsym.*\sexec\s' "$CFG_ROOT/sway/config" \
           | sed -E 's/.*\sexec\s+//; s/^sh -c .*//; s/^(\S+).*/\1/' | sort -u) \
         "$term_bin" "$menu_bin" swayidle swaylock swaynag grim slurp wl-copy; do
  [ -z "$b" ] && continue
  case "$b" in \$*|"") continue;; esac
  have "$b" || missing="$missing $b"
done
check "every binary named by a binding exists" [ -z "$missing" ]
[ -n "$missing" ] && echo "     missing:$missing"

# ------------------------------------------- bindsym command bodies (finding 1)
# sway --validate skips these entirely, so execute each against a real (nested,
# headless) sway and classify the reply by its `parse_error` field. A *state*
# complaint ("Can't move an empty workspace") proves the command parsed and
# reached semantic evaluation; only parse_error is a config bug.
if have sway && have jq; then
  # THREE things must come out of the copy, and the third one caused a real
  # incident on 2026-08-13 -- read before editing:
  #   include /etc/sway/config.d/*  -> runs sway-systemd's session.sh, which
  #     rewrites XDG_CURRENT_DESKTOP/XDG_SESSION_TYPE in the LIVE systemd+D-Bus
  #     environment of the session you are sitting in.
  #   exec lines                    -> would launch nm-applet etc. for real.
  #   bar { swaybar_command waybar }-> each nested sway spawns its OWN waybar.
  #     Attached to a headless compositor it cannot draw on, such a waybar was
  #     measured growing to 9.2 GB RSS / 34 GB virtual and triggering the kernel
  #     OOM killer. Worse, sway-systemd's assign-cgroups.py places it in the
  #     *terminal's* systemd scope, so the OOM kill took down the whole WezTerm
  #     scope and closed every window in it. Stripping the bar block is not
  #     tidiness; it is the difference between a test and an outage.
  sed -e 's|^include /etc/sway/config.d/\*|# stripped for test|' \
      -e 's|^\s*exec .*|# stripped for test|' \
      -e '/^bar {/,/^}/d' \
      "$CFG_ROOT/sway/config" > "$SB/test.conf"
  check "test copy has no bar block (would spawn a real waybar)" \
    bash -c "! grep -q 'swaybar_command' '$SB/test.conf'"
  check "test copy has no live 'include /etc/sway/config.d'" \
    bash -c "! grep -qE '^include /etc/sway/config.d' '$SB/test.conf'"
  check "test copy has no startup exec lines" \
    bash -c "! grep -qE '^\s*exec ' '$SB/test.conf'"

  NESTED_SOCK="$SB/sway.sock"
  WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 SWAYSOCK="$NESTED_SOCK" \
    sway -c "$SB/test.conf" >"$SB/sway.log" 2>&1 &
  for _ in $(seq 1 40); do
    SWAYSOCK="$NESTED_SOCK" swaymsg -t get_version >/dev/null 2>&1 && break
    sleep 0.25
  done

  if SWAYSOCK="$NESTED_SOCK" swaymsg -t get_version >/dev/null 2>&1; then
    check "nested sway loaded the config without error" \
      bash -c "! grep -qiE '\[error\].*(config|line)' '$SB/sway.log'"

    parse_errors=0
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      # Discriminating a config bug from a state complaint is fiddlier than it
      # looks, and BOTH obvious approaches are wrong (each caught by mutation
      # testing, 2026-08-13):
      #   - grepping the raw reply for "Unknown/invalid command" NEVER matches:
      #     sway's IPC JSON escapes the slash, so the bytes read "Unknown\/...".
      #     That made this check pass vacuously.
      #   - the `parse_error` field is NOT a discriminator: sway sets it true for
      #     pure state failures too ("Scratchpad is empty" arrives with
      #     parse_error: true), which flags every valid command as broken.
      # So: decode the JSON with jq (which turns \/ back into /) and match the
      # decoded .error string.
      out="$(SWAYSOCK="$NESTED_SOCK" swaymsg -- "$cmd" 2>/dev/null)"
      if [ "$(jq -r 'any(.[]?; (.error // "") | test("Unknown/invalid command"))' \
              <<<"$out" 2>/dev/null)" = true ]; then
        echo "     PARSE ERROR in binding command: $cmd"
        parse_errors=$((parse_errors+1))
      fi
      SWAYSOCK="$NESTED_SOCK" swaymsg 'mode "default"' >/dev/null 2>&1
    done < <(grep -hE '^\s*bindsym' "$CFG_ROOT/sway/config" \
             | sed -E 's/^\s*bindsym\s+//; s/^(--[a-z-]+\s+)*//; s/^\S+\s+//' \
             | grep -v '^exec ' | sort -u)
    check "every non-exec binding command parses at runtime" [ "$parse_errors" = 0 ]

    SWAYSOCK="$NESTED_SOCK" swaymsg exit >/dev/null 2>&1
    NESTED_SOCK=""
  else
    skipit "nested sway would not start (binding-body checks skipped)"
  fi
else
  skipit "sway or jq missing (binding-body checks skipped)"
fi

# ------------------------------------------------------- GTK3 CSS (finding 2/4)
# Both Waybar and wofi are GTK3. A parse error costs the whole bar / a broken
# launcher, with no useful error anywhere, so parse them the same way GTK will.
gtk_css_ok() {
  python3 - "$1" <<'PY' >/dev/null 2>&1
import sys, gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
Gtk.CssProvider().load_from_data(open(sys.argv[1], "rb").read())
PY
}
if python3 -c 'import gi' >/dev/null 2>&1; then
  check "waybar/style.css parses as GTK3 CSS" gtk_css_ok "$CFG_ROOT/waybar/style.css"
  check "wofi/style.css parses as GTK3 CSS"   gtk_css_ok "$CFG_ROOT/wofi/style.css"
  # Anti-vacuity: the checker must REJECT known-bad CSS, or every "parses"
  # result above would be meaningless. "tnum" 1 is the exact CSS-spec form GTK3
  # rejects (it accepts a bare "tnum") -- the very mistake that killed the bar.
  css_rejects() { ! gtk_css_ok "$1"; }
  printf '#x { font-feature-settings: "tnum" 1; }\n' > "$SB/bad.css"
  check "CSS checker rejects known-bad CSS (anti-vacuity)" css_rejects "$SB/bad.css"
else
  skipit "python3-gi missing (GTK CSS checks skipped)"
fi

# waybar's config is JSONC -- valid JSON once // comments are stripped.
check "waybar/config is valid JSON (comments stripped)" \
  python3 -c "import json,re,sys;json.loads(re.sub(r'^\s*//.*$','',open('$CFG_ROOT/waybar/config').read(),flags=re.M))"

# A clock format showing seconds needs interval 1: waybar defaults to 60 and
# polls on the minute, which renders %S as '00' forever.
if grep -qE '"format"\s*:\s*"\{:[^"]*%[TS]' "$CFG_ROOT/waybar/config"; then
  check "clock shows seconds => interval is 1" \
    python3 -c "
import json,re,sys
d=json.loads(re.sub(r'^\s*//.*\$','',open('$CFG_ROOT/waybar/config').read(),flags=re.M))
sys.exit(0 if d.get('clock',{}).get('interval')==1 else 1)"
fi

# ------------------------------------------- man-page key validation (finding 3)
# Each of these three exits or misbehaves on an unrecognised key, so every key
# must appear in its own man page. The option lists are scraped from the man
# pages themselves, so they track the installed version rather than a snapshot.
validate_keys() { # $1=config  $2=option-list  $3=label
  local cfg="$1" opts="$2" label="$3" bad="" k
  while IFS= read -r line; do
    case "$line" in ''|\#*|\[*) continue;; esac
    k="${line%%=*}"; k="${k%% *}"
    grep -qx "$k" "$opts" || bad="$bad $k"
  done < "$cfg"
  [ -z "$bad" ] || { echo "     undocumented in $label:$bad"; return 1; }
}

if man 1 swaylock >/dev/null 2>&1; then
  man 1 swaylock 2>/dev/null | col -b | grep -oE '^\s+(-[A-Za-z], )?--[a-z-]+' \
    | grep -oE -- '--[a-z-]+' | sed 's/^--//' | sort -u > "$SB/swaylock.opts"
  check "every swaylock/config key is documented" \
    validate_keys "$CFG_ROOT/swaylock/config" "$SB/swaylock.opts" "man 1 swaylock"
else
  skipit "man 1 swaylock unavailable"
fi

if man 5 mako >/dev/null 2>&1; then
  man 5 mako 2>/dev/null | col -b | grep -oE '^\s{5,9}[a-z][a-z0-9-]*=' \
    | tr -d ' =' | sort -u > "$SB/mako.opts"
  check "every mako/config key is documented" \
    validate_keys "$CFG_ROOT/mako/config" "$SB/mako.opts" "man 5 mako"
else
  skipit "man 5 mako unavailable"
fi

if man 5 wofi >/dev/null 2>&1; then
  man 5 wofi 2>/dev/null | col -b | sed -n '/^CONFIG OPTIONS/,/^CSS SELECTORS/p' \
    | grep -oE '^\s{7}[a-z_]+=' | tr -d ' =' | sort -u > "$SB/wofi.opts"
  check "every wofi/config key is documented" \
    validate_keys "$CFG_ROOT/wofi/config" "$SB/wofi.opts" "man 5 wofi"
else
  skipit "man 5 wofi unavailable"
fi

# ------------------------------------------------------------ cross-config wiring

# The stow arrays must agree with each other and with what is on disk, or
# stow-all silently skips a package (the documented silent-skip trap).
check "stow arrays are consistent and every package dir exists" \
  bash -c '
    source "'"$CFG_ROOT"'/bash/.bashrc.d/60-stow.sh"
    rc=0
    for p in "${STOW_ORDER[@]}"; do
      [ -n "${STOW_TARGETS[$p]:-}" ] || { echo "     no target: $p"; rc=1; }
      [ -d "'"$CFG_ROOT"'/$p" ]      || { echo "     no dir: $p";    rc=1; }
    done
    for k in "${!STOW_TARGETS[@]}"; do
      printf "%s\n" "${STOW_ORDER[@]}" | grep -qx "$k" || { echo "     not in ORDER: $k"; rc=1; }
    done
    exit $rc'

# One urgent colour desktop-wide. These live in four different config languages
# and are deliberately not derived from one another, so only a test keeps them
# in step.
URGENT="d08770"
for f in sway/config waybar/style.css mako/config swaylock/config; do
  check "urgent colour #$URGENT present in $f" \
    grep -qi "$URGENT" "$CFG_ROOT/$f"
done

# swaylock is invoked from two places; both must stay bare so the config file
# remains the single source of appearance.
check "swaylock invoked identically from both call sites" \
  bash -c "[ \"\$(grep -ohE 'swaylock -f' '$CFG_ROOT/sway/config' | sort -u | wc -l)\" = 1 ] &&
           [ \"\$(grep -cE 'swaylock' '$CFG_ROOT/sway/config')\" -ge 2 ]"

# The lock must stay before-sleep-only: a `timeout` clause would reintroduce
# idle locking, which is a standing declined decision.
check "swayidle has no timeout clause (no idle locking)" \
  bash -c "! grep -E '^\s*exec swayidle' '$CFG_ROOT/sway/config' | grep -q 'timeout'"

# The suite must leave nothing behind. A leaked nested sway or waybar is how a
# test turns into an OOM (see the bar-block comment above), so this is an
# assertion, not hygiene.
sleep 1
leaked="$(pgrep -a -f "$SB" 2>/dev/null | grep -vE "pgrep|run\.sh" || true)"
check "suite leaked no processes" [ -z "$leaked" ]
[ -n "$leaked" ] && echo "     leaked: $leaked"

echo
echo "passed: $pass  failed: $fail${skip:+  skipped: $skip}"
(( fail == 0 ))
