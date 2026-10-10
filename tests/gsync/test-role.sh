#!/usr/bin/env bash
# The machine's role and the conflict-copy refusal in 50-git-sync.sh
# (org/machines/transport-2026-10: rules.md fedxps-2 and ws-5; written
# 2026-10-10 at the pilot's step 3a, for its preconditions P2 and P5).
#
# Sandboxed: a fake HOME whose Desktop holds clones of local bare origins and
# whose configs/git/hosts/ holds fixture host files. The hostname the sync
# commands read comes from a `uname` stub first on PATH, so the suite names
# the machine it pretends to be, and no link ~/.config/git/host.inc exists
# anywhere in it -- the refusals must come from the file alone. Git identity
# from the environment; no global config read. No network.
set -u
SB="$(mktemp -d "${TMPDIR:-/tmp}/gsync-role.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$CFG_ROOT/bash/.bashrc.d/50-git-sync.sh"
_gsync_online() { return 0; }   # local-path remotes; no real network involved

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
must() { "$@" || { echo "SETUP-FAIL: $*"; exit 1; }; }
count() { grep -c -- "$2" <<<"$1"; } # count TEXT NEEDLE -> lines containing NEEDLE
row() { grep -E "^$2 " <<<"$1"; }    # row OUTPUT REPO -> the dashboard line for REPO

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export HOME="$SB/home"   # the sync commands and the role helper key on $HOME
HOSTS="$HOME/Desktop/configs/git/hosts"
mkdir -p "$HOSTS" "$SB/stub"
printf '#!/bin/sh\ncat "%s/host"\n' "$SB" > "$SB/stub/uname"
chmod +x "$SB/stub/uname"
# The push gauge (bigfed-2, 2026-10-10), stubbed: it records every call with
# whether anything was staged when it ran, and answers for a repository from
# STUB_GAUGE_<name> as "rc:text" (default: pass in silence). Section 5 drives it;
# every other section needs it to pass.
cat > "$SB/stub/sync-check" <<'EOF'
#!/usr/bin/env bash
repo="${@: -1}"; name="$(basename "$repo")"
staged=clean; git -C "$repo" diff --cached --quiet 2>/dev/null || staged=staged
printf '%s %s %s\n' "$name" "$staged" "$*" >> "${STUB_GAUGE_LOG:-/dev/null}"
var="STUB_GAUGE_${name//[^A-Za-z0-9]/_}"; spec="${!var:-0:}"
rc="${spec%%:*}"; text="${spec#*:}"
[ -n "$text" ] && printf '%s\n' "$text"
exit "$rc"
EOF
chmod +x "$SB/stub/sync-check"
export STUB_GAUGE_LOG="$SB/gauge.log"
PATH="$SB/stub:$PATH"
hash -r
be() { printf '%s\n' "$1" > "$SB/host"; _GSYNC_ROLE=""; } # become hostname $1
hostfile() { printf '%b' "$2" > "$HOSTS/$1.inc"; _GSYNC_ROLE=""; }
# Every entry under .git by path, inode, mtime and size -- the index included:
# a plain `git status` rewrites a fresh clone's index once (racy entries), and
# gstatall passes --no-optional-locks for the rows this machine reads, so a
# reader repository's whole .git must come through gstatall untouched even
# with no GIT_OPTIONAL_LOCKS in this suite's environment.
gitsnap() { find "$1/.git" -printf '%p %i %T@ %s\n' | sort | md5sum; }
head_of() { git -C "$1" rev-parse HEAD; }
mkpair() { # mkpair NAME -> bare origin-NAME.git, clone ~/Desktop/NAME, a sibling clone peer-NAME
  must git init -q --bare -b main "$SB/origin-$1.git"
  must git clone -q "$SB/origin-$1.git" "$HOME/Desktop/$1"
  echo base > "$HOME/Desktop/$1/base.txt"
  must git -C "$HOME/Desktop/$1" add -A
  must git -C "$HOME/Desktop/$1" commit -qm base
  must git -C "$HOME/Desktop/$1" push -qu origin main
  must git clone -q "$SB/origin-$1.git" "$SB/peer-$1"
}
peer_commit() { # peer_commit NAME -> origin-NAME gains one commit from the sibling clone
  must git -C "$SB/peer-$1" pull -q --rebase
  echo "peer $RANDOM" >> "$SB/peer-$1/peer.txt"
  must git -C "$SB/peer-$1" add -A
  must git -C "$SB/peer-$1" commit -qm "peer edit"
  must git -C "$SB/peer-$1" push -q
}
mkpair nousowl
mkpair org
REPOS_DESKTOP=("$HOME/Desktop/org" "$HOME/Desktop/nousowl")
N="$HOME/Desktop/nousowl" O="$HOME/Desktop/org"

