#!/usr/bin/env bash
# Regression suite for the 2026-07-26 four-lens audit of 50-git-sync.sh.
# Every fix from the audit has a test here that fails against the pre-audit code.
set -u
SB="$(mktemp -d "${TMPDIR:-/tmp}/gsync-audit.XXXXXX")"
trap 'rm -rf "$SB"' EXIT

CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$CFG_ROOT/bash/.bashrc.d/50-git-sync.sh"
source "$CFG_ROOT/bash/.bashrc.d/60-stow.sh"   # STOW_ORDER for hint tests
_gsync_online() { return 0; }                        # local-path remotes

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
must() { "$@" || { echo "SETUP-FAIL: $*"; exit 1; }; }
mkpair() { # mkpair NAME -> bare origin-NAME.git + clone NAME with one pushed commit
  must git init -q --bare -b main "$SB/origin-$1.git"
  must git clone -q "$SB/origin-$1.git" "$SB/$1"
  echo base > "$SB/$1/base.txt"
  must git -C "$SB/$1" add -A
  must git -C "$SB/$1" commit -qm base
  must git -C "$SB/$1" push -qu origin main
}
cd "$SB"

# --- G1: conflicted revert must be caught, not committed over.
mkpair r1
g="$(git -C r1 rev-parse --absolute-git-dir)"
git -C r1 rev-parse HEAD > "$g/REVERT_HEAD"
out="$(_gsync_push_repo r1 "$SB/r1" m)"; rc=$?
check "revert guard: rc=1"            [ "$rc" -eq 1 ]
check "revert guard: named"           contains "$out" "revert in progress"
rm "$g/REVERT_HEAD"

# --- CF-F1: unborn repo is skipped untouched, correct label.
must git init -qb main unborn
echo x > unborn/notes.md
out="$(_gsync_push_repo unborn "$SB/unborn" m)"; rc=$?
check "unborn: rc=2 skip"             [ "$rc" -eq 2 ]
check "unborn: labeled"               contains "$out" "no commits yet"
check "unborn: no commit created"     bash -c "! git -C '$SB/unborn' rev-parse --verify -q HEAD >/dev/null"

# --- G2: declined files with hostile names are truly unstaged, no collateral.
mkpair r2
echo tracked > r2/big1.bin
must git -C r2 add -A; must git -C r2 commit -qm t; must git -C r2 push -q
echo modified >> r2/big1.bin           # innocent modification of a tracked file
truncate -s 30M 'r2/big[1].bin'        # flagged (size), name glob-matches big1.bin
echo s > 'r2/:secret.pem'              # flagged (secrets), leading-colon pathspec trap
out="$(_gsync_push_repo r2 "$SB/r2" m)"; rc=$?
check "hostile: rc=0"                 [ "$rc" -eq 0 ]
check "hostile: bracket not tracked"  bash -c "! git -C '$SB/r2' ls-files --error-unmatch ':(literal)big[1].bin' >/dev/null 2>&1"
check "hostile: colon not tracked"    bash -c "! git -C '$SB/r2' ls-files --error-unmatch ':secret.pem' >/dev/null 2>&1"
check "hostile: innocent mod pushed"  bash -c "git -C '$SB/r2' show HEAD:big1.bin | grep -q modified"

# --- G3a: rename-to-secret-name is vetted (rename detection off for listing).
mkpair r3
echo t > r3/template.txt
must git -C r3 add -A; must git -C r3 commit -qm t; must git -C r3 push -q
must git -C r3 mv template.txt .env
echo "SECRET=1" >> r3/.env
out="$(_gsync_push_repo r3 "$SB/r3" m)"; rc=$?
check "rename vet: warned"            contains "$out" "matches secrets pattern '.env'"
check "rename vet: .env not tracked"  bash -c "! git -C '$SB/r3' ls-files --error-unmatch .env >/dev/null 2>&1"

# --- G3b: typechange (symlink -> huge file) meets the size guard.
mkpair r4
ln -s base.txt r4/link
must git -C r4 add -A; must git -C r4 commit -qm t; must git -C r4 push -q
rm r4/link; truncate -s 30M r4/link
out="$(_gsync_push_repo r4 "$SB/r4" m)"; rc=$?
check "typechange vet: warned"        contains "$out" "MB (guard:"
check "typechange vet: still symlink in HEAD" bash -c "git -C '$SB/r4' cat-file -p HEAD^{tree} | grep -q '120000.*link'"

