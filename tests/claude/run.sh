#!/usr/bin/env bash
# Regression suite for claude-link and the Claude session hooks.
#
#   bash tests/claude/run.sh
#
# Fully sandboxed under $TMPDIR: a fake HOME, a fake org/claude-config, a fake
# ~/Desktop. Touches nothing real, needs no network. Resolves the scripts
# relative to its own location, so it tests the checkout it lives in.
#
# Last line follows the tests/gsync convention: "passed: N  failed: M".
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
LINK="$REPO/bin/claude-link"
HOOKS="$HOME/Desktop/org/claude-config/hooks"      # hook scripts under test
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
no()   { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (got '$2', want '$3')"; fi; }
yes_() { if eval "$2"; then ok "$1"; else no "$1"; fi; }
not_() { if eval "$2"; then no "$1"; else ok "$1"; fi; }

[ -x "$LINK" ] || { echo "claude-link not executable at $LINK"; exit 1; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/claude-suite.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# build a fresh sandbox; echoes its root
mkworld() {
  local w; w=$(mktemp -d "$WORK/w.XXXXXX")
  mkdir -p "$w"/{cfg/memory/-shared,cfg/repos/rep,home/.claude/projects,desk/rep/.claude,desk/.claude}
  git -C "$w/cfg" init -q; git -C "$w/cfg" commit -q --allow-empty -m init
  printf 'shared rules\n'                        > "$w/cfg/CLAUDE.md"
  printf '{"model":"m"}\n'                       > "$w/cfg/settings.json"
  mkdir -p "$w/cfg/agents"; : > "$w/cfg/agents/.gitkeep"
  printf 'shared mem\n'                          > "$w/cfg/memory/-shared/s.md"
  printf -- '- [s](s.md) — h\n'                  > "$w/cfg/memory/-shared/MEMORY.md"
  printf '{"permissions":{"allow":["Bash(a)"]}}\n' > "$w/cfg/repos/rep/settings.local.json"
  echo "$w"
}
run() { local w=$1; shift
  CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" \
    "$LINK" "$@" 2>&1; }

echo "== preflight refusals =="
w=$(mkworld)
out=$(CLAUDE_LINK_CFG="$w/nope" CLAUDE_LINK_HOME="$w/home/.claude" "$LINK" 2>&1); rc=$?
check "missing config dir exits 2" "$rc" "2"
yes_  "  and says why"                    '[[ "$out" == *"not found"* ]]'
out=$(CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/nohome" "$LINK" 2>&1); rc=$?
check "missing ~/.claude exits 2" "$rc" "2"
yes_  "  and names the remedy"            '[[ "$out" == *"claude"*"once"* ]]'
mkdir -p "$w/home/.claude/inside"
out=$(CLAUDE_LINK_CFG="$w/home/.claude/inside" CLAUDE_LINK_HOME="$w/home/.claude" "$LINK" 2>&1); rc=$?
check "config inside ~/.claude refused" "$rc" "2"
out=$(run "$w" --bogus 2>&1); rc=$?
check "unknown flag exits 2" "$rc" "2"

echo "== dry run =="
w=$(mkworld)
out=$(run "$w"); rc=$?
check "dry run exit 1 when work pending" "$rc" "1"
not_ "changes nothing"                    '[ -L "$w/home/.claude/CLAUDE.md" ]'
yes_ "reports what it would link"         '[[ "$out" == *"would link"* ]]'
yes_ "says nothing was changed"           '[[ "$out" == *"Nothing was changed"* ]]'

echo "== linking =="
w=$(mkworld)
run "$w" --apply >/dev/null
yes_ "CLAUDE.md linked"                   '[ -L "$w/home/.claude/CLAUDE.md" ]'
yes_ "settings.json linked"               '[ -L "$w/home/.claude/settings.json" ]'
yes_ "scaffold dir linked"                '[ -L "$w/home/.claude/agents" ]'
yes_ "memory scope linked"                '[ -L "$w/home/.claude/projects/-shared/memory" ]'
yes_ "repo permissions linked"            '[ -L "$w/desk/rep/.claude/settings.local.json" ]'
check "link resolves to shared copy" \
  "$(readlink -f "$w/home/.claude/CLAUDE.md")" "$(readlink -f "$w/cfg/CLAUDE.md")"

echo "== the folding guard =="
# A scope the machine has never opened must get its parent created, with the
# link at <scope>/memory -- NOT at <scope>, which would put transcripts in git.
yes_ "scope parent is a real dir"         '[ -d "$w/home/.claude/projects/-shared" ] && [ ! -L "$w/home/.claude/projects/-shared" ]'
yes_ "link is at memory/, one level down" '[ -L "$w/home/.claude/projects/-shared/memory" ]'

echo "== idempotency =="
out=$(run "$w" --apply); rc=$?
check "re-run exits 0"                    "$rc" "0"
check "reports all correct"               "$(echo "$out" | grep -c '\[LINK\]')" "0"
check "memory not duplicated"             "$(ls "$w/cfg/memory/-shared" | wc -l)" "2"

echo "== adoption =="
w=$(mkworld)
mkdir -p "$w/home/.claude/projects/-shared/memory"
printf 'shared mem\n' > "$w/home/.claude/projects/-shared/memory/s.md"      # identical
printf 'local\n'      > "$w/home/.claude/projects/-shared/memory/local.md"  # unique
printf -- '- [local](local.md) — h\n' > "$w/home/.claude/projects/-shared/memory/MEMORY.md"
printf '{"permissions":{"allow":["Bash(b)"]}}\n' > "$w/desk/rep/.claude/settings.local.json"
printf 'DIFFERENT\n' > "$w/home/.claude/CLAUDE.md"
out=$(run "$w" --adopt)
yes_ "unique memory moved into shared"    '[ -f "$w/cfg/memory/-shared/local.md" ]'
check "identical memory not duplicated"   "$(ls "$w/cfg/memory/-shared"/s.md* | wc -l)" "1"
check "index merged, both entries"        "$(grep -c '^- \[' "$w/cfg/memory/-shared/MEMORY.md")" "2"
yes_ "memory dir is now a link"           '[ -L "$w/home/.claude/projects/-shared/memory" ]'
check "permissions unioned"               "$(python3 -c "import json;print(len(json.load(open('$w/cfg/repos/rep/settings.local.json'))['permissions']['allow']))")" "2"
not_ "differing CLAUDE.md NOT clobbered"  '[ -L "$w/home/.claude/CLAUDE.md" ]'
check "  shared copy untouched"           "$(cat "$w/cfg/CLAUDE.md")" "shared rules"
yes_ "  backup was taken"                 '[ -n "$(find "$w/home/.claude/link-backups" -name CLAUDE.md 2>/dev/null)" ]'
yes_ "  and warns"                        '[[ "$out" == *"backed up and skipped"* ]]'

echo "== a pre-existing plain directory unions, not skipped =="
w=$(mkworld)
mkdir -p "$w/cfg/plans" "$w/home/.claude/plans"
printf 'shared\n' > "$w/cfg/plans/a.md"
printf 'mine\n'   > "$w/home/.claude/plans/b.md"
out=$(run "$w" --adopt)
yes_ "local plan moved into shared"       '[ -f "$w/cfg/plans/b.md" ]'
yes_ "shared plan still there"            '[ -f "$w/cfg/plans/a.md" ]'
yes_ "plans/ is now a link"               '[ -L "$w/home/.claude/plans" ]'
not_ "not reported as differing"          '[[ "$out" == *"plans"*"backed up and skipped"* ]]'

echo "== conflicting memory kept side by side =="
w=$(mkworld)
mkdir -p "$w/home/.claude/projects/-shared/memory"
printf 'DIVERGENT\n' > "$w/home/.claude/projects/-shared/memory/s.md"
run "$w" --adopt >/dev/null
check "shared version preserved"          "$(cat "$w/cfg/memory/-shared/s.md")" "shared mem"
yes_ "local version kept alongside"       '[ -n "$(ls "$w/cfg/memory/-shared"/s.md.* 2>/dev/null)" ]'

echo "== harvest (new scope / new repo) =="
w=$(mkworld)
mkdir -p "$w/home/.claude/projects/-brand-new/memory"
printf 'fresh\n' > "$w/home/.claude/projects/-brand-new/memory/n.md"
mkdir -p "$w/desk/newrepo/.claude"
printf '{"permissions":{"allow":["Bash(z)"]}}\n' > "$w/desk/newrepo/.claude/settings.local.json"
run "$w" --apply >/dev/null
yes_ "new scope promoted to shared"       '[ -f "$w/cfg/memory/-brand-new/n.md" ]'
yes_ "  and linked back"                  '[ -L "$w/home/.claude/projects/-brand-new/memory" ]'
yes_ "new repo perms promoted"            '[ -f "$w/cfg/repos/newrepo/settings.local.json" ]'
yes_ "  and linked back"                  '[ -L "$w/desk/newrepo/.claude/settings.local.json" ]'

echo "== dangling links from deleted shared files are swept =="
w=$(mkworld); run "$w" --apply >/dev/null
rm "$w/cfg/repos/rep/settings.local.json"           # deleted on the other machine
yes_ "link is dangling before the sweep"  '[ -L "$w/desk/rep/.claude/settings.local.json" ] && [ ! -e "$w/desk/rep/.claude/settings.local.json" ]'
# a dangling link the tool must NOT touch: right filename, target outside the shared config
ln -s "$w/elsewhere/gone.md" "$w/desk/rep/CLAUDE.local.md" 2>/dev/null
out=$(run "$w" --apply)
not_ "dangling link removed"              '[ -L "$w/desk/rep/.claude/settings.local.json" ]'
yes_ "  and it says so"                   '[[ "$out" == *"dangling"* ]]'
yes_ "foreign dangling link untouched"    '[ -L "$w/desk/rep/CLAUDE.local.md" ]'
out=$(run "$w")
not_ "dry run does not sweep"             '[[ "$out" == *"removed dangling"* ]]'

echo "== ephemeral scopes are never harvested or linked =="
w=$(mkworld)
for e in -tmp-scratch -var-tmp-x -run-user-1000-y; do
  mkdir -p "$w/home/.claude/projects/$e/memory"; printf 'junk\n' > "$w/home/.claude/projects/$e/memory/j.md"
done
mkdir -p "$w/cfg/memory/-tmp-already-there"; printf 'x\n' > "$w/cfg/memory/-tmp-already-there/x.md"
out=$(run "$w" --auto)
not_ "/tmp scope not harvested"           '[ -e "$w/cfg/memory/-tmp-scratch" ]'
not_ "/var/tmp scope not harvested"       '[ -e "$w/cfg/memory/-var-tmp-x" ]'
not_ "/run/user scope not harvested"      '[ -e "$w/cfg/memory/-run-user-1000-y" ]'
yes_ "  the local copies are left alone"  '[ -f "$w/home/.claude/projects/-tmp-scratch/memory/j.md" ] && [ ! -L "$w/home/.claude/projects/-tmp-scratch/memory" ]'
out=$(run "$w" --apply)
not_ "an ephemeral scope in the shared tree is not linked either" '[ -L "$w/home/.claude/projects/-tmp-already-there/memory" ]'
yes_ "  and it says why"                  '[[ "$out" == *"ephemeral directory"* ]]'
yes_ "real scopes still link"             '[ -L "$w/home/.claude/projects/-shared/memory" ]'

echo "== --auto is narrow and silent =="
w=$(mkworld)
mkdir -p "$w/home/.claude/projects/-brand-new/memory"; printf 'f\n' > "$w/home/.claude/projects/-brand-new/memory/n.md"
mkdir -p "$w/home/.claude/projects/-shared/memory";    printf 'DIVERGENT\n' > "$w/home/.claude/projects/-shared/memory/s.md"
out=$(run "$w" --auto)
check "stdout is empty"                   "$out" ""
yes_ "writes a log instead"               '[ -s "$w/home/.claude/claude-link-auto.log" ]'
yes_ "harvests the safe new scope"        '[ -L "$w/home/.claude/projects/-brand-new/memory" ]'
not_ "refuses the ambiguous one"          '[ -L "$w/home/.claude/projects/-shared/memory" ]'
check "  and leaves shared copy intact"   "$(cat "$w/cfg/memory/-shared/s.md")" "shared mem"

echo "== --auto refuses a busy repo =="
w=$(mkworld)
mkdir -p "$w/cfg/.git/rebase-merge" "$w/home/.claude/projects/-mid/memory"
printf 'x\n' > "$w/home/.claude/projects/-mid/memory/x.md"
run "$w" --auto >/dev/null 2>&1
not_ "no write during rebase"             '[ -e "$w/cfg/memory/-mid" ]'
not_ "  no log written either"            '[ -e "$w/home/.claude/claude-link-auto.log" ]'
rmdir "$w/cfg/.git/rebase-merge"
run "$w" --auto >/dev/null 2>&1
yes_ "proceeds once rebase is over"       '[ -L "$w/home/.claude/projects/-mid/memory" ]'
for g in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG; do
  w=$(mkworld); : > "$w/cfg/.git/$g"
  mkdir -p "$w/home/.claude/projects/-g/memory"; printf 'x\n' > "$w/home/.claude/projects/-g/memory/x.md"
  run "$w" --auto >/dev/null 2>&1
  not_ "refuses during $g"                '[ -e "$w/cfg/memory/-g" ]'
done

echo "== absent repos are skipped, not failed =="
w=$(mkworld)
mkdir -p "$w/cfg/repos/ghost"; printf '{"permissions":{"allow":[]}}\n' > "$w/cfg/repos/ghost/settings.local.json"
out=$(run "$w" --apply); rc=$?
yes_ "reports the skip"                   '[[ "$out" == *"ghost"*"not on this machine"* ]]'
not_ "does not error out"                 '[ "$rc" = 2 ]'

echo "== --unlink reverses, keeping the merged content =="
w=$(mkworld)
mkdir -p "$w/home/.claude/projects/-shared/memory"; printf 'local\n' > "$w/home/.claude/projects/-shared/memory/local.md"
run "$w" --adopt >/dev/null
run "$w" --unlink >/dev/null
not_ "CLAUDE.md is a real file again"     '[ -L "$w/home/.claude/CLAUDE.md" ]'
not_ "memory is a real dir again"         '[ -L "$w/home/.claude/projects/-shared/memory" ]'
yes_ "  and still holds the merged set"   '[ -f "$w/home/.claude/projects/-shared/memory/local.md" ] && [ -f "$w/home/.claude/projects/-shared/memory/s.md" ]'
w=$(mkworld); mkdir -p "$w/elsewhere"; printf 'other\n' > "$w/elsewhere/CLAUDE.md"
ln -s "$w/elsewhere/CLAUDE.md" "$w/home/.claude/CLAUDE.md"
out=$(run "$w" --adopt)
yes_ "foreign symlink is warned about"    '[[ "$out" == *"points elsewhere"* ]]'
check "  and left pointing where it did"  "$(readlink -f "$w/home/.claude/CLAUDE.md")" "$(readlink -f "$w/elsewhere/CLAUDE.md")"
run "$w" --unlink >/dev/null
yes_ "  --unlink refuses to touch it"     '[ -L "$w/home/.claude/CLAUDE.md" ]' 

echo "== SessionStart hook =="
if [ -x "$HOOKS/session-start.sh" ]; then
  w=$(mkworld); run "$w" --apply >/dev/null
  ctx() { python3 -c 'import json,sys;print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'; }
  out=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh" | ctx)
  yes_ "healthy: names the machine"       '[[ "$out" == *"Machine:"* ]]'
  not_ "healthy: no warning"              '[[ "$out" == *WARNING* ]]'
  rm "$w/home/.claude/CLAUDE.md"; printf 'stray\n' > "$w/home/.claude/CLAUDE.md"
  out=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh" | ctx)
  yes_ "unlinked CLAUDE.md warns"         '[[ "$out" == *WARNING*CLAUDE.md* ]]'
  rm "$w/home/.claude/projects/-shared/memory"; mkdir -p "$w/home/.claude/projects/-shared/memory"
  out=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh" | ctx)
  yes_ "unadopted memory scope noted"     '[[ "$out" == *"memory scope"* ]]'
  mkdir -p "$w/bin"; printf '#!/bin/sh\necho "we\\"ird\\\\host"\n' > "$w/bin/hostname"; chmod +x "$w/bin/hostname"
  PATH="$w/bin:$PATH" HOME="$w/home" bash "$HOOKS/session-start.sh" | python3 -c 'import json,sys;json.load(sys.stdin)' 2>/dev/null \
    && ok "hostile hostname still yields valid JSON" || no "hostile hostname breaks JSON"
  yes_ "no python3 dependency"            '! grep -qE "^[^#]*python3" "$HOOKS/session-start.sh"'
else
  no "session-start.sh not found at $HOOKS"
fi

echo "== the hook ignores ephemeral scopes but not real ones =="
if [ -x "$HOOKS/session-start.sh" ]; then
  w=$(mkworld); run "$w" --apply >/dev/null
  mkdir -p "$w/home/.claude/projects/-tmp-junk/memory"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  not_ "an unlinked /tmp scope does not warn"  'echo "$j" | python3 -c "import json,sys;sys.exit(0 if json.load(sys.stdin).get(\"systemMessage\") else 1)"'
  mkdir -p "$w/home/.claude/projects/-home-bph-Desktop-real/memory"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "  but a real unlinked scope does"      'echo "$j" | python3 -c "import json,sys;sys.exit(0 if json.load(sys.stdin).get(\"systemMessage\") else 1)"'
  yes_ "  and counts only the real one"        '[[ "$j" == *"1 memory scope"* ]]'
fi

echo "== SessionEnd hook =="
if [ -x "$HOOKS/session-end.sh" ]; then
  w=$(mkworld)
  mkdir -p "$w/home/.claude/projects/-hooked/memory"; printf 'h\n' > "$w/home/.claude/projects/-hooked/memory/h.md"
  CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" \
    bash "$HOOKS/session-end.sh"; rc=$?
  check "exits 0"                         "$rc" "0"
  yes_ "harvests through the hook"        '[ -L "$w/home/.claude/projects/-hooked/memory" ]'
  ( PATH=/usr/bin:/bin HOME=/nonexistent timeout 25 bash "$HOOKS/session-end.sh" ) ; rc=$?
  check "exits 0 with claude-link absent" "$rc" "0"
else
  no "session-end.sh not found at $HOOKS"
fi

echo "== SessionStart speaks to the user, not just the model =="
if [ -x "$HOOKS/session-start.sh" ]; then
  w=$(mkworld); run "$w" --apply >/dev/null
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "healthy: no systemMessage"        'echo "$j" | python3 -c "import json,sys;sys.exit(0 if \"systemMessage\" not in json.load(sys.stdin) else 1)"'
  rm "$w/home/.claude/CLAUDE.md"; printf 'stray\n' > "$w/home/.claude/CLAUDE.md"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "broken: systemMessage present"    'echo "$j" | python3 -c "import json,sys;sys.exit(0 if json.load(sys.stdin).get(\"systemMessage\") else 1)"'
  yes_ "  and still valid JSON"           'echo "$j" | python3 -c "import json,sys;json.load(sys.stdin)"'
  yes_ "  model context kept too"         'echo "$j" | python3 -c "import json,sys;sys.exit(0 if json.load(sys.stdin)[\"hookSpecificOutput\"][\"additionalContext\"] else 1)"'
fi

echo "== gpullall wires up what it pulls =="
GS="$REPO/bash/.bashrc.d/50-git-sync.sh"
if [ -f "$GS" ]; then
  # shellcheck disable=SC1090
  ( set +u; . "$GS" ) >/dev/null 2>&1
  set +u; . "$GS" >/dev/null 2>&1; set -u
  r=$(mktemp -d "$WORK/gs.XXXXXX"); git -C "$r" init -q
  git -C "$r" config user.email t@t; git -C "$r" config user.name t
  mkdir -p "$r/claude-config/memory/-x"; printf 'a\n' > "$r/claude-config/memory/-x/a.md"
  git -C "$r" add -A; git -C "$r" commit -qm one; old=$(git -C "$r" rev-parse HEAD)
  mkdir -p "$r/claude-config/memory/-y"; printf 'b\n' > "$r/claude-config/memory/-y/b.md"
  git -C "$r" add -A; git -C "$r" commit -qm two
  # hints are queued now; the flush is what prints them (same subshell, so the
  # queue survives between the two calls).
  out=$(PATH=/nonexistent:/usr/bin:/bin _gsync_pull_hints org "$r" "$old" 2>&1; _gsync_flush_hints 2>&1)
  yes_ "new scope fires the hint"         '[[ "$out" == *"claude-config changed"* ]]'
  out=$(_gsync_pull_hints configs "$r" "$old" 2>&1; _gsync_flush_hints 2>&1)
  not_ "does not fire for other repos"    '[[ "$out" == *"claude-config changed"* ]]'
  printf 'a2\n' > "$r/claude-config/memory/-x/a.md"
  git -C "$r" add -A; git -C "$r" commit -qm three; mid=$(git -C "$r" rev-parse HEAD~1)
  out=$(_gsync_pull_hints org "$r" "$mid" 2>&1; _gsync_flush_hints 2>&1)
  not_ "a mere edit does not fire it"     '[[ "$out" == *"claude-config changed"* ]]'
  yes_ "the || true guard is present"     'grep -q "claude-link --auto >/dev/null 2>&1 || true" "$GS"'
else
  no "50-git-sync.sh not found"
fi

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