# --- 1. the pilot: fedxps writes every repository but nousowl ---------------
echo "== fedxps, readerRepo = nousowl =="
be fedxps
hostfile fedxps '[gsync]\n\treaderRepo = nousowl\n'
peer_commit nousowl            # origin ahead: a pull would move HEAD
echo local > "$N/local.txt"    # a new file: a push would commit
echo local > "$O/local.txt"
snapN="$(gitsnap "$N")"; headN="$(head_of "$N")"
out="$(gpush nousowl)"; rc=$?
check "gpush nousowl: rc=1 (a named repo's skip is a failure)" [ "$rc" -eq 1 ]
check "gpush nousowl: refused, one line"               [ "$(count "$out" 'nousowl: refused')" -eq 1 ]
check "gpush nousowl: names the hostname"              contains "$out" "fedxps reads this repository"
check "gpush nousowl: names him-5 with a clone command" contains "$out" "git clone $SB/origin-nousowl.git ~/src/outage/nousowl"
check "gpush nousowl: nothing pushed"                  lacks "$out" "pushed"
check "gpush nousowl: origin unchanged"                [ "$(git -C "$SB/origin-nousowl.git" rev-list --count main)" -eq 2 ]
check "gpush nousowl: HEAD unchanged"                  [ "$(head_of "$N")" = "$headN" ]
check "gpush nousowl: nothing under .git changed"      [ "$(gitsnap "$N")" = "$snapN" ]
check "gpush nousowl: the new file is still untracked" bash -c "! git -C '$N' ls-files --error-unmatch local.txt >/dev/null 2>&1"
out="$(gpull nousowl)"; rc=$?
check "gpull nousowl: rc=1"                            [ "$rc" -eq 1 ]
check "gpull nousowl: refused"                         contains "$out" "nousowl: refused"
check "gpull nousowl: HEAD unchanged (origin is ahead)" [ "$(head_of "$N")" = "$headN" ]
check "gpull nousowl: nothing under .git changed"      [ "$(gitsnap "$N")" = "$snapN" ]
out="$(gpushall)"; rc=$?
check "gpushall: rc=0 (a skip is benign)"              [ "$rc" -eq 0 ]
check "gpushall: counters"                             contains "$out" "ok: 1  skipped: 1  failed: 0  pending: 0"
check "gpushall: nousowl skipped with one line"        [ "$(count "$out" 'nousowl: refused')" -eq 1 ]
check "gpushall: nousowl in the skipped list"          contains "$out" "skipped: nousowl"
check "gpushall: org carried"                          contains "$out" "org: committed 1 path(s); pushed"
check "gpushall: nousowl's .git untouched"             [ "$(gitsnap "$N")" = "$snapN" ]
peer_commit org
out="$(gpullall)"; rc=$?
check "gpullall: rc=0"                                 [ "$rc" -eq 0 ]
check "gpullall: counters"                             contains "$out" "ok: 1  skipped: 1  failed: 0"
check "gpullall: nousowl skipped with one line"        [ "$(count "$out" 'nousowl: refused')" -eq 1 ]
check "gpullall: org updated"                          contains "$out" "org: updated"
check "gpullall: nousowl HEAD unchanged"               [ "$(head_of "$N")" = "$headN" ]
check "gpullall: nousowl's .git untouched"             [ "$(gitsnap "$N")" = "$snapN" ]
peer_commit org                # both origins ahead again
out="$(gstatall -f)"; rc=$?
check "gstatall -f: rc=0"                              [ "$rc" -eq 0 ]
check "gstatall -f: org fetched, needs pull"           contains "$(row "$out" org)" "needs pull"
check "gstatall -f: nousowl marked reader"             contains "$(row "$out" nousowl)" "reader"
check "gstatall -f: nousowl not fetched (BEHIND still 0)" contains "$(row "$out" nousowl)" "      0      0  reader"
check "gstatall -f: nousowl's whole .git untouched (no fetch, no index write)" [ "$(gitsnap "$N")" = "$snapN" ]
check "gstatall -f: footer says fetched, reader rows excepted (1/2)" contains "$out" "(fetched"
check "gstatall -f: footer says fetched, reader rows excepted (2/2)" contains "$out" "except rows marked reader"
out="$(gstatall)"; rc=$?
check "gstatall: plain run rc=0"                       [ "$rc" -eq 0 ]
check "gstatall: both rows present (1/2)" [ -n "$(row "$out" org)" ]
check "gstatall: both rows present (2/2)" [ -n "$(row "$out" nousowl)" ]
check "gstatall: org row not marked reader"            lacks "$(row "$out" org)" "reader"
check "gstatall: nousowl's whole .git untouched by the plain run" [ "$(gitsnap "$N")" = "$snapN" ]
# every spelling of the name reaches the same .git, so every spelling is refused
for spelling in nousowl/ ./nousowl ../Desktop/nousowl; do
  out="$(gpush "$spelling")"; rc=$?
  check "gpush $spelling: refused by canonical path (1/3)" [ "$rc" -eq 1 ]
  check "gpush $spelling: refused by canonical path (2/3)" contains "$out" "refused"
  check "gpush $spelling: refused by canonical path (3/3)" lacks "$out" "pushed"
