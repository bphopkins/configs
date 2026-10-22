#!/usr/bin/env bash
# Regression suite for context-check.
#
#   bash tests/context-check/run.sh
#
# Fully sandboxed under $TMPDIR: a fake config tree (made a git work tree only
# where check 2's ignore rule is tested), a fake HOME holding a fake ~/.claude,
# ~/.claude.json and Claude install, a fake ~/Desktop. Touches nothing real and
# needs no network. The installed Claude binary is never read:
# the premise checks (10 to 19) run against a stub binary carrying the vendor's
# anchor strings with the values measured on 2.1.296, a stub flag cache and stub
# transcripts, each mutated in turn; the stub would leave a marker if it were
# ever started, and the suite asserts it never is. Caged (tests/cage.sh) since
# 2026-10-12. Resolves the script relative to its own location, so it tests the
# checkout it lives in.
#
# Last line follows the tests/gsync convention: "passed: N  failed: M".
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
# shellcheck source=/dev/null
source "$REPO/tests/cage.sh"
cage context-check "$@"
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

san() { printf '%s' "$1" | sed 's/[^a-zA-Z0-9_-]/-/g'; }   # the harness's scope name for a launch folder

# a stub binary: the vendor's anchors, in the shapes the gauge reads, with the
# values measured on 2.1.296; executable, and leaving a marker if ever started
stubbin() {
  printf '%s\n' '#!/bin/sh' "touch '$1.started'; exit 0" \
    'x,R7 as isMemoryRecallEnabled,y' \
    'function R7(){if(k("tengu_moth_copse",!1))return!0;return HEr()}function HEr(){return!!process.env.CLAUDE_MEMORY_STORES?.trim()}' \
    'return{base:r,via:"git"}' \
    'var Iu="MEMORY.md",iN=200,Roe=25000,cwr=4*Roe,nRe=200,xoe=4096;function glt(t){}' \
    'var Wyn={MAX_SESSION_BYTES:61440};' \
    'Only part of it was loaded' \
    ' tool due to disable-model-invocation. ' \
    'if((e.type==="Project"||e.type==="Local")&&k("tengu_paper_halyard",!1))return!1;' > "$1"
  chmod +x "$1"
}

# the transcripts of one session launched in desk/rep, whose sub/ carries a
# charter, and of one general-purpose worker of it; the scope has a memory index
transcripts() {
  local w=$1 L="$1/desk/rep" S P sid=$SID
  S=$(san "$L"); P="$w/home/.claude/projects/$S"
  mkdir -p "$P/memory" "$P/$sid/subagents"
  printf -- '- [x](x.md) — h\n' > "$P/memory/MEMORY.md"
  BUNDLE='{"type":"attachment","attachment":{"type":"instructions","files":[{"path":"'"$w"'/home/.claude/CLAUDE.md","type":"User"},{"path":"'"$w"'/desk/CLAUDE.md","type":"Project"},{"path":"'"$P"'/memory/MEMORY.md","type":"AutoMem"}]},"cwd":"'"$L"'"}'
  {
    printf '{"type":"user","cwd":"%s","timestamp":"2026-10-12T00:00:00.000Z","version":"9.9.9","message":{"role":"user","content":"hi"}}\n' "$L"
    printf '%s\n' "$BUNDLE"
    printf '{"type":"assistant","cwd":"%s","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"%s/sub/a.txt"}}]}}\n' "$L" "$L"
    printf '{"type":"attachment","cwd":"%s","attachment":{"type":"nested_memory","path":"%s/sub/CLAUDE.md","content":{"type":"Project"}}}\n' "$L" "$L"
  } > "$P/$sid.jsonl"
  printf '{"agentType":"general-purpose"}\n' > "$P/$sid/subagents/agent-1.meta.json"
  { printf '{"type":"user","cwd":"%s/sub","message":{"role":"user","content":"go"}}\n' "$L"; printf '%s\n' "$BUNDLE"; } > "$P/$sid/subagents/agent-1.jsonl"
}

SID=aaaaaaaa-0000-0000-0000-000000000001
vars() { # the transcript paths of a world, for the tests that mutate them
  LAUNCH="$1/desk/rep"; PROJ="$1/home/.claude/projects/$(san "$LAUNCH")"
  MAIN="$PROJ/$SID.jsonl"; WORKER="$PROJ/$SID/subagents/agent-1"
}

