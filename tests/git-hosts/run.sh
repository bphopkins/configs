#!/usr/bin/env bash
# Regression suite for the git host files (org/machines/transport-2026-10,
# rules.md ws-6, fedxps-1, fedxps-6, bigfed-1; written 2026-10-26 at step 5a):
# git/config's [init], the reader's refusing hook
# git/hooks-reader/reference-transaction that git/hosts/fedxps.inc arms, the
# reader guard's read matrix under fedxps.inc, and bigfed.inc's foreground
# maintenance.
#
# Hermetic: HOME is a sandbox in the shape stow leaves the real one --
# ~/.config/git/config a link to this checkout's git/config, hooks-reader a
# link to this checkout's directory, host.inc a link to the host file under
# test -- with a fixture identity where git/config's private include looks for
# it. GIT_CONFIG_GLOBAL names that config and the system file is off, so
# nothing of this machine's own git configuration is read; a `uname` stub
# names the machine fedxps for the hook's message. Every repository is made
# here, and a reader's copy is a `cp -a` copy (new inodes, the same contents
# and mtimes), the shape Syncthing delivers. No network, no privileges.
#
# Caged: tests/cage.sh -- a systemd user scope with a memory ceiling, swap
# off, a task cap and a time cap, stopped on the way out; no user manager, no
# run. Run after any edit to git/config, git/hosts/ or git/hooks-reader/
# (about 15 s on bigfed). Last line "passed: N  failed: M"; exit 0 iff
# nothing failed. Lines starting `info` record what is measured without being
# asserted: what a refused command leaves behind, what passes the hook (its
# bypasses and git's reflog machinery, which the agents' rule keeps off,
# rules.md agents-2), the two index writers kept off by habit (fedxps-4), the
# hook's cost, and the read matrix's table.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$CFG_ROOT/tests/cage.sh"
cage git-hosts "$@"

# --- the sandbox ------------------------------------------------------------
SB="$(mktemp -d "${TMPDIR:-/tmp}/git-hosts-tests.XXXXXX")"
H="$SB/home"
D="$H/Desktop"
# A detached maintenance from the control case may still run in the sandbox;
# wait for it before removing the tree (the cage reaps it either way).
cleanup() {
  local i
  for i in $(seq 1 100); do [[ -z "$(gitprocs "$SB")" ]] && break; sleep 0.1; done
  rm -rf "$SB"
}
trap cleanup EXIT

while read -r v; do unset "$v"; done < <(compgen -e | grep '^GIT_')
unset XDG_CONFIG_HOME
mkdir -p "$H/.config/git" "$D/org/claude-config/git" "$H/src" "$SB/bin" "$SB/hosts"
printf '[user]\n\tname = Rig\n\temail = rig@example.invalid\n' > "$D/org/claude-config/git/identity"
ln -s "$CFG_ROOT/git/config" "$H/.config/git/config"
ln -s "$CFG_ROOT/git/hooks-reader" "$H/.config/git/hooks-reader"
printf '#!/bin/sh\necho fedxps\n' > "$SB/bin/uname"
chmod +x "$SB/bin/uname"
export HOME="$H" PATH="$SB/bin:$PATH" GIT_CONFIG_NOSYSTEM=1
export GIT_EDITOR=true GIT_PAGER=cat PAGER=cat GIT_TERMINAL_PROMPT=0
HOSTED="$H/.config/git/config"
# git's defaults with an identity and nothing else: setup, and the controls
PLAIN="$SB/plain.gitconfig"
printf '[user]\n\tname = Rig\n\temail = rig@example.invalid\n[init]\n\tdefaultBranch = main\n[advice]\n\tdetachedHead = false\n' > "$PLAIN"
HOOK="$CFG_ROOT/git/hooks-reader/reference-transaction"
REAL_F="$CFG_ROOT/git/hosts/fedxps.inc"
REAL_B="$CFG_ROOT/git/hosts/bigfed.inc"

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
info() { echo "info - $*"; }
must() { "$@" >/dev/null 2>&1 || { echo "SETUP-FAIL: $*"; echo "passed: $pass  failed: $((fail + 1))"; exit 1; }; }
# Every removal goes through sbrm, which removes nothing outside the sandbox,
# so a variable gone wrong cannot reach a real directory.
sbrm() {
  local p
  for p in "$@"; do
    case "$p" in
      "$SB"/?*) rm -rf -- "$p" ;;
      *)
        echo "SETUP-FAIL: refusing to remove '$p', outside the sandbox"
        echo "passed: $pass  failed: $((fail + 1))"
        exit 1
        ;;
    esac
  done
}
contains() { [[ "$1" == *"$2"* ]]; }
plain() { GIT_CONFIG_GLOBAL="$PLAIN" git "$@"; }
host() { ln -sfn "$1" "$H/.config/git/host.inc"; }

