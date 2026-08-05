#!/usr/bin/env bash
# Two-machine workflow simulation for 50-git-sync.sh.
# Recreates the real pitfall: repo x ahead on machine1, repo y ahead on
# machine2, then true same-repo divergence (non-conflicting and conflicting).
# "Machines" are directories; REPOS_DESKTOP is repointed per machine, which is
# exactly what gpullall/gpushall/gstatall iterate.
set -u

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/gsync-2m.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$CFG_ROOT/bash/.bashrc.d/50-git-sync.sh"
_gsync_online() { return 0; }   # local-path remotes; no real network involved

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
must() { "$@" || { echo "SETUP-FAIL: $*"; exit 1; }; }
row() { # row OUTPUT REPO -> the dashboard line for REPO
  grep -E "^$2 " <<<"$1"
}

cd "$SANDBOX"
for r in x y; do
  must git init -q --bare -b main "origin-$r.git"
  must git clone -q "origin-$r.git" "m1/$r"
  echo base > "m1/$r/base.txt"
  must git -C "m1/$r" add -A
  must git -C "m1/$r" commit -qm base
  must git -C "m1/$r" push -qu origin main
  must git clone -q "origin-$r.git" "m2/$r"
done
M1=("$SANDBOX/m1/x" "$SANDBOX/m1/y")
M2=("$SANDBOX/m2/x" "$SANDBOX/m2/y")

# --- The classic pitfall: x ahead on m1, y ahead on m2, neither pushed.
echo work1 > m1/x/work.txt
must git -C m1/x add -A; must git -C m1/x commit -qm "m1 work in x"
echo work2 > m2/y/work.txt
must git -C m2/y add -A; must git -C m2/y commit -qm "m2 work in y"

REPOS_DESKTOP=("${M1[@]}")
out="$(gstatall -f)"
check "m1 sees x needs push"        contains "$(row "$out" x)" "needs push"
check "m1 sees y current"           contains "$(row "$out" y)" "0      0  -"
REPOS_DESKTOP=("${M2[@]}")
out="$(gstatall -f)"
check "m2 sees y needs push"        contains "$(row "$out" y)" "needs push"
check "m2 cannot see m1 unpushed"   contains "$(row "$out" x)" "0      0  -"

# m1 pushes; now m2's fetch-refreshed dashboard shows the whole picture.
REPOS_DESKTOP=("${M1[@]}")
out="$(gpushall)"; rc=$?
check "m1 gpushall rc=0"            [ "$rc" -eq 0 ]
check "m1 gpushall counters"        contains "$out" "ok: 2  skipped: 0  failed: 0  pending: 0"
check "m1 gpushall pushed x"        contains "$out" "x: pushed 1 commit(s)"
check "m1 gpushall y untouched"     contains "$out" "y: up to date"
REPOS_DESKTOP=("${M2[@]}")
out="$(gstatall -f)"
check "m2 now sees x needs pull"    contains "$(row "$out" x)" "needs pull"
check "m2 still sees y needs push"  contains "$(row "$out" y)" "needs push"

# m2 pulls: x fast-forwards, y is flagged as ahead rather than called done.
out="$(gpullall)"
check "m2 gpullall updated x"       contains "$out" "x: updated"
check "m2 gpullall warns y ahead"   contains "$out" "y: ahead by 1 unpushed commit(s)"
out="$(gpushall)"
check "m2 gpushall pushed y"        contains "$out" "y: pushed 1 commit(s)"
REPOS_DESKTOP=("${M1[@]}")
out="$(gpullall)"
check "m1 gpullall updated y"       contains "$out" "y: updated"

# Convergence: every clone identical to its origin.
converged=1
for r in x y; do
  o="$(git -C "origin-$r.git" rev-parse main)"
  [[ "$(git -C "m1/$r" rev-parse HEAD)" == "$o" && "$(git -C "m2/$r" rev-parse HEAD)" == "$o" ]] || converged=0
done
check "all repos converged"         [ "$converged" -eq 1 ]

# --- Same-repo divergence, non-conflicting (different files).
echo a > m1/x/from-m1.txt
must git -C m1/x add -A; must git -C m1/x commit -qm "m1 diverge"; must git -C m1/x push -q
echo b > m2/x/from-m2.txt
must git -C m2/x add -A; must git -C m2/x commit -qm "m2 diverge"
REPOS_DESKTOP=("${M2[@]}")
out="$(gstatall -f)"
check "m2 sees x DIVERGED"          contains "$(row "$out" x)" "DIVERGED"
out="$(gpushall)"
check "diverged: rebase+push clean" contains "$out" "x: pushed 1 commit(s)"
check "diverged: both commits kept" bash -c "git -C '$SANDBOX/m2/x' log --format=%s | grep -q 'm1 diverge' && git -C '$SANDBOX/m2/x' log --format=%s | grep -q 'm2 diverge'"
REPOS_DESKTOP=("${M1[@]}")
out="$(gpullall)"
check "m1 picks up merged history"  contains "$out" "x: updated"
check "m1 has m2's file"            [ -f "$SANDBOX/m1/x/from-m2.txt" ]

# --- Same-repo divergence, conflicting (same line of same file).
echo m1-version > m1/y/clash.txt
must git -C m1/y add -A; must git -C m1/y commit -qm "m1 clash"; must git -C m1/y push -q
echo m2-version > m2/y/clash.txt
must git -C m2/y add -A; must git -C m2/y commit -qm "m2 clash"
REPOS_DESKTOP=("${M2[@]}")
out="$(gpushall)"; rc=$?
check "conflict: gpushall rc=1"     [ "$rc" -eq 1 ]
check "conflict: counters"          contains "$out" "ok: 1  skipped: 0  failed: 1  pending: 0"
check "conflict: reported+aborted"  contains "$out" "y: rebase conflict"
check "conflict: named in summary"  contains "$out" "needs attention: y"
check "conflict: y left clean"      bash -c "cd '$SANDBOX/m2/y' && git status --porcelain | wc -l | grep -qx 0"
check "conflict: m2 commit intact"  bash -c "git -C '$SANDBOX/m2/y' log --format=%s | head -1 | grep -q 'm2 clash'"
check "conflict: x still synced ok" contains "$out" "x: up to date"

# --- Composed STATE verdicts: dirty work never elided by a sync verdict.
echo more > m1/x/more.txt
must git -C m1/x add -A; must git -C m1/x commit -qm more; must git -C m1/x push -q
echo wip > m2/x/wip.txt        # untracked scratch on m2 -> dirty + behind
echo wip > m2/y/wip.txt        # y is still diverged from the conflict test
REPOS_DESKTOP=("${M2[@]}")
out="$(gstatall -f)"
check "compose: dirty+behind"       contains "$(row "$out" x)" "uncommitted; needs pull"
check "compose: dirty+diverged"     contains "$(row "$out" y)" "uncommitted; DIVERGED"

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