# a healthy sandbox; echoes its root
mkworld() {
  local w; w=$(mktemp -d "$WORK/w.XXXXXX")
  mkdir -p "$w"/{cfg/rules,cfg/memory/-scope,cfg/repos/rep,cfg/plans,cfg/agents,home/.claude/projects/-scope,home/.local/bin,home/.local/share/claude/versions,desk/rep/.claude,desk/rep/sub}
  printf 'global\n'                                   > "$w/cfg/CLAUDE.md"
  printf -- '---\ndescription: d\n---\n\nalways on\n'  > "$w/cfg/rules/always.md"
  printf -- '---\ndescription: d\npaths:\n  - "**/*.tex"\n---\n\nconditional\n' > "$w/cfg/rules/cond.md"
  : > "$w/cfg/plans/.gitkeep"
  printf -- '---\nname: m\ndescription: d\nmetadata:\n  type: feedback\n---\n\nbody\n' > "$w/cfg/memory/-scope/m.md"
  printf -- '- [M](m.md) — hook\n'                    > "$w/cfg/memory/-scope/MEMORY.md"
  printf '{"permissions":{"allow":["Bash(ls)"]}}\n'   > "$w/cfg/repos/rep/settings.local.json"
  ln -s "$w/cfg/memory/-scope" "$w/home/.claude/projects/-scope/memory"
  ln -s "$w/cfg/repos/rep/settings.local.json" "$w/desk/rep/.claude/settings.local.json"
  # the ground the routines stand on: a stub install, its flag cache, the version
  # on record, the retention setting, an agent that omits the charters, and the
  # transcripts of one session and one worker
  stubbin "$w/home/.local/share/claude/versions/9.9.9"
  ln -s "$w/home/.local/share/claude/versions/9.9.9" "$w/home/.local/bin/claude"
  printf '{"cachedGrowthBookFeatures":{"tengu_moth_copse":false,"tengu_mill_orange":false,"tengu_sepia_cormorant":[],"tengu_umber_petrel":false,"tengu_other":true},"cachedGrowthBookFeaturesAt":1791792882185}\n' > "$w/home/.claude.json"
  printf '9.9.9 2026-10-12 test\n'                    > "$w/cfg/claude-version-checked"
  printf '{"cleanupPeriodDays": 365}\n'               > "$w/cfg/settings.json"
  printf -- '---\nname: Explore\nomitClaudeMd: true\n---\n' > "$w/cfg/agents/Explore.md"
  printf 'charter\n' > "$w/desk/rep/sub/CLAUDE.md"; printf 'x\n' > "$w/desk/rep/sub/a.txt"
  transcripts "$w"
  echo "$w"
}
run() { local w=$1; shift
  HOME="$w/home" CLAUDE_LINK_CFG="$w/cfg" CLAUDE_LINK_HOME="$w/home/.claude" CLAUDE_LINK_DESK="$w/desk" \
    "$GAUGE" "$@" 2>&1; }
rc()  { local w=$1; shift; run "$w" "$@" >/dev/null; echo $?; }
# the transcript stubs: one record appended to a transcript
rec_read()   { printf '{"type":"assistant","cwd":"%s","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"%s"}}]}}\n' "$LAUNCH" "$1"; }
rec_bash()   { printf '{"type":"assistant","cwd":"%s","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"%s"}}]}}\n' "$LAUNCH" "$1"; }
rec_load()   { printf '{"type":"attachment","cwd":"%s","attachment":{"type":"nested_memory","path":"%s","content":{"type":"Project"}}}\n' "$LAUNCH" "$1"; }
rec_recall() { printf '{"type":"attachment","cwd":"%s","attachment":{"type":"relevant_memories","memories":[]}}\n' "$LAUNCH"; }

echo "== a healthy tree is silent and exits 0 =="
w=$(mkworld); out=$(run "$w")
not_ "no FAIL lines"                  '[[ "$out" == *"[FAIL]"* ]]'
not_ "no WARN lines"                  '[[ "$out" == *"[WARN]"* ]]'
yes_ "says all clear"                 '[[ "$out" == *"all clear"* ]]'
check "exits 0" "$(rc "$w")" "0"
yes_ "nineteen checks reported"       '[ "$(grep -c "^\[" <<<"$out")" = 19 ]'