# Every entry under DIR: type, inode and mtime, and every file's sha1.
snap() {
  (cd "$1" && {
    find . -mindepth 1 -printf 'M %P\t%y %i %T@\n'
    find . -type f -printf '%P\0' | xargs -0 -r sha1sum | sed 's/^\([0-9a-f]*\)  \(.*\)$/S \2\t\1/'
  } | LC_ALL=C sort) > "$2"
}
# The ref part of a snapshot: HEAD, packed-refs, the files under refs/ and
# a linked worktree's HEAD; and, apart, the directories under refs/, whose
# mtime a ref lock taken and dropped changes.
refs_of() { grep -E $'^[MS] (HEAD|packed-refs|refs/.*|worktrees/[^/\t]+/HEAD)\t' "$1" | grep -v -E $'\td '; }
refdirs_of() { grep -E $'^M (refs|refs/.*)\td ' "$1"; }
refs_same() { cmp -s <(refs_of "$1") <(refs_of "$2"); }
refdirs_same() { cmp -s <(refdirs_of "$1") <(refdirs_of "$2"); }
same() { cmp -s "$1" "$2"; }
differs() { ! cmp -s "$1" "$2"; }
# The paths two snapshots disagree on, loose objects counted.
changed() {
  LC_ALL=C comm -3 "$1" "$2" | sed -E 's/^\t//; s/^[MS] //; s/\t.*//' | LC_ALL=C sort -u |
    awk '/^objects\/[0-9a-f][0-9a-f](\/|$)/ { n++; next } { printf "%s ", $0 } END { if (n) printf "objects/??/* x%d", n }'
}
treesnap() { (cd "$1" && find . -path ./.git -prune -o -type f -printf '%P\0' | xargs -0 -r sha1sum | LC_ALL=C sort); }
# git processes whose working directory lies under $1, matched by argv and
# /proc -- a detached maintenance names no path on its command line.
gitprocs() {
  local p cwd a
  for p in /proc/[0-9]*; do
    cwd=$(readlink "$p/cwd" 2>/dev/null) || continue
    case "$cwd/" in "$1"/*) ;; *) continue ;; esac
    a=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)
    case "$a" in git\ * | */git\ * | /usr/libexec/git-core/*) echo "${p#/proc/} $a" ;; esac
  done
}

# The host files under test. The variants are the real fedxps.inc with its
# role keys replaced, so each carries the real guard and the real hooksPath.
variant() {
  {
    grep -v -i -E '^[[:space:]]*#?[[:space:]]*(role|readerrepo)[[:space:]]*=' "$REAL_F"
    printf '[gsync]\n%b' "$2"
  } > "$SB/hosts/$1.inc"
}
variant pilot '\treaderRepo = nousowl\n'
variant reader '\trole = reader\n'
variant none ''
variant slash '\treaderRepo = nousowl/\n'
variant typo '\treaderRepo = nouswol\n'
host "$REAL_F"

# --- 1. new repositories keep the files ref backend (ws-6) -----------------
echo "== init.defaultRefFormat (ws-6) =="
cp "$CFG_ROOT/git/config" "$SB/config-copy"
cp "$CFG_ROOT/git/config" "$SB/config-noinit"
git config -f "$SB/config-noinit" --remove-section init 2>/dev/null
# A system file asking for reftable stands in for a git whose built-in
# default has moved (git 3.0, Documentation/BreakingChanges): without it the
# check could not tell the line from 2.56's own default.
printf '[init]\n\tdefaultRefFormat = reftable\n' > "$SB/system-reftable"
fmt() { sbrm "$SB/fmt-r" && (cd "$SB" && env "$@" git init -q fmt-r && git -C fmt-r rev-parse --show-ref-format); }
check "git init under a copy of git/config: files" \
  [ "$(fmt GIT_CONFIG_GLOBAL="$SB/config-copy")" = files ]
check "the same, a system default of reftable beneath it: still files" \
  [ "$(fmt -u GIT_CONFIG_NOSYSTEM GIT_CONFIG_SYSTEM="$SB/system-reftable" GIT_CONFIG_GLOBAL="$SB/config-copy")" = files ]
check "control: without the [init] section that default wins (reftable)" \
  [ "$(fmt -u GIT_CONFIG_NOSYSTEM GIT_CONFIG_SYSTEM="$SB/system-reftable" GIT_CONFIG_GLOBAL="$SB/config-noinit")" = reftable ]
must env -u GIT_CONFIG_NOSYSTEM GIT_CONFIG_SYSTEM="$SB/system-reftable" GIT_CONFIG_GLOBAL="$SB/config-copy" git -C "$SB" clone -q fmt-r fmt-clone
check "git clone under the copy, over the same system default: files" \
  [ "$(git -C "$SB/fmt-clone" rev-parse --show-ref-format)" = files ]
sbrm "$SB/fmt-r" "$SB/fmt-clone"

# --- 2. the host files as they stand --------------------------------------
echo "== the host files as they stand =="
check "fedxps.inc arms core.hooksPath = ~/.config/git/hooks-reader" \
  [ "$(git -C / config -f "$REAL_F" --get core.hooksPath)" = '~/.config/git/hooks-reader' ]
check "fedxps.inc names a reader role or a reader repository" \
  bash -c "git -C / config -f '$REAL_F' --get-regexp '^gsync\.(role|readerrepo)$' | grep -q -v -x 'gsync.role writer'"
check "bigfed.inc sets no hooksPath" \
  bash -c "! git -C / config -f '$REAL_B' --get core.hooksPath"
check "bigfed.inc: maintenance.autoDetach = false" \
  [ "$(git -C / config -f "$REAL_B" --type=bool --get maintenance.autoDetach)" = false ]
check "the hook is executable in the checkout" [ -x "$HOOK" ]
mode="$(git -C "$CFG_ROOT" --no-optional-locks ls-files -s -- git/hooks-reader/reference-transaction | cut -d' ' -f1)"
if [[ -n "$mode" ]]; then
  check "the hook is tracked executable (100755)" [ "$mode" = 100755 ]
else
  info "the hook is not tracked yet; its executable bit travels with the first commit"
fi
check "the hook parses as POSIX sh" sh -n "$HOOK"
ascii_file() { [[ -f "$1" ]] && ! LC_ALL=C grep -q -P '[^\x00-\x7F]' "$1"; }
check "the hook is plain ASCII" ascii_file "$HOOK"
must plain init -q -b main "$SB/probe"
check "through the link, git reads core.hooksPath from host.inc" \
  [ "$(GIT_CONFIG_GLOBAL="$HOSTED" git -C "$SB/probe" config --show-origin --get core.hooksPath | cut -f1)" = "file:$H/.config/git/host.inc" ]
check "git expands its ~ against HOME: the hook path is the sandbox's" \
  [ "$(GIT_CONFIG_GLOBAL="$HOSTED" git -C "$SB/probe" rev-parse --git-path hooks/reference-transaction)" = "$H/.config/git/hooks-reader/reference-transaction" ]
host "$REAL_B"
check "bigfed.inc through the link: no hooksPath" \
  bash -c "! GIT_CONFIG_GLOBAL='$HOSTED' git -C '$SB/probe' config --get core.hooksPath"
host "$REAL_F"
sbrm "$SB/probe"

# --- the writer's repository the reader receives ---------------------------
# origin.git, a bare origin outside the Desktop; w, the writer's clone, with a
# branch, an annotated tag, a stash, a local commit, and origin/main fetched
# one commit behind origin's main, so fetch, pull, merge and rebase each have
# a ref to move.
must plain init -q --bare -b main "$SB/origin.git"
must plain clone -q "$SB/origin.git" "$SB/w"
mkdir -p "$SB/w/src" "$SB/w/doc"
for i in $(seq 1 12); do echo "line $i" > "$SB/w/src/f$i.txt"; echo "doc $i" > "$SB/w/doc/d$i.md"; done
printf 'readme\n' > "$SB/w/README.md"
must plain -C "$SB/w" add -A
must plain -C "$SB/w" commit -qm base
must plain -C "$SB/w" push -q origin main
must plain -C "$SB/w" branch other
must plain -C "$SB/w" tag -a v1 -m v1
must plain clone -q "$SB/origin.git" "$SB/peer"
echo o1 >> "$SB/peer/src/f1.txt"
must plain -C "$SB/peer" commit -qam o1
must plain -C "$SB/peer" push -q
must plain -C "$SB/w" fetch -q
echo l1 >> "$SB/w/doc/d1.md"
must plain -C "$SB/w" commit -qam l1
echo o2 >> "$SB/peer/src/f2.txt"
must plain -C "$SB/peer" commit -qam o2
must plain -C "$SB/peer" push -q
echo stashed >> "$SB/w/README.md"
must plain -C "$SB/w" stash -q
RD="$D/nousowl"
fresh() { sbrm "$RD" "$H/src/wt" "$H/src/wt-b" "$H/src/pushsrc"; cp -a "$SB/w" "$RD"; }

# --- 3. the refusals (fedxps-6), under the real fedxps.inc ------------------
# Each case: a fresh reader copy at ~/Desktop/nousowl, PREP run under git's
# defaults, then OP run in CWD under the sandbox's real configuration with
# GIT_OPTIONAL_LOCKS=0, as on fedxps. The real file names nousowl as a reader
# repository today, and every repository at the cutover, so these hold in
# both states of it.
echo "== the hook refuses every ref update in a repository fedxps reads =="
refusal_ok() { contains "$1" "refused: fedxps reads ~/Desktop/nousowl" && contains "$1" "~/src/outage/nousowl" && contains "$1" "him-5"; }
refuse() { # refuse NAME CWD PREP OP [locks]: "locks" records the ref lock taken, for a command that takes one outside the transaction
  local name=$1 cwd=$2 prep=$3 op=$4 locks=${5:-} rc err
  fresh
  if [[ -n "$prep" ]] && ! (cd "$RD" && GIT_CONFIG_GLOBAL="$PLAIN" bash -c "$prep") >/dev/null 2>&1; then
    echo "FAIL - $name: its preparation failed"; ((fail += 1)); return
  fi
  snap "$RD/.git" "$SB/g0"
  treesnap "$RD" > "$SB/t0"
  err="$(cd "$cwd" && GIT_CONFIG_GLOBAL="$HOSTED" GIT_OPTIONAL_LOCKS=0 bash -c "$op" 2>&1 >/dev/null)"
  rc=$?
  snap "$RD/.git" "$SB/g1"
  treesnap "$RD" > "$SB/t1"
  check "$name: refused (exit $rc)" [ "$rc" -ne 0 ]
  check "$name: the refusal names the machine, the repository and him-5's route" refusal_ok "$err"
  check "$name: no ref and no HEAD changed" refs_same "$SB/g0" "$SB/g1"
  if [[ -z "$locks" ]]; then
    check "$name: no ref lock taken (refused before any lock)" refdirs_same "$SB/g0" "$SB/g1"
  else
    info "$name: a ref lock taken outside the transaction: $(refdirs_same "$SB/g0" "$SB/g1" && echo no || echo yes)"
  fi
  info "$name: leaves under .git: $(changed "$SB/g0" "$SB/g1" | sed 's/^$/nothing/'); working tree $(same "$SB/t0" "$SB/t1" && echo unchanged || echo CHANGED)"
}
refuse "commit -a" "$RD" 'echo r >> README.md' 'git commit -qam reader'
refuse "commit --amend" "$RD" '' 'git commit -q --amend -m amended'
refuse "fetch into origin/main" "$RD" '' 'git fetch -q origin'
refuse "pull" "$RD" '' 'git pull -q --no-rebase origin main'
refuse "merge origin/main" "$RD" '' 'git merge -q --no-edit origin/main'
refuse "rebase origin/main" "$RD" '' 'git rebase -q origin/main'
refuse "cherry-pick origin/main" "$RD" '' 'git cherry-pick origin/main'
refuse "stash" "$RD" 'echo r >> README.md' 'git stash -q'
refuse "stash pop, the only entry" "$RD" '' 'git stash pop -q'
# With one entry, pop and drop delete refs/stash through a transaction, which
# the hook refuses -- after drop has rewritten the stash's reflog under a
# lock of its own (section 5 has the deeper stash).
refuse "stash drop, the only entry" "$RD" '' 'git stash drop -q' locks
refuse "branch -m" "$RD" '' 'git branch -m main main2'
refuse "branch new" "$RD" '' 'git branch new'
refuse "checkout -b" "$RD" '' 'git checkout -q -b t1'
refuse "switch -c" "$RD" '' 'git switch -q -c t2'
refuse "switch other" "$RD" '' 'git switch -q other'
# The reviewer's case (2026-10-26): a refused checkout of a branch has already
# rewritten the index and the tree, which Syncthing then carries to bigfed;
# the refusal names the read that shows it, and that read does show it.
refuse "checkout other" "$RD" '' 'git checkout -q other'
moved_shown() { [[ -n "$(cd "$RD" && GIT_CONFIG_GLOBAL="$HOSTED" GIT_OPTIONAL_LOCKS=0 git status --porcelain)" ]]; }
check "checkout other: GIT_OPTIONAL_LOCKS=0 git status --porcelain shows the moved tree" moved_shown
refuse "reset --hard HEAD~1" "$RD" '' 'git reset -q --hard HEAD~1'
refuse "reset --mixed HEAD~1" "$RD" '' 'git reset -q HEAD~1'
refuse "update-ref" "$RD" '' 'git update-ref refs/heads/x HEAD'
refuse "symbolic-ref" "$RD" '' 'git symbolic-ref HEAD refs/heads/other'
refuse "tag" "$RD" '' 'git tag t-reader'
refuse "tag -d" "$RD" '' 'git tag -d v1'
refuse "notes add" "$RD" '' 'git notes add -m note HEAD'
refuse "pack-refs --all" "$RD" '' 'git pack-refs --all'
refuse "worktree add -b, outside the tree" "$RD" '' "git worktree add -q -b wtb '$H/src/wt-b' HEAD"
refuse "worktree add --detach, outside the tree" "$RD" '' "git worktree add -q --detach '$H/src/wt-b' HEAD"
refuse "commit in a linked worktree outside the tree" "$H/src" \
  "git worktree add -q --detach '$H/src/wt' HEAD && echo r >> '$H/src/wt/README.md'" \
  "cd '$H/src/wt' && git commit -qam from-worktree"
refuse "commit through --git-dir from outside" "$H/src" 'echo r >> README.md' \
  "git --git-dir='$RD/.git' --work-tree='$RD' commit -qam via-git-dir"
refuse "update-ref through GIT_DIR from outside" "$H/src" '' \
  "GIT_DIR='$RD/.git' git update-ref refs/heads/y HEAD"
refuse "commit through a symlink into the tree" "$H/src" "ln -sfn '$RD' '$H/src/nlink'" \
  "cd '$H/src/nlink' && git commit -q --allow-empty -m via-link"
refuse "clone into the tree" "$H/src" '' "git clone -q '$SB/origin.git' '$RD/vendor/clone'"
check "clone into the tree: git removed what it began" [ ! -e "$RD/vendor/clone" ]
refuse "push into it from a clone outside" "$H/src" \
  "git clone -q '$RD' '$H/src/pushsrc' && cd '$H/src/pushsrc' && git commit -q --allow-empty -m outside" \
  "cd '$H/src/pushsrc' && git push -q origin HEAD:refs/heads/from-outside"
sbrm "$H/src/nlink"

# --- 4. what the hook does not stop (fedxps-6, agents-1) --------------------
echo "== what the hook lets through, as the rule says =="
let_through() { # let_through NAME PREP OP: OP's exit, and a snapshot pair in g0/g1
  fresh
  [[ -z "$2" ]] || (cd "$RD" && GIT_CONFIG_GLOBAL="$PLAIN" bash -c "$2") >/dev/null 2>&1
  snap "$RD/.git" "$SB/g0"
  (cd "$RD" && GIT_CONFIG_GLOBAL="$HOSTED" GIT_OPTIONAL_LOCKS=0 bash -c "$3") >/dev/null 2>"$SB/err"
  LT_RC=$?
  snap "$RD/.git" "$SB/g1"
  info "$1: exit $LT_RC; the hook's refusal printed: $(grep -q '^refused: ' "$SB/err" && echo yes || echo no); wrote under .git: $(changed "$SB/g0" "$SB/g1" | sed 's/^$/nothing/')"
}
index_changed() { differs <(grep -E $'^[MS] index\t' "$SB/g0") <(grep -E $'^[MS] index\t' "$SB/g1"); }
config_changed() { differs <(grep -E $'^[MS] config\t' "$SB/g0") <(grep -E $'^[MS] config\t' "$SB/g1"); }
objects_changed() { differs <(grep -E $'^[MS] objects/' "$SB/g0") <(grep -E $'^[MS] objects/' "$SB/g1"); }
readme_is_head() { cmp -s "$RD/README.md" <(git -C "$RD" show HEAD:README.md); }
let_through "add" 'echo r >> README.md' 'git add README.md'
check "add: exits 0" [ "$LT_RC" -eq 0 ]
check "add: the index is written" index_changed
let_through "config write" '' 'git config transport.test 1'
check "config write: exits 0" [ "$LT_RC" -eq 0 ]
check "config write: .git/config is written" config_changed
# gc repacks and exits 0; its pack-refs step alone is refused, and prints
# the refusal (the reviewer's precision, 2026-10-26).
let_through "gc" '' 'git gc -q'
check "gc: exits 0" [ "$LT_RC" -eq 0 ]
check "gc: the repack runs (objects/ rewritten)" objects_changed
check "gc: no ref and no HEAD changed (its pack-refs refused)" refs_same "$SB/g0" "$SB/g1"
let_through "reset --hard on a dirty tree" 'echo dirty >> README.md' 'git reset -q --hard'
check "reset --hard: its working-tree half ran, the edit is gone" readme_is_head
let_through "checkout -- path" 'echo dirty >> README.md' 'git checkout -- README.md'
check "checkout -- path: exits 0, the edit is gone" readme_is_head
let_through "restore" 'echo dirty >> README.md' 'git restore README.md'
check "restore: exits 0, the edit is gone" readme_is_head

# --- 5. what passes the hook, recorded --------------------------------------
# The bypasses switch hooks off; agents-2 keeps them off by rule. Git's reflog
# machinery writes a ref outside any transaction when asked to update it
# (`reflog delete|expire --updateref`), which `stash drop` and `stash pop` do
# whenever an entry remains; agents-2 lists `stash` among the writes.
echo "== what passes the hook (recorded; agents-2 keeps these off by rule) =="
record() { # record NAME PREP OP
  local rc
  fresh
  [[ -z "$2" ]] || (cd "$RD" && GIT_CONFIG_GLOBAL="$PLAIN" bash -c "$2") >/dev/null 2>&1
  snap "$RD/.git" "$SB/g0"
  (cd "$RD" && GIT_CONFIG_GLOBAL="$HOSTED" GIT_OPTIONAL_LOCKS=0 bash -c "$3") >/dev/null 2>&1
  rc=$?
  snap "$RD/.git" "$SB/g1"
  info "$1: exit $rc; $(refs_same "$SB/g0" "$SB/g1" && echo 'no ref moved' || echo "refs moved: $(changed <(refs_of "$SB/g0") <(refs_of "$SB/g1"))")"
}
record "-c core.hooksPath=/dev/null" '' 'git -c core.hooksPath=/dev/null commit -q --allow-empty -m bypass'
record "-c hook.reference-transaction.enabled=false" '' 'git -c hook.reference-transaction.enabled=false commit -q --allow-empty -m bypass'
record "a repository-local core.hooksPath" '' 'git config core.hooksPath .git/hooks && git commit -q --allow-empty -m bypass'
record "GIT_CONFIG_GLOBAL=/dev/null" '' 'GIT_CONFIG_GLOBAL=/dev/null git -c user.name=x -c user.email=x@example.invalid commit -q --allow-empty -m bypass'
record "stash drop, one of two entries" 'echo s2 >> README.md && git stash -q' 'git stash drop -q'
record "stash pop, one of two entries" 'echo s2 >> README.md && git stash -q' 'git stash pop -q'
record "reflog delete --updateref on the branch" 'git commit -q --allow-empty -m extra' 'git reflog delete --updateref --rewrite main@{0}'
record "reflog expire --updateref --all" '' 'git reflog expire --expire=now --updateref --all'

# --- 6. the role decides where it refuses ---------------------------------
echo "== the role keys =="
for r in other nousowl.net deep/a/b; do
  sbrm "$D/$r"
  mkdir -p "$(dirname "$D/$r")"
  cp -a "$SB/w" "$D/$r"
done
fresh
must plain init -q -b main "$RD/nested"
must plain -C "$RD/nested" commit -q --allow-empty -m nested
must plain clone -q "$SB/w" "$H/src/outage/nousowl"
ln -sfn "$D/other" "$H/src/olink"
probe() { (cd "$1" && GIT_CONFIG_GLOBAL="$HOSTED" GIT_OPTIONAL_LOCKS=0 git commit -q --allow-empty -m probe) >/dev/null 2>&1; }
refused() { ! probe "$1"; }
passes() { probe "$1"; }
host "$SB/hosts/pilot.inc"
check "pilot key: nousowl refused" refused "$RD"
check "pilot key: a repository nested in nousowl refused" refused "$RD/nested"
check "pilot key: another Desktop repository passes" passes "$D/other"
check "pilot key: nousowl.net passes (a name sharing the prefix)" passes "$D/nousowl.net"
check "pilot key: a deep Desktop repository passes" passes "$D/deep/a/b"
check "pilot key: a clone under ~/src passes" passes "$H/src/outage/nousowl"
host "$SB/hosts/reader.inc"
check "role = reader: nousowl refused" refused "$RD"
check "role = reader: another Desktop repository refused" refused "$D/other"
check "role = reader: nousowl.net refused" refused "$D/nousowl.net"
check "role = reader: a deep Desktop repository refused" refused "$D/deep/a/b"
check "role = reader: a Desktop repository reached through a link outside refused" refused "$H/src/olink"
check "role = reader: a clone under ~/src passes" passes "$H/src/outage/nousowl"
must git -C "$D/other" config gsync.role writer
check "role = reader: a repository's own gsync.role = writer lifts nothing" refused "$D/other"
must git -C "$D/other" config --unset gsync.role
check "role = reader: -c gsync.role=writer lifts nothing" \
  bash -c "! (cd '$D/other' && GIT_CONFIG_GLOBAL='$HOSTED' git -c gsync.role=writer commit -q --allow-empty -m probe) 2>/dev/null"
host "$SB/hosts/none.inc"
check "no role, no reader repository: nousowl passes" passes "$RD"
check "no role, no reader repository: another Desktop repository passes" passes "$D/other"
host "$SB/hosts/slash.inc"
check "readerRepo = nousowl/ (a trailing slash): nousowl refused" refused "$RD"
check "readerRepo = nousowl/: another Desktop repository passes" passes "$D/other"
host "$SB/hosts/typo.inc"
check "readerRepo naming no directory: refuses nothing, as the sync commands" passes "$RD"
host "$REAL_B"
check "bigfed.inc: nousowl passes" passes "$RD"
check "bigfed.inc: another Desktop repository passes" passes "$D/other"
sbrm "$H/src/olink"

# --- 7. a repository born in the tree ------------------------------------
echo "== init and clone into the Desktop =="
born() { GIT_CONFIG_GLOBAL="$HOSTED" git init -q -b main "$1" >/dev/null 2>&1; }
unborn() { ! born "$1"; }
host "$SB/hosts/reader.inc"
check "role = reader: git init in the Desktop refused" unborn "$D/fresh"
check "role = reader: what the refused init leaves has no HEAD (no repository)" [ ! -e "$D/fresh/.git/HEAD" ]
check "role = reader: git clone into the Desktop refused" \
  bash -c "! GIT_CONFIG_GLOBAL='$HOSTED' git clone -q '$SB/origin.git' '$D/cloned' 2>/dev/null"
check "role = reader: the refused clone left nothing" [ ! -e "$D/cloned" ]
check "role = reader: git clone outside the Desktop passes" \
  bash -c "GIT_CONFIG_GLOBAL='$HOSTED' git clone -q '$SB/origin.git' '$H/src/fine' 2>/dev/null"
host "$SB/hosts/pilot.inc"
check "pilot key: git init elsewhere in the Desktop passes" born "$D/fresh2"
check "pilot key: that repository is whole (HEAD)" [ -e "$D/fresh2/.git/HEAD" ]
check "pilot key: git init inside nousowl refused" unborn "$RD/nested2"

# --- 8. the hook's states and its safe side --------------------------------
echo "== the hook's states =="
host "$REAL_F"
hookrc() { (cd "$1" && GIT_CONFIG_GLOBAL="${3:-$HOSTED}" sh "$HOOK" "$2" < /dev/null > /dev/null 2>&1); echo $?; }
check "preparing in nousowl: refuses" [ "$(hookrc "$RD" preparing)" = 1 ]
check "prepared in nousowl: refuses (a git before 2.54, which skips preparing)" [ "$(hookrc "$RD" prepared)" = 1 ]
check "committed: passes at once" [ "$(hookrc "$RD" committed)" = 0 ]
check "aborted: passes at once" [ "$(hookrc "$RD" aborted)" = 0 ]
check "an unknown state: passes" [ "$(hookrc "$RD" something-new)" = 0 ]
check "preparing outside the Desktop: passes" [ "$(hookrc "$H/src/outage/nousowl" preparing)" = 0 ]
printf '[core\n\tbroken\n' > "$SB/broken.gitconfig"
check "a configuration git cannot read, in the Desktop: refuses (the safe side)" \
  [ "$(hookrc "$D/other" preparing "$SB/broken.gitconfig")" = 1 ]
check "the same outside the Desktop: passes" [ "$(hookrc "$H/src/outage/nousowl" preparing "$SB/broken.gitconfig")" = 0 ]
check "a HOME with no Desktop: passes" \
  bash -c "cd '$RD' && HOME='$SB/nohome' GIT_CONFIG_GLOBAL='$HOSTED' sh '$HOOK' preparing < /dev/null >/dev/null 2>&1"
# git names the common directory by its canonical path, so the hook must
# resolve ~/Desktop too, or a HOME with a symlink on its path passes all.
ln -sfn "$H" "$SB/homelink"
via_link() { (cd "$RD" && HOME="$SB/homelink" GIT_CONFIG_GLOBAL="$SB/homelink/.config/git/config" git commit -q --allow-empty -m probe) >/dev/null 2>&1; }
via_link_refused() { ! via_link; }
check "a HOME reached through a symlink: nousowl still refused" via_link_refused
out="$(cd "$RD" && GIT_CONFIG_GLOBAL="$HOSTED" git update-ref refs/heads/z HEAD 2>&1)"
check "the message, from git: the hook's lines before git's own" \
  bash -c "printf '%s\n' \"\$1\" | head -1 | grep -q '^refused: fedxps reads ~/Desktop/nousowl -- '" _ "$out"
moved_text() { contains "$out" "the index and the working tree may already have moved" && contains "$out" "GIT_OPTIONAL_LOCKS=0 git status --porcelain" && contains "$out" "agents-1"; }
check "the message says the index and the tree may already have moved, the read that shows it, and agents-1" moved_text
info "the refusal as git prints it:"
printf '%s\n' "$out" | sed 's/^/info -   /'

# --- 9. the hook's cost, recorded -----------------------------------------
echo "== the hook's cost (recorded) =="
must plain clone -q "$SB/w" "$H/src/costly"
cost() { # cost DIR [git -c ...]: microseconds per update-ref transaction, over 100
  local dir=$1 t0 t1 i
  shift
  t0=$(date +%s%N)
  for i in $(seq 1 100); do GIT_CONFIG_GLOBAL="$HOSTED" git -C "$dir" "$@" update-ref refs/heads/c HEAD 2>/dev/null; done
  t1=$(date +%s%N)
  echo $(((t1 - t0) / 100000))
}
host "$REAL_F"
info "per ref transaction, $(nproc) cores: no hook $(cost "$H/src/costly" -c core.hooksPath=/dev/null) us; hook, a repository outside the Desktop $(cost "$H/src/costly") us"
host "$SB/hosts/pilot.inc"
info "per ref transaction: hook, pilot key, a Desktop repository fedxps still writes $(cost "$D/other") us; refused in nousowl $(cost "$RD") us"

# --- 10. the read matrix (fedxps-1) ----------------------------------------
# A writer's repository with a few dozen files, its index refreshed and then
# left older than a second, so no entry is racy; each operation runs on a
# fresh `cp -a` copy after a tracked file is touched. Under the guard: the
# real fedxps.inc through the link and GIT_OPTIONAL_LOCKS=0. The control:
# git's defaults, no variable.
echo "== the read matrix (fedxps-1) =="
host "$REAL_F"
RM="$SB/rm"
must plain clone -q "$SB/w" "$RM"
echo s >> "$RM/README.md"
must plain -C "$RM" stash -q
plain -C "$RM" status >/dev/null 2>&1
sleep 1.1
RC="$D/readcopy"
# checkStat = minimal: Syncthing's new inodes leave every entry stat-clean,
# which is what keeps the reader's reads fast and its plumbing quiet.
statdirty() { # statdirty guard|control: the entries git diff-files lists on an untouched copy
  sbrm "$RC"
  cp -a "$RM" "$RC"
  if [[ $1 == guard ]]; then
    (cd "$RC" && GIT_CONFIG_GLOBAL="$HOSTED" GIT_OPTIONAL_LOCKS=0 git diff-files --name-only | wc -l)
  else
    (cd "$RC" && GIT_CONFIG_GLOBAL="$PLAIN" git diff-files --name-only | wc -l)
  fi
}
check "guard: an untouched copy is stat-clean, git diff-files lists nothing" [ "$(statdirty guard)" -eq 0 ]
check "control: under git's defaults git diff-files lists every entry" [ "$(statdirty control)" -gt 0 ]
matrix_run() { # matrix_run guard|control OP -> "yes" or "no": did anything under .git change
  sbrm "$RC"
  cp -a "$RM" "$RC"
  touch "$RC/src/f3.txt"
  snap "$RC/.git" "$SB/m0"
  if [[ $1 == guard ]]; then
    (cd "$RC" && GIT_CONFIG_GLOBAL="$HOSTED" GIT_OPTIONAL_LOCKS=0 bash -c "$2") >/dev/null 2>&1
  else
    (cd "$RC" && GIT_CONFIG_GLOBAL="$PLAIN" bash -c "$2") >/dev/null 2>&1
  fi
  snap "$RC/.git" "$SB/m1"
  if same "$SB/m0" "$SB/m1"; then echo no; else echo "yes: $(changed "$SB/m0" "$SB/m1")"; fi
}
READS=(
  'git status' 'git status --porcelain' 'git status --porcelain -uall' 'git status --short'
  'git status -sb' 'git diff' 'git diff --stat' 'git diff --quiet' 'git diff --name-only'
  'git diff --cached' 'git diff HEAD' 'git diff HEAD~1' 'git diff --no-ext-diff --quiet --exit-code'
  'git log -5' 'git log --oneline -n 5' 'git show HEAD' 'git show --stat HEAD' 'git blame README.md'
  'git branch' 'git branch -vv' 'git branch --show-current' 'git ls-files' 'git ls-files -m'
  'git rev-parse HEAD' 'git rev-parse --abbrev-ref HEAD' 'git fsck --no-progress' 'git for-each-ref'
  'git stash list' 'git stash show' 'git worktree list' 'git describe' 'git describe --tags --always'
  'git cat-file -p HEAD' 'git grep -n line'
)
WRITERS=('git describe --always --dirty' 'git update-index -q --refresh')
TABLE=()
for op in "${READS[@]}"; do
  g="$(matrix_run guard "$op")"
  c="$(matrix_run control "$op")"
  TABLE+=("$op|$g|$c")
  check "guard: '$op' leaves every entry under .git unchanged" [ "$g" = no ]
done
for op in "${WRITERS[@]}"; do
  g="$(matrix_run guard "$op")"
  c="$(matrix_run control "$op")"
  TABLE+=("$op|$g|$c")
  info "kept off by habit (fedxps-4): '$op' under the guard writes: $g"
done
for op in 'git status' 'git status --porcelain -uall' 'git diff' 'git diff --stat'; do
  c="$(matrix_run control "$op")"
  check "control: '$op' under git's defaults rewrites the index (the matrix discriminates)" contains "$c" index
done
info "the matrix: operation | guard: wrote under .git | control: wrote under .git"
for row in "${TABLE[@]}"; do
  IFS='|' read -r op g c <<<"$row"
  printf 'info -   %-45s | %-28s | %s\n' "$op" "$g" "$c"
done
sbrm "$RC"

# --- 11. maintenance in the foreground (bigfed-1) --------------------------
# A repository under bigfed.inc whose own config sets the geometric repack's
# loose-object threshold low, and 4,000 loose blobs of random bytes: the next
# commit crosses it, and git's automatic maintenance repacks. The control is
# the same under a host file with autoDetach = true.
echo "== maintenance in the foreground (bigfed-1) =="
mkdir -p "$SB/blobs"
python3 - "$SB/blobs" <<'PY'
import os, sys
for i in range(4000):
    with open(os.path.join(sys.argv[1], 'b%05d' % i), 'wb') as f:
        f.write(os.urandom(4096))
PY
sed 's/^\tautoDetach = false$/\tautoDetach = true/' "$REAL_B" > "$SB/hosts/bigfed-detach.inc"
check "setup: the control host file says autoDetach = true" \
  [ "$(git -C / config -f "$SB/hosts/bigfed-detach.inc" --type=bool --get maintenance.autoDetach)" = true ]
mk_maint() {
  must plain init -q -b main "$1"
  echo a > "$1/a"
  must plain -C "$1" add a
  must plain -C "$1" commit -qm base
  must plain -C "$1" config maintenance.geometric-repack.auto 100
  find "$SB/blobs" -type f | plain -C "$1" hash-object -w --stdin-paths >/dev/null
}
loose() { git -C "$1" count-objects | cut -d' ' -f1; }
MF="$D/maint-fg"
MB="$D/maint-bg"
mk_maint "$MF"
mk_maint "$MB"
check "setup: 4,000 loose objects before the commit" [ "$(loose "$MF")" -ge 4000 ]
host "$REAL_B"
check "bigfed.inc: maintenance.autoDetach resolves false, from host.inc" \
  [ "$(GIT_CONFIG_GLOBAL="$HOSTED" git -C "$MF" config --show-origin --type=bool --get maintenance.autoDetach)" = "file:$H/.config/git/host.inc	false" ]
# The lock is read the instant the commit returns, before the slower /proc
# scan: a detached repack of this size ends within a few hundred ms.
crossing() { # crossing REPO: commit past the threshold; sets LOCK, PROCS, MS
  local t0 t1
  echo b >> "$1/a"
  t0=$(date +%s%N)
  (cd "$1" && GIT_CONFIG_GLOBAL="$HOSTED" git commit -qam crossing) >/dev/null 2>&1
  LOCK=no
  [[ -e "$1/.git/objects/maintenance.lock" ]] && LOCK=yes
  t1=$(date +%s%N)
  PROCS="$(gitprocs "$1")"
  MS=$(((t1 - t0) / 1000000))
}
crossing "$MF"
check "no maintenance.lock when the commit returns" [ "$LOCK" = no ]
check "no git process of the sandbox repository survives the commit" [ -z "$PROCS" ]
check "the repack ran: no loose objects left" [ "$(loose "$MF")" -eq 0 ]
info "foreground: the commit took $MS ms"
host "$SB/hosts/bigfed-detach.inc"
crossing "$MB"
lock=$LOCK procs=$PROCS
info "control (autoDetach = true): the commit took $MS ms; at its return maintenance.lock: $lock; git processes: $(printf '%s' "${procs:-none}" | tr '\n' ';')"
check "control: the commit returns before the repack ends (lock or process left)" \
  bash -c "[ '$lock' = yes ] || [ -n '$procs' ]"
for i in $(seq 1 100); do
  [[ -z "$(gitprocs "$MB")" && ! -e "$MB/.git/objects/maintenance.lock" ]] && break
  sleep 0.1
done
check "control: the detached repack then finishes on its own" [ "$(loose "$MB")" -eq 0 ]

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