done
out="$(gpull nousowl/)"; rc=$?
check "gpull nousowl/: refused (1/2)" [ "$rc" -eq 1 ]
check "gpull nousowl/: refused (2/2)" contains "$out" "refused"
mkdir -p "$N/sub"
out="$(gpush nousowl/sub)"; rc=$?
check "gpush nousowl/sub: a name inside the repository is refused (1/2)" [ "$rc" -eq 1 ]
check "gpush nousowl/sub: a name inside the repository is refused (2/2)" contains "$out" "refused"
out="$(gpull nousowl/sub)"; rc=$?
check "gpull nousowl/sub: refused" contains "$out" "refused"
ln -s nousowl "$HOME/Desktop/nlink"
out="$(gpush nlink)"; rc=$?
check "gpush nlink (a symlink to it): refused (1/2)" [ "$rc" -eq 1 ]
check "gpush nlink (a symlink to it): refused (2/2)" contains "$out" "refused"
rm "$HOME/Desktop/nlink"
rmdir "$N/sub"
check "spellings: nousowl's .git still untouched"      [ "$(gitsnap "$N")" = "$snapN" ]
check "spellings: origin still at 2 commits"           [ "$(git -C "$SB/origin-nousowl.git" rev-list --count main)" -eq 2 ]
# the key's value is canonicalised the same way
hostfile fedxps '[gsync]\n\treaderRepo = nousowl/\n'
out="$(gpush nousowl)"; rc=$?
check "readerRepo = nousowl/ (trailing slash): refuses (1/2)" [ "$rc" -eq 1 ]
check "readerRepo = nousowl/ (trailing slash): refuses (2/2)" contains "$out" "refused"
# a value that names no repository of the rotation refuses nothing and is warned about
for bad in Nousowl nousowl/.git . ; do
  hostfile fedxps "[gsync]\n\treaderRepo = $bad\n"
  out="$(gstatall)"; rc=$?
  check "readerRepo = $bad (no rotation repository): warned" contains "$out" "readerRepo '$bad' names no repository of REPOS_DESKTOP"
  check "readerRepo = $bad: nousowl row not a reader"  lacks "$(row "$out" nousowl)" "reader"
done
hostfile fedxps '[gsync]\n\treaderRepo = nousowl\n'
# a second readerRepo line is honoured too
hostfile fedxps '[gsync]\n\treaderRepo = nousowl\n\treaderRepo = org\n'
out="$(gpushall)"; rc=$?
check "two readerRepo keys: both refused"              contains "$out" "ok: 0  skipped: 2"
must git -C "$O" pull -q --rebase                      # catch org up for the sections below
rm -f "$N/local.txt"

# --- 2. the cutover: fedxps reads every repository ---------------------------
echo "== fedxps, role = reader (no link exists anywhere in this sandbox) =="
be fedxps
hostfile fedxps '[gsync]\n\trole = reader\n'
peer_commit nousowl; peer_commit org
echo local > "$O/local2.txt"
snapN="$(gitsnap "$N")"; snapO="$(gitsnap "$O")"
out="$(gpushall)"; rc=$?
check "gpushall: rc=1"                                 [ "$rc" -eq 1 ]
check "gpushall: one line, naming the reader"          contains "$out" "fedxps is a reader — nothing pushed"
check "gpushall: names the route from here"            contains "$out" "ssh -t bigfed 'bash -ic gpushall'"
check "gpushall: no per-repo lines"                    lacks "$out" "org:"
check "gpushall: no summary line"                      lacks "$out" "Push complete"
check "gpushall: nousowl's .git untouched"             [ "$(gitsnap "$N")" = "$snapN" ]
check "gpushall: org's .git untouched"                 [ "$(gitsnap "$O")" = "$snapO" ]
out="$(gpullall)"; rc=$?
check "gpullall: rc=1"                                 [ "$rc" -eq 1 ]
check "gpullall: one line, naming the reader"          contains "$out" "fedxps is a reader — nothing pulled"
check "gpullall: nothing under either .git changed (1/2)" [ "$(gitsnap "$N")" = "$snapN" ]
check "gpullall: nothing under either .git changed (2/2)" [ "$(gitsnap "$O")" = "$snapO" ]
out="$(gpush org)"; rc=$?
check "gpush org: rc=1, refused (1/2)" [ "$rc" -eq 1 ]
check "gpush org: rc=1, refused (2/2)" contains "$out" "org: refused"
out="$(gpull nousowl)"; rc=$?
check "gpull nousowl: rc=1, refused (1/2)" [ "$rc" -eq 1 ]
check "gpull nousowl: rc=1, refused (2/2)" contains "$out" "nousowl: refused"
out="$(gstatall -f)"; rc=$?
check "gstatall -f: rc=0, warns, fetches nothing (1/2)" [ "$rc" -eq 0 ]
check "gstatall -f: rc=0, warns, fetches nothing (2/2)" contains "$out" "fedxps is a reader — nothing fetched"
check "gstatall -f: rows still shown (1/2)" [ -n "$(row "$out" org)" ]
check "gstatall -f: rows still shown (2/2)" [ -n "$(row "$out" nousowl)" ]
check "gstatall -f: every row marked reader (1/2)" contains "$(row "$out" org)" "reader"
check "gstatall -f: every row marked reader (2/2)" contains "$(row "$out" nousowl)" "reader"
check "gstatall -f: both .git untouched, index included (1/2)" [ "$(gitsnap "$N")" = "$snapN" ]
check "gstatall -f: both .git untouched, index included (2/2)" [ "$(gitsnap "$O")" = "$snapO" ]
check "gstatall -f: the refusal names him-5"           contains "$out" "him-5"
check "gstatall -f: footer names the reader"           contains "$out" "a reader fetches nothing"
out="$(gstatall)"; rc=$?
check "gstatall: plain run rc=0 with rows (1/2)" [ "$rc" -eq 0 ]
check "gstatall: plain run rc=0 with rows (2/2)" [ -n "$(row "$out" org)" ]
check "gstatall: dirty work still shown"               contains "$(row "$out" org)" "uncommitted"
# every entry point reads the role afresh: a stale value in the shell from an
# earlier run (here: planted) must not survive into the next command
refusal() { [[ "$1" == *"refused"* || "$1" == *"is a reader"* ]]; }
for cmd in gpushall gpullall "gpush org" "gpull nousowl" "gstatall -f"; do
  _GSYNC_ROLE=writer
  out="$($cmd)"; rc=$?
  check "stale _GSYNC_ROLE=writer in the shell: $cmd still refuses" refusal "$out"