echo "== it writes nothing, and never starts the binary =="
w=$(mkworld)
before=$(find "$w/cfg" "$w/home" -type f -exec md5sum {} + | sort)
run "$w" -v >/dev/null
after=$(find "$w/cfg" "$w/home" -type f -exec md5sum {} + | sort)
check "config tree and home byte-identical after a run" "$before" "$after"
not_ "the stub binary was never started" '[ -e "$w/home/.local/share/claude/versions/9.9.9.started" ]'

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
out=$(run "$w"); nl=$'\n'
yes_ "an empty dir fails"             '[[ "$out" == *"1 empty directory"* ]]'
check "  exits 1" "$(rc "$w")" "1"
yes_ "  its fix line is the command alone, the caveat on a note above it" '[[ "$out" == *"       note: claude-link --apply holds an empty memory scope open"*"$nl       fix: claude-link --apply$nl"* ]]'
yes_ "  and parses when pasted whole" 'bash -n -c "$(sed -n "s/^       fix: //p" <<<"$out")"'
: > "$w/cfg/memory/-empty/.gitkeep"
not_ "a keeper clears it"             '[[ "$(run "$w")" == *"empty directory"*"[FAIL]"* ]]'
w=$(mkworld); git -C "$w/cfg" init -q; printf 'skills/synced/\nskills/.staging/\n' > "$w/cfg/.gitignore"
mkdir -p "$w/cfg/skills/synced/b/.staging" "$w/cfg/skills/.staging"
not_ "an empty dir git ignores is not counted, inside an ignored folder or by its own pattern" '[[ "$(run "$w")" == *"empty directory(ies)"* ]]'
mkdir -p "$w/cfg/memory/-empty"; out=$(run "$w" -v)
yes_ "  while one git carries still fails"   '[[ "$out" == *"1 empty directory"* ]]'
yes_ "  and -v names that one alone"         '[[ "$out" == *"/cfg/memory/-empty"* && "$out" != *".staging"* ]]'
w=$(mkworld); mkdir -p "$w/cfg/skills/synced/b/.staging"
yes_ "outside a git work tree nothing is ignored: it fails" '! git -C "$w/cfg" rev-parse --is-inside-work-tree >/dev/null 2>&1 && [[ "$(run "$w")" == *"1 empty directory"* ]]'

echo "== memory index line shape =="
w=$(mkworld)
{ printf -- '- [M](m.md) — '; head -c 240 < /dev/zero | tr '\0' 'x'; printf '\n'; } > "$w/cfg/memory/-scope/MEMORY.md"
out=$(run "$w")
yes_ "an over-long entry fails"       '[[ "$out" == *"1 at or over the ~200c demote trigger"* ]]'
yes_ "  reports the worst length"     '[[ "$out" == *"worst 25"* ]]'
yes_ "  names the consequence"        '[[ "$out" == *"carrying content that belongs in the topic file"* ]]'
yes_ "  states the real caps and that the model is told" '[[ "$out" == *"200 lines and 25000 chars per index"* && "$out" == *"the tail does not, and the"*"model is told so"* ]]'
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

echo "== the version on record (check 10, 2026-10-12) =="
w=$(mkworld); out=$(run "$w"); nl=$'\n'
yes_ "on record: OK, with the rest of the line"   '[[ "$out" == *"[ OK ] Claude Code 9.9.9, the version on record (2026-10-12 test)"* ]]'
printf '1.2.3 2026-09-01 test\n' > "$w/cfg/claude-version-checked"
out=$(run "$w")
yes_ "an older record fails, naming both"         '[[ "$out" == *"[FAIL] Claude Code 9.9.9 installed; 1.2.3 on record"* ]]'
yes_ "  and prints the line to paste"             '[[ "$out" == *"fix: echo \"9.9.9 "*"\" > "*"/cfg/claude-version-checked"* ]]'
yes_ "  ending at the path: paste-ready"          '[[ "$out" == *"/cfg/claude-version-checked$nl"* ]]'
yes_ "  after a note saying when to paste it"     '[[ "$out" == *"       note: paste the fix after reading the lines below$nl       fix: echo"* ]]'
yes_ "  with the date and the machine in it"      '[[ "$out" == *"echo \"9.9.9 $(date +%F) $(hostname -s)\""* ]]'
check "  exits 1" "$(rc "$w")" "1"
printf '10.0.0 2026-12-01 other\n' > "$w/cfg/claude-version-checked"; out=$(run "$w")
yes_ "a newer record, from the machine that updated first: OK, naming both" '[[ "$out" == *"[ OK ] Claude Code 9.9.9 installed, older than the 10.0.0 on record (2026-12-01 other): nothing to record here; this machine catches up at its next update"* ]]'
not_ "  and no line that would set the shared record back" '[[ "$out" == *"fix: echo"* ]]'
check "  exits 0" "$(rc "$w")" "0"
printf '9.10.0 2026-12-01 other\n' > "$w/cfg/claude-version-checked"
yes_ "  versions compare as versions: 9.10.0 is newer than 9.9.9" '[[ "$(run "$w")" == *"[ OK ] Claude Code 9.9.9 installed, older than the 9.10.0 on record"* ]]'
rm "$w/cfg/claude-version-checked"; out=$(run "$w")
yes_ "no record: fails and asks for one"          '[[ "$out" == *"[FAIL] Claude Code 9.9.9 installed; no version on record"* ]]'
yes_ "  with the same note and paste-ready line"  '[[ "$out" == *"       note: paste the fix after reading the lines below$nl       fix: echo \"9.9.9 "*"/cfg/claude-version-checked$nl"* ]]'
w=$(mkworld); rm "$w/home/.local/bin/claude"
out=$(PATH=/usr/bin:/bin run "$w")
yes_ "no install, none on PATH: warns"            '[[ "$out" == *"[WARN] Claude Code: no binary at ~/.local/bin/claude or on PATH"* ]]'
not_ "  and reads no premise from it"             '[[ "$out" == *"recall gate"* ]]'
check "  exits 2" "$(PATH=/usr/bin:/bin rc "$w")" "2"
w=$(mkworld); rm "$w/home/.local/bin/claude"; cp "$w/home/.local/share/claude/versions/9.9.9" "$w/home/.local/share/claude/latest"
ln -s "$w/home/.local/share/claude/latest" "$w/home/.local/bin/claude"
out=$(run "$w")
yes_ "an install whose path carries no version: warns" '[[ "$out" == *"[WARN] Claude Code: version not readable from the install path"* ]]'
yes_ "  but still reads the premises from it"     '[[ "$out" == *"[ OK ] recall gate"* ]]'
yes_ "  and names the installed version as such"  '[[ "$out" == *"fix: read it with"* ]]'