# --- G9: embedded git repo is flagged, not silently pushed as a gitlink.
mkpair r5
must git init -qb main r5/inner
echo i > r5/inner/f; must git -C r5/inner add -A; must git -C r5/inner commit -qm i
out="$(_gsync_push_repo r5 "$SB/r5" m)"; rc=$?
check "embedded repo: warned"         contains "$out" "embedded git repository"
check "embedded repo: not committed"  bash -c "! git -C '$SB/r5' ls-files --error-unmatch inner >/dev/null 2>&1"

# --- S3: secret directory components are matched.
mkpair r6
mkdir -p r6/.env r6/old-credentials
echo s > r6/.env/secrets.json
echo s > r6/old-credentials/notes.md
out="$(_gsync_push_repo r6 "$SB/r6" m)"; rc=$?
check "component: .env/ flagged"      contains "$out" ".env/secrets.json"
check "component: dropped both"       bash -c "[ \"\$(git -C '$SB/r6' ls-files | wc -l)\" = 1 ]"

# --- S5: garbage GSYNC_MAX_MB falls back instead of aborting the run.
mkpair r7
echo ok > r7/fine.txt
out="$(GSYNC_MAX_MB=25M _gsync_push_repo r7 "$SB/r7" m)"; rc=$?
check "maxmb garbage: rc=0"           [ "$rc" -eq 0 ]
check "maxmb garbage: warned"         contains "$out" "not a number"
check "maxmb garbage: still pushed"   contains "$out" "committed 1 path(s); pushed"

# --- S1: gpushall argument parser.
mkpair r8
REPOS_DESKTOP=("$SB/r8")
echo w > r8/w.txt
out="$(gpushall -f)"; rc=$?
check "gpushall -f: rejected rc=1"    [ "$rc" -eq 1 ]
check "gpushall -f: hint to gstatall" contains "$out" "gstatall -f"
check "gpushall -f: nothing committed" bash -c "git -C '$SB/r8' status --porcelain | grep -q w.txt"
out="$(gpushall -m)"; rc=$?
check "gpushall -m bare: rc=1"        [ "$rc" -eq 1 ]
out="$(gpushall Reorganized bash configs)"; rc=$?
check "legacy msg: rc=0"              [ "$rc" -eq 0 ]
check "legacy msg: all words"         bash -c "git -C '$SB/r8' log -1 --format=%s | grep -qx 'Reorganized bash configs'"
echo w2 > r8/w2.txt
out="$(gpushall)"; rc=$?
check "default subject: hostname fmt" bash -c "git -C '$SB/r8' log -1 --format=%s | grep -qE \"^$(hostname): [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$\""

# --- B: deleted-only commit (sibling of the historic mod-only bug).
rm r8/w2.txt
out="$(gpushall)"; rc=$?
check "delete-only: rc=0"             [ "$rc" -eq 0 ]
check "delete-only: synced"           contains "$out" "committed 1 path(s); pushed"
check "delete-only: summary ok"       contains "$out" "ok: 1  skipped: 0  failed: 0  pending: 0"

# --- CF-F4 + G6: initial push discloses; exact-ref ls-remote isn't fooled.
must git init -q --bare -b main origin-r9.git
( cd "$SB" && git clone -q origin-r9.git seed && cd seed && git checkout -qb feature/main && echo f > f.txt && git add -A && git commit -qm f && git push -qu origin feature/main ) 2>/dev/null
must git init -qb main r9
must git -C r9 remote add origin "$SB/origin-r9.git"
echo n > r9/new.txt
must git -C r9 add -A; must git -C r9 commit -qm seed
out="$(_gsync_push_repo r9 "$SB/r9" m)"; rc=$?
check "initial push: rc=0"            [ "$rc" -eq 0 ]
check "initial push: disclosed"       contains "$out" "initial push to origin/main"
check "initial push: upstream set"    bash -c "git -C '$SB/r9' rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1"

# --- CF-F3: offline never-pushed repo reports PEND, not OK.
must git init -qb main r10
must git -C r10 remote add origin "$SB/origin-r9.git"
echo n > r10/n.txt; must git -C r10 add -A; must git -C r10 commit -qm c
_gsync_online() { return 1; }
out="$(_gsync_push_repo r10 "$SB/r10" m)"; rc=$?
check "offline no-upstream: rc=3"     [ "$rc" -eq 3 ]
check "offline no-upstream: PEND"     contains "$out" "initial push pending (offline)"