done
_GSYNC_ROLE=""
# a host file git cannot parse is not "no role": a reader, with a warning
hostfile fedxps '[core]\n\tcheck_stat = minimal\n[gsync]\n\trole = reader\n'
out="$(gpushall)"; rc=$?
check "malformed host file: refused (fails safe) (1/2)" [ "$rc" -eq 1 ]
check "malformed host file: refused (fails safe) (2/2)" contains "$out" "is a reader"
check "malformed host file: warned, naming the exit"   contains "$out" "unreadable by git (exit 128)"
check "malformed host file: nothing under either .git changed (1/2)" [ "$(gitsnap "$N")" = "$snapN" ]
check "malformed host file: nothing under either .git changed (2/2)" [ "$(gitsnap "$O")" = "$snapO" ]
# the role is read wherever the command is typed, a dangling .git file included
hostfile fedxps '[gsync]\n\trole = reader\n'
mkdir -p "$SB/dangling"; echo "gitdir: $SB/nowhere" > "$SB/dangling/.git"
out="$(cd "$SB/dangling" && gpushall)"; rc=$?
check "typed in a directory with a dangling .git file: still refused (1/2)" [ "$rc" -eq 1 ]
check "typed in a directory with a dangling .git file: still refused (2/2)" contains "$out" "is a reader"
# a host file this user cannot read: a reader too
chmod 000 "$HOSTS/fedxps.inc"; _GSYNC_ROLE=""
out="$(gpushall)"; rc=$?
check "unreadable host file: refused (fails safe) (1/2)" [ "$rc" -eq 1 ]
check "unreadable host file: refused (fails safe) (2/2)" contains "$out" "is a reader"
check "unreadable host file: warned"                   contains "$out" "cannot be read"
chmod 644 "$HOSTS/fedxps.inc"
# the hostname is read short and lowercased: an FQDN or a case difference still finds the file
hostfile fedxps '[gsync]\n\trole = reader\n'
for h in FEDXPS fedxps.lan Fedxps "fedxps "; do
  be "$h"
  out="$(gpushall)"; rc=$?
  check "hostname '$h': still fedxps's file, refused" contains "$out" "is a reader"
done
be fedxps
# a repeated role: any non-writer value makes a reader, whatever comes last
hostfile fedxps '[gsync]\n\trole = reader\n\trole = writer\n'
out="$(gpushall)"; rc=$?
check "role = reader then role = writer: reader" contains "$out" "is a reader"
# a role reached through an [include] inside the host file counts, as for git
printf '[gsync]\n\trole = reader\n' > "$HOSTS/extra.inc"
hostfile fedxps '[include]\n\tpath = extra.inc\n'
out="$(gpushall)"; rc=$?
check "role through an include in the host file: reader" contains "$out" "is a reader"
rm "$HOSTS/extra.inc"
# a directory where the host file should be: unreadable, a reader
rm "$HOSTS/fedxps.inc"; mkdir "$HOSTS/fedxps.inc"; _GSYNC_ROLE=""
out="$(gpushall)"; rc=$?
check "a directory as the host file: refused (fails safe)" contains "$out" "is a reader"
rmdir "$HOSTS/fedxps.inc"
# the second source: the file ~/.config/git/host.inc points at, which git reads
hostfile fedxps '[gsync]\n\trole = reader\n'
mkdir -p "$HOME/.config/git"
ln -s ../../Desktop/configs/git/hosts/fedxps.inc "$HOME/.config/git/host.inc"
be stranger
out="$(gpushall)"; rc=$?
check "hostname with no file, link to a reader file: refused (1/2)" [ "$rc" -eq 1 ]
check "hostname with no file, link to a reader file: refused (2/2)" contains "$out" "is a reader"
check "link and hostname disagree: warned" contains "$out" "names fedxps.inc but this machine is stranger"
ln -sfn /nowhere "$HOME/.config/git/host.inc"; _GSYNC_ROLE=""
out="$(gpushall)"; rc=$?
check "a dangling host link: refused (fails safe) (1/2)" contains "$out" "is a reader"
check "a dangling host link: refused (fails safe) (2/2)" contains "$out" "dangling"
rm "$HOME/.config/git/host.inc"
be fedxps
# a strict-mode IFS in the calling shell must not stop the keys from parsing
out="$(IFS=$'\n\t'; gpushall)"; rc=$?
check "IFS without a space: still refused" contains "$out" "is a reader"
out="$(gpullall)"
check "gpullall's refusal names gpullall, not gpushall" contains "$out" "gpullall there"
# a typo in the role, or an empty role, fails on the safe side
hostfile fedxps '[gsync]\n\trole = readr\n'
out="$(gpushall)"; rc=$?
check "role = readr: reader (fails safe) (1/2)" [ "$rc" -eq 1 ]
check "role = readr: reader (fails safe) (2/2)" contains "$out" "is a reader"
hostfile fedxps '[gsync]\n\trole =\n'
out="$(gpushall)"; rc=$?
check "role empty: reader (fails safe) (1/2)" [ "$rc" -eq 1 ]
check "role empty: reader (fails safe) (2/2)" contains "$out" "is a reader"
rm -f "$O/local2.txt"

