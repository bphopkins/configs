#!/usr/bin/env bash
# Exercise the interactive vet prompt under a real pseudo-terminal (script(1)),
# which no other suite touches: [[ -t 0 ]] is true, so read -p actually runs.
set -u
SB="$(mktemp -d "${TMPDIR:-/tmp}/gsync-tty.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }

cd "$SB"
git init -q --bare -b main origin.git
git clone -q origin.git work 2>/dev/null
echo base > work/base.txt
git -C work add -A && git -C work commit -qm base && git -C work push -qu origin main 2>/dev/null

# The role helper reads configs/git/hosts/$(uname -n).inc (2026-10-10); a
# hostname with no host file keeps the driver a writer on either machine.
mkdir -p "$SB/stub"
printf '#!/bin/sh\necho gsync-suite\n' > "$SB/stub/uname"
chmod +x "$SB/stub/uname"
cat > driver.sh <<EOF
PATH="$SB/stub:\$PATH"
source "$CFG_ROOT/bash/.bashrc.d/50-git-sync.sh"
_GSYNC_ONLINE_CACHE=1
_gsync_push_repo T "\$1" "tty test"
EOF

ptyrun() { # run "bash driver.sh <repo>" under a pty, feeding $1 as stdin;
  # rc propagates via pty.spawn -> sys.exit, so callers can assert it. The
  # spawn returns a raw wait status, which sys.exit would fold to 0 for any
  # exit code (1 is status 256; found 2026-10-10 when a refusal's rc=1 read
  # as 0), so it is converted first.
  printf '%s' "$1" | python3 -c "import os,pty,sys; sys.exit(os.waitstatus_to_exitcode(pty.spawn(['bash','driver.sh','$SB/work'])))" 2>&1
}

# --- Answer y: the flagged file is committed and listed.
echo secret > work/cert.pem
out="$(ptyrun $'y\n')"; rc=$?
check "y: rc=0"                    [ "$rc" -eq 0 ]
check "prompt was shown"           contains "$out" "commit it? [y/N]"
check "y: flagged reason shown"    contains "$out" "matches secrets pattern '*.pem'"
check "y: file committed"          bash -c "git -C '$SB/work' ls-files --error-unmatch cert.pem >/dev/null 2>&1"
check "y: file in new-list"        contains "$out" "new: cert.pem"
check "y: colorized (tty)"         contains "$out" "$(printf '\e[33m')"

# --- Answer Enter (default N): flagged file left behind, rest committed.
echo secret > work/.env
echo normal > work/normal.txt
out="$(ptyrun $'\n')"; rc=$?
check "N: rc=0"                    [ "$rc" -eq 0 ]
check "N: left uncommitted"        contains "$out" "left uncommitted: .env"
check "N: .env not tracked"        bash -c "! git -C '$SB/work' ls-files --error-unmatch .env >/dev/null 2>&1"
check "N: .env still on disk"      [ -f "$SB/work/.env" ]
check "N: normal.txt committed"    bash -c "git -C '$SB/work' ls-files --error-unmatch normal.txt >/dev/null 2>&1"
check "N: pushed"                  contains "$out" "committed 1 path(s); pushed"

# --- Mixed answers: two flagged files, y then N.
rm work/.env   # still on disk from the decline test; would add a third prompt
echo k1 > work/one.pem
echo k2 > work/two.pem
out="$(ptyrun $'y\nn\n')"; rc=$?
check "mixed: rc=0"                [ "$rc" -eq 0 ]
check "mixed: one committed"       bash -c "git -C '$SB/work' ls-files --error-unmatch one.pem >/dev/null 2>&1"
check "mixed: two left behind"     bash -c "! git -C '$SB/work' ls-files --error-unmatch two.pem >/dev/null 2>&1"
check "mixed: drop named"          contains "$out" "left uncommitted: two.pem"

# --- A Syncthing conflict copy on a tty (2026-10-10, ws-5): refused outright,
# no y/N prompt for it or for the flagged file beside it, nothing committed.
rm work/two.pem
echo theirs > work/notes.sync-conflict-20261009-160110-GE3DRZ3.txt
echo k3 > work/three.pem
out="$(ptyrun $'y\n')"; rc=$?
check "copy: rc=1"                 [ "$rc" -eq 1 ]
check "copy: refused"              contains "$out" "Syncthing conflict copy"
check "copy: no prompt shown"      lacks "$out" "commit it? [y/N]"
check "copy: not committed"        bash -c "! git -C '$SB/work' ls-files --error-unmatch notes.sync-conflict-20261009-160110-GE3DRZ3.txt >/dev/null 2>&1"
check "copy: the pem beside it not committed" bash -c "! git -C '$SB/work' ls-files --error-unmatch three.pem >/dev/null 2>&1"
check "copy: neither left staged"  [ -z "$(git -C "$SB/work" diff --cached --name-only)" ]
check "copy: both still on disk"   bash -c "[ -f '$SB/work/three.pem' ] && [ -f '$SB/work/notes.sync-conflict-20261009-160110-GE3DRZ3.txt' ]"

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
