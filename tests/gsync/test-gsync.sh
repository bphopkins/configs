#!/usr/bin/env bash
# Functional tests for the rewritten 50-git-sync.sh, run entirely against
# scratch repos in a temp dir. Network is faked via _GSYNC_ONLINE_CACHE=1
# (the remotes are local paths, so no real network is ever needed).
set -u

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/gsync-test.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$CFG_ROOT/bash/.bashrc.d/50-git-sync.sh"
_GSYNC_ONLINE_CACHE=1   # local-path remotes; skip the github probe

pass=0 fail=0
check() { # check DESC EXPR...
  local desc="$1"; shift
  if "$@"; then echo "ok   - $desc"; ((pass+=1)); else echo "FAIL - $desc"; ((fail+=1)); fi
}
contains() { [[ "$1" == *"$2"* ]]; }
no_progress() { ! _gsync_in_progress "$1" >/dev/null; }
must() { "$@" || { echo "SETUP-FAIL: $*"; exit 1; }; }

cd "$SANDBOX"
must git init -q --bare -b main origin.git
must git clone -q origin.git cloneA
git -C cloneA checkout -q -b main 2>/dev/null || git -C cloneA checkout -q main
echo base > cloneA/base.txt
must git -C cloneA add -A
must git -C cloneA commit -qm base
must git -C cloneA push -qu origin main
must git clone -q origin.git cloneB

# --- 1. plain push: new file committed, listed, pushed
echo hello > cloneA/notes.txt
out="$(_gsync_push_repo A "$SANDBOX/cloneA" "test msg 1")"; rc=$?
check "push: rc=0"                 [ "$rc" -eq 0 ]
check "push: SYNC line"            contains "$out" "committed 1 path(s); pushed"
check "push: new file listed"      contains "$out" "new: notes.txt"
check "push: commit reached origin" bash -c "git -C '$SANDBOX/origin.git' log --format=%s main | head -1 | grep -q 'test msg 1'"

# --- 1b. modified-tracked-files-only commit (no new files): the most common
# real-world push. Regression for the empty-new_note return-status bug.
echo hello2 >> cloneA/notes.txt
out="$(_gsync_push_repo A "$SANDBOX/cloneA" "test msg 1b")"; rc=$?
check "mod-only: rc=0"             [ "$rc" -eq 0 ]
check "mod-only: SYNC line"        contains "$out" "committed 1 path(s); pushed"

# --- 2. size guard (no tty: flagged file left uncommitted, rest committed)
truncate -s 30M cloneA/huge.bin
echo small > cloneA/small.txt
out="$(_gsync_push_repo A "$SANDBOX/cloneA" "test msg 2")"; rc=$?
check "size: rc=0"                  [ "$rc" -eq 0 ]
check "size: warned with size"      contains "$out" "30 MB (guard: GSYNC_MAX_MB=25)"
check "size: left uncommitted"      contains "$out" "left uncommitted: huge.bin"
check "size: small.txt committed"   bash -c "git -C '$SANDBOX/cloneA' ls-files --error-unmatch small.txt >/dev/null 2>&1"
check "size: huge.bin not tracked"  bash -c "! git -C '$SANDBOX/cloneA' ls-files --error-unmatch huge.bin >/dev/null 2>&1"
check "size: huge.bin still on disk" [ -f "$SANDBOX/cloneA/huge.bin" ]
rm cloneA/huge.bin

# --- 3. secrets guard
echo "TOKEN=x" > cloneA/.env
out="$(_gsync_push_repo A "$SANDBOX/cloneA" "test msg 3")"; rc=$?
check "secret: rc=0 (all declined)"  [ "$rc" -eq 0 ]
check "secret: warned"              contains "$out" "matches secrets pattern '.env'"
check "secret: left uncommitted"    contains "$out" "left uncommitted: .env"
check "secret: not tracked"         bash -c "! git -C '$SANDBOX/cloneA' ls-files --error-unmatch .env >/dev/null 2>&1"
rm cloneA/.env

# --- 4. rebase conflict: auto-abort, commit intact, clean state
must git -C cloneB pull -q
echo lineB > cloneB/conflict.txt
must git -C cloneB add -A
must git -C cloneB commit -qm fromB
must git -C cloneB push -q
echo lineA > cloneA/conflict.txt
out="$(_gsync_push_repo A "$SANDBOX/cloneA" "test msg 4")"; rc=$?
check "conflict: rc=1"              [ "$rc" -eq 1 ]
check "conflict: abort reported"    contains "$out" "rebase conflict"
check "conflict: repo clean state"  no_progress "$SANDBOX/cloneA"
check "conflict: commit intact"     bash -c "git -C '$SANDBOX/cloneA' log --format=%s | head -1 | grep -q 'test msg 4'"
# clean up the divergence for later tests
git -C cloneA fetch -q && git -C cloneA reset -q --hard origin/main