# --- 3. the writer, and a stranger ------------------------------------------
echo "== bigfed, role = writer; a hostname with no host file =="
be bigfed
hostfile bigfed '[gsync]\n\trole = writer\n[maintenance]\n\tautoDetach = false\n'
out="$(gpullall)"; rc=$?
check "bigfed gpullall: rc=0, both pulled (1/2)" [ "$rc" -eq 0 ]
check "bigfed gpullall: rc=0, both pulled (2/2)" contains "$out" "ok: 2  skipped: 0"
check "bigfed gpullall: nousowl updated"               contains "$out" "nousowl: updated"
echo w > "$O/w.txt"
out="$(gpushall)"; rc=$?
check "bigfed gpushall: rc=0"                          [ "$rc" -eq 0 ]
check "bigfed gpushall: org pushed"                    contains "$out" "org: committed 1 path(s); pushed"
check "bigfed gpushall: no refusal (1/2)" lacks "$out" "refused"
check "bigfed gpushall: no refusal (2/2)" lacks "$out" "reader"
peer_commit nousowl
out="$(gstatall -f)"
check "bigfed gstatall -f: fetches (1/2)" contains "$(row "$out" nousowl)" "needs pull"
check "bigfed gstatall -f: fetches (2/2)" contains "$out" "(fetched"
check "bigfed gstatall -f: no reader marks"            lacks "$out" "reader"
be stranger
echo s > "$O/s.txt"
out="$(gpushall)"; rc=$?
check "stranger (no host file): a writer (1/2)" [ "$rc" -eq 0 ]
check "stranger (no host file): a writer (2/2)" contains "$out" "org: committed 1 path(s); pushed"
peer_commit nousowl
out="$(gpull nousowl)"; rc=$?
check "stranger: gpull works (1/2)" [ "$rc" -eq 0 ]
check "stranger: gpull works (2/2)" contains "$out" "nousowl: updated"
# the host file is keyed on the hostname: fedxps's file does not bind bigfed
hostfile fedxps '[gsync]\n\trole = reader\n'
be bigfed
echo b > "$O/b.txt"
out="$(gpushall)"; rc=$?
check "fedxps's reader file leaves bigfed a writer (1/2)" [ "$rc" -eq 0 ]
check "fedxps's reader file leaves bigfed a writer (2/2)" contains "$out" "org: committed 1 path(s); pushed"