echo "== the premises read from the binary (checks 11 to 14): each anchor, mutated =="
w=$(mkworld); B="$w/home/.local/share/claude/versions/9.9.9"
out=$(run "$w")
yes_ "recall gate OK, naming switch and variable"  '[[ "$out" == *"[ OK ] recall gate (row 2): the switch tengu_moth_copse or the variable CLAUDE_MEMORY_STORES"* ]]'
yes_ "memory scope OK"                             '[[ "$out" == *"[ OK ] memory scope (row 3)"* ]]'
yes_ "memory numbers OK, all five"                 '[[ "$out" == *"[ OK ] memory numbers (rows 4, 11): per index 200 lines or 25,000 chars, the model told when cut; per recalled file 200 lines or 4,096 B, 61,440 B a session"* ]]'
yes_ "skill gate OK"                               '[[ "$out" == *"[ OK ] skill gate (row 18)"* ]]'
sed -i 's/Roe=25000/Roe=50000/' "$B"; out=$(run "$w")
yes_ "a moved cap fails, both readings shown"      '[[ "$out" == *"[FAIL] memory numbers (rows 4, 11): the binary reads 200/50000/200/4096/61440 where 200/25000/200/4096/61440 is on record"* ]]'
yes_ "  names the texts that rest on it"           '[[ "$out" == *"rests on: this gauge (check 3 and its note); context-policy.md"* ]]'
yes_ "  and the fix: re-measure, the inventory row, the ledger class" '[[ "$out" == *"fix: re-measure on Claude Code 9.9.9, then correct the texts above (org/claude-config/context-order-2026-10/battery/dev-4-rented-ground.md, rows 4, 11); /restore-order files it as moved-premise"* ]]'
check "  exits 1" "$(rc "$w")" "1"
sed -i 's/MAX_SESSION_BYTES:61440/MAX_SESSION_BYTES:4096/' "$w/home/.local/share/claude/versions/9.9.9"
yes_ "a moved session cap fails too"               '[[ "$(run "$w")" == *"reads 200/50000/200/4096/4096 where"* ]]'
w=$(mkworld); B="$w/home/.local/share/claude/versions/9.9.9"; sed -i '/via:"git"/d' "$B"; out=$(run "$w")
yes_ "a gone anchor warns, never OK"               '[[ "$out" == *"[WARN] memory scope (row 3): the anchor via:\"git\" is not in this binary; could not determine"* ]]'
yes_ "  with a fix that says to find it"           '[[ "$out" == *"fix: find the anchor on Claude Code 9.9.9 and update this gauge"*"row 3)"* ]]'
check "  exits 2" "$(rc "$w")" "2"
w=$(mkworld); B="$w/home/.local/share/claude/versions/9.9.9"; sed -i 's/k("tengu_moth_copse",!1)/k("tengu_other",!1)/' "$B"
yes_ "a gate that drops the switch fails"          '[[ "$(run "$w")" == *"[FAIL] recall gate (row 2): no longer reads the switch tengu_moth_copse"* ]]'
w=$(mkworld); B="$w/home/.local/share/claude/versions/9.9.9"; sed -i 's/process.env.CLAUDE_MEMORY_STORES?.trim()/process.env.OTHER?.trim()/' "$B"
yes_ "a gate that drops the variable fails"        '[[ "$(run "$w")" == *"[FAIL] recall gate (row 2): no longer reads the variable CLAUDE_MEMORY_STORES"* ]]'
w=$(mkworld); B="$w/home/.local/share/claude/versions/9.9.9"; sed -i 's/ as isMemoryRecallEnabled/ as isSomethingElse/' "$B"
yes_ "a gone gate anchor warns"                    '[[ "$(run "$w")" == *"[WARN] recall gate (row 2): its anchor is not in this binary"* ]]'
w=$(mkworld); B="$w/home/.local/share/claude/versions/9.9.9"; sed -i 's/function R7(){/function R8(){/' "$B"
yes_ "a gate with no readable body warns"          '[[ "$(run "$w")" == *"[WARN] recall gate (row 2): the gate has no readable body"* ]]'
w=$(mkworld); B="$w/home/.local/share/claude/versions/9.9.9"; sed -i '/disable-model-invocation/d' "$B"
yes_ "a gone skill gate warns"                     '[[ "$(run "$w")" == *"[WARN] skill gate (row 18): the refusal is not in this binary"* ]]'
w=$(mkworld); B="$w/home/.local/share/claude/versions/9.9.9"; sed -i '/Only part of it was loaded/d' "$B"
yes_ "a gone partial-load warning warns"           '[[ "$(run "$w")" == *"[WARN] memory numbers (rows 4, 11): the partial-load warning not found in this binary"* ]]'
w=$(mkworld); B="$w/home/.local/share/claude/versions/9.9.9"; sed -i '/MEMORY.md/d; /MAX_SESSION_BYTES/d' "$B"
yes_ "gone caps: both named"                       '[[ "$(run "$w")" == *"[WARN] memory numbers (rows 4, 11): the index caps and the session cap not found"* ]]'