# --- 5. merge-in-progress guard
g="$(git -C cloneA rev-parse --absolute-git-dir)"
git -C cloneA rev-parse HEAD > "$g/MERGE_HEAD"
out="$(_gsync_push_repo A "$SANDBOX/cloneA" "x")"; rc=$?
check "merge guard: rc=1"           [ "$rc" -eq 1 ]
check "merge guard: named"          contains "$out" "merge in progress"
rm "$g/MERGE_HEAD"

# --- 6. pull helper: update flows through, up-to-date is quiet
must git -C cloneB pull -q --rebase
echo more >> cloneB/conflict.txt
must git -C cloneB add -A
must git -C cloneB commit -qm moreB
must git -C cloneB push -q
out="$(_gsync_pull_repo A "$SANDBOX/cloneA")"; rc=$?
check "pull: rc=0"                  [ "$rc" -eq 0 ]
check "pull: updated line"          contains "$out" "A: updated"
out="$(_gsync_pull_repo A "$SANDBOX/cloneA")"; rc=$?
check "pull: idempotent rc=0"       [ "$rc" -eq 0 ]
check "pull: idempotent up-to-date" contains "$out" "A: up to date"

# --- 7. offline push: commit lands, push pending
_GSYNC_ONLINE_CACHE=0
echo offline > cloneA/off.txt
out="$(_gsync_push_repo A "$SANDBOX/cloneA" "offline msg")"; rc=$?
check "offline: rc=3"               [ "$rc" -eq 3 ]
check "offline: pending reported"   contains "$out" "push pending (offline)"
check "offline: commit landed"      bash -c "git -C '$SANDBOX/cloneA' log --format=%s | head -1 | grep -q 'offline msg'"
_GSYNC_ONLINE_CACHE=1
out="$(_gsync_push_repo A "$SANDBOX/cloneA" "unused")"; rc=$?
check "back online: rc=0"            [ "$rc" -eq 0 ]
check "back online: pushed stranded" contains "$out" "pushed 1 commit(s)"

# --- 8. non-main branch warning
git -C cloneA checkout -qb experiment
echo exp > cloneA/exp.txt
out="$(_gsync_push_repo A "$SANDBOX/cloneA" "exp msg")"; rc=$?
check "branch: warned"              contains "$out" "on branch 'experiment' (not main)"
check "branch: initial push rc=0"   [ "$rc" -eq 0 ]
check "branch: initial push shown"  contains "$out" "initial push to origin/experiment"
git -C cloneA checkout -q main

# --- 9. hints (repo must be named 'configs'; STOW_ORDER from 60-stow.sh)
source "$CFG_ROOT/bash/.bashrc.d/60-stow.sh"
mkdir -p "$SANDBOX/hintrepo"
git -C "$SANDBOX/hintrepo" init -qb main
mkdir -p "$SANDBOX/hintrepo/bash/.bashrc.d" "$SANDBOX/hintrepo/nvim"
echo a > "$SANDBOX/hintrepo/README.md"
git -C "$SANDBOX/hintrepo" add -A && git -C "$SANDBOX/hintrepo" commit -qm c1
old="$(git -C "$SANDBOX/hintrepo" rev-parse HEAD)"
echo b > "$SANDBOX/hintrepo/bash/.bashrc.d/95-new.sh"   # added file in bash pkg
echo c > "$SANDBOX/hintrepo/nvim/init.lua"              # added file in nvim pkg
git -C "$SANDBOX/hintrepo" add -A && git -C "$SANDBOX/hintrepo" commit -qm c2
out="$(_gsync_pull_hints configs "$SANDBOX/hintrepo" "$old")"
check "hints: re-source hint"       contains "$out" "source ~/.bashrc"
check "hints: stow-all hint"        contains "$out" "stow-all"
check "hints: names bash pkg"       contains "$out" "bash"
check "hints: names nvim pkg"       contains "$out" "nvim"
out="$(_gsync_pull_hints notconfigs "$SANDBOX/hintrepo" "$old")"
check "hints: only for configs"     [ -z "$out" ]
# modification-only commit: no stow hint, yes bash hint if bash file modified
old="$(git -C "$SANDBOX/hintrepo" rev-parse HEAD)"
echo mod >> "$SANDBOX/hintrepo/nvim/init.lua"
git -C "$SANDBOX/hintrepo" add -A && git -C "$SANDBOX/hintrepo" commit -qm c3
out="$(_gsync_pull_hints configs "$SANDBOX/hintrepo" "$old")"
check "hints: mod-only => no hints" [ -z "$out" ]

# --- 10. arg parsing
out="$(gpush 2>&1)"; rc=$?
check "gpush no args: usage rc=1"   [ "$rc" -eq 1 ]
check "gpush no args: usage"        contains "$out" "Usage: gpush"
out="$(gpull 2>&1)"; rc=$?
check "gpull no args: usage rc=1"   [ "$rc" -eq 1 ]
check "gpull no args: usage"        contains "$out" "Usage: gpull"

# --- 11. completion
COMP_WORDS=(gpush diss); COMP_CWORD=1
_gsync_complete
check "completion: dissertation*"   contains "${COMPREPLY[*]}" "dissertation"
check "completion: two matches"     [ "${#COMPREPLY[@]}" -eq 2 ]

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