# --- 4. ws-5: a conflict copy refuses the repository's push -----------------
echo "== a Syncthing conflict copy among the new paths =="
be bigfed
mkdir -p "$O/sub"
echo theirs > "$O/notes.sync-conflict-20261009-160110-GE3DRZ3.txt"
echo theirs > "$O/sub/x.sync-conflict-20261009-160110-GE3DRZ3.md"
echo mine >> "$O/base.txt"                       # an innocent edit beside them
echo plain > "$O/conflict-notes.txt"             # the word alone is not the pattern
headO="$(head_of "$O")"; before="$(git -C "$SB/origin-org.git" rev-parse main)"
out="$(gpush org)"; rc=$?
check "conflict copy: rc=1"                            [ "$rc" -eq 1 ]
check "conflict copy: FAIL names the rule and the remedy (1/2)" contains "$out" "Syncthing conflict copy"
check "conflict copy: FAIL names the rule and the remedy (2/2)" contains "$out" "ws-5, him-2"
check "conflict copy: both copies listed (1/2)" contains "$out" "notes.sync-conflict-20261009-160110-GE3DRZ3.txt"
check "conflict copy: both copies listed (2/2)" contains "$out" "sub/x.sync-conflict-20261009-160110-GE3DRZ3.md"
check "conflict copy: no prompt offered"               lacks "$out" "commit it?"
check "conflict copy: nothing committed"               [ "$(head_of "$O")" = "$headO" ]
check "conflict copy: origin unchanged"                [ "$(git -C "$SB/origin-org.git" rev-parse main)" = "$before" ]
check "conflict copy: copies still on disk (1/2)" [ -f "$O/notes.sync-conflict-20261009-160110-GE3DRZ3.txt" ]
check "conflict copy: copies still on disk (2/2)" [ -f "$O/sub/x.sync-conflict-20261009-160110-GE3DRZ3.md" ]
check "conflict copy: copies unstaged after the refusal" [ -z "$(git -C "$O" diff --cached --name-only | grep sync-conflict)" ]
check "conflict copy: the innocent edit stays staged"  bash -c "git -C '$O' diff --cached --name-only | grep -qx base.txt"
git -C "$O" commit -qm "a commit by another route" 2>/dev/null
check "conflict copy: a hand commit after the refusal carries no copy" [ -z "$(git -C "$O" show --name-only --format= HEAD | grep sync-conflict)" ]
out="$(gpushall)"; rc=$?
check "conflict copy: gpushall refuses org too (1/2)" [ "$rc" -eq 1 ]
check "conflict copy: gpushall refuses org too (2/2)" contains "$out" "needs attention: org"
check "conflict copy: gpushall still carries nousowl"  contains "$out" "nousowl: up to date"
rm "$O/notes.sync-conflict-20261009-160110-GE3DRZ3.txt" "$O/sub/x.sync-conflict-20261009-160110-GE3DRZ3.md"
# an extensionless copy, as Syncthing names a file with no extension
echo theirs > "$O/Makefile.sync-conflict-20261009-160110-GE3DRZ3"
out="$(gpush org)"; rc=$?
check "extensionless copy: refused (1/2)" [ "$rc" -eq 1 ]
check "extensionless copy: refused (2/2)" contains "$out" "Makefile.sync-conflict-20261009-160110-GE3DRZ3"
rm "$O/Makefile.sync-conflict-20261009-160110-GE3DRZ3"
# a tracked file renamed into a copy's name (a 100% rename, which rename detection would hide)
headO="$(head_of "$O")"
must git -C "$O" mv conflict-notes.txt conflict-notes.sync-conflict-20261009-160110-GE3DRZ3.txt
out="$(gpush org)"; rc=$?
check "a rename into a copy's name: refused (1/2)" [ "$rc" -eq 1 ]
check "a rename into a copy's name: refused (2/2)" contains "$out" "conflict-notes.sync-conflict-20261009-160110-GE3DRZ3.txt"
check "a rename into a copy's name: nothing committed" [ "$(head_of "$O")" = "$headO" ]
# the refusal unstaged the new name, so it is an untracked copy now: remove it
# with the rest of the rename, and put the plain file back for the end
git -C "$O" reset -q --hard origin/main
rm -f "$O/conflict-notes.sync-conflict-20261009-160110-GE3DRZ3.txt"
echo plain > "$O/conflict-notes.txt"
# a copy beside a secret and an oversize file: the refusal unstages those too, with no prompt
echo theirs > "$O/notes.sync-conflict-20261009-160110-GE3DRZ3.txt"
echo key > "$O/id_rsa"
truncate -s 30M "$O/data.bin"
echo mine2 >> "$O/base.txt"
out="$(gpush org)"; rc=$?
check "copy beside a secret: refused" [ "$rc" -eq 1 ]
check "copy beside a secret: the secret named as left unstaged" contains "$out" "also left unstaged, unvetted:"
check "copy beside a secret: id_rsa in that line" bash -c "grep -F 'also left unstaged' <<<\"\$1\" | grep -q id_rsa" _ "$out"
check "copy beside a secret: data.bin in that line" bash -c "grep -F 'also left unstaged' <<<\"\$1\" | grep -q data.bin" _ "$out"
check "copy beside a secret: nothing of the three staged" [ -z "$(git -C "$O" diff --cached --name-only | grep -E 'sync-conflict|id_rsa|data.bin')" ]
check "copy beside a secret: the innocent edit stays staged" bash -c "git -C '$O' diff --cached --name-only | grep -qx base.txt"
git -C "$O" commit -qam "a commit by another route" 2>/dev/null
check "copy beside a secret: a hand commit -am afterwards carries none of the three" [ -z "$(git -C "$O" show --name-only --format= HEAD | grep -E 'sync-conflict|id_rsa|data.bin')" ]
rm "$O/notes.sync-conflict-20261009-160110-GE3DRZ3.txt" "$O/id_rsa" "$O/data.bin"
# a copy committed by another route, then edited: tracked copies refuse too
echo theirs > "$O/old.sync-conflict-20261009-160110-GE3DRZ3.txt"
must git -C "$O" add old.sync-conflict-20261009-160110-GE3DRZ3.txt
must git -C "$O" commit -qm "committed by hand"
out="$(gpush org)"; rc=$?
check "a tracked, unchanged copy: refused (1/2)" [ "$rc" -eq 1 ]
check "a tracked, unchanged copy: refused (2/2)" contains "$out" "old.sync-conflict-20261009-160110-GE3DRZ3.txt"
check "a tracked copy: the remedy names git rm" contains "$out" "git rm it"
check "a tracked copy: not pushed" [ "$(git -C "$SB/origin-org.git" rev-list --count main)" -lt "$(git -C "$O" rev-list --count HEAD)" ]
echo edited >> "$O/old.sync-conflict-20261009-160110-GE3DRZ3.txt"
out="$(gpushall)"; rc=$?
check "a tracked, modified copy: gpushall refuses org (1/2)" [ "$rc" -eq 1 ]
check "a tracked, modified copy: gpushall refuses org (2/2)" contains "$out" "needs attention: org"
check "a tracked, modified copy: the edit unstaged" [ -z "$(git -C "$O" diff --cached --name-only)" ]
check "a tracked, modified copy: gpushall still carries nousowl" contains "$out" "nousowl: up to date"
must git -C "$O" rm -qf old.sync-conflict-20261009-160110-GE3DRZ3.txt
out="$(gpush org)"; rc=$?
check "the tracked copy removed: push goes through (1/2)" [ "$rc" -eq 0 ]
check "the tracked copy removed: push goes through (2/2)" contains "$out" "pushed"
echo final > "$O/final.txt"
out="$(gpush org)"; rc=$?
check "copies removed: push goes through (1/2)" [ "$rc" -eq 0 ]
check "copies removed: push goes through (2/2)" contains "$out" "pushed"
check "copies removed: no copy left anywhere in the tree" [ -z "$(find "$O" -name '*.sync-conflict-*')" ]
check "copies removed: the innocent edit went"         bash -c "git -C '$SB/origin-org.git' show main:base.txt | grep -q mine"
check "copies removed: conflict-notes.txt went"        bash -c "git -C '$SB/origin-org.git' ls-tree --name-only main | grep -qx conflict-notes.txt"

