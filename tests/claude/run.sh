#!/usr/bin/env bash
# Regression suite for claude-link and the Claude session hooks.
#
#   bash tests/claude/run.sh
#
# Fully sandboxed under $TMPDIR: a fake HOME, a fake org/claude-config, a fake
# ~/Desktop, and git with no global or system config. Needs no network. Runs
# caged (tests/cage.sh). Resolves claude-link relative to its own location, so
# it tests the checkout it lives in, or $CLAUDE_SUITE_LINK when a mutation run
# points it at another copy; the hooks live in org/claude-config and are read
# from there, or from $CLAUDE_SUITE_HOOKS likewise. Writes nothing real --
# three late sections read the live config tree, and only read it.
#
# Last line follows the tests/gsync convention: "passed: N  failed: M".
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
# shellcheck source=/dev/null
source "$REPO/tests/cage.sh"
cage claude "$@"
LINK="${CLAUDE_SUITE_LINK:-$REPO/bin/claude-link}"                     # claude-link under test
HOOKS="${CLAUDE_SUITE_HOOKS:-$HOME/Desktop/org/claude-config/hooks}"  # hook scripts under test
RCFG="${CLAUDE_LINK_CFG:-$HOME/Desktop/org/claude-config}"           # the live tree, read only
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
no()   { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (got '$2', want '$3')"; fi; }
yes_() { if eval "$2"; then ok "$1"; else no "$1"; fi; }
not_() { if eval "$2"; then no "$1"; else ok "$1"; fi; }

[ -x "$LINK" ] || { echo "claude-link not executable at $LINK"; exit 1; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/claude-suite.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
# git sees no config of this machine's: the identity include, the private
# global exclude and its hooks stay out, and scratch commits get a stand-in.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 XDG_CONFIG_HOME="$WORK/xdg"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

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
  # a stub Claude install in the native installer's layout, and the version
  # context-check last ran against, for the hook's version line (2026-10-12)
  mkdir -p "$w/home/.local/bin" "$w/home/.local/share/claude/versions"
  printf 'stub\n' > "$w/home/.local/share/claude/versions/9.9.9"
  ln -s "$w/home/.local/share/claude/versions/9.9.9" "$w/home/.local/bin/claude"
  printf '9.9.9 2026-10-12 test\n' > "$w/cfg/claude-version-checked"
  echo "$w"
}
run() { local w=$1; shift
  HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" \
    "$LINK" "$@" 2>&1; }
# snap <dir>  -- every entry's type, path and link target, and every file's
# hash: two snapshots equal mean nothing under <dir> was written
snap() { ( cd "$1" && find . -path ./.git -prune -o -printf '%y %p %l\n' | sort
           find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 -r md5sum ) 2>/dev/null; }
# sysm <json>  -- the hook's systemMessage, or nothing
sysm() { echo "$1" | python3 -c "import json,sys;print(json.load(sys.stdin).get('systemMessage',''))"; }

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

echo "== dangling links inside ~/.claude are swept too =="
# The plans regression. The user-level pass is driven by `[ -e "$CFG/$e" ]`, so a
# shared directory that disappears is skipped in silence; only the sweep sees it.
w=$(mkworld)
mkdir -p "$w/cfg/plans"; : > "$w/cfg/plans/.gitkeep"
run "$w" --apply >/dev/null
yes_ "a shared dir links at user level"   '[ -L "$w/home/.claude/plans" ]'
rm -f "$w/cfg/plans/.gitkeep"; rmdir "$w/cfg/plans"   # last file gone; git drops the dir
yes_ "link dangles once the dir goes"     '[ -L "$w/home/.claude/plans" ] && [ ! -e "$w/home/.claude/plans" ]'
out=$(run "$w")
yes_ "  dry run reports it"               '[[ "$out" == *"would remove dangling link"*plans* ]]'
yes_ "  and the link pass stays silent"   '[[ "$out" != *"[WARN]"*plans* ]]'
out=$(run "$w" --apply)
not_ "  --apply removes it"               '[ -L "$w/home/.claude/plans" ]'
ln -s "$w/nowhere/x" "$w/home/.claude/foreign"
run "$w" --apply >/dev/null
yes_ "foreign dangling link here untouched" '[ -L "$w/home/.claude/foreign" ]'
# the fedxps case: a memory scope deleted from the shared tree
rm -f "$w/cfg/memory/-shared/s.md" "$w/cfg/memory/-shared/MEMORY.md"; rmdir "$w/cfg/memory/-shared"
out=$(run "$w" --apply)
not_ "dangling memory-scope link swept"   '[ -L "$w/home/.claude/projects/-shared/memory" ]'
yes_ "  transcript dir left in place"     '[ -d "$w/home/.claude/projects/-shared" ]'

echo "== an empty memory scope is held open so it replicates =="
w=$(mkworld)
mkdir -p "$w/cfg/memory/-empty"
run "$w" --auto >/dev/null 2>&1          # --auto prints nothing; it logs
not_ "--auto does not create a keeper"    '[ -e "$w/cfg/memory/-empty/.gitkeep" ]'
yes_ "  and says why in the log"          'grep -q "empty and unkept" "$w/home/.claude/claude-link-auto.log"'
out=$(run "$w")
yes_ "dry run reports the keeper"         '[[ "$out" == *"would add .gitkeep"* ]]'
not_ "  and creates nothing"              '[ -e "$w/cfg/memory/-empty/.gitkeep" ]'
out=$(run "$w" --apply)
yes_ "--apply creates the keeper"         '[ -f "$w/cfg/memory/-empty/.gitkeep" ]'
yes_ "  the scope still links"            '[ -L "$w/home/.claude/projects/-empty/memory" ]'
out=$(run "$w" --apply)
not_ "  idempotent: no second report"     '[[ "$out" == *".gitkeep"* ]]'
not_ "a scope with content is left alone" '[ -e "$w/cfg/memory/-shared/.gitkeep" ]'

echo "== the hook notices a dangling link into the config =="
if [ -x "$HOOKS/session-start.sh" ]; then
  w=$(mkworld); run "$w" --apply >/dev/null
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  not_ "healthy: resolving links do not warn" '[[ "$j" == *"no longer exists"* ]]'
  ln -s "$w/cfg/gone" "$w/home/.claude/plans"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "a dangling link into the config warns" '[[ "$j" == *"1 link(s)"*"no longer exists"* ]]'
  yes_ "  and reaches the user too"       'echo "$j" | python3 -c "import json,sys;sys.exit(0 if json.load(sys.stdin).get(\"systemMessage\") else 1)"'
  ln -s "$w/nowhere/else" "$w/home/.claude/foreign"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "  a foreign dangling link is not counted" '[[ "$j" == *"1 link(s)"* ]]'
fi

echo "== the hook reads the gauge where it is stowed (ws-15, 2026-10-10) =="
if [ -x "$HOOKS/session-start.sh" ]; then
  w=$(mkworld); run "$w" --apply >/dev/null
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  not_ "no ~/bin/sync-check: nothing about the gauge" '[[ "$j" == *"sync-check"* ]]'
  mkdir -p "$w/home/bin"
  printf '#!/bin/sh\nfor f in a b c d e f g h; do echo "[ OK ] $f: up to date"; done; echo; echo "all clear"\n' > "$w/home/bin/sync-check"; chmod +x "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "all clear: the model is told, with the count" '[[ "$j" == *"sync-check: all clear (8 folders up to date)"* ]]'
  not_ "  and the user is not interrupted"  'echo "$j" | python3 -c "import json,sys;sys.exit(0 if json.load(sys.stdin).get(\"systemMessage\") else 1)"'
  # the session line (2026-10-27, settled 76, 77): the stub records its words,
  # and prints the newest full reading's suffix on its folders' OK lines
  printf '#!/bin/sh\necho "$*" > "%s/gauge-args"\nfor f in a b; do echo "[ OK ] $f: up to date (the newest full reading, by byebye 9 h ago, before this boot)"; done\necho "[ OK ] under .git: no conflict copy, no lock older than 10 min"\necho "[ OK ] hub nousowl: the index is 1.0 MB"\necho; echo "all clear"\n' "$w" > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  check "the hook runs the gauge's session line, no other word" "$(cat "$w/gauge-args" 2>/dev/null)" "session"
  yes_ "all clear by the newest reading: its caller and age, and the live lines said" '[[ "$j" == *"sync-check: all clear (2 folders up to date by the newest full reading, byebye 9 h ago, before this boot; conflicts, guard, config and hub read live)."* ]]'
  not_ "  and the user is not interrupted"  'echo "$j" | python3 -c "import json,sys;sys.exit(0 if json.load(sys.stdin).get(\"systemMessage\") else 1)"'
  printf '#!/bin/sh\necho "[ OK ] a: up to date (the newest full reading, by byebye 9 h ago, before this boot)"\necho "[ OK ] b: up to date -- fedxps is offline: 1 item wait for it at the hub (the newest full reading, by gpush 2 h ago)"\necho "[ OK ] c: up to date (the newest full reading, by byebye 9 h ago, before this boot)"\necho; echo "all clear"\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "readings that differ: each named once, in the folders' order" '[[ "$j" == *"sync-check: all clear (3 folders up to date by the newest full readings, from byebye 9 h ago (before this boot) and gpush 2 h ago; conflicts, guard, config and hub read live)."* ]]'
  printf '#!/bin/sh\necho "[ OK ] a: up to date (the newest full reading, by sync-check sync 40 s ago)"\necho; echo "all clear"\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "one folder: singular, a caller of two words kept whole" '[[ "$j" == *"sync-check: all clear (1 folder up to date by the newest full reading, sync-check sync 40 s ago; conflicts"* ]]'
  printf '#!/bin/sh\necho "[WARN] alpha: no full reading on record"; echo "       fix: sync-check sync"; echo "[ OK ] under .git: no conflict copy"; echo; echo "0 needing attention, 1 unknown"; exit 2\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "no reading on record (exit 2): reaches the user, the line named" '[[ "$(sysm "$j")" == *"sync-check exit 2: [WARN] alpha: no full reading on record"* ]]'
  # a reading older than seven days takes the same exit-2 path (2026-10-27)
  printf '#!/bin/sh\necho "[WARN] alpha: the newest full reading is 8 d old (by byebye, before this boot): too old to stand as a reading"; echo "       fix: sync-check sync"; echo; echo "0 needing attention, 1 unknown"; exit 2\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "a reading too old to stand (exit 2): reaches the user, the WARN named" '[[ "$(sysm "$j")" == *"sync-check exit 2: [WARN] alpha: the newest full reading is 8 d old (by byebye, before this boot): too old to stand as a reading"* ]]'
  printf '#!/bin/sh\necho "[ OK ] a: up to date"; echo "[FAIL] nousowl: stranded on bigfed: docs/x.md"; echo "       fix: edit it on fedxps"; echo; echo "1 needing attention, 0 unknown"; exit 1\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "a FAIL: reaches the user"           'echo "$j" | python3 -c "import json,sys;m=json.load(sys.stdin).get(\"systemMessage\",\"\");sys.exit(0 if \"sync-check exit 1: [FAIL] nousowl: stranded on bigfed\" in m else 1)"'
  yes_ "  and the model, as a warning"      '[[ "$j" == *"WARNING: sync-check exit 1"* ]]'
  yes_ "  valid JSON with the gauge text in it" 'echo "$j" | python3 -c "import json,sys;json.load(sys.stdin)"'
  printf '#!/bin/sh\necho "[WARN] x: Syncthing is not answering"; exit 2\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "a WARN (exit 2): reaches the user"  'echo "$j" | python3 -c "import json,sys;sys.exit(0 if \"sync-check exit 2\" in json.load(sys.stdin).get(\"systemMessage\",\"\") else 1)"'
  printf '#!/bin/sh\necho "[ OK ] a: up to date"; echo "[DUE] adelotype-data: up to date; the known item log no longer shows stranded on bigfed"; echo "       fix: delete its line from KNOWN"; echo; echo "1 needing attention, 0 unknown"; exit 3\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "a DUE alone (exit 3, which the gates pass): still reaches the user" 'echo "$j" | python3 -c "import json,sys;m=json.load(sys.stdin).get(\"systemMessage\",\"\");sys.exit(0 if \"sync-check exit 3: [DUE] adelotype-data: up to date\" in m else 1)"'
  yes_ "  and the model, as a warning"      '[[ "$j" == *"WARNING: sync-check exit 3"* ]]'
  printf '#!/bin/sh\nsleep 6\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "a hung gauge: cut at 4 s and said so" '[[ "$j" == *"did not answer within 4 s"* ]]'
  check "  with nothing printed, the message as before" "$(sysm "$j")" "sync-check did not answer within 4 s; run 'sync-check' by hand."
  # a cut after lines were printed: the stored reading prints at once, so the
  # cut falls on a live line, the hub's away from home (2026-10-27)
  printf '#!/bin/sh\necho "[ OK ] a: up to date (the newest full reading, by byebye 9 h ago)"\nsleep 6\n' > "$w/home/bin/sync-check"
  t0=$(date +%s%N); j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh"); t1=$(date +%s%N)
  check "one OK line, then a hang: the line's reading and the cut, to the user" "$(sysm "$j")" "sync-check did not answer within 4 s. Before the cut it printed: 1 folder up to date by the newest full reading, byebye 9 h ago. The rest did not answer; run 'sync-check' by hand."
  yes_ "  and the model, as a warning"      '[[ "$j" == *"WARNING: sync-check did not answer within 4 s. Before the cut it printed: 1 folder up to date"* ]]'
  yes_ "  still inside the hook's 5 s"        '[ $(( (t1 - t0) / 1000000 )) -lt 4500 ]'
  printf '#!/bin/sh\necho "[ OK ] a: up to date (the newest full reading, by gpush 3 min ago)"\necho "[FAIL] under a .git: 1 conflict copy and 0 lock files older than 10 min"\necho "       fix: rename it"\necho "[ OK ] in the directories that load: no conflict copy"\necho "[ OK ] elsewhere under ~/Desktop: no conflict copy"\nsleep 6\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  check "a FAIL before the cut: shown first, then the reading, the live OK lines counted" "$(sysm "$j")" "sync-check did not answer within 4 s. Before the cut it printed: [FAIL] under a .git: 1 conflict copy and 0 lock files older than 10 min; 1 folder up to date by the newest full reading, gpush 3 min ago; 2 more lines OK. The rest did not answer; run 'sync-check' by hand."
  not_ "  the fix line left to the gauge"     '[[ "$j" == *"rename it"* ]]'
  printf '#!/bin/sh\necho "[ OK ] under .git: no conflict copy, no lock older than 10 min"\nsleep 6\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  check "live OK lines alone before the cut: counted, no folder claimed" "$(sysm "$j")" "sync-check did not answer within 4 s. Before the cut it printed: 1 line OK. The rest did not answer; run 'sync-check' by hand."
  # (f) no FAIL and no OK before the cut: a WARN, a WAIT and a DUE each kept
  # (the reviewer's surviving mutant, 2026-10-27)
  printf '#!/bin/sh\necho "[WARN] alpha: no full reading on record"\necho "       fix: sync-check sync"\necho "[WAIT] nousowl: paused on this machine"\necho "[DUE] gamma: up to date; the watcher reports: x"\nsleep 6\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  check "(f) a WARN, a WAIT and a DUE alone before the cut: each kept, in order" "$(sysm "$j")" "sync-check did not answer within 4 s. Before the cut it printed: [WARN] alpha: no full reading on record; [WAIT] nousowl: paused on this machine; [DUE] gamma: up to date; the watcher reports: x. The rest did not answer; run 'sync-check' by hand."
  yes_ "  valid JSON with the gauge text in it" 'echo "$j" | python3 -c "import json,sys;json.load(sys.stdin)"'
  ln -s "$w/cfg/gone" "$w/home/.claude/plans"
  printf '#!/bin/sh\necho "[FAIL] y: z"; exit 1\n' > "$w/home/bin/sync-check"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "both kinds of warning: one systemMessage carries both" 'echo "$j" | python3 -c "import json,sys;m=json.load(sys.stdin).get(\"systemMessage\",\"\");sys.exit(0 if (\"claude-link:\" in m and \"| sync-check exit 1\" in m) else 1)"'
fi

echo "== the hook compares Claude Code with the version context-check last ran against (2026-10-12) =="
if [ -x "$HOOKS/session-start.sh" ]; then
  w=$(mkworld); run "$w" --apply >/dev/null
  hasmsg() { echo "$1" | python3 -c "import json,sys;sys.exit(0 if json.load(sys.stdin).get(\"systemMessage\") else 1)"; }
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "on record: the model is told the version"   '[[ "$j" == *"Claude Code 9.9.9, the version context-check last ran against."* ]]'
  not_ "  and the user is not interrupted"          'hasmsg "$j"'
  printf '1.2.3 2026-09-01 test\n' > "$w/cfg/claude-version-checked"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "a newer install: the user is told it changed, then and now" 'echo "$j" | python3 -c "import json,sys;m=json.load(sys.stdin).get(\"systemMessage\",\"\");sys.exit(0 if \"Claude Code has changed since context-check last ran: 1.2.3 then, 9.9.9 now; run \" in m else 1)"'
  yes_ "  and the model, as a warning"              '[[ "$j" == *"WARNING: Claude Code has changed since context-check last ran: 1.2.3 then, 9.9.9 now"* ]]'
  printf '10.0.0 2026-12-01 test\n' > "$w/cfg/claude-version-checked"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "a record newer than the install is said honestly" '[[ "$j" == *"context-check last ran against Claude Code 10.0.0, newer than the 9.9.9 installed here; this machine catches up at its next update; nothing for him to do."* ]]'
  not_ "  to the model alone: it clears at the next update (2026-10-18)" 'hasmsg "$j"'
  rm "$w/cfg/claude-version-checked"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "no record: asks for one, naming the version" '[[ "$j" == *"context-check has no Claude Code version on record; run "*"and record 9.9.9 as it says."* ]]'
  yes_ "  in both channels"                         'hasmsg "$j"'
  rm "$w/home/.local/bin/claude"
  j=$(PATH=/usr/bin:/bin HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "no install: says the version could not be read" '[[ "$j" == *"version could not be read from its install path"* ]]'
  yes_ "  valid JSON throughout"                    'echo "$j" | python3 -c "import json,sys;json.load(sys.stdin)"'
  w=$(mkworld); run "$w" --apply >/dev/null
  ln -s "$w/cfg/gone" "$w/home/.claude/plans"; printf '1.2.3\n' > "$w/cfg/claude-version-checked"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "with a claude-link warning: one systemMessage carries both" 'echo "$j" | python3 -c "import json,sys;m=json.load(sys.stdin).get(\"systemMessage\",\"\");sys.exit(0 if (\"claude-link:\" in m and \"| Claude Code has changed since\" in m) else 1)"'
  yes_ "the binary is read, never started"          '! grep -qE "^[^#]*claude --version" "$HOOKS/session-start.sh"'
fi

echo "== when the versions differ, the hook reads the gauge's binary checks (2026-10-18) =="
if [ -x "$HOOKS/session-start.sh" ]; then
  w=$(mkworld); run "$w" --apply >/dev/null; mkdir -p "$w/home/bin"
  hook() { HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh"; }
  sysm() { echo "$1" | python3 -c "import json,sys;print(json.load(sys.stdin).get('systemMessage',''))"; }
  ms()   { echo $(( $(date +%s%N) / 1000000 )); }
  # a stub ~/bin/context-check: logs how it was called, then runs the body given
  gauge() { printf '#!/bin/sh\necho "$*" >> "%s/called"\n%s\n' "$w" "$1" > "$w/home/bin/context-check"; chmod +x "$w/home/bin/context-check"; }
  gauge 'echo "[ OK ] recall gate (row 2): as measured"; echo; echo "all clear"'
  j=$(hook)
  not_ "versions agree: the gauge is not run"       '[ -e "$w/called" ]'
  printf '1.2.3 2026-09-01 test\n' > "$w/cfg/claude-version-checked"
  j=$(hook)
  check "a newer install: the gauge is run, once, with --binary" "$(cat "$w/called" 2>/dev/null)" "--binary"
  yes_ "  its checks hold: the model is told, then and now" '[[ "$j" == *"Claude Code has changed since context-check last ran: 1.2.3 then, 9.9.9 now; its binary and switch checks hold on 9.9.9; nothing for him to do."* ]]'
  check "  and the user is not interrupted"          "$(sysm "$j")" ""
  not_ "  nor the model warned"                      '[[ "$j" == *"WARNING"* ]]'
  gauge 'echo "[FAIL] memory numbers (rows 4, 11): the binary reads 1 where 2 is on record"; echo "       rests on: x"; echo "       fix: y"; echo "[ OK ] skill gate (row 18): as measured"; echo; echo "1 failing, 0 unknown"; exit 1'
  j=$(hook)
  yes_ "a check fails: the user is told which"       '[[ "$(sysm "$j")" == *"Claude Code has changed since context-check last ran: 1.2.3 then, 9.9.9 now, and a check on the binary or the server switches fails: memory numbers (rows 4, 11): the binary reads 1 where 2 is on record; run '"'"'context-check'"'"'."* ]]'
  yes_ "  and the model, as a warning"               '[[ "$j" == *"WARNING: Claude Code has changed since context-check last ran"* ]]'
  not_ "  leaving the rests-on and fix lines to the gauge" '[[ "$j" == *"rests on"* || "$j" == *"fix: y"* ]]'
  gauge 'echo "[FAIL] a: one"; echo "[WARN] b: two"; echo "[FAIL] c: three"; echo; echo "2 failing, 1 unknown"; exit 1'
  j=$(hook)
  yes_ "  two failing lines at most, joined"         '[[ "$(sysm "$j")" == *"fails: a: one; b: two; run "* ]]'
  gauge 'echo "[WARN] memory scope (row 3): the anchor via:\"git\" is not in this binary; could not determine"; echo; echo "1 unknown, nothing failing"; exit 2'
  j=$(hook)
  yes_ "a check that cannot be read (exit 2): the user is told, with its line" '[[ "$(sysm "$j")" == *"its binary checks could not all be read (exit 2: memory scope (row 3): the anchor via:\"git\" is not in this binary; could not determine); run "* ]]'
  yes_ "  valid JSON with the gauge's quotes in it" 'echo "$j" | python3 -c "import json,sys;json.load(sys.stdin)"'
  gauge 'sleep 6'
  t0=$(ms); j=$(hook); t1=$(ms)
  yes_ "a hung gauge: cut at 3 s and said so, to the user" '[[ "$(sysm "$j")" == *"its binary checks did not answer within 3 s; run "* ]]'
  yes_ "  well inside the hook's 5 s"                '[ $((t1 - t0)) -lt 4500 ]'
  printf '10.0.0 2026-12-01 test\n' > "$w/cfg/claude-version-checked"
  gauge 'echo "[ OK ] recall gate (row 2): as measured"; echo; echo "all clear"'
  j=$(hook)
  yes_ "a newer record, checks holding: the model alone is told this machine catches up" '[[ "$j" == *"context-check last ran against Claude Code 10.0.0, newer than the 9.9.9 installed here; its binary and switch checks hold on 9.9.9, and this machine catches up at its next update; nothing for him to do."* ]]'
  check "  and the user is not interrupted"          "$(sysm "$j")" ""
  gauge 'echo "[FAIL] server switches (rows 2, 28, 29): tengu_moth_copse (recall) cached true"; echo; echo "1 failing, 0 unknown"; exit 1'
  j=$(hook)
  yes_ "  but a failing check still reaches the user" '[[ "$(sysm "$j")" == *"newer than the 9.9.9 installed here, and a check on the binary or the server switches fails: server switches (rows 2, 28, 29): tengu_moth_copse (recall) cached true; run "* ]]'
  printf '1.2.3 2026-09-01 test\n' > "$w/cfg/claude-version-checked"
  printf '#!/bin/sh\nsleep 2.5\nfor f in a b; do echo "[ OK ] $f: up to date"; done; echo; echo "all clear"\n' > "$w/home/bin/sync-check"; chmod +x "$w/home/bin/sync-check"
  gauge 'sleep 2; echo "[ OK ] recall gate (row 2): as measured"; echo; echo "all clear"'
  t0=$(ms); j=$(hook); t1=$(ms)
  yes_ "the binary checks run beside sync-check, not after it" '[ $((t1 - t0)) -lt 4000 ]'
  yes_ "  and both readings arrive"                  '[[ "$j" == *"sync-check: all clear (2 folders up to date)"* && "$j" == *"its binary and switch checks hold on 9.9.9"* ]]'
  yes_ "  valid JSON throughout"                     'echo "$j" | python3 -c "import json,sys;json.load(sys.stdin)"'
fi

echo "== ephemeral scopes are never harvested or linked =="
w=$(mkworld)
for e in -tmp-scratch -var-tmp-x -run-user-1000-y; do
  mkdir -p "$w/home/.claude/projects/$e/memory"; printf 'junk\n' > "$w/home/.claude/projects/$e/memory/j.md"
done
mkdir -p "$w/cfg/memory/-tmp-already-there"; printf 'x\n' > "$w/cfg/memory/-tmp-already-there/x.md"
out=$(run "$w" --apply)                  # the harvesting run: --auto harvests nothing since 2026-10-26
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
not_ "leaves the new scope to --apply (ws-13)" '[ -L "$w/home/.claude/projects/-brand-new/memory" ]'
not_ "refuses the ambiguous one"          '[ -L "$w/home/.claude/projects/-shared/memory" ]'
check "  and leaves shared copy intact"   "$(cat "$w/cfg/memory/-shared/s.md")" "shared mem"

echo "== --auto refuses a busy repo =="
# What --auto still does is link: the arrived scope -shared stays unlinked
# while the repository is mid-operation, and links once it is over.
w=$(mkworld)
mkdir -p "$w/cfg/.git/rebase-merge"
run "$w" --auto >/dev/null 2>&1
not_ "no write during rebase"             '[ -e "$w/home/.claude/projects/-shared/memory" ]'
not_ "  no log written either"            '[ -e "$w/home/.claude/claude-link-auto.log" ]'
rmdir "$w/cfg/.git/rebase-merge"
run "$w" --auto >/dev/null 2>&1
yes_ "proceeds once rebase is over"       '[ -L "$w/home/.claude/projects/-shared/memory" ]'
for g in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG; do
  w=$(mkworld); : > "$w/cfg/.git/$g"
  run "$w" --auto >/dev/null 2>&1
  not_ "refuses during $g"                '[ -e "$w/home/.claude/projects/-shared/memory" ]'
done

echo "== one run at a time (ws-12) =="
# The battery's link/e2.sh: runs ending together, each finding the same new
# scope, nested a copy and made self-links in the shared tree. A held lock
# turns a second run away; thirty at once leave the tree as one run would.
newscope() {  # a real memory scope this machine made, not yet shared
  mkdir -p "$1/home/.claude/projects/-newscope/memory"
  printf -- '- [n](n.md) — new\n' > "$1/home/.claude/projects/-newscope/memory/MEMORY.md"
  printf 'n\n' > "$1/home/.claude/projects/-newscope/memory/n.md"
}
held() { local w=$1; shift   # run claude-link while another process holds the lock
  flock "$w/home/.claude/.claude-link.lock" env HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" \
    CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" "$LINK" "$@" 2>&1; }
w=$(mkworld); newscope "$w"
out=$(held "$w" --apply); rc=$?
check "--apply while another run holds the lock exits 2" "$rc" "2"
check "  with one line"                           "$(printf '%s\n' "$out" | grep -c .)" "1"
yes_ "  naming the lock"                          '[[ "$out" == *"holds"*".claude-link.lock"* ]]'
not_ "  and changes nothing"                      '[ -L "$w/home/.claude/CLAUDE.md" ] || [ -e "$w/cfg/memory/-newscope" ]'
out=$(held "$w" --auto); rc=$?
check "--auto under a held lock exits 0"          "$rc" "0"
check "  in silence"                              "$out" ""
not_ "  logging nothing"                          '[ -e "$w/home/.claude/claude-link-auto.log" ]'
not_ "  and changing nothing"                     '[ -L "$w/home/.claude/projects/-shared/memory" ]'
out=$(held "$w"); rc=$?
check "the dry run takes no lock"                 "$rc" "1"
yes_ "  and still reports"                        '[[ "$out" == *"would link"* ]]'
out=$(run "$w" --apply); rc=$?
check "once the lock is free, --apply runs"       "$rc" "1"
yes_ "  and harvests"                             '[ -L "$w/home/.claude/projects/-newscope/memory" ]'
w=$(mkworld); newscope "$w"
for i in $(seq 1 30); do ( run "$w" --apply > "$w/run.$i"; echo $? > "$w/rc.$i" ) & done; wait
turned=0 odd=0
for i in $(seq 1 30); do
  case "$(cat "$w/rc.$i")" in
    2) grep -q "another claude-link run holds" "$w/run.$i" && turned=$((turned+1)) || odd=$((odd+1)) ;;
    0|1) ;;
    *) odd=$((odd+1)) ;;
  esac
done
check "thirty --apply at once: the new scope harvested once" \
  "$(cd "$w/cfg/memory/-newscope" 2>/dev/null && find . | sort | tr '\n' ' ')" ". ./MEMORY.md ./n.md "
not_ "  no nested copy"                           '[ -e "$w/cfg/memory/-newscope/memory" ]'
check "  no link anywhere in the shared tree"     "$(find "$w/cfg" -path "$w/cfg/.git" -prune -o -type l -print | wc -l)" "0"
check "  its index intact"                        "$(cat "$w/cfg/memory/-newscope/MEMORY.md" 2>/dev/null)" "- [n](n.md) — new"
check "  the local scope a link to it"            "$(readlink -f "$w/home/.claude/projects/-newscope/memory")" "$(readlink -f "$w/cfg/memory/-newscope")"
check "  the arrived scope linked as one link"    "$(readlink "$w/home/.claude/projects/-shared/memory")" "$w/cfg/memory/-shared"
check "  no run failed"                           "$(cat "$w"/run.* | grep -c '\[FAIL\]')" "0"
check "  each run either ran or was turned away by the lock" "$odd" "0"
w=$(mkworld); newscope "$w"
for i in $(seq 1 30); do run "$w" --auto > "$w/run.$i" & done; wait
not_ "thirty --auto at once: nothing harvested"   '[ -e "$w/cfg/memory/-newscope" ]'
check "  no link anywhere in the shared tree"     "$(find "$w/cfg" -path "$w/cfg/.git" -prune -o -type l -print | wc -l)" "0"
check "  the arrived scope linked as one link"    "$(readlink "$w/home/.claude/projects/-shared/memory")" "$w/cfg/memory/-shared"
check "  the shared index intact"                 "$(cat "$w/cfg/memory/-shared/MEMORY.md")" "- [s](s.md) — h"
check "  the new scope left whole where it was"   "$(ls "$w/home/.claude/projects/-newscope/memory" | tr '\n' ' ')" "MEMORY.md n.md "
check "  and every run silent"                    "$(cat "$w"/run.* | wc -c)" "0"

echo "== --auto writes only under ~/.claude once the Desktop is a folder (ws-13) =="
# The cutover's state, a .stfolder marker at ~/Desktop: a layer's link that
# has arrived before its target (Syncthing makes a symlink from the index
# alone; live-B section 2, the battery's t7.sh), a layer arrived with no link
# yet, a new scope and a new permission file of this machine's, an arrived
# scope with an empty local memory/ and one with a full one.
w=$(mkworld); mkdir "$w/desk/.stfolder"
mkdir -p "$w/desk/rep2" "$w/cfg/repos/rep3" "$w/desk/rep3" "$w/desk/fresh/.claude" "$w/cfg/memory/-arrived" "$w/cfg/memory/-kept"
ln -s "$w/cfg/repos/rep2/CLAUDE.local.md" "$w/desk/rep2/CLAUDE.local.md"       # its target not yet arrived
printf 'layer\n' > "$w/cfg/repos/rep3/CLAUDE.local.md"                          # arrived, not linked here
printf '{"permissions":{"allow":["Bash(f)"]}}\n' > "$w/desk/fresh/.claude/settings.local.json"
newscope "$w"
printf 'a\n' > "$w/cfg/memory/-arrived/a.md"; mkdir -p "$w/home/.claude/projects/-arrived/memory"   # empty, made by a session
printf 'k\n' > "$w/cfg/memory/-kept/k.md";    mkdir -p "$w/home/.claude/projects/-kept/memory"
printf 'local\n' > "$w/home/.claude/projects/-kept/memory/l.md"
ln -s "$w/cfg/gone" "$w/home/.claude/plans"                                     # dangling, under ~/.claude
cfg0=$(snap "$w/cfg"); desk0=$(snap "$w/desk")
out=$(run "$w" --auto); rc=$?
check "--auto: nothing written in the shared tree"  "$(snap "$w/cfg")" "$cfg0"
check "  nor in ~/Desktop"                          "$(snap "$w/desk")" "$desk0"
check "  silent"                                    "$out" ""
yes_ "the dangling layer link survives --auto"      '[ -L "$w/desk/rep2/CLAUDE.local.md" ]'
not_ "the arrived layer is not linked by --auto"    '[ -e "$w/desk/rep3/CLAUDE.local.md" ]'
yes_ "  and the log names it"                       'grep -q "not linked: .*rep3/CLAUDE.local.md" "$w/home/.claude/claude-link-auto.log"'
not_ "a new scope is not harvested by --auto"       '[ -L "$w/home/.claude/projects/-newscope/memory" ]'
yes_ "  and the log says so"                        'grep -q "new memory scope -newscope: --auto harvests nothing" "$w/home/.claude/claude-link-auto.log"'
not_ "a new permission file is not harvested"       '[ -L "$w/desk/fresh/.claude/settings.local.json" ]'
yes_ "an empty local memory/ ends linked"           '[ -L "$w/home/.claude/projects/-arrived/memory" ]'
check "  to its shared scope"                       "$(readlink -f "$w/home/.claude/projects/-arrived/memory")" "$(readlink -f "$w/cfg/memory/-arrived")"
not_ "a full one is left alone"                     '[ -L "$w/home/.claude/projects/-kept/memory" ]'
yes_ "  its file where it was"                      '[ -f "$w/home/.claude/projects/-kept/memory/l.md" ]'
yes_ "  and the log says so"                        'grep -q "exists and is not a link: .*-kept/memory" "$w/home/.claude/claude-link-auto.log"'
not_ "a dangling link under ~/.claude is still swept" '[ -L "$w/home/.claude/plans" ]'
out=$(run "$w"); rc=$?
yes_ "the dry run reports the Desktop's dangling link" '[[ "$out" == *"would remove dangling link"*"rep2/CLAUDE.local.md"* ]]'
out=$(run "$w" --apply); rc=$?
not_ "--apply sweeps the dangling layer link"       '[ -L "$w/desk/rep2/CLAUDE.local.md" ]'
yes_ "  links the arrived layer"                    '[ -L "$w/desk/rep3/CLAUDE.local.md" ]'
yes_ "  harvests the new scope"                     '[ -f "$w/cfg/memory/-newscope/n.md" ] && [ -L "$w/home/.claude/projects/-newscope/memory" ]'
yes_ "  and the new permission file"                '[ -f "$w/cfg/repos/fresh/settings.local.json" ] && [ -L "$w/desk/fresh/.claude/settings.local.json" ]'
not_ "  and still leaves the full scope to --adopt" '[ -L "$w/home/.claude/projects/-kept/memory" ]'
w=$(mkworld); mkdir -p "$w/home/.claude/projects/-shared/memory"
out=$(run "$w"); rc=$?
yes_ "the dry run names the empty directory it would replace" '[[ "$out" == *"would replace the empty directory"*"-shared/memory"* ]]'
yes_ "  and leaves it"                              '[ -d "$w/home/.claude/projects/-shared/memory" ] && [ ! -L "$w/home/.claude/projects/-shared/memory" ]'
run "$w" --apply >/dev/null
yes_ "--apply replaces it too"                      '[ -L "$w/home/.claude/projects/-shared/memory" ]'

echo "== the vendor's skill state stays on its machine (ws-14) =="
# Today's shape: ~/.claude/skills one link into the shared skills/, where
# Anthropic's skill sync keeps synced/, .trash/ and .staging/ (live-B section 3).
skillworld() {
  local w; w=$(mkworld)
  mkdir -p "$w/cfg/skills/restore-order/tools" "$w/cfg/skills/wrap-up" "$w/cfg/skills/synced/alpha" \
           "$w/cfg/skills/synced/beta" "$w/cfg/skills/.trash/old" "$w/cfg/skills/.staging"
  : > "$w/cfg/skills/.gitkeep"
  printf -- '---\nname: restore-order\n---\n' > "$w/cfg/skills/restore-order/SKILL.md"
  printf 'x\n' > "$w/cfg/skills/restore-order/tools/census.py"
  printf -- '---\nname: wrap-up\n---\n'       > "$w/cfg/skills/wrap-up/SKILL.md"
  printf 'a\n' > "$w/cfg/skills/synced/alpha/SKILL.md"; printf 'b\n' > "$w/cfg/skills/synced/beta/SKILL.md"
  printf '{"skills":[]}\n' > "$w/cfg/skills/synced/manifest.json"; : > "$w/cfg/skills/synced/.last-complete-round"
  printf 't\n' > "$w/cfg/skills/.trash/old/SKILL.md"
  ln -s "$w/cfg/skills" "$w/home/.claude/skills"
  echo "$w"
}
w=$(skillworld); v0=$(snap "$w/cfg/skills/synced")
out=$(run "$w"); rc=$?
yes_ "dry run: names the change"                  '[[ "$out" == *"would make ~/.claude/skills a directory of per-skill links"* ]]'
yes_ "  each skill it would link"                 '[[ "$out" == *"would link ~/.claude/skills/restore-order"* && "$out" == *"would link ~/.claude/skills/wrap-up"* ]]'
yes_ "  the vendor's state it would move"         '[[ "$out" == *"would move skills/synced (4 files) out of the shared tree"* && "$out" == *"would move skills/.trash (1 files)"* ]]'
yes_ "  and changes nothing"                      '[ -L "$w/home/.claude/skills" ] && [ -d "$w/cfg/skills/synced" ]'
run "$w" --auto >/dev/null
yes_ "--auto moves nothing"                       '[ -L "$w/home/.claude/skills" ] && [ -f "$w/cfg/skills/synced/manifest.json" ]'
yes_ "  and the log says what will"               'grep -q "claude-link --apply makes it a directory of per-skill links" "$w/home/.claude/claude-link-auto.log"'
out=$(run "$w" --apply); rc=$?
check "--apply: exit 1, changes made"             "$rc" "1"
yes_ "  ~/.claude/skills a real directory"        '[ -d "$w/home/.claude/skills" ] && [ ! -L "$w/home/.claude/skills" ]'
check "  each authored skill a link into the shared tree" "$(readlink "$w/home/.claude/skills/restore-order") $(readlink "$w/home/.claude/skills/wrap-up")" "$w/cfg/skills/restore-order $w/cfg/skills/wrap-up"
yes_ "  the links resolve"                        '[ -f "$w/home/.claude/skills/restore-order/tools/census.py" ] && [ -f "$w/home/.claude/skills/wrap-up/SKILL.md" ]'
check "  no vendor state left in the shared tree" "$(find "$w/cfg/skills" -path '*synced*' -o -name .trash -o -name .staging | wc -l)" "0"
check "  the vendor's files moved whole"          "$(snap "$w/home/.claude/skills/synced")" "$v0"
yes_ "  .trash and .staging with them"            '[ -f "$w/home/.claude/skills/.trash/old/SKILL.md" ] && [ -d "$w/home/.claude/skills/.staging" ]'
yes_ "  the vendor's directories real, not links" '[ ! -L "$w/home/.claude/skills/synced" ] && [ ! -L "$w/home/.claude/skills/.trash" ]'
not_ "  a dotfile of the shared skills/ is not linked" '[ -e "$w/home/.claude/skills/.gitkeep" ]'
yes_ "  and the output says it was a rename"      '[[ "$out" == *"moved skills/synced (4 files) out of the shared tree"*"(a rename on one filesystem)"* ]]'
not_ "  no scaffolding left behind"               'ls -A "$w/home/.claude" | grep -q "^\.skills\."'
out=$(run "$w" --apply); rc=$?
check "a second --apply has nothing to do"        "$rc" "0"
check "  and says nothing about skills"           "$(printf '%s\n' "$out" | sed -n '/== skills ==/,/^$/p' | grep -c '\[')" "0"
if [ -x "$HOOKS/session-start.sh" ]; then
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  not_ "the hook's sentinels still pass"          '[[ "$j" == *"not linked into org/claude-config"* ]]'
  not_ "  no link counted as dangling"            '[[ "$j" == *"no longer exists"* ]]'
  check "  and the user is not interrupted"       "$(sysm "$j")" ""
fi
mkdir -p "$w/cfg/skills/fresh"; printf 'f\n' > "$w/cfg/skills/fresh/SKILL.md"
run "$w" --auto >/dev/null
check "a new authored skill: --auto links it"     "$(readlink "$w/home/.claude/skills/fresh")" "$w/cfg/skills/fresh"
rm -f "$w/cfg/skills/fresh/SKILL.md"; rmdir "$w/cfg/skills/fresh"
run "$w" --auto >/dev/null
not_ "a skill gone from the shared tree: --auto sweeps its link" '[ -L "$w/home/.claude/skills/fresh" ]'
mkdir -p "$w/home/.claude/skills/mine"; printf 'm\n' > "$w/home/.claude/skills/mine/SKILL.md"
out=$(run "$w" --apply)
yes_ "a skill made here alone is named"           '[[ "$out" == *"a skill on this machine alone: ~/.claude/skills/mine"* ]]'
yes_ "  and left where it is"                     '[ -f "$w/home/.claude/skills/mine/SKILL.md" ] && [ ! -L "$w/home/.claude/skills/mine" ] && [ ! -e "$w/cfg/skills/mine" ]'
not_ "  the vendor's synced/ is not named so"     '[[ "$out" == *"alone: ~/.claude/skills/synced"* ]]'
mkdir -p "$w/cfg/skills/synced/z"; printf 'z\n' > "$w/cfg/skills/synced/z/SKILL.md"   # a machine still in the old shape wrote here
out=$(run "$w" --apply)
yes_ "vendor state in both places: warned"        '[[ "$out" == *"skills/synced is both in the shared tree and in ~/.claude/skills"* ]]'
yes_ "  and neither copy touched"                 '[ -f "$w/cfg/skills/synced/z/SKILL.md" ] && [ -f "$w/home/.claude/skills/synced/manifest.json" ] && [ ! -e "$w/home/.claude/skills/synced/z" ]'
rm -f "$w/cfg/skills/synced/z/SKILL.md"; rmdir "$w/cfg/skills/synced/z" "$w/cfg/skills/synced"
run "$w" --unlink >/dev/null
yes_ "--unlink: each per-skill link a real copy"  '[ -d "$w/home/.claude/skills/restore-order" ] && [ ! -L "$w/home/.claude/skills/restore-order" ] && [ -f "$w/home/.claude/skills/restore-order/tools/census.py" ]'
yes_ "  the vendor's state stays where it is"     '[ -f "$w/home/.claude/skills/synced/manifest.json" ]'
check "  and none of it in the shared tree"       "$(find "$w/cfg/skills" -path '*synced*' | wc -l)" "0"
w=$(mkworld); mkdir -p "$w/cfg/skills/solo" "$w/cfg/skills/synced/v"; printf 's\n' > "$w/cfg/skills/solo/SKILL.md"
printf 'v\n' > "$w/cfg/skills/synced/v/SKILL.md"   # the vendor's state, still in the shared tree
run "$w" --auto >/dev/null
yes_ "a new machine: --auto builds the directory of links" '[ -d "$w/home/.claude/skills" ] && [ ! -L "$w/home/.claude/skills" ] && [ -L "$w/home/.claude/skills/solo" ]'
yes_ "  and moves nothing out of the shared tree" '[ -f "$w/cfg/skills/synced/v/SKILL.md" ] && [ ! -e "$w/home/.claude/skills/synced" ]'
yes_ "  the log saying what --apply will move"    'grep -q "skills/synced (1 files) is in the shared tree; claude-link --apply moves it" "$w/home/.claude/claude-link-auto.log"'
run "$w" --apply >/dev/null
yes_ "  which it does"                            '[ -f "$w/home/.claude/skills/synced/v/SKILL.md" ] && [ ! -e "$w/cfg/skills/synced" ]'

echo "== before the cutover --auto links an arrived layer, and after it does not (R1 M2) =="
# Until ~/Desktop is a Syncthing folder a new layer reaches this machine by a
# git pull, whose hint runs --auto, and nothing else would link it; once a
# .stfolder marker sits at ~/Desktop or above it, the link arrives with the
# folder. Removal stays --apply's in both states.
layerworld() {  # a layer arrived but not linked here, and a link still waiting for its target
  local w; w=$(mkworld)
  mkdir -p "$w/cfg/repos/rep3" "$w/desk/rep3" "$w/desk/rep2"
  printf 'layer\n' > "$w/cfg/repos/rep3/CLAUDE.local.md"
  ln -s "$w/cfg/repos/rep2/CLAUDE.local.md" "$w/desk/rep2/CLAUDE.local.md"
  echo "$w"
}
w=$(layerworld); cfg0=$(snap "$w/cfg")
out=$(run "$w" --auto)
check "no marker: --auto links the arrived layer"    "$(readlink "$w/desk/rep3/CLAUDE.local.md")" "$w/cfg/repos/rep3/CLAUDE.local.md"
check "  and the arrived permission file"            "$(readlink "$w/desk/rep/.claude/settings.local.json")" "$w/cfg/repos/rep/settings.local.json"
yes_ "  removes nothing: the waiting link stays"     '[ -L "$w/desk/rep2/CLAUDE.local.md" ]'
check "  writes nothing in the shared tree"          "$(snap "$w/cfg")" "$cfg0"
check "  silent"                                     "$out" ""
yes_ "  and the log says why"                        'grep -qF "lies in no Syncthing folder (no .stfolder at it or above it): --auto makes a missing link here and removes none" "$w/home/.claude/claude-link-auto.log"'
run "$w" --apply >/dev/null
not_ "  --apply sweeps the waiting link, as before"  '[ -L "$w/desk/rep2/CLAUDE.local.md" ]'
for at in desk above; do
  w=$(layerworld)
  if [ "$at" = desk ]; then m="$w/desk"; said="at ~/Desktop"; else m="$w"; said="above ~/Desktop"; fi
  mkdir "$m/.stfolder"; m=$(cd "$m" && pwd -P); desk0=$(snap "$w/desk")
  run "$w" --auto >/dev/null
  not_ "a marker $said: --auto links nothing there"  '[ -e "$w/desk/rep3/CLAUDE.local.md" ] || [ -e "$w/desk/rep/.claude/settings.local.json" ]'
  check "  writes nothing in ~/Desktop"              "$(snap "$w/desk")" "$desk0"
  yes_ "  and the log names the folder"              'grep -qF "rep3/CLAUDE.local.md  (~/Desktop lies in the Syncthing folder at $m, so the link arrives with it" "$w/home/.claude/claude-link-auto.log"'
  run "$w" --apply >/dev/null
  yes_ "  --apply links, as before"                  '[ -L "$w/desk/rep3/CLAUDE.local.md" ] && [ -L "$w/desk/rep/.claude/settings.local.json" ]'
  not_ "  and sweeps the waiting link, as before"    '[ -L "$w/desk/rep2/CLAUDE.local.md" ]'
done

echo "== the adversarial read's cases (R2, 2026-10-26) =="
# Each pins a defect or a surviving mutant of R2's report
# (transport-5a/reports/R2-adversarial.md): M6, the three lows, and the
# mutants CL05, CL10, CL11 and CL13. A race is simulated deterministically by
# a wrapped tool first on the sandbox PATH.
REAL_LN=$(command -v ln) REAL_MKDIR=$(command -v mkdir) REAL_MV=$(command -v mv)
raw() { local w=$1; shift   # claude-link with stdout and stderr apart: stdout to $w/out, stderr to $w/err
  HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" \
    "$LINK" "$@" >"$w/out" 2>"$w/err"; }
for modes in "--auto --apply" "--apply --auto" "--auto --adopt" "--auto --unlink" "--unlink --auto"; do
  w=$(mkworld); newscope "$w"; cfg0=$(snap "$w/cfg"); desk0=$(snap "$w/desk")
  # shellcheck disable=SC2086
  raw "$w" $modes; rc=$?
  check "$modes: refused, exit 2"                 "$rc" "2"
  check "  one line on stderr"                    "$(grep -c . "$w/err")" "1"
  yes_ "  saying --auto runs alone"               'grep -q "auto runs alone" "$w/err"'
  check "  nothing on stdout"                     "$(cat "$w/out")" ""
  yes_ "  nothing written: no link, no log"       '[ ! -e "$w/home/.claude/CLAUDE.md" ] && [ ! -e "$w/home/.claude/claude-link-auto.log" ] && [ "$(snap "$w/cfg")" = "$cfg0" ] && [ "$(snap "$w/desk")" = "$desk0" ]'
done
w=$(mkworld); : > "$w/home/.claude/.claude-link.lock"; chmod 0444 "$w/home/.claude/.claude-link.lock"
raw "$w" --auto; rc=$?
check "a lock file that cannot be opened: --auto exits 0" "$rc" "0"
check "  silent"                                  "$(cat "$w/out" "$w/err")" ""
yes_ "  does nothing"                             '[ ! -e "$w/home/.claude/CLAUDE.md" ]'
yes_ "  and logs one line with the lock and the error" 'grep -qF "claude-link: cannot take the lock $w/home/.claude/.claude-link.lock: Permission denied; nothing done" "$w/home/.claude/claude-link-auto.log"'
raw "$w" --apply; rc=$?
check "  --apply: exit 2"                         "$rc" "2"
check "  with one line, the lock and the error"   "$(cat "$w/err")" "claude-link: cannot take the lock $w/home/.claude/.claude-link.lock: Permission denied; nothing changed."
chmod 0644 "$w/home/.claude/.claude-link.lock"
# CL05: a session creates memory/ between the link pass's test and its link.
w=$(mkworld); mkdir -p "$w/bin"
printf '#!/bin/sh\nfor a; do d=$a; done\ncase "$d" in */projects/-shared/memory) %s -p "$d" ;; esac\nexec %s "$@"\n' "$REAL_MKDIR" "$REAL_LN" > "$w/bin/ln"; chmod +x "$w/bin/ln"
out=$(HOME="$w/home" PATH="$w/bin:$PATH" CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" "$LINK" --apply 2>&1); rc=$?
check "a directory appears where the link goes: the run fails, exit 2" "$rc" "2"
check "  and no link lands inside it"             "$(ls -A "$w/home/.claude/projects/-shared/memory" 2>/dev/null | wc -l)" "0"
run "$w" --apply >/dev/null
check "  the next run links it"                   "$(readlink "$w/home/.claude/projects/-shared/memory")" "$w/cfg/memory/-shared"
# CL13: the other machine's harvest of the same scope arrives between the
# harvest's test and its copy.
w=$(mkworld); newscope "$w"; mkdir -p "$w/bin"
printf '#!/bin/sh\nif [ "$1" = -p ] && [ "$2" = "%s" ] && [ ! -e "$2/-newscope" ]; then\n  %s -p "$2/-newscope"; printf "theirs\\n" > "$2/-newscope/t.md"\nfi\nexec %s "$@"\n' \
  "$w/cfg/memory" "$REAL_MKDIR" "$REAL_MKDIR" > "$w/bin/mkdir"; chmod +x "$w/bin/mkdir"
out=$(HOME="$w/home" PATH="$w/bin:$PATH" CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" "$LINK" --apply 2>&1); rc=$?
check "the shared scope arrives mid-harvest: the harvest fails, exit 2" "$rc" "2"
check "  nothing copied into the arrival"        "$(cd "$w/cfg/memory/-newscope" && find . | sort | tr '\n' ' ')" ". ./t.md "
yes_ "  and the local scope kept whole, for --adopt" '[ -f "$w/home/.claude/projects/-newscope/memory/n.md" ] && [ ! -L "$w/home/.claude/projects/-newscope/memory" ]'
# CL10: the new skills directory cannot take the link's name.
w=$(skillworld); mkdir -p "$w/bin"
printf '#!/bin/sh\ncase "$*" in *.skills.claude-link.*) echo "mv: simulated failure" >&2; exit 1 ;; esac\nexec %s "$@"\n' "$REAL_MV" > "$w/bin/mv"; chmod +x "$w/bin/mv"
out=$(HOME="$w/home" PATH="$w/bin:$PATH" CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" "$LINK" --apply 2>&1); rc=$?
check "the swap fails: exit 2"                    "$rc" "2"
check "  the old link put back"                   "$(readlink "$w/home/.claude/skills")" "$w/cfg/skills"
yes_ "  the vendor's state left in place"         '[ -f "$w/cfg/skills/synced/manifest.json" ]'
not_ "  and no scaffolding left behind"           'ls -A "$w/home/.claude" | grep -q "^\.skills\."'
# CL11: --unlink in the old shape copies the whole directory, as before.
w=$(skillworld)
out=$(run "$w" --unlink)
yes_ "--unlink in the old shape: ~/.claude/skills a real copy" '[ -d "$w/home/.claude/skills" ] && [ ! -L "$w/home/.claude/skills" ] && [ -f "$w/home/.claude/skills/restore-order/tools/census.py" ] && [ -f "$w/home/.claude/skills/synced/manifest.json" ]'
yes_ "  and it says so"                           '[[ "$out" == *"unlinked, now a real copy: ~/.claude/skills"* ]]'
if [ -x "$HOOKS/session-start.sh" ]; then
  w=$(mkworld); run "$w" --apply >/dev/null
  hook() { HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh"; }
  printf 'z\n' > "$w/cfg/memory/-shared/ctl$(printf '\001')x$(printf '\r')y.md"
  j=$(hook)
  yes_ "a control character in a topic name: valid JSON" 'echo "$j" | python3 -c "import json,sys;json.load(sys.stdin)" 2>/dev/null'
  yes_ "  and the name shown as it is"            '[[ "$(sysm "$j")" == *"-shared/ctl"$'"'"'\001'"'"'"x"$'"'"'\r'"'"'"y.md"* ]]'
  rm -f "$w/cfg/memory/-shared/ctl"*
  ete=$'\xc3\xa9t\xc3\xa9'                 # e-acute, t, e-acute in UTF-8
  for n in "a b" "c d" "$ete" "e f"; do printf 'x\n' > "$w/cfg/memory/-shared/$n.md"; done
  printf -- '- [ab](a%%20b.md) — h\n- [cd](<c d.md>) — h\n- [ete](%%C3%%A9t%%C3%%A9.md) — h\n' >> "$w/cfg/memory/-shared/MEMORY.md"
  j=$(hook)
  not_ "a link spelt a%20b.md, <c d.md> or percent-encoded: named, so not reported" '[[ "$j" == *"-shared/a b.md"* || "$j" == *"-shared/c d.md"* || "$j" == *"-shared/$ete.md"* ]]'
  yes_ "  while a file no link names still is"    '[[ "$(sysm "$j")" == *"1 memory file(s)"*"-shared/e f.md"* ]]'
fi

echo "== the host pass: ~/CLAUDE.md, this machine's own charter (decision 12; 5b, 2026-10-26) =="
# A link to hosts/<hostname -s>.md in the shared tree, made by the deliberate
# runs and never by --auto, since ~/CLAUDE.md lies outside ~/.claude (ws-13).
# hostname is a stub first on the sandbox PATH: testhost with -s, a full name
# without it, so a pass that drops the -s finds no file.
hrun() { local w=$1; shift
  PATH="$w/bin:$PATH" HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" \
    "$LINK" "$@" 2>&1; }
hostworld() {  # this machine's host file and the other's, everything else linked, no ~/CLAUDE.md
  local w; w=$(mkworld); mkdir -p "$w/bin" "$w/cfg/hosts"
  printf '#!/bin/sh\ncase "$1" in -s) echo testhost ;; *) echo testhost.example.org ;; esac\n' > "$w/bin/hostname"; chmod +x "$w/bin/hostname"
  printf 'this machine\n' > "$w/cfg/hosts/testhost.md"
  printf 'the other\n'    > "$w/cfg/hosts/otherhost.md"
  hrun "$w" --apply >/dev/null; rm -f "$w/home/CLAUDE.md"
  echo "$w"
}
hostlines() { printf '%s\n' "$1" | sed -n '/^== host ==$/,/^$/p' | grep '\['; }
w=$(hostworld)
out=$(hrun "$w"); rc=$?
check "dry run, the host file present and no link: exit 1" "$rc" "1"
check "  naming it"                                "$(hostlines "$out")" "  [LINK] would link ~/CLAUDE.md"
check "  its only pending change"                  "$(printf '%s\n' "$out" | grep -c '^  \[\(LINK\|ADPT\)\]')" "1"
not_ "  and it makes nothing"                      '[ -e "$w/home/CLAUDE.md" ] || [ -L "$w/home/CLAUDE.md" ]'
out=$(hrun "$w" --auto)
check "--auto, the link missing: silent"           "$out" ""
not_ "  makes none"                                '[ -e "$w/home/CLAUDE.md" ] || [ -L "$w/home/CLAUDE.md" ]'
yes_ "  and its log names claude-link --apply"     'grep -qF "not linked: ~/CLAUDE.md  (it lies outside ~/.claude, so --auto makes none; claude-link --apply does)" "$w/home/.claude/claude-link-auto.log"'
out=$(hrun "$w" --apply); rc=$?
check "--apply links it: exit 1"                   "$rc" "1"
check "  to this machine's host file"              "$(readlink "$w/home/CLAUDE.md")" "$w/cfg/hosts/testhost.md"
check "  and says so"                              "$(hostlines "$out")" "  [LINK] ~/CLAUDE.md"
out=$(hrun "$w" --apply); rc=$?
check "a second --apply: all correct, exit 0"      "$rc" "0"
check "  nothing said about it"                    "$(hostlines "$out")" ""
out=$(hrun "$w"); rc=$?
check "  and the dry run exits 0"                  "$rc" "0"
if [ -x "$HOOKS/session-start.sh" ]; then
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  not_ "  the hook reads the made link as healthy" '[[ "$j" == *"~/CLAUDE.md"* ]]'
fi
rm -f "$w/home/.claude/claude-link-auto.log"
out=$(hrun "$w" --auto)
check "--auto, the link correct: leaves it"        "$(readlink "$w/home/CLAUDE.md")" "$w/cfg/hosts/testhost.md"
not_ "  with nothing to log about it"              'grep -qF "~/CLAUDE.md" "$w/home/.claude/claude-link-auto.log"'
hrun "$w" --unlink >/dev/null
yes_ "--unlink: ~/CLAUDE.md a real copy"           '[ -f "$w/home/CLAUDE.md" ] && [ ! -L "$w/home/CLAUDE.md" ]'
check "  with the host file's content"             "$(cat "$w/home/CLAUDE.md")" "this machine"
check "  the host file untouched"                  "$(cat "$w/cfg/hosts/testhost.md")" "this machine"
w=$(hostworld); rm "$w/cfg/hosts/testhost.md"
out=$(hrun "$w"); rc=$?
check "no host file for this machine: the dry run exits 0" "$rc" "0"
check "  silent about ~/CLAUDE.md"                 "$(hostlines "$out")" ""
hrun "$w" --apply >/dev/null
not_ "  --apply makes no link"                     '[ -e "$w/home/CLAUDE.md" ] || [ -L "$w/home/CLAUDE.md" ]'
printf 'by hand\n' > "$w/home/CLAUDE.md"
out=$(hrun "$w" --apply); rc=$?
check "  a plain ~/CLAUDE.md beside no host file: silent, exit 0" "$(hostlines "$out") $rc" " 0"
w=$(hostworld); printf 'my own\n' > "$w/home/CLAUDE.md"
out=$(hrun "$w" --apply)
check "a real differing ~/CLAUDE.md: --apply warns" "$(hostlines "$out")" "  [WARN] exists and is not a link: ~/CLAUDE.md   (re-run with --adopt)"
check "  and leaves it"                            "$(cat "$w/home/CLAUDE.md")" "my own"
out=$(hrun "$w" --adopt)
check "--adopt backs it up"                        "$(cat "$w"/home/.claude/link-backups/*/CLAUDE.md 2>/dev/null)" "my own"
yes_ "  skips it, saying so"                       '[[ "$out" == *"differs from the shared copy, backed up and skipped: ~/CLAUDE.md"* ]]'
yes_ "  the file still his"                        '[ -f "$w/home/CLAUDE.md" ] && [ ! -L "$w/home/CLAUDE.md" ] && [ "$(cat "$w/home/CLAUDE.md")" = "my own" ]'
check "  and the host file untouched"              "$(cat "$w/cfg/hosts/testhost.md")" "this machine"
w=$(hostworld); printf 'this machine\n' > "$w/home/CLAUDE.md"
out=$(hrun "$w" --adopt)
check "an identical ~/CLAUDE.md: --adopt replaces it with the link" "$(readlink "$w/home/CLAUDE.md")" "$w/cfg/hosts/testhost.md"
yes_ "  and says so"                               '[[ "$out" == *"~/CLAUDE.md  (identical, replaced)"* ]]'
w=$(hostworld); hrun "$w" --apply >/dev/null; rm "$w/cfg/hosts/testhost.md"
out=$(hrun "$w"); rc=$?
check "the host file gone, the link dangling: one warning" "$(hostlines "$out" | grep -c .)" "1"
yes_ "  naming the missing file"                   '[[ "$(hostlines "$out")" == "  [WARN] ~/CLAUDE.md is a link to $w/cfg/hosts/testhost.md, which is not there"* ]]'
check "  the dry run exiting 0 over it, a WARN of sync-check config" "$rc" "0"
yes_ "  and counting it in the summary"            '[[ "$out" == *"warnings        : 1"* ]]'
hrun "$w" --apply >/dev/null
check "  --apply leaves the link"                  "$(readlink "$w/home/CLAUDE.md")" "$w/cfg/hosts/testhost.md"
out=$(hrun "$w" --auto)
check "  --auto silent"                            "$out" ""
ln -sfn "$w/elsewhere/CLAUDE.md" "$w/home/CLAUDE.md"
out=$(hrun "$w")
check "a dangling ~/CLAUDE.md not into hosts/: not named" "$(hostlines "$out")" ""

echo "== absent repos are skipped, not failed =="
w=$(mkworld)
mkdir -p "$w/cfg/repos/ghost"; printf '{"permissions":{"allow":[]}}\n' > "$w/cfg/repos/ghost/settings.local.json"
out=$(run "$w" --apply); rc=$?
yes_ "reports the skip"                   '[[ "$out" == *"ghost"*"not on this machine"* ]]'
not_ "does not error out"                 '[ "$rc" = 2 ]'

echo "== orphan charters are reported, never moved =="
# An orphan is a charter git ignores and does not track: nothing syncs it, and a
# merge that brings its path replaces it in silence. The sandbox brings its own
# exclude, so the result does not depend on this machine's git config.
w=$(mkworld)
printf '**/CLAUDE.md\n**/CLAUDE.local.md\n' > "$w/excludes"
printf '[core]\n\texcludesFile = %s\n[user]\n\tname = t\n\temail = t@t\n' "$w/excludes" > "$w/gitconfig"
gx() { GIT_CONFIG_GLOBAL="$w/gitconfig" GIT_CONFIG_NOSYSTEM=1 "$@"; }
mkdir -p "$w/desk/proj/sub" "$w/desk/seen" "$w/desk/loose" "$w/cfg/repos/proj"
gx git -C "$w/desk/proj" init -q
printf 'tracked\n' > "$w/desk/proj/CLAUDE.md"
gx git -C "$w/desk/proj" add -f CLAUDE.md; gx git -C "$w/desk/proj" commit -q -m one
printf 'o\n' > "$w/desk/proj/sub/CLAUDE.md"            # ignored and untracked
printf 'o\n' > "$w/desk/proj/sub/CLAUDE.local.md"      # ignored and untracked
printf 'layer\n' > "$w/cfg/repos/proj/CLAUDE.local.md" # linked in by --apply
gx git -C "$w/desk/seen" init -q
printf '!CLAUDE.md\n' > "$w/desk/seen/.gitignore"
printf 'v\n' > "$w/desk/seen/CLAUDE.md"                # untracked, but git status lists it
printf 'l\n' > "$w/desk/loose/CLAUDE.md"               # in no work tree
out=$(gx run "$w")
yes_ "an ignored untracked CLAUDE.md is reported" '[[ "$out" == *"orphan charter"*"proj/sub/CLAUDE.md"* ]]'
yes_ "  and a CLAUDE.local.md"                    '[[ "$out" == *"orphan charter"*"proj/sub/CLAUDE.local.md"* ]]'
not_ "a tracked charter is not"                   '[[ "$out" == *"orphan charter"*"/proj/CLAUDE.md"* ]]'
not_ "a charter git status lists is not"          '[[ "$out" == *"orphan charter"*"seen/CLAUDE.md"* ]]'
not_ "a charter in no work tree is not"           '[[ "$out" == *"loose/CLAUDE.md"* ]]'
yes_ "the summary counts them"                    '[[ "$out" == *"orphans "*": 2"* ]]'
not_ "the dry run writes no list"                 '[ -e "$w/home/.claude/claude-link-orphans" ]'
gx run "$w" --apply >/dev/null
check "--apply keeps the list for the hook"       "$(grep -c . "$w/home/.claude/claude-link-orphans" 2>/dev/null)" "2"
yes_ "  and moves nothing"                        '[ -f "$w/desk/proj/sub/CLAUDE.md" ] && [ ! -L "$w/desk/proj/sub/CLAUDE.md" ] && [ -f "$w/desk/proj/sub/CLAUDE.local.md" ] && [ ! -L "$w/desk/proj/sub/CLAUDE.local.md" ]'
yes_ "a link into the layer is not an orphan"     '[ -L "$w/desk/proj/CLAUDE.local.md" ] && ! grep -q "proj/CLAUDE.local.md" "$w/home/.claude/claude-link-orphans"'
out=$(gx run "$w" --apply); rc=$?
check "orphans leave the exit status alone"       "$rc" "0"
rm -f "$w/home/.claude/claude-link-orphans"
out=$(gx run "$w" --auto)
check "--auto stays silent"                       "$out" ""
check "  and keeps the list too"                  "$(grep -c . "$w/home/.claude/claude-link-orphans" 2>/dev/null)" "2"
rm "$w/desk/proj/sub/CLAUDE.md" "$w/desk/proj/sub/CLAUDE.local.md"
gx run "$w" --apply >/dev/null
not_ "once they are gone, so is the list"         '[ -e "$w/home/.claude/claude-link-orphans" ]'

echo "== the hook counts orphan charters =="
if [ -x "$HOOKS/session-start.sh" ]; then
  w=$(mkworld); run "$w" --apply >/dev/null
  # two paths and a stray blank line, which is not counted
  printf '~/Desktop/a/CLAUDE.md\n\n~/Desktop/b/sub/CLAUDE.local.md\n' > "$w/home/.claude/claude-link-orphans"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "a listed orphan warns, with the count" '[[ "$j" == *"2 orphan charter(s)"* ]]'
  yes_ "  and reaches the user too"            'echo "$j" | python3 -c "import json,sys;sys.exit(0 if json.load(sys.stdin).get(\"systemMessage\") else 1)"'
  : > "$w/home/.claude/claude-link-orphans"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  not_ "an empty list is silent"               '[[ "$j" == *"orphan"* ]]'
  rm "$w/home/.claude/claude-link-orphans"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  not_ "  and so is no list"                   '[[ "$j" == *"orphan"* ]]'
else
  no "session-start.sh not found at $HOOKS"
fi

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
  not_ "an empty one with no shared scope: nothing to adopt, no warning" '[[ "$j" == *"memory scope"* ]]'
  printf 'r\n' > "$w/home/.claude/projects/-home-bph-Desktop-real/memory/r.md"
  j=$(HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh")
  yes_ "  but a real unlinked scope does"      'echo "$j" | python3 -c "import json,sys;sys.exit(0 if json.load(sys.stdin).get(\"systemMessage\") else 1)"'
  yes_ "  and counts only the real one"        '[[ "$j" == *"1 memory scope"* ]]'
fi

echo "== SessionEnd hook =="
if [ -x "$HOOKS/session-end.sh" ]; then
  # The hook finds claude-link at ~/bin, where it is stowed: here, the one under test.
  w=$(mkworld); mkdir -p "$w/home/bin"; ln -s "$LINK" "$w/home/bin/claude-link"
  mkdir -p "$w/home/.claude/projects/-hooked/memory"; printf 'h\n' > "$w/home/.claude/projects/-hooked/memory/h.md"
  HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" \
    bash "$HOOKS/session-end.sh"; rc=$?
  check "exits 0"                         "$rc" "0"
  yes_ "links the arrived scope through the hook" '[ -L "$w/home/.claude/projects/-shared/memory" ]'
  not_ "  and harvests nothing (ws-13)"   '[ -e "$w/cfg/memory/-hooked" ]'
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

echo "== the hook names memories that would not load (ws-15) =="
if [ -x "$HOOKS/session-start.sh" ]; then
  w=$(mkworld); run "$w" --apply >/dev/null
  hook() { HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" bash "$HOOKS/session-start.sh"; }
  valid() { echo "$1" | python3 -c "import json,sys;json.load(sys.stdin)" 2>/dev/null; }
  j=$(hook)
  not_ "healthy: no memory warning"               '[[ "$j" == *"WARNING: memory"* ]]'
  printf 'lost\n' > "$w/cfg/memory/-shared/lost.md"
  j=$(hook)
  yes_ "a topic file its index does not name: the model is told, scope and file" '[[ "$j" == *"WARNING: memory: 1 memory file(s) that their scope"*"MEMORY.md does not name, so they never load: -shared/lost.md; add each"* ]]'
  yes_ "  and the user"                           '[[ "$(sysm "$j")" == *"memory: 1 memory file(s)"*"-shared/lost.md"* ]]'
  printf -- '- [lost](lost.md) — back\n' >> "$w/cfg/memory/-shared/MEMORY.md"
  j=$(hook)
  not_ "  named again: silent"                    '[[ "$j" == *"WARNING: memory"* ]]'
  printf -- '- [s](s.md) — h\n- [n](n.md) — theirs\n' > "$w/cfg/memory/-shared/MEMORY.sync-conflict-20261009-153031-ABCDEFG.md"
  j=$(hook)
  yes_ "a conflict copy of the index: named, to both channels" '[[ "$(sysm "$j")" == *"1 conflict copy(ies) among the memories, which never load: -shared/MEMORY.sync-conflict-20261009-153031-ABCDEFG.md"* ]]'
  yes_ "  the model too"                          '[[ "$j" == *"WARNING: memory: 1 conflict copy(ies)"* ]]'
  not_ "  and not counted again as an unnamed file" '[[ "$j" == *"does not name"* ]]'
  printf 'x\n' > "$w/cfg/memory/-shared/s.sync-conflict-20261009-153031-ABCDEFG.md"
  j=$(hook)
  yes_ "  a topic file's copy counted beside it"  '[[ "$j" == *"2 conflict copy(ies)"* ]]'
  rm -f "$w/cfg/memory/-shared/"*.sync-conflict-*
  mkdir -p "$w/home/.claude/projects/-real/memory"; printf 'u\n' > "$w/home/.claude/projects/-real/memory/u.md"
  j=$(hook)
  not_ "a scope still a real directory is the adoption count's alone" '[[ "$j" == *"-real/u.md"* ]]'
  rm -f "$w/home/.claude/projects/-real/memory/u.md"
  for i in 1 2 3 4 5 6 7 8 9; do printf 'x\n' > "$w/cfg/memory/-shared/m$i.md"; done
  j=$(hook)
  yes_ "nine unnamed: six named, the rest counted" '[[ "$j" == *"9 memory file(s)"*"-shared/m6.md and 3 more; add each"* ]]'
  rm -f "$w/cfg/memory/-shared/m"?.md
  printf 'q\n' > "$w/cfg/memory/-shared/we\"ird\\name.md"
  j=$(hook)
  yes_ "a hostile file name still yields valid JSON" 'valid "$j"'
  yes_ "  and is named"                           '[[ "$(sysm "$j")" == *"-shared/we\"ird\\name.md"* ]]'
  rm -f "$w/cfg/memory/-shared/we"*
  mkdir -p "$w/cfg/hosts"; printf 'this machine\n' > "$w/cfg/hosts/bigfed.md"
  ln -s "$w/cfg/hosts/bigfed.md" "$w/home/CLAUDE.md"
  j=$(hook)
  not_ "~/CLAUDE.md a link to its file: silent"   '[[ "$j" == *"~/CLAUDE.md"* ]]'
  ln -sfn "$w/cfg/hosts/gone.md" "$w/home/CLAUDE.md"
  j=$(hook)
  yes_ "a dangling ~/CLAUDE.md: the user is told" '[[ "$(sysm "$j")" == *"~/CLAUDE.md is a link to $w/cfg/hosts/gone.md, which is not there, so this machine"*"charter is not loading"* ]]'
  yes_ "  and the model"                          '[[ "$j" == *"WARNING: ~/CLAUDE.md is a link to"* ]]'
  printf 'older\n' > "$w/cfg/hosts/bigfed.sync-conflict-20261009-153031-ABCDEFG.md"
  ln -sfn "$w/cfg/hosts/bigfed.sync-conflict-20261009-153031-ABCDEFG.md" "$w/home/CLAUDE.md"
  j=$(hook)
  yes_ "a link aimed at a conflict copy: the user is told" '[[ "$(sysm "$j")" == *"~/CLAUDE.md resolves to a Syncthing conflict copy, $w/cfg/hosts/bigfed.sync-conflict-20261009-153031-ABCDEFG.md, and loads it"* ]]'
  yes_ "  valid JSON throughout"                  'valid "$j"'
  rm "$w/home/CLAUDE.md"; printf 'plain\n' > "$w/home/CLAUDE.md"
  j=$(hook)
  not_ "a plain ~/CLAUDE.md: silent"              '[[ "$j" == *"~/CLAUDE.md"* ]]'
  rm "$w/home/CLAUDE.md"
  # The budget: 400 topic files in 20 linked scopes, every one indexed, and a
  # gauge that hangs until the hook cuts it.
  for k in $(seq -w 1 20); do
    mkdir -p "$w/cfg/memory/-s$k"; : > "$w/cfg/memory/-s$k/MEMORY.md"
    for i in $(seq -w 1 20); do
      printf 'body\n' > "$w/cfg/memory/-s$k/topic-$i.md"
      printf -- '- [topic %s](topic-%s.md) — a hook line long enough to look like the real ones do\n' "$i" "$i" >> "$w/cfg/memory/-s$k/MEMORY.md"
    done
  done
  run "$w" --apply >/dev/null
  t0=$(date +%s%N); j=$(hook); t1=$(date +%s%N)
  not_ "400 indexed files: no warning"            '[[ "$j" == *"WARNING"* ]]'
  yes_ "  read inside 1 s"                        '[ $(( (t1 - t0) / 1000000 )) -lt 1000 ]'
  mkdir -p "$w/home/bin"; printf '#!/bin/sh\nsleep 6\n' > "$w/home/bin/sync-check"; chmod +x "$w/home/bin/sync-check"
  t0=$(date +%s%N); j=$(hook); t1=$(date +%s%N)
  yes_ "  and with a hung gauge, still inside the hook's 5 s" '[ $(( (t1 - t0) / 1000000 )) -lt 4500 ]'
  echo "     (the hook took $(( (t1 - t0) / 1000000 )) ms with a hung gauge)"
else
  no "session-start.sh not found at $HOOKS"
fi

echo "== the live config holds no directory git cannot carry =="
# The root cause of the plans breakage, asserted against the real tree: git
# cannot carry an empty directory, so an empty one here means a link on the
# other machine is about to dangle. Read-only.
if [ -d "$RCFG" ]; then
  empties=$(find "$RCFG" -path "$RCFG/.git" -prune -o -type d -empty -print 2>/dev/null)
  if [ -z "$empties" ]; then ok "no empty directories in the shared config"
  else no "empty directories in the shared config: $(echo $empties)"; fi
  yes_ "  plans/ is held open by a keeper" '[ -e "$RCFG/plans/.gitkeep" ]'
else
  ok "live config not on this machine, skipped"
fi

echo "== the live settings keep conflict copies out of context (ws-3) =="
# Static: the key and its value. That it stops a rule's conflict copy, through
# the symlinked rules/, was measured by the battery (claude T2b-T2c); a
# headless re-run belongs after each Claude Code upgrade. Read-only.
if [ -f "$RCFG/settings.json" ]; then
  check "claudeMdExcludes is exactly the conflict-copy glob" \
    "$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1])).get("claudeMdExcludes")))' "$RCFG/settings.json")" '["**/*.sync-conflict-*"]'
  check "  and .gitignore still guards the vendor's three skill directories" \
    "$(grep -cxE 'skills/(synced|\.trash|\.staging)/' "$RCFG/.gitignore")" "3"
else
  ok "live config not on this machine, skipped"
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