echo "== the server switches (check 15): the flag cache, mutated =="
w=$(mkworld); out=$(run "$w")
yes_ "five quiet: OK, the charter switch in the binary" '[[ "$out" == *"[ OK ] server switches (rows 2, 28, 29): 5 cached quiet (recall, index recall, charter loading, auto memory per model); the charter-loading switch in the binary"* ]]'
out=$(run "$w" -v)
yes_ "-v lists each switch's cached value"         '[[ "$out" == *"tengu_moth_copse (recall): false"* && "$out" == *"tengu_paper_halyard (charter loading off): absent"* && "$out" == *"tengu_sepia_cormorant (models without auto memory): []"* ]]'
yes_ "  and when the cache was written"            '[[ "$out" == *"cached at 2026-10-12"* ]]'
sed -i 's/"tengu_moth_copse":false/"tengu_moth_copse":true/' "$w/home/.claude.json"; out=$(run "$w")
yes_ "recall switched on: fails, naming it"        '[[ "$out" == *"[FAIL] server switches (rows 2, 28, 29): tengu_moth_copse (recall) cached true"* ]]'
yes_ "  and says the decision is his"              '[[ "$out" == *"decide its use or refusal from what it does in his sessions"* ]]'
check "  exits 1" "$(rc "$w")" "1"
w=$(mkworld); sed -i 's/"tengu_sepia_cormorant":\[\]/"tengu_sepia_cormorant":["m"]/' "$w/home/.claude.json"
yes_ "a model listed without auto memory fails"    '[[ "$(run "$w")" == *"tengu_sepia_cormorant (models without auto memory) cached [\"m\"]"* ]]'
w=$(mkworld); sed -i 's/"tengu_mill_orange":false/"tengu_mill_orange":false,"tengu_paper_halyard":false/' "$w/home/.claude.json"
yes_ "the charter switch cached false is quiet"    '[[ "$(run "$w")" == *"[ OK ] server switches"* ]]'
sed -i 's/"tengu_paper_halyard":false/"tengu_paper_halyard":true/' "$w/home/.claude.json"
yes_ "  cached true fails"                         '[[ "$(run "$w")" == *"[FAIL] server switches (rows 2, 28, 29): tengu_paper_halyard (charter loading off) cached true"* ]]'
w=$(mkworld); printf '{"other":1}\n' > "$w/home/.claude.json"
yes_ "no cached switches: warns"                   '[[ "$(run "$w")" == *"[WARN] server switches (rows 2, 28, 29): no cachedGrowthBookFeatures"* ]]'
rm "$w/home/.claude.json"
yes_ "no ~/.claude.json: warns"                    '[[ "$(run "$w")" == *"[WARN] server switches"* ]]'
w=$(mkworld); sed -i '/tengu_paper_halyard/d' "$w/home/.local/share/claude/versions/9.9.9"
yes_ "the charter switch gone from the binary: warns, pointing at check 17" '[[ "$(run "$w")" == *"[WARN] server switches (rows 2, 28, 29): 5 cached quiet, but the charter-loading switch is not in this binary"*"(check 17 sees their loads)"* ]]'