# --- 5. the push gauge: a refusal skips the repository, the rest still pushes ---
echo "== bigfed, the push gauge refusing nousowl =="
be bigfed
hostfile bigfed '[gsync]\n\trole = writer\n'
git -C "$N" ls-files --error-unmatch local.txt >/dev/null 2>&1 && git -C "$N" rm -q --cached local.txt 2>/dev/null
echo new > "$N/gauge.txt"; echo new > "$O/gauge.txt"
: > "$STUB_GAUGE_LOG"
export STUB_GAUGE_nousowl='1:[FAIL] nousowl: stranded on fedxps: notes.txt'
snapN="$(gitsnap "$N")"
out="$(gpush nousowl)"; rc=$?
check "gpush nousowl: rc=1 (a named repo's skip is a failure)" [ "$rc" -eq 1 ]
check "gpush nousowl: the SKIP line names the gauge"  contains "$out" "nousowl: not pushed — the push gauge refused"
check "gpush nousowl: the gauge's own line is shown under it" contains "$out" "    [FAIL] nousowl: stranded on fedxps: notes.txt"
check "gpush nousowl: names bigfed-2"                 contains "$out" "bigfed-2"
check "gpush nousowl: nothing pushed"                 lacks "$out" "path(s); pushed"
check "gpush nousowl: nothing committed, the new file still untracked" bash -c "! git -C '$N' ls-files --error-unmatch gauge.txt >/dev/null 2>&1"
check "gpush nousowl: nothing under .git changed"      [ "$(gitsnap "$N")" = "$snapN" ]
check "gpush nousowl: the gauge ran before add -A (nothing staged)" contains "$(cat "$STUB_GAUGE_LOG")" "nousowl clean push -q -- $N"
check "gpush nousowl: the gauge was called with the repository's path" contains "$(cat "$STUB_GAUGE_LOG")" "-- $N"
out="$(gpushall)"; rc=$?
check "gpushall: rc=0 (a refusal is a skip, not a failure)" [ "$rc" -eq 0 ]
check "gpushall: counters"                             contains "$out" "ok: 1  skipped: 1  failed: 0  pending: 0"
check "gpushall: nousowl in the skipped list"          contains "$out" "skipped: nousowl"
check "gpushall: org carried"                          contains "$out" "org: committed 1 path(s); pushed"
check "gpushall: nousowl's .git untouched"             [ "$(gitsnap "$N")" = "$snapN" ]
check "gpushall: the gauge ran for org too, before its add -A" contains "$(cat "$STUB_GAUGE_LOG")" "org clean push -q -- $O"
export STUB_GAUGE_nousowl='2:[WARN] alpha: nousowl did not answer over ssh'
out="$(gpush nousowl)"; rc=$?
check "a cluster that cannot be read (exit 2): pushed, under a WARN (his word 2026-10-10) (1/4)" [ "$rc" -eq 0 ]
check "a cluster that cannot be read (exit 2): pushed, under a WARN (his word 2026-10-10) (2/4)" contains "$out" "the push gauge could not read the cluster — pushing this machine's own state"
check "a cluster that cannot be read (exit 2): pushed, under a WARN (his word 2026-10-10) (3/4)" contains "$out" "    [WARN] alpha: nousowl did not answer over ssh"
check "a cluster that cannot be read (exit 2): pushed, under a WARN (his word 2026-10-10) (4/4)" contains "$out" "nousowl: committed 1 path(s); pushed"
check "  the file is committed now"                   bash -c "git -C '$N' ls-files --error-unmatch gauge.txt >/dev/null 2>&1"
export STUB_GAUGE_nousowl='0:[ OK ] nousowl: folder nousowl up to date, nothing under .git needed, no phantom ref; HEAD equal on fedxps'
echo pass > "$N/pass.txt"
out="$(gpush nousowl)"; rc=$?
check "a pass with a line: the line is shown and the push goes through (1/3)" [ "$rc" -eq 0 ]
check "a pass with a line: the line is shown and the push goes through (2/3)" bash -c 'grep -qx "\[ OK \] nousowl: folder nousowl up to date.*" <<<"$1"' _ "$out"
check "a pass with a line: the line is shown and the push goes through (3/3)" contains "$out" "nousowl: committed 1 path(s); pushed"
unset STUB_GAUGE_nousowl
echo again > "$N/gauge.txt"
out="$(gpush nousowl)"; rc=$?
check "a silent pass (no folder): no gauge line, pushed (1/3)" [ "$rc" -eq 0 ]
check "a silent pass (no folder): no gauge line, pushed (2/3)" lacks "$out" "    ["
check "a silent pass (no folder): no gauge line, pushed (3/3)" contains "$out" "nousowl: committed 1 path(s); pushed"
# the gauge missing from PATH: one hint, and the push goes through
mkdir -p "$SB/stub-nogauge"; cp "$SB/stub/uname" "$SB/stub-nogauge/"
echo again2 > "$O/gauge.txt"
out="$(PATH="$SB/stub-nogauge:/usr/bin:/bin" gpushall)"; rc=$?
check "no gauge on PATH: rc=0, pushed"                 [ "$rc" -eq 0 ]
check "no gauge on PATH: one hint, naming stow-all"     [ "$(count "$out" 'sync-check is not on PATH')" -eq 1 ]
check "no gauge on PATH: the hint names bin/sync-check" contains "$out" "stow-all installs bin/sync-check"
check "no gauge on PATH: org pushed"                    contains "$out" "org: committed 1 path(s); pushed"
# ... except a repository with a Syncthing marker at its root or above it
mkdir -p "$N/.stfolder"; echo x > "$N/nogauge.txt"
out="$(PATH="$SB/stub-nogauge:/usr/bin:/bin" gpush nousowl)"; rc=$?
check "no gauge, a .stfolder at the repository's root: refused (1/3)" [ "$rc" -eq 1 ]
check "no gauge, a .stfolder at the repository's root: refused (2/3)" contains "$out" "lies in the Syncthing folder at $N"
check "no gauge, a .stfolder at the repository's root: refused (3/3)" bash -c "! git -C '$N' ls-files --error-unmatch nogauge.txt >/dev/null 2>&1"
rmdir "$N/.stfolder"; mkdir -p "$HOME/Desktop/.stfolder"
out="$(PATH="$SB/stub-nogauge:/usr/bin:/bin" gpushall)"; rc=$?
check "no gauge, a .stfolder above every repository: all skipped (1/2)" contains "$out" "ok: 0  skipped: 2"
check "no gauge, a .stfolder above every repository: all skipped (2/2)" contains "$out" "lies in the Syncthing folder at $HOME/Desktop"
rmdir "$HOME/Desktop/.stfolder"; rm -f "$N/nogauge.txt"
# a reader never reaches the gauge for a repository it reads: the refusal comes first
be fedxps
hostfile fedxps '[gsync]\n\treaderRepo = nousowl\n'
: > "$STUB_GAUGE_LOG"
export STUB_GAUGE_nousowl='0:[ OK ] should not be reached'
out="$(gpush nousowl)"
check "fedxps reading nousowl: refused before the gauge (1/2)" contains "$out" "nousowl: refused"
check "fedxps reading nousowl: refused before the gauge (2/2)" [ ! -s "$STUB_GAUGE_LOG" ]
unset STUB_GAUGE_nousowl
hostfile fedxps ''