# --- B4: offline entry points.
REPOS_DESKTOP=("$SB/r8")
echo off > r8/off.txt
out="$(gpushall)"; rc=$?
check "offline gpushall: rc=0"        [ "$rc" -eq 0 ]
check "offline gpushall: pending: 1"  contains "$out" "pending: 1"
check "offline gpushall: PEND summary" contains "$out" "push pending (offline): r8"
out="$(gpullall)"; rc=$?
check "offline gpullall: rc=1"        [ "$rc" -eq 1 ]
check "offline gpullall: warned"      contains "$out" "offline — nothing pulled"
out="$(gstatall -f)"; rc=$?
check "offline gstatall -f: rc=0"     [ "$rc" -eq 0 ]
check "offline gstatall -f: fallback" contains "$out" "(local view"
_gsync_online() { return 0; }
out="$(gpushall)"   # flush r8's pending commit for later tests
check "back online: flushed"          contains "$out" "pushed 1 commit(s)"

# --- B3: gpullall on the diverged morning-after names the remedy.
must git clone -q "$SB/origin-r8.git" r8b
echo remote > r8b/base.txt; must git -C r8b add -A; must git -C r8b commit -qm remote; must git -C r8b push -q
echo local > r8/only-local.txt; must git -C r8 add -A; must git -C r8 commit -qm local
out="$(gpullall)"; rc=$?
check "diverged pull: rc=1"           [ "$rc" -eq 1 ]
check "diverged pull: remedy named"   contains "$out" "run: gpush r8 (it rebases)"
check "diverged pull: needs attention" contains "$out" "needs attention: r8"
out="$(gpushall)"; rc=$?
check "diverged push: rc=0 rebases"   [ "$rc" -eq 0 ]
check "diverged push: integrated"     contains "$out" "integrated changes from origin"

# --- B10 + S2: behind-only gpushall reports the pull and fires hints (unicode-proof).
must git init -q --bare -b main origin-cfg.git
must git clone -q origin-cfg.git configs
mkdir -p configs/bash/.bashrc.d configs/nvim
echo a > configs/README.md
must git -C configs add -A; must git -C configs commit -qm c1; must git -C configs push -qu origin main
must git clone -q origin-cfg.git cfg2
mkdir -p cfg2/bash/.bashrc.d cfg2/nvim
echo b > "cfg2/bash/.bashrc.d/95-café.sh"     # unicode: defeats quotePath-blind parsing
echo c > cfg2/nvim/new.lua
must git -C cfg2 add -A; must git -C cfg2 commit -qm c2; must git -C cfg2 push -q
out="$(_gsync_push_repo configs "$SB/configs" m)"; rc=$?
check "behind push: rc=0"             [ "$rc" -eq 0 ]
check "behind push: reported PULL"    contains "$out" "integrated changes from origin"
check "behind push: no up-to-date lie" lacks "$out" "up to date"
check "behind push: re-source hint"   contains "$out" "source ~/.bashrc"
check "behind push: stow hint names"  contains "$out" "stow-all"

# --- G4: a force-moved remote tag no longer wedges every pull.
mkpair r11
must git -C r11 tag v1
must git -C r11 push -q origin v1
must git clone -q "$SB/origin-r11.git" r11b
echo t2 > r11b/t2.txt; must git -C r11b add -A; must git -C r11b commit -qm t2
must git -C r11b tag -f v1
must git -C r11b push -q origin main
must git -C r11b push -qf origin v1
out="$(_gsync_pull_repo r11 "$SB/r11" 2>&1)"; rc=$?
check "moved tag: pull rc=0"          [ "$rc" -eq 0 ]
check "moved tag: updated"            contains "$out" "r11: updated"

# --- B6: detached HEAD skips cleanly through gpushall.
mkpair r12
must git -C r12 checkout -q --detach
REPOS_DESKTOP=("$SB/r12")
out="$(gpushall)"; rc=$?
check "detached: rc=0 (skip != fail)" [ "$rc" -eq 0 ]
check "detached: counted skipped"     contains "$out" "skipped: 1"
check "detached: named in summary"    contains "$out" "skipped: r12"

# --- B7: >12 new files truncate the listing.
mkpair r13
for i in $(seq 1 15); do echo x > "r13/f$i.txt"; done
out="$(_gsync_push_repo r13 "$SB/r13" m)"; rc=$?
check "truncate: rc=0"                [ "$rc" -eq 0 ]
check "truncate: +3 more"             contains "$out" "+3 more"

# --- B7: declined file re-flagged on the next run.
mkpair r14
echo s > r14/.env
out1="$(_gsync_push_repo r14 "$SB/r14" m)"
out2="$(_gsync_push_repo r14 "$SB/r14" m)"; rc=$?
check "re-flag: warned both runs"     bash -c "contains() { [[ \"\$1\" == *\"\$2\"* ]]; }; contains '$out1' \"secrets pattern\" && contains '$out2' \"secrets pattern\""
check "re-flag: second run rc=0"      [ "$rc" -eq 0 ]

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
