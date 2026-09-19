#!/usr/bin/env bash
# Regression suite for context-check.
#
#   bash tests/context-check/run.sh
#
# Fully sandboxed under $TMPDIR: a fake config tree, a fake ~/.claude, a fake
# ~/Desktop. Touches nothing real and needs no network. Resolves the script
# relative to its own location, so it tests the checkout it lives in.
#
# Last line follows the tests/gsync convention: "passed: N  failed: M".
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GAUGE="$REPO/bin/context-check"
pass=0; fail=0
ok() { pass=$((pass+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
no() { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
yes_() { if eval "$2"; then ok "$1"; else no "$1"; fi; }
not_() { if eval "$2"; then no "$1"; else ok "$1"; fi; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (got '$2', want '$3')"; fi; }

[ -x "$GAUGE" ] || { echo "context-check not executable at $GAUGE"; exit 1; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ctxcheck.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# a healthy sandbox; echoes its root
mkworld() {
  local w; w=$(mktemp -d "$WORK/w.XXXXXX")
  mkdir -p "$w"/{cfg/rules,cfg/memory/-scope,cfg/repos/rep,cfg/plans,home/.claude/projects/-scope,desk/rep/.claude}
  printf 'global\n'                                   > "$w/cfg/CLAUDE.md"
  printf -- '---\ndescription: d\n---\n\nalways on\n'  > "$w/cfg/rules/always.md"
  printf -- '---\ndescription: d\npaths:\n  - "**/*.tex"\n---\n\nconditional\n' > "$w/cfg/rules/cond.md"
  : > "$w/cfg/plans/.gitkeep"
  printf -- '---\nname: m\ndescription: d\nmetadata:\n  type: feedback\n---\n\nbody\n' > "$w/cfg/memory/-scope/m.md"
  printf -- '- [M](m.md) — hook\n'                    > "$w/cfg/memory/-scope/MEMORY.md"
  printf '{"permissions":{"allow":["Bash(ls)"]}}\n'   > "$w/cfg/repos/rep/settings.local.json"
  ln -s "$w/cfg/memory/-scope" "$w/home/.claude/projects/-scope/memory"
  ln -s "$w/cfg/repos/rep/settings.local.json" "$w/desk/rep/.claude/settings.local.json"
  echo "$w"
}
run() { local w=$1; shift
  CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" \
    "$GAUGE" "$@" 2>&1; }
rc()  { local w=$1; shift; run "$w" "$@" >/dev/null; echo $?; }

echo "== a healthy tree is silent and exits 0 =="
w=$(mkworld); out=$(run "$w")
not_ "no FAIL lines"                  '[[ "$out" == *"[FAIL]"* ]]'
not_ "no WARN lines"                  '[[ "$out" == *"[WARN]"* ]]'
yes_ "says all clear"                 '[[ "$out" == *"all clear"* ]]'
check "exits 0" "$(rc "$w")" "0"
yes_ "nine checks reported"           '[ "$(grep -c "^\[" <<<"$out")" = 9 ]'

echo "== it writes nothing =="
w=$(mkworld)
before=$(find "$w/cfg" -type f -exec md5sum {} + | sort)
run "$w" -v >/dev/null
after=$(find "$w/cfg" -type f -exec md5sum {} + | sort)
check "config tree byte-identical after a run" "$before" "$after"

echo "== dangling links into the config =="
w=$(mkworld); ln -s "$w/cfg/gone" "$w/home/.claude/plans"
out=$(run "$w"); check "exits 1" "$(rc "$w")" "1"
yes_ "reports one dangling link"      '[[ "$out" == *"1 dangling"* ]]'
yes_ "names the repair"               '[[ "$out" == *"claude-link --apply"* ]]'
ln -s "$w/elsewhere/x" "$w/home/.claude/foreign"
out=$(run "$w")
yes_ "a foreign dangling link is not counted" '[[ "$out" == *"1 dangling"* ]]'
yes_ "-v lists the offending path"    '[[ "$(run "$w" -v)" == *".claude/plans"* ]]'

echo "== directories git cannot carry =="
w=$(mkworld); mkdir -p "$w/cfg/memory/-empty"
out=$(run "$w")
yes_ "an empty dir fails"             '[[ "$out" == *"1 empty directory"* ]]'
check "  exits 1" "$(rc "$w")" "1"
: > "$w/cfg/memory/-empty/.gitkeep"
not_ "a keeper clears it"             '[[ "$(run "$w")" == *"empty directory"*"[FAIL]"* ]]'

echo "== memory index line shape =="
w=$(mkworld)
{ printf -- '- [M](m.md) — '; head -c 240 < /dev/zero | tr '\0' 'x'; printf '\n'; } > "$w/cfg/memory/-scope/MEMORY.md"
out=$(run "$w")
yes_ "an over-long entry fails"       '[[ "$out" == *"1 at or over the ~200c demote trigger"* ]]'
yes_ "  reports the worst length"     '[[ "$out" == *"worst 25"* ]]'
yes_ "  names the consequence"        '[[ "$out" == *"carrying content that belongs in the topic file"* ]]'
yes_ "  states the real caps and partial failure" '[[ "$out" == *"the tail is dropped silently"* ]]'
w=$(mkworld)
yes_ "a short entry passes, with the largest index size" '[[ "$(run "$w")" == *"largest index"*"B, -scope)"* ]]'

echo "== rules frontmatter: globs: is the silent failure =="
w=$(mkworld)
printf -- '---\ndescription: d\nglobs:\n  - "**/*.tex"\n---\n\nbody\n' > "$w/cfg/rules/oops.md"
out=$(run "$w")
yes_ "globs: fails"                   '[[ "$out" == *"use globs:"* ]]'
yes_ "  says they load every session" '[[ "$out" == *"every session"* ]]'
w=$(mkworld)
not_ "paths: does not fail"           '[[ "$(run "$w")" == *"use globs:"* ]]'

echo "== always-on budget: measured, judged only if he sets a ceiling =="
w=$(mkworld); out=$(run "$w")
yes_ "reports the word total"                 '[[ "$out" == *"always-on prose:"*"words"* ]]'
yes_ "  counts only unconditional rules"      '[[ "$out" == *"1 unconditional rules"* ]]'
not_ "  no verdict without a ceiling"         '[[ "$out" == *"over your ceiling"* ]]'
out=$(CONTEXT_CHECK_ALWAYS_ON_MAX=1 run "$w")
yes_ "a ceiling set is enforced"              '[[ "$out" == *"over your ceiling of 1"* ]]'
check "  and exits 1" "$(CONTEXT_CHECK_ALWAYS_ON_MAX=1 rc "$w")" "1"

echo "== memory frontmatter =="
w=$(mkworld); sed -i 's/^name: m$/name: wrong/' "$w/cfg/memory/-scope/m.md"
yes_ "a name that differs from the filename fails" '[[ "$(run "$w")" == *"frontmatter: 1 problem"* ]]'
w=$(mkworld); sed -i 's/type: feedback/type: nonsense/' "$w/cfg/memory/-scope/m.md"
yes_ "an unknown type fails"           '[[ "$(run "$w")" == *"frontmatter: 1 problem"* ]]'
w=$(mkworld); printf 'no frontmatter\n' > "$w/cfg/memory/-scope/m.md"
yes_ "a file with no frontmatter fails" '[[ "$(run "$w")" == *"no frontmatter"* ]] || [[ "$(run "$w" -v)" == *"no frontmatter"* ]]'

echo "== index against directory, both directions =="
w=$(mkworld); printf -- '---\nname: extra\ndescription: d\nmetadata:\n  type: user\n---\n\nb\n' > "$w/cfg/memory/-scope/extra.md"
yes_ "a memory missing from the index fails" '[[ "$(run "$w")" == *"1 disagreement"* ]]'
w=$(mkworld); printf -- '- [M](m.md) — h\n- [Ghost](ghost.md) — h\n' > "$w/cfg/memory/-scope/MEMORY.md"
yes_ "an index entry with no file fails"     '[[ "$(run "$w")" == *"1 disagreement"* ]]'

echo "== permission entries naming a path that is gone =="
w=$(mkworld)
printf '{"permissions":{"allow":["Read(/home/definitely/not/here/**)"]}}\n' > "$w/cfg/repos/rep/settings.local.json"
yes_ "a dead path fails"               '[[ "$(run "$w")" == *"name a path that no longer exists"* ]]'
w=$(mkworld)
printf '{"permissions":{"allow":["Read('"$w"'/desk/**)"]}}\n' > "$w/cfg/repos/rep/settings.local.json"
not_ "a live path does not"             '[[ "$(run "$w")" == *"name a path that no longer exists"* ]]'

echo "== a repo absent on this machine is reported, not failed =="
w=$(mkworld); rm -rf "$w/desk/rep"
out=$(run "$w")
yes_ "reported as OK"                   '[[ "$out" == *"[ OK ] repos/: 1 entry"* ]]'
not_ "  and does not fail the run"      '[[ "$out" == *"[FAIL] repos/"* ]]'

echo "== could-not-determine is never silent health =="
w=$(mkworld)
out=$(CLAUDE_LINK_CFG="$w/nope" CLAUDE_LINK_HOME="$w/home/.claude" "$GAUGE" 2>&1); rc2=$?
yes_ "a missing config tree warns"      '[[ "$out" == *"[WARN]"* ]]'
check "  and exits 2, not 0" "$rc2" "2"

echo
printf 'passed: %d  failed: %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