# --- 6. the live contract: the checkout's own host files (read only) --------
echo "== the checkout's host files and include =="
F="$CFG_ROOT/git/hosts/fedxps.inc"; B="$CFG_ROOT/git/hosts/bigfed.inc"; C="$CFG_ROOT/git/config"
check "fedxps.inc: core.checkStat = minimal"           [ "$(git config -f "$F" --get core.checkStat)" = minimal ]
check "fedxps.inc: core.trustctime = false"            [ "$(git config -f "$F" --get core.trustctime)" = false ]
check "fedxps.inc: diff.autoRefreshIndex = false"      [ "$(git config -f "$F" --get diff.autoRefreshIndex)" = false ]
check "fedxps.inc: gc.auto = 0"                        [ "$(git config -f "$F" --get gc.auto)" = 0 ]
check "fedxps.inc: maintenance.auto = false"           [ "$(git config -f "$F" --get maintenance.auto)" = false ]
check "fedxps.inc: no writer role"                     [ "$(git config -f "$F" --get gsync.role)" != writer ]
check "bigfed.inc: gsync.role = writer"                [ "$(git config -f "$B" --get gsync.role)" = writer ]
check "bigfed.inc: maintenance.autoDetach = false"     [ "$(git config -f "$B" --get maintenance.autoDetach)" = false ]
check "bigfed.inc: keeps git's defaults (no reader setting)" [ -z "$(git config -f "$B" --get-regexp '^(core\.checkstat|core\.trustctime|diff\.autorefreshindex|gc\.auto|maintenance\.auto)$')" ]
check "bigfed.inc: no readerRepo"                      [ -z "$(git config -f "$B" --get-all gsync.readerRepo)" ]
check "git/config includes ~/.config/git/host.inc"     bash -c "git config -f '$C' --get-all include.path | grep -qx '~/.config/git/host.inc'"
check "git/config: the host include comes last"        [ "$(git config -f "$C" --get-all include.path | tail -1)" = "~/.config/git/host.inc" ]
# an armed readerRepo must name a repository of the rotation (a typo refuses nothing)
source "$CFG_ROOT/bash/.bashrc.d/50-git-sync.sh"   # the real REPOS_DESKTOP again
rot=" $(for r in "${REPOS_DESKTOP[@]}"; do basename "$r"; done | tr '\n' ' ') "
armed_ok=1
while read -r v; do [[ -n "$v" && "$rot" == *" ${v%/} "* ]] || armed_ok=0; done < <(git config -f "$F" --get-all gsync.readerRepo)
check "fedxps.inc: every armed readerRepo names a rotation repository" [ "$armed_ok" -eq 1 ]

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