echo "== seen in the transcripts (checks 16 to 19): each premise, mutated =="
w=$(mkworld); vars "$w"; out=$(run "$w")
yes_ "recall in practice OK: 0 recalls, the index in every bundle" '[[ "$out" == *"[ OK ] recall in practice (rows 2, 4, 11), 14 days: 0 recalls in 2 transcripts; the memory index in 1 of 1 start bundles whose scope has one"* ]]'
yes_ "charter loading OK: the load under the launch folder, the session received its charter" '[[ "$out" == *"[ OK ] charter loading (row 1), 14 days: 1 charter loads, all under the launch folder; 1 of 1 sessions that read under a charter'"'"'s folder received it"* ]]'
yes_ "workers OK, naming what is left aside"       '[[ "$out" == *"[ OK ] workers (rows 5, 6), 14 days: 1 of 1 start bundles carry what their session received (Explore and forks aside)"* ]]'
yes_ "retention OK, with the oldest transcript"    '[[ "$out" == *"[ OK ] transcripts kept 365 days (row 13, cleanupPeriodDays); the oldest last written $(date +%Y-%m-%d)"* ]]'
yes_ "-v shows the loads by their tool"            '[[ "$(run "$w" -v)" == *"loads by the tool before them: Read 1"* ]]'
rec_recall >> "$MAIN"; out=$(run "$w")
yes_ "recall fired: fails, with the consequence"   '[[ "$out" == *"[FAIL] recall in practice (rows 2, 4, 11), 14 days: recall fired 1 time — the index then stops loading at session start"* ]]'
yes_ "  rests on the recall texts"                 '[[ "$out" == *"rests on: context-policy-questions.md; context-drift-2026-09/run3-2026-09-23.md"* ]]'
w=$(mkworld); vars "$w"; sed -i 's/,{"path":"[^"]*MEMORY.md","type":"AutoMem"}//' "$MAIN"; out=$(run "$w" -v)
yes_ "the index missing, but younger than the session: not judged, and -v says so" '[[ "$out" == *"[ OK ] recall in practice"*"the memory index in 0 of 0 start bundles"* && "$out" == *"not judged, the index is younger than the session: "*"/aaaaaaaa-0000-0000-0000-000000000001.jsonl"* ]]'
touch -d '2026-10-01' "$PROJ/memory/MEMORY.md"; out=$(run "$w")
yes_ "the index missing from a start bundle it predates: fails" '[[ "$out" == *"[FAIL] recall in practice (rows 2, 4, 11), 14 days: the memory index missing from 1 of 1 start bundles whose scope has one"* ]]'
yes_ "  -v names the session"                      '[[ "$(run "$w" -v)" == *"index missing: "*"/aaaaaaaa-0000-0000-0000-000000000001.jsonl"* ]]'
printf '{"type":"attachment","cwd":"%s","attachment":{"type":"instructions","files":[{"path":"%s/memory/MEMORY.md","type":"AutoMem"}]}}\n' "$LAUNCH" "$PROJ" >> "$MAIN"
yes_ "  a later attachment carrying the index completes the bundle" '[[ "$(run "$w")" == *"the memory index in 1 of 1 start bundles whose scope has one"* ]]'
w=$(mkworld); vars "$w"; rm "$PROJ/memory/MEMORY.md"
yes_ "no index in the scope: nothing expected"     '[[ "$(run "$w")" == *"the memory index in 0 of 0 start bundles whose scope has one"* ]]'
w=$(mkworld); vars "$w"; printf '{"type":"user","cwd":"%s","timestamp":"2026-10-12T00:00:00.000Z","message":{"role":"user","content":"x"}}\n' "$LAUNCH" > "$PROJ/bbbbbbbb-0000-0000-0000-000000000002.jsonl"
out=$(run "$w" -v)
yes_ "a session with no start bundle is not judged" '[[ "$out" == *"0 recalls in 3 transcripts; the memory index in 1 of 1 start bundles"* && "$out" == *"no start bundle, not judged: "*"/bbbbbbbb-0000-0000-0000-000000000002.jsonl"* ]]'
w=$(mkworld); vars "$w"; printf '{"type":"attachment","cwd":"%s","attachment":{"type":"nested_memory","path":"%s/cfg/rules/cond.md","content":{"type":"User"}}}\n' "$LAUNCH" "$w" >> "$MAIN"
yes_ "a path-scoped rule loads by the same attachment, outside any launch folder, and is counted apart" '[[ "$(run "$w")" == *"[ OK ] charter loading (row 1), 14 days: 1 charter loads, all under the launch folder, 1 rule loads; 1 of 1"* ]]'
w=$(mkworld); vars "$w"; rec_load "$w/desk/elsewhere/CLAUDE.md" >> "$MAIN"; out=$(run "$w")
yes_ "a load outside the launch folder fails"      '[[ "$out" == *"[FAIL] charter loading (row 1), 14 days: 1 of 2 charter loads outside the launch folder"* ]]'
yes_ "  -v names it"                               '[[ "$(run "$w" -v)" == *"outside the launch folder: "*"/desk/elsewhere/CLAUDE.md"* ]]'
yes_ "  rests on the loading texts"                '[[ "$out" == *"rests on: context-policy.md (loading); skills/restore-order/SKILL.md and tools/census.py"* ]]'
w=$(mkworld); vars "$w"; sed -i '/nested_memory/d' "$MAIN"; out=$(run "$w")
yes_ "a session that read under a charter's folder and never received it fails" '[[ "$out" == *"[FAIL] charter loading (row 1), 14 days: 1 of 1 sessions that read under a charter'"'"'s folder never received it"* ]]'
yes_ "  -v names the session and the folder"       '[[ "$(run "$w" -v)" == *"/aaaaaaaa-0000-0000-0000-000000000001.jsonl: read under "*"/desk/rep/sub, never received its charter"* ]]'
rec_read "$LAUNCH/sub/CLAUDE.md" >> "$MAIN"
yes_ "  unless the model read the charter itself"  '[[ "$(run "$w")" == *"0 of 0 sessions that read under a charter'"'"'s folder received it"* ]]'
w=$(mkworld); vars "$w"; sed -i '/nested_memory/d' "$MAIN"; rec_bash "cat $LAUNCH/sub/CLAUDE.md" >> "$MAIN"
yes_ "  or viewed it from the shell"               '[[ "$(run "$w")" == *"0 of 0 sessions that read under a charter'"'"'s folder received it"* ]]'
w=$(mkworld); vars "$w"; mkdir -p "$LAUNCH/memory"; printf 'c\n' > "$LAUNCH/memory/CLAUDE.md"; rec_read "$LAUNCH/memory/n.md" >> "$MAIN"
yes_ "a touch inside a memory directory expects nothing" '[[ "$(run "$w")" == *"[ OK ] charter loading (row 1)"*"1 of 1 sessions"* ]]'
w=$(mkworld); vars "$w"; sed -i 's/,{"path":"[^"]*MEMORY.md","type":"AutoMem"}//' "$WORKER.jsonl"; out=$(run "$w")
yes_ "a worker lacking the index fails"            '[[ "$out" == *"[FAIL] workers (rows 5, 6), 14 days: 1 of 1 start bundles lack what their session received (Explore and forks aside)"* ]]'
yes_ "  -v says what it lacks"                     '[[ "$(run "$w" -v)" == *"subagents/agent-1.jsonl (general-purpose): lacks AutoMem"* ]]'
yes_ "  rests on the worker texts"                 '[[ "$out" == *"rests on: context-policy.md (what workers receive); agents/Explore.md and Plan.md"* ]]'
printf '{"type":"attachment","cwd":"%s","attachment":{"type":"instructions","files":[{"path":"%s/memory/MEMORY.md","type":"AutoMem"}]}}\n' "$LAUNCH" "$PROJ" >> "$WORKER.jsonl"
yes_ "  a later attachment carrying the index completes it" '[[ "$(run "$w")" == *"[ OK ] workers (rows 5, 6), 14 days: 1 of 1"* ]]'
w=$(mkworld); vars "$w"; sed -i '/instructions/d' "$WORKER.jsonl"
yes_ "a worker with no bundle fails"               '[[ "$(run "$w" -v)" == *"[FAIL] workers"*"(general-purpose): no start bundle"* ]]'
printf '{"agentType":"Explore"}\n' > "$WORKER.meta.json"
yes_ "  not when its type omits the charters"      '[[ "$(run "$w")" == *"[ OK ] workers (rows 5, 6), 14 days: none in the window (Explore and forks aside)"* ]]'
printf '{"agentType":"fork"}\n' > "$WORKER.meta.json"
yes_ "  nor when it is a fork"                     '[[ "$(run "$w")" == *"[ OK ] workers (rows 5, 6), 14 days: none in the window"* ]]'
rm "$WORKER.meta.json"
yes_ "  nor without a .meta.json, which -v reports" '[[ "$(run "$w" -v)" == *"[ OK ] workers"*"not judged, no .meta.json: "*"subagents/agent-1.jsonl"* ]]'
w=$(mkworld); vars "$w"; WF="$PROJ/$SID/subagents/workflows/wf_1"; mkdir -p "$WF"
printf '{"type":"journal"}\n' > "$WF/journal.jsonl"
printf '{"agentType":"general-purpose"}\n' > "$WF/agent-2.meta.json"; cp "$WORKER.jsonl" "$WF/agent-2.jsonl"
out=$(run "$w")
yes_ "a Workflow run's agent is a worker of its session" '[[ "$out" == *"0 recalls in 3 transcripts"*"[ OK ] workers (rows 5, 6), 14 days: 2 of 2"* ]]'
sed -i 's/,{"path":"[^"]*MEMORY.md","type":"AutoMem"}//' "$WF/agent-2.jsonl"
yes_ "  judged against its session's bundle"       '[[ "$(run "$w" -v)" == *"[FAIL] workers (rows 5, 6), 14 days: 1 of 2"*"subagents/workflows/wf_1/agent-2.jsonl (general-purpose): lacks AutoMem"* ]]'
yes_ "  while its journal is not a transcript"     '[[ "$out" != *"journal"* ]]'
w=$(mkworld); vars "$w"; touch -d '20 days ago' "$MAIN" "$WORKER.jsonl"; out=$(run "$w")
yes_ "nothing in the window: three warnings, never OK" '[ "$(grep -c "^\[WARN\] transcripts: none written in the last 14 days; could not determine" <<<"$out")" = 3 ]'
check "  exits 2" "$(rc "$w")" "2"
yes_ "  CONTEXT_CHECK_DAYS widens it"              '[[ "$(CONTEXT_CHECK_DAYS=30 run "$w")" == *"[ OK ] charter loading (row 1), 30 days: 1 charter loads"* ]]'
w=$(mkworld); vars "$w"; rm -rf "$w/home/.claude/projects"
out=$(run "$w")
yes_ "no transcript store: warns"                  '[[ "$out" == *"[WARN] no transcripts at "*"/.claude/projects"* ]]'
w=$(mkworld); vars "$w"; printf '{}\n' > "$w/cfg/settings.json"; out=$(run "$w")
yes_ "no retention setting: fails, with the default named" '[[ "$out" == *"[FAIL] transcripts (row 13): cleanupPeriodDays is not set in settings.json, so the 30-day default sweeps"* ]]'
yes_ "  and a literal fix, not a re-measure"       '[[ "$out" == *"fix: add \"cleanupPeriodDays\": 365 to settings.json"* && "$out" != *"re-measure on Claude Code 9.9.9, then correct"*"row 13"* ]]'

echo "== --binary: checks 11 to 15 alone, what the SessionStart hook asks (2026-10-18) =="
w=$(mkworld); out=$(run "$w" --binary)
check "five checks reported, and no others" "$(grep -c '^\[' <<<"$out")" "5"
yes_ "  the recall gate first, the server switches last" '[[ "$(grep "^\[" <<<"$out" | head -n 1)" == *"[ OK ] recall gate (row 2)"* && "$(grep "^\[" <<<"$out" | tail -n 1)" == *"[ OK ] server switches (rows 2, 28, 29)"* ]]'
yes_ "  all clear"                                 '[[ "$out" == *"all clear"* ]]'
check "  exits 0" "$(rc "$w" --binary)" "0"
printf '1.2.3 2026-09-01 test\n' > "$w/cfg/claude-version-checked"; mkdir -p "$w/cfg/memory/-empty"
check "a record the install has passed is the hook's to judge, a tree fault is not read: still 0" "$(rc "$w" --binary)" "0"
not_ "  and neither the version nor the transcripts are reported" '[[ "$(run "$w" --binary)" == *"Claude Code 9.9.9"* || "$(run "$w" --binary)" == *"transcripts"* ]]'
sed -i 's/Roe=25000/Roe=50000/' "$w/home/.local/share/claude/versions/9.9.9"
check "a moved premise: exits 1"                   "$(rc "$w" --binary)" "1"
yes_ "  with its FAIL line, as the hook reads it"  '[[ "$(run "$w" --binary)" == *"[FAIL] memory numbers (rows 4, 11): the binary reads 200/50000"* ]]'
w=$(mkworld); sed -i '/via:"git"/d' "$w/home/.local/share/claude/versions/9.9.9"
check "a gone anchor: exits 2"                     "$(rc "$w" --binary)" "2"
yes_ "  with its WARN line"                        '[[ "$(run "$w" --binary)" == *"[WARN] memory scope (row 3): the anchor via:\"git\" is not in this binary"* ]]'
w=$(mkworld); sed -i 's/"tengu_moth_copse":false/"tengu_moth_copse":true/' "$w/home/.claude.json"
check "a server switch turned on: exits 1"         "$(rc "$w" --binary)" "1"
w=$(mkworld); rm "$w/home/.local/bin/claude"
check "no install, none on PATH: exits 2"          "$(PATH=/usr/bin:/bin rc "$w" --binary)" "2"
yes_ "  saying so"                                 '[[ "$(PATH=/usr/bin:/bin run "$w" --binary)" == *"[WARN] Claude Code: no binary at ~/.local/bin/claude or on PATH"* ]]'
w=$(mkworld)
before=$(find "$w/cfg" "$w/home" -type f -exec md5sum {} + | sort); run "$w" --binary >/dev/null
check "  writes nothing"                           "$(find "$w/cfg" "$w/home" -type f -exec md5sum {} + | sort)" "$before"
not_ "  and never starts the binary"               '[ -e "$w/home/.local/share/claude/versions/9.9.9.started" ]'
h=$(run "$w" --help)
yes_ "--help names it, and shows the whole header and no code" '[[ "$h" == *"context-check --binary"* && "$h" == *"never silently assumed healthy"* && "$h" != *"set -uo"* ]]'

echo "== could-not-determine is never silent health =="
w=$(mkworld)
out=$(CLAUDE_LINK_CFG="$w/nope" CLAUDE_LINK_HOME="$w/home/.claude" "$GAUGE" 2>&1); rc2=$?
yes_ "a missing config tree warns"      '[[ "$out" == *"[WARN]"* ]]'
check "  and exits 2, not 0" "$rc2" "2"

echo
printf 'passed: %d  failed: %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
