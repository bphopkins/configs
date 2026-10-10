#!/usr/bin/env bash
# Regression suite for bin/sync-check, the transport campaign's gauge
# (org/machines/transport-2026-10/rules.md: ws-1, ws-2, fedxps-3, bigfed-2;
# built 2026-10-10 at the pilot's step 3b, pilot/build-gauge.md there).
#
# Nothing real is reached: three fixture Syncthing instances -- fedxps, bigfed
# and the hub nousowl -- are Python HTTP servers on loopback answering from
# per-case JSON (fixture-server.py), each with a config.xml the gauge parses
# as it would the real one (scenario.py writes both from one spec with dotted
# overrides); a stub ssh runs the gauge's own remote mode, or the peer's git,
# in that host's sandbox home against that host's fixture, or refuses when the
# host is marked down; a stub uname names the machine. The repositories are
# local clones under the sandbox homes. GIT_OPTIONAL_LOCKS is set per case.
# Caged (tests/cage.sh). The settle is shortened through SYNC_CHECK_SETTLE and
# SYNC_CHECK_POLL. The last section runs the real gauge's conflicts and guard
# lines on this machine, read-only, and asserts only that tags and exit
# status agree.
#
# Run after any edit to bin/sync-check (~55 s; the cage stops it at 120 s, so a
# section that doubles the count needs a second cage). SYNC_CHECK=<path> runs the suite
# against another copy of the gauge, which is how it was mutation-tested (the
# breaks are listed in pilot/build-gauge.md). Last line follows the tests/gsync
# convention: "passed: N  failed: M"; exit 0 iff nothing failed.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$CFG_ROOT/tests/cage.sh"
cage sync-check "$@"

HERE="$CFG_ROOT/tests/sync-check"
GAUGE="${SYNC_CHECK:-$CFG_ROOT/bin/sync-check}"
for t in python3 git find; do command -v "$t" >/dev/null 2>&1 || {
  echo "sync-check tests: $t missing -- not running" >&2; echo "passed: 0  failed: 1"; exit 2; }; done
[ -x "$GAUGE" ] || { echo "sync-check tests: $GAUGE is not executable -- not running" >&2; echo "passed: 0  failed: 1"; exit 2; }

SB="$(mktemp -d "${TMPDIR:-/tmp}/sync-check-tests.XXXXXX")"
SERVERS=()
cleanup() { for p in "${SERVERS[@]}"; do kill "$p" 2>/dev/null; done; rm -rf "$SB"; }
trap cleanup EXIT

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
has()   { grep -qE -- "$2" <<<"$1" || { echo "     got:  $(head -c 1500 <<<"$1")"; echo "     want: a line matching $2"; return 1; }; }
lacks() { ! grep -qE -- "$2" <<<"$1" || { echo "     got:  $(head -c 1500 <<<"$1")"; echo "     want: nothing matching $2"; return 1; }; }
is()    { [ "$1" = "$2" ] || { echo "     got:  $1"; echo "     want: $2"; return 1; }; }

# --- the sandbox --------------------------------------------------------------
mkdir -p "$SB/stub" "$SB/fx" "$SB/ssh"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_NOSYSTEM=1
LIVE_GOL="${GIT_OPTIONAL_LOCKS-__unset__}"   # the caller's, restored for the live section
unset GIT_CONFIG_GLOBAL GIT_OPTIONAL_LOCKS GIT_DIR GIT_WORK_TREE XDG_CONFIG_HOME XDG_STATE_HOME SYNC_CHECK_CONFIG
export SYNC_CHECK_SETTLE=0.6 SYNC_CHECK_POLL=0.2
KEY="fixture-key-$RANDOM$RANDOM"; printf '%s' "$KEY" > "$SB/key"
python3 - "$SB/ports" <<'PY'
import socket, sys
ports = []
socks = []
for _ in range(3):
    s = socket.socket(); s.bind(("127.0.0.1", 0)); socks.append(s); ports.append(s.getsockname()[1])
for s in socks: s.close()
open(sys.argv[1], "w").write("\n".join(map(str, ports)) + "\n")
PY
read -r P_FED P_BIG P_HUB < <(tr '\n' ' ' < "$SB/ports")
for h in fedxps bigfed nousowl; do
  mkdir -p "$SB/fx/$h" "$SB/ssh/$h/home"
  case $h in fedxps) p=$P_FED;; bigfed) p=$P_BIG;; nousowl) p=$P_HUB;; esac
  python3 "$HERE/fixture-server.py" "$p" "$SB/fx/$h" "$KEY" & SERVERS+=($!)
done
for p in $P_FED $P_BIG $P_HUB; do
  for i in $(seq 1 50); do curl -s -o /dev/null -m 1 "http://127.0.0.1:$p/" 2>/dev/null && break; sleep 0.1; done
done

cat >"$SB/stub/uname" <<'STUB'
#!/bin/sh
cat "$STUB_HOST_FILE"
STUB
cat >"$SB/stub/ssh" <<'STUB'
#!/usr/bin/env bash
# stub ssh: refuses a host marked down or unknown (255, as ssh does); otherwise
# runs the command words as that host's shell would, in that host's sandbox
# home, against that host's Syncthing fixture; records every call.
host=""
while [ $# -gt 0 ]; do
  case "$1" in -o|-p|-i|-l|-F) shift 2 ;; -*) shift ;; *) host=$1; shift; break ;; esac
done
printf '%s: %s\n' "$host" "$*" >>"$STUB_SSH_LOG"
d="$STUB_SSH_DIR/$host"
[ -d "$d" ] || { echo "ssh: Could not resolve hostname $host: Name or service not known" >&2; exit 255; }
[ -e "$d/down" ] && { echo "ssh: connect to host $host port 22: No route to host" >&2; exit 255; }
if [ -n "${STUB_SSH_STDIN:-}" ] && [[ "$*" != *--remote-views* ]]; then cat >> "$STUB_SSH_STDIN"; fi
[ -n "${STUB_SSH_BANNER:-}" ] && echo "$STUB_SSH_BANNER"     # a shell rc that echoes
export HOME="$d/home" SYNC_CHECK_CONFIG="$d/config.xml"
exec bash -c "$*"
STUB
chmod +x "$SB/stub/uname" "$SB/stub/ssh"
export STUB_HOST_FILE="$SB/host" STUB_SSH_DIR="$SB/ssh" STUB_SSH_LOG="$SB/ssh.log"
PATH="$SB/stub:$PATH"; hash -r

# repositories: a bare origin, a clone in each workstation's home at the same HEAD
mkrepos() {
  rm -rf "$SB/origin-nousowl.git" "$SB/origin-org.git"
  for r in nousowl org; do
    git init -q --bare -b main "$SB/origin-$r.git"
    for h in fedxps bigfed; do rm -rf "$SB/ssh/$h/home/Desktop/$r"; done
    git clone -q "$SB/origin-$r.git" "$SB/ssh/bigfed/home/Desktop/$r"
    echo base > "$SB/ssh/bigfed/home/Desktop/$r/base.txt"
    git -C "$SB/ssh/bigfed/home/Desktop/$r" add -A
    git -C "$SB/ssh/bigfed/home/Desktop/$r" commit -qm base
    git -C "$SB/ssh/bigfed/home/Desktop/$r" push -qu origin main
    git clone -q "$SB/origin-$r.git" "$SB/ssh/fedxps/home/Desktop/$r"
  done
  for h in fedxps bigfed; do mkdir -p "$SB/ssh/$h/home/Desktop/alpha" "$SB/ssh/$h/home/.local/share/adelotype/log"; done
}
mkrepos

# the git half of each sandbox home: the stowed config with the host include, the host files, the link
HOSTS_FED="$SB/ssh/fedxps/home/Desktop/configs/git/hosts"; HOSTS_BIG="$SB/ssh/bigfed/home/Desktop/configs/git/hosts"
for h in fedxps bigfed; do
  H="$SB/ssh/$h/home"
  mkdir -p "$H/.config/git" "$H/Desktop/configs/git/hosts"
  printf '[include]\n\tpath = ~/.config/git/host.inc\n' > "$H/.config/git/config"
done
FEDINC='[gsync]\n\treaderRepo = nousowl\n[core]\n\tcheckStat = minimal\n\ttrustctime = false\n[diff]\n\tautoRefreshIndex = false\n[gc]\n\tauto = 0\n[maintenance]\n\tauto = false\n'
BIGINC='[gsync]\n\trole = writer\n[maintenance]\n\tautoDetach = false\n'
printf '%b' "$FEDINC" > "$HOSTS_FED/fedxps.inc"; printf '%b' "$BIGINC" > "$HOSTS_FED/bigfed.inc"
printf '%b' "$FEDINC" > "$HOSTS_BIG/fedxps.inc"; printf '%b' "$BIGINC" > "$HOSTS_BIG/bigfed.inc"
ln -s ../../Desktop/configs/git/hosts/fedxps.inc "$SB/ssh/fedxps/home/.config/git/host.inc"
ln -s ../../Desktop/configs/git/hosts/bigfed.inc "$SB/ssh/bigfed/home/.config/git/host.inc"

be() { printf '%s\n' "$1" > "$SB/host"; ME=$1; export HOME="$SB/ssh/$1/home" SYNC_CHECK_CONFIG="$SB/ssh/$1/config.xml"; }
scenario() { python3 "$HERE/scenario.py" "$SB" "$ME" "$@"; : > "$SB/ssh.log"; for h in fedxps bigfed nousowl; do : > "$SB/fx/$h/requests.log"; rm -f "$SB/ssh/$h/down"; done; }
run() { "$GAUGE" "$@" 2>&1; }
rc() { "$GAUGE" "$@" >/dev/null 2>&1; echo $?; }
reqs() { cat "$SB/fx/$1/requests.log"; }

# ==============================================================================
echo "== sync: everything up to date, seen from fedxps =="
be fedxps; scenario
out=$(run sync -v); r=$(rc sync)
check "three OK lines, one per folder"       is "$(grep -c '^\[ OK \]' <<<"$out")" 3
check "says all clear"                       has "$out" '^all clear$'
check "exit 0"                               is "$r" 0
check "each folder scanned before it is read" bash -c "grep -n 'db/scan?folder=f1' '$SB/fx/fedxps/requests.log' | head -1 | cut -d: -f1 | xargs -I{} test {} -lt \$(grep -n 'db/status?folder=f1' '$SB/fx/fedxps/requests.log' | head -1 | cut -d: -f1)"
check "the scan is a POST"                   has "$(reqs fedxps)" '^POST /rest/db/scan\?folder=f1$'
check "the hub is never asked to scan"       lacks "$(reqs nousowl)" 'db/scan'
check "no instance's /rest/config is read (it carries the password)" lacks "$(cat "$SB"/fx/*/requests.log)" '/rest/config'
check "the hub was read over ssh in remote mode" has "$(cat "$SB/ssh.log")" '^nousowl: python3 -I - --remote-views f1 f2 f3$'
check "the peer was not asked (nothing owed or needed)" lacks "$(cat "$SB/ssh.log")" '^bigfed:'
check "the key is never printed, even verbose" lacks "$out" "$KEY"
check "the key is not on the ssh command line" lacks "$(cat "$SB/ssh.log")" "$KEY"
check "-v shows the hub's view of both workstations" has "$out" "nousowl's view of bigfed: valid"
check "the hub's view of this machine is read as 'connected'" has "$out" "nousowl's view of fedxps: valid, needs 0 items and 0 deletes, 100.0 %, connected"

echo "== sync: the percentage plays no part =="
be fedxps; scenario 'fedxps.folders.f1.completion.HUB.needDeletes=1' 'fedxps.folders.f1.completion.HUB.names=["gone.txt"]'
out=$(run sync); r=$(rc sync)
check "a deletion the hub still needs at 100 % is stranded on this machine" has "$out" '^\[FAIL\] alpha: stranded on fedxps: gone.txt'
check "  with him-2's repair, on the other machine" has "$out" 'fix: edit each listed path on bigfed, never on fedxps'
check "  exit 1"                             is "$r" 1
check "  the other folders still read OK"     has "$out" '^\[ OK \] nousowl: up to date'

echo "== sync: a folder still syncing is WAIT, not stranded =="
be fedxps; scenario 'fedxps.folders.f2.state="syncing"' 'fedxps.folders.f2.needTotalItems=3'
out=$(run sync); r=$(rc sync)
check "WAIT with the state"                  has "$out" '^\[WAIT\] nousowl: syncing on this machine'
check "  no stranded verdict"                lacks "$out" 'stranded'
check "  exit 1"                             is "$r" 1

scenario 'fedxps.folders.f2.state="syncing"' 'fedxps.folders.f2.needTotalItems=3'
check "  and no 'do not arrive' repair while it transfers (review 3b-2)" lacks "$(run sync)" 'do not arrive'
scenario 'fedxps.folders.f1.completion.HUB.needItems=1' 'fedxps.folders.f1.completion.HUB.names=["big.pdf"]' 'nousowl.folders.f1.state="syncing"'
out=$(run sync); r=$(rc sync)
check "an upload still running at the hub: WAIT, never stranded" has "$out" '^\[WAIT\] alpha: nousowl is syncing'
check "  no stranded verdict"                lacks "$out" 'stranded'
check "  exit 1"                             is "$r" 1
scenario 'fedxps.folders.f1.needTotalItems=3'
check "an unnamed need counts right"         has "$(run sync)" 'needs 3 items that do not arrive: \(unnamed\)'

echo "== sync: a need that clears within the settle reads OK =="
be fedxps; scenario 'fedxps.folders.f1.status_seq=[{"needTotalItems":1},{"needTotalItems":1},{"needTotalItems":0}]' 'fedxps.folders.f1.needNames=["late.txt"]'
out=$(run sync); r=$(rc sync)
check "OK after the re-reads"                has "$out" '^\[ OK \] alpha: up to date'
check "  exit 0"                             is "$r" 0
check "  the status was re-read at least three times" bash -c "[ \$(grep -c 'db/status?folder=f1' '$SB/fx/fedxps/requests.log') -ge 3 ]"

echo "== sync: a need that survives the settle is a failure =="
be fedxps; scenario 'fedxps.folders.f1.needTotalItems=2' 'fedxps.folders.f1.needNames=["a.txt","b.txt"]'
out=$(run sync); r=$(rc sync)
check "named"                                has "$out" '^\[FAIL\] alpha: needs 2 items that do not arrive: a.txt, b.txt'
check "  exit 1"                             is "$r" 1

echo "== sync: the known stuck item, named, reads OK; anything else fails =="
be fedxps
K='fedxps.folders.f3.label="adelotype-data"'
scenario "$K" 'bigfed.folders.f3.completion.HUB.needItems=1' 'bigfed.folders.f3.completion.HUB.names=["log"]' 'nousowl.folders.f3.completion.BIG.needItems=1' 'nousowl.folders.f3.completion.BIG.names=["M.syncthing-enc/QE/OPAQUE"]'
out=$(run sync); r=$(rc sync)
check "adelotype-data OK with the item named" has "$out" '^\[ OK \] adelotype-data: up to date -- the known item log stays stranded on bigfed \(since 2026-09-30'
check "  exit 0"                              is "$r" 0
check "  bigfed was asked, since the hub showed it owing something" has "$(cat "$SB/ssh.log")" '^bigfed: python3 -I - --remote-views'
check "  no settle wait for a known item (under 3 s of a 5 s settle)" bash -c "s=\$(date +%s%N); SYNC_CHECK_SETTLE=5 '$GAUGE' sync >/dev/null 2>&1; e=\$(date +%s%N); [ \$(( (e-s)/1000000 )) -lt 3000 ]"
scenario "$K" 'bigfed.folders.f3.completion.HUB.needItems=2' 'bigfed.folders.f3.completion.HUB.names=["log","other.txt"]' 'nousowl.folders.f3.completion.BIG.needItems=2'
out=$(run sync); r=$(rc sync)
check "a second item beside it fails, naming only the unknown one" has "$out" '^\[FAIL\] adelotype-data: stranded on bigfed: other.txt$'
check "  exit 1"                              is "$r" 1
scenario "$K" 'bigfed.folders.f1.completion.HUB.needItems=1' 'bigfed.folders.f1.completion.HUB.names=["log"]' 'nousowl.folders.f1.completion.BIG.needItems=1'
out=$(run sync)
check "the same name in another folder is not the known item" has "$out" '^\[FAIL\] alpha: stranded on bigfed: log$'
scenario "$K" 'bigfed.folders.f3.completion.HUB.needItems=1' 'bigfed.folders.f3.completion.HUB.names=["log"]' 'nousowl.folders.f3.completion.BIG.needItems=2'
out=$(run sync)
check "the hub counting more than bigfed names fails" has "$out" '^\[FAIL\] adelotype-data: the hub lists 1 item for bigfed beyond what bigfed names'
scenario "$K" 'fedxps.folders.f3.label="adelotype-data"'
out=$(run sync); r=$(rc sync)
check "the known item no longer showing anywhere: DUE, delete its line" has "$out" '^\[DUE\] adelotype-data: up to date; the known item log no longer shows stranded on bigfed'
check "  fix names KNOWN"                     has "$out" 'delete its line from KNOWN'
check "  exit 1"                             is "$r" 1
check "  the other folders OK, the label alone decides" has "$out" '^\[ OK \] alpha: up to date'
scenario "$K"; touch "$SB/ssh/nousowl/down"
check "  with the hub unread, no such verdict" lacks "$(run sync)" 'no longer shows'
scenario 'fedxps.folders.f1.watchError="failed to setup inotify handler. Please increase inotify limits"'
out=$(run sync); r=$(rc sync)
check "a dead watcher: DUE, up to date but seen only by scans" has "$out" '^\[DUE\] alpha: up to date; the watcher reports: failed to setup inotify'
check "  fix names the inotify limit"        has "$out" 'fs.inotify.max_user_watches'
check "  exit 1"                             is "$r" 1

echo "== sync: the other workstation unreachable, or asleep =="
be fedxps; scenario 'nousowl.folders.f3.completion.BIG.needItems=1'; touch "$SB/ssh/bigfed/down"
out=$(run sync); r=$(rc sync)
check "connected per the hub but silent over ssh: WARN, unverified" has "$out" '^\[WARN\] gamma: 1 item at the hub for bigfed, unverified: bigfed did not answer over ssh'
check "  exit 2"                             is "$r" 2
scenario 'nousowl.folders.f3.completion.BIG.needItems=1' 'nousowl.connected.BIG=false'; touch "$SB/ssh/bigfed/down"
out=$(run sync); r=$(rc sync)
check "offline per the hub: what waits for it is not this machine's fault" has "$out" '^\[ OK \] gamma: up to date -- bigfed is offline: 1 item wait for it at the hub'
check "  exit 0"                             is "$r" 0
check "  bigfed was not asked"               lacks "$(cat "$SB/ssh.log")" '^bigfed:'
check "  no settle wait for what waits at the hub for a sleeping peer (under 3 s of a 5 s settle)" bash -c "s=\$(date +%s%N); SYNC_CHECK_SETTLE=5 '$GAUGE' sync >/dev/null 2>&1; e=\$(date +%s%N); [ \$(( (e-s)/1000000 )) -lt 3000 ]"

echo "== sync: the hub's own state =="
be fedxps; scenario 'nousowl.folders.f1=__delete__'
out=$(run sync); r=$(rc sync)
check "a folder the hub lacks, named by label, its id kept out of the line" has "$out" '^\[FAIL\] alpha: nousowl has no folder alpha \(the id is in'
check "  no folder id printed"               lacks "$out" 'folder f1'
check "  exit 1"                             is "$r" 1
scenario 'nousowl.folders.f2.paused=true'
out=$(run sync)
check "a folder paused on the hub"           has "$out" '^\[FAIL\] nousowl: paused on nousowl'
scenario 'nousowl.folders.f2.pullErrors=3'
out=$(run sync)
check "pull errors on the hub, with hub-4's reading" has "$out" "^\[FAIL\] nousowl: 3 pull errors on nousowl"
check "  the fix names the full-volume case"  has "$out" "insufficient space"
scenario 'nousowl.folders.f2.needTotalItems=1' 'nousowl.folders.f2.needDeletes=1'
out=$(run sync)
check "the hub needing a deletion nobody names: the residue cure" has "$out" '^\[FAIL\] nousowl: the hub needs 1 item that no workstation names'
check "  fix: recreate, let it reach the hub, delete again" has "$out" 'recreate the name on the machine that deleted it'
scenario 'nousowl.folders.f2.needTotalItems=1'
out=$(run sync)
check "the hub needing a file nobody names: not called a deletion" lacks "$out" 'recreate the name'
check "  fix: wake the sleeping workstation"  has "$out" 'wake the one that is asleep'
scenario 'nousowl.folders.f2.completion.FED.needItems=1'
out=$(run sync)
check "the hub listing an item for this machine that it does not name" has "$out" '^\[FAIL\] nousowl: the hub lists 1 item this machine needs that it does not name'
scenario 'nousowl.folders.f2.maxConflicts=0'
check "maxConflicts 0 on the hub: FAIL (ws-7; review 3b-2's survivor m16)" has "$(run sync)" '^\[FAIL\] nousowl: maxConflicts is 0 on nousowl'
scenario 'nousowl.folders.f2.state="syncing"'
check "the hub still syncing: WAIT"          has "$(run sync)" '^\[WAIT\] nousowl: nousowl is syncing'
scenario 'nousowl.folders.f2.completion.FED.remoteState="unknown"' 'nousowl.connected.FED=false'
check "the hub not seeing this machine: WARN" has "$(run sync)" '^\[WARN\] nousowl: nousowl does not see this machine connected'
scenario 'nousowl.folders.f1.completion.BIG.needItems=1' 'bigfed.folders.f1.needTotalItems=1' 'bigfed.folders.f1.needNames=["late.md"]'
check "the other workstation needing what does not arrive: FAIL, named" has "$(run sync)" '^\[FAIL\] alpha: bigfed needs 1 item that do not arrive: late.md'
scenario 'nousowl.folders.f1.state="error"' 'nousowl.folders.f1.error="folder marker missing"'
out=$(run sync)
check "a hub folder in the error state: FAIL with its text (review 3b-2)" has "$out" '^\[FAIL\] alpha: folder error on nousowl: folder marker missing'
check "  never a wait"                       lacks "$out" '^\[WAIT\] alpha'
scenario 'fedxps.folders.f1.state="error"' 'fedxps.folders.f1.error="folder marker missing"'
check "the same here: the FAIL alone"       lacks "$(run sync)" '^\[WAIT\] alpha: error on this machine'
scenario; touch "$SB/ssh/nousowl/down"
out=$(run sync); r=$(rc sync)
check "the hub silent over ssh: WARN per folder" has "$out" "^\[WARN\] alpha: nousowl's view unread: nousowl did not answer over ssh"
check "  exit 2"                             is "$r" 2
check "  the fix is the ssh probe"           has "$out" 'fix: ssh -o BatchMode=yes nousowl true'

echo "== sync: this machine's own state =="
be fedxps; scenario 'fedxps.folders.f1.completion.HUB.remoteState="unknown"'
out=$(run sync); r=$(rc sync)
check "hub not connected: WARN with the kill switch first" has "$out" "^\[WARN\] alpha: nousowl is not connected to this machine's Syncthing"
check "  fix names Proton VPN's kill switch"  has "$out" "Proton VPN's kill switch"
check "  exit 2"                             is "$r" 2
scenario 'fedxps.folders.f1.completion.HUB.remoteState="paused"'
check "hub device paused here: FAIL"         has "$(run sync)" '^\[FAIL\] alpha: nousowl is paused on this machine'
scenario 'fedxps.folders.f1.completion.HUB.remoteState="notSharing"'
check "hub not sharing back: FAIL"           has "$(run sync)" '^\[FAIL\] alpha: nousowl does not share alpha back'
scenario 'fedxps.folders.f1.paused=true'
out=$(run sync)
check "a folder paused here: WAIT"           has "$out" '^\[WAIT\] alpha: paused on this machine'
check "  and not scanned"                    lacks "$(reqs fedxps)" 'db/scan\?folder=f1'
scenario 'fedxps.folders.f1.maxConflicts=0'
check "maxConflicts 0: FAIL (ws-7)"          has "$(run sync)" '^\[FAIL\] alpha: maxConflicts is 0 here'
scenario 'fedxps.folders.f1.pullErrors=2'
check "pull errors here: FAIL"               has "$(run sync)" '^\[FAIL\] alpha: 2 pull errors on this machine'
scenario 'fedxps.folders.f1.error="folder marker missing"'
out=$(run sync)
check "a folder error: FAIL, never make a marker by hand" has "$out" 'folder error on this machine: folder marker missing'
check "  says never to make a marker"        has "$out" 'never make one by hand'

echo "== sync: could not determine is never silent health =="
be fedxps; scenario
python3 - "$SB/ssh/fedxps/config.xml" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"<address>127\.0\.0\.1:\d+</address>", "<address>127.0.0.1:1</address>", s); open(p, "w").write(s)
PY
out=$(run sync); r=$(rc sync)
check "daemon not answering: WARN"           has "$out" '^\[WARN\] Syncthing is not answering at http://127.0.0.1:1/rest/'
check "  exit 2"                             is "$r" 2
scenario
python3 - "$SB/ssh/fedxps/config.xml" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"<apikey>[^<]*</apikey>", "<apikey>wrong</apikey>", s); open(p, "w").write(s)
PY
out=$(run sync); r=$(rc sync)
check "a refused key: WARN"                  has "$out" '^\[WARN\] the API key in .* is refused'
check "  exit 2"                             is "$r" 2
out=$(SYNC_CHECK_CONFIG="$SB/nowhere.xml" run sync); r=$(SYNC_CHECK_CONFIG="$SB/nowhere.xml" rc sync)
check "no configuration: WARN"               has "$out" '^\[WARN\] no Syncthing configuration on this machine'
check "  exit 2"                             is "$r" 2

scenario
out=$(SYNC_CHECK_SETTLE=15s SYNC_CHECK_POLL=-1 run sync); r=$(SYNC_CHECK_SETTLE=15s SYNC_CHECK_POLL=-1 rc sync)
check "unusable settle values fall back to the defaults, no traceback (review 3b-2)" is "$r" 0

echo "== sync: the settle re-reads the hub and the peer, not only this machine (review 3b-1) =="
be fedxps; scenario 'nousowl.folders.f2.status_seq=[{"state":"syncing","needTotalItems":1},{"state":"idle","needTotalItems":0}]'
out=$(run sync); r=$?
check "the hub syncing at the first read and idle at the next: OK" has "$out" '^\[ OK \] nousowl: up to date'
check "  the hub was read more than once"     bash -c "[ \$(grep -c 'db/status?folder=f2' '$SB/fx/nousowl/requests.log') -ge 2 ]"
scenario 'nousowl.folders.f1.status_seq=[{"needTotalItems":1},{"needTotalItems":0}]'
out=$(run sync)
check "the hub needing an edit in flight, then nothing: OK, no residue cure" has "$out" '^\[ OK \] alpha: up to date'
scenario 'nousowl.folders.f1.completion.BIG.needItems=1' 'bigfed.folders.f1.status_seq=[{"state":"syncing","needTotalItems":1},{"state":"idle","needTotalItems":0}]' 'bigfed.folders.f1.needNames=["a.txt"]'
python3 - "$SB/fx/nousowl/responses.json" <<'PY'
import json, sys
p = sys.argv[1]; t = json.load(open(p))
k = [k for k in t if k.startswith("GET /rest/db/completion?folder=f1&device=BIGFEDX")][0]
b = t[k]["body"]; t[k]["body"] = {"__seq__": [b, dict(b, needItems=0)]}
json.dump(t, open(p, "w"))
PY
out=$(run sync)
check "bigfed mid-pull at its first read, done at the next: OK" has "$out" '^\[ OK \] alpha: up to date'
check "  bigfed was read more than once"      bash -c "[ \$(grep -c '^bigfed:' '$SB/ssh.log') -ge 2 ]"
scenario 'fedxps.folders.f1.status_seq=[{"needTotalItems":1},{"needTotalItems":0}]'
out=$(run sync)
check "a need counted, then gone before db/need lists it: re-read, OK" has "$out" '^\[ OK \] alpha: up to date'

echo "== sync: remoteState is valid or it is not OK (review 3b-1) =="
be fedxps; scenario 'fedxps.folders.f1.completion.HUB.remoteState=null'
check "my view of the hub with no remoteState: WARN" has "$(run sync)" '^\[WARN\] alpha: my view of nousowl reports remoteState None'
scenario 'fedxps.folders.f1.completion.HUB.remoteState="weird"'
check "  an unknown value: WARN, exit 2"        is "$(rc sync)" 2
scenario 'nousowl.folders.f1.completion.FED.remoteState="notSharing"'
check "the hub's view of this machine: notSharing is a FAIL" has "$(run sync)" "^\[FAIL\] alpha: nousowl's view of fedxps: notSharing"
scenario 'nousowl.folders.f1.completion.BIG.remoteState="paused"'
check "the hub's view of bigfed: paused is a FAIL" has "$(run sync)" "^\[FAIL\] alpha: nousowl's view of bigfed: paused"
scenario 'nousowl.folders.f1.state=null'
check "the hub reporting no state: WARN, never idle" has "$(run sync)" '^\[WARN\] alpha: nousowl reports no state'
scenario 'nousowl.folders.f1.completion.BIG.needItems=1'
python3 - "$SB/fx/nousowl/responses.json" <<'PY'
import json, sys
p = sys.argv[1]; t = json.load(open(p)); t.pop("GET /rest/system/connections"); json.dump(t, open(p, "w"))
PY
out=$(run sync)
check "the hub's connections unreadable: the peer is asked, not assumed asleep" has "$(cat "$SB/ssh.log")" '^bigfed: python3 -I - --remote-views'
check "  and nothing reads 'offline'"         lacks "$out" 'is offline'
scenario 'fedxps.hub_enc=false' 'fedxps.folders.f1.completion.HUB.needItems=5'
out=$(run sync); r=$(rc sync)
check "a folder with no hub: WARN, never up to date" has "$out" '^\[WARN\] alpha: shared with nousowl and with no hub'
check "  exit 2"                             is "$r" 2

echo "== sync: him-2's second case, the hub holding a conflict's loser (review 3b-1) =="
be fedxps; scenario 'fedxps.folders.f1.completion.HUB.needItems=1' 'fedxps.folders.f1.completion.HUB.names=["x.txt"]' \
  'bigfed.folders.f1.completion.HUB.needItems=1' 'bigfed.folders.f1.completion.HUB.names=["x.txt"]' \
  'nousowl.folders.f1.completion.BIG.needItems=1' 'nousowl.folders.f1.completion.FED.needItems=1'
out=$(run sync)
check "both list x.txt towards the hub: the loser's repair" has "$out" "the hub holds a conflict's loser: x.txt"
check "  edit once more on either machine"    has "$out" 'edit the file once more on either machine'
check "  no contradictory 'never on' repairs" lacks "$out" 'never on'

# ==============================================================================
echo "== conflicts =="
be fedxps; scenario
out=$(run conflicts); r=$(rc conflicts)
check "clean: three OK lines"                is "$(grep -c '^\[ OK \]' <<<"$out")" 3
check "  exit 0"                             is "$r" 0
check "  the sweep covers the folder outside ~/Desktop" has "$out" 'elsewhere under ~/.local/share/adelotype, ~/Desktop'
N="$HOME/Desktop/nousowl"
mkdir -p "$N/.git/refs/heads"
echo x > "$N/.git/refs/heads/main.sync-conflict-20261009-162229-GE3DRZ3"
touch -d '20 minutes ago' "$N/.git/index.lock"
touch "$N/.git/fresh.lock"
mkdir -p "$HOME/Desktop/org/claude-config/rules" "$HOME/Desktop/configs/environment.d" "$HOME/Desktop/other/rules"
echo r > "$HOME/Desktop/org/claude-config/rules/house.sync-conflict-20261009-195347-7Z3LCI7.md"
echo e > "$HOME/Desktop/configs/environment.d/10-x.sync-conflict-20261009-195347-7Z3LCI7.conf"
echo o > "$HOME/Desktop/other/rules/notes.sync-conflict-20261009-195347-7Z3LCI7.md"
echo d > "$HOME/.local/share/adelotype/log/fedxps.sync-conflict-20261009-195347-7Z3LCI7.jsonl"
out=$(run conflicts); r=$(rc conflicts)
check "under .git: one copy and one stale lock" has "$out" '^\[FAIL\] under a .git: 1 conflict copy and 1 lock file older than 10 min'
check "  the phantom ref listed with its time" has "$out" 'main.sync-conflict-20261009-162229-GE3DRZ3  20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]'
check "  the stale lock listed"              has "$out" 'index.lock'
check "  the fresh lock not"                 lacks "$out" 'fresh.lock'
check "  fix: rename the phantom, commit the tree, him-2" has "$out" 'rename it to a name without sync-conflict'
check "loaded directories: two copies"       has "$out" '^\[FAIL\] in a directory that loads: 2 conflict copies'
check "  the rules copy"                     has "$out" 'claude-config/rules/house.sync-conflict'
check "  the environment.d copy, by component" has "$out" 'environment.d/10-x.sync-conflict'
check "  fix: keep the right text, delete the copy; the suffix names the winner" has "$out" 'the suffix names the device that won, never the loser'
check "elsewhere: DUE, two copies"           has "$out" '^\[DUE\] elsewhere: 2 conflict copies to merge'
check "  a rules/ directory outside claude-config is elsewhere" has "$out" 'other/rules/notes.sync-conflict'
check "  the copy in the folder outside ~/Desktop is found" has "$out" 'adelotype/log/fedxps.sync-conflict'
check "  exit 1"                             is "$r" 1
rm -f "$N/.git/refs/heads/main.sync-conflict-20261009-162229-GE3DRZ3" "$N/.git/index.lock" "$N/.git/fresh.lock"
rm -rf "$HOME/Desktop/org/claude-config" "$HOME/Desktop/configs/environment.d" "$HOME/Desktop/other" "$HOME/.local/share/adelotype/log/fedxps.sync-conflict-20261009-195347-7Z3LCI7.jsonl"
echo o > "$HOME/Desktop/alpha/notes.sync-conflict-20261009-195347-7Z3LCI7.md"
out=$(run conflicts); r=$(rc conflicts)
check "one copy elsewhere alone: DUE and exit 1" is "$r" 1
check "  the other two lines OK"             is "$(grep -c '^\[ OK \]' <<<"$out")" 2
rm -f "$HOME/Desktop/alpha/notes.sync-conflict-20261009-195347-7Z3LCI7.md"
mkdir -p "$HOME/Desktop/locked"; echo x > "$HOME/Desktop/locked/notes.sync-conflict-20261009-195347-7Z3LCI7.md"; chmod 000 "$HOME/Desktop/locked"
out=$(run conflicts); r=$(rc conflicts)
check "a directory find cannot enter: WARN, never a clean sweep (review 3b-1)" has "$out" '^\[WARN\] the sweep could not read everything'
check "  exit 2"                             is "$r" 2
chmod 755 "$HOME/Desktop/locked"; rm -rf "$HOME/Desktop/locked"
printf 'x' > "$HOME/Desktop/alpha/odd$(printf '\n')name.sync-conflict-20261009-195347-7Z3LCI7.md"
out=$(run conflicts)
check "a newline in a copy's name: one entry, the sweep whole (review 3b-2)" has "$out" '^\[DUE\] elsewhere: 1 conflict copy to merge'
rm -f "$HOME/Desktop/alpha/odd"*

# ==============================================================================
echo "== guard: the reader, whole =="
be fedxps; scenario
export GIT_OPTIONAL_LOCKS=0
out=$(run guard); r=$(rc guard)
check "the link resolves"                    has "$out" '^\[ OK \] ~/.config/git/host.inc -> ~/Desktop/configs/git/hosts/fedxps.inc'
check "every key resolves from it"           has "$out" '^\[ OK \] git resolves every setting in hosts/fedxps.inc from the link: core.checkstat, core.trustctime, diff.autorefreshindex, gc.auto, gsync.readerrepo, maintenance.auto'
check "the variable, with the reason"        has "$out" '^\[ OK \] GIT_OPTIONAL_LOCKS=0 in this environment \(readerRepo = nousowl\)'
check "no write under .git, since the daemon started" has "$out" '^\[ OK \] no write under a .git this machine reads, in 0 disk events \(since Syncthing started at 2026-10-10T10:04:50\)'
check "  exit 0"                             is "$r" 0
echo "== guard: the link =="
rm "$HOME/.config/git/host.inc"
out=$(run guard); r=$(rc guard)
check "missing link: FAIL with the ln -s command" has "$out" '^\[FAIL\] ~/.config/git/host.inc is missing'
check "  the command"                        has "$out" 'fix: ln -s \.\./\.\./Desktop/configs/git/hosts/fedxps\.inc ~/\.config/git/host\.inc'
check "  and the settings do not resolve, anywhere and inside the reader repository" has "$out" '^\[FAIL\] git does not resolve the host file.s settings: 12 keys'
check "  each key named for both places"     has "$out" 'core.checkstat unset for ~/Desktop/nousowl \(the host file says minimal\)'
check "  exit 1"                             is "$r" 1
ln -s ../../Desktop/configs/git/hosts/gone.inc "$HOME/.config/git/host.inc"
out=$(run guard)
check "dangling link: FAIL, and a reader meanwhile" has "$out" '^\[FAIL\] ~/.config/git/host.inc is dangling'
check "  with the warning the sync commands give" has "$out" '^\[WARN\] ~/.config/git/host.inc is dangling: a reader until it is fixed'
rm "$HOME/.config/git/host.inc"; ln -s ../../Desktop/configs/git/hosts/bigfed.inc "$HOME/.config/git/host.inc"
out=$(run guard)
check "the wrong machine's file: FAIL"       has "$out" '^\[FAIL\] ~/.config/git/host.inc -> ~/Desktop/configs/git/hosts/bigfed.inc, but this machine is fedxps'
check "  fedxps.inc's keys are unset, bigfed's file being what git reads" has "$out" 'core.checkstat unset for git anywhere \(the host file says minimal\)'
check "  the warning the sync commands give too" has "$out" '^\[WARN\] ~/.config/git/host.inc names bigfed.inc but this machine is fedxps; the stricter of the two holds'
rm "$HOME/.config/git/host.inc"; ln -s ../../Desktop/configs/git/hosts/fedxps.inc "$HOME/.config/git/host.inc"
echo "== guard: a repository's own config overriding the guard =="
git -C "$N" config core.checkStat default
out=$(run guard); r=$(rc guard)
check "the override is found inside the reader repository" has "$out" 'core.checkstat = default from ~/Desktop/nousowl/.git/config for ~/Desktop/nousowl \(the host file says minimal\)'
check "  exit 1"                             is "$r" 1
git -C "$N" config --unset core.checkStat
echo "== guard: the environment half =="
unset GIT_OPTIONAL_LOCKS
out=$(run guard); r=$(rc guard)
check "unset on a reader: FAIL with the login remedy" has "$out" '^\[FAIL\] GIT_OPTIONAL_LOCKS is unset in this environment, and this machine reads \(readerRepo = nousowl\)'
check "  fix: log out and in"                has "$out" 'fix: log out and in: 10-env.sh exports it at login'
check "  exit 1"                             is "$r" 1
export GIT_OPTIONAL_LOCKS=0
out=$(GIT_OPTIONAL_LOCKS=false run guard)
check "GIT_OPTIONAL_LOCKS=false on a reader: git reads it as off, OK (review 3b-1)" has "$out" '^\[ OK \] GIT_OPTIONAL_LOCKS=false in this environment'
out=$(GIT_OPTIONAL_LOCKS=maybe run guard)
check "GIT_OPTIONAL_LOCKS=maybe: git refuses it, FAIL"  has "$out" '^\[FAIL\] GIT_OPTIONAL_LOCKS is .maybe. in this environment, which git refuses'
echo "== guard: writes seen under .git =="
scenario "fedxps.events=[{\"id\":1,\"globalID\":1,\"time\":\"2026-10-10T11:15:22.1-07:00\",\"type\":\"LocalChangeDetected\",\"data\":{\"action\":\"modified\",\"folder\":\"f2\",\"folderID\":\"f2\",\"label\":\"nousowl\",\"path\":\".git/index\",\"type\":\"file\",\"modifiedBy\":\"x\"}},{\"id\":2,\"globalID\":2,\"time\":\"2026-10-10T11:15:23.1-07:00\",\"type\":\"LocalChangeDetected\",\"data\":{\"action\":\"modified\",\"folder\":\"f2\",\"folderID\":\"f2\",\"label\":\"nousowl\",\"path\":\"README.md\",\"type\":\"file\",\"modifiedBy\":\"x\"}},{\"id\":3,\"globalID\":3,\"time\":\"2026-10-10T11:15:24.1-07:00\",\"type\":\"RemoteChangeDetected\",\"data\":{\"action\":\"modified\",\"folder\":\"f2\",\"folderID\":\"f2\",\"label\":\"nousowl\",\"path\":\".git/refs/heads/main\",\"type\":\"file\",\"modifiedBy\":\"y\"}},{\"id\":4,\"globalID\":4,\"time\":\"2026-10-10T11:15:25.1-07:00\",\"type\":\"LocalChangeDetected\",\"data\":{\"action\":\"modified\",\"folder\":\"f1\",\"folderID\":\"f1\",\"label\":\"alpha\",\"path\":\"sub/.git/config\",\"type\":\"file\",\"modifiedBy\":\"x\"}}]"
out=$(run guard); r=$(rc guard)
check "one write under the reader repository's .git: FAIL" has "$out" '^\[FAIL\] 1 write seen under a .git this machine reads \(since Syncthing started'
check "  the path and time"                  has "$out" '2026-10-10T11:15:22  ~/Desktop/nousowl/.git/index'
check "  a write outside .git is not counted" lacks "$out" 'README.md'
check "  a remote change under .git is not a write" lacks "$out" 'refs/heads/main'
check "  a .git in a folder this machine writes is not counted under readerRepo" lacks "$out" 'sub/.git/config'
check "  fix names fedxps-4's writers"       has "$out" "fedxps-4"
check "  exit 1"                             is "$r" 1
printf '[gsync]\n\trole = reader\n[core]\n\tcheckStat = minimal\n' > "$HOSTS_FED/fedxps.inc"
out=$(run guard)
check "under role = reader every .git counts" has "$out" '^\[FAIL\] 2 writes seen under a .git'
check "  the alpha one too"                  has "$out" 'alpha/sub/.git/config'
printf '%b' "$FEDINC" > "$HOSTS_FED/fedxps.inc"
python3 - "$SB/fx/fedxps/responses.json" <<'PY'
import json, sys
p = sys.argv[1]; t = json.load(open(p))
ev = [{"id": i, "globalID": i, "time": "2026-10-10T10:%02d:00.0-07:00" % (i % 60), "type": "RemoteChangeDetected",
       "data": {"action": "modified", "folder": "f1", "folderID": "f1", "label": "alpha", "path": "x%d" % i, "type": "file", "modifiedBy": "y"}} for i in range(1, 1001)]
t["GET /rest/events/disk?since=0&limit=1000&timeout=0"] = {"body": ev}
json.dump(t, open(p, "w"))
PY
out=$(run guard)
check "a full buffer says what is out of reach" has "$out" '^\[ OK \] no write under a .git this machine reads, in 1000 disk events \(the last 1000 disk events, from 2026-10-10T10:01:00; earlier ones are out of reach\)'
scenario
python3 - "$SB/ssh/fedxps/config.xml" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"<address>127\.0\.0\.1:\d+</address>", "<address>127.0.0.1:1</address>", s); open(p, "w").write(s)
PY
out=$(run guard); r=$(rc guard)
check "daemon silent on a reader: the write log is unknown, WARN" has "$out" '^\[WARN\] Syncthing is not answering at http://127.0.0.1:1/rest/: its disk events cannot be read'
check "  exit 2"                             is "$r" 2
echo "== guard: the writer, and a stranger =="
be bigfed; scenario; unset GIT_OPTIONAL_LOCKS
out=$(run guard); r=$(rc guard)
check "bigfed: link OK"                      has "$out" '^\[ OK \] ~/.config/git/host.inc -> ~/Desktop/configs/git/hosts/bigfed.inc'
check "bigfed: its two keys resolve"         has "$out" '^\[ OK \] git resolves every setting in hosts/bigfed.inc from the link: gsync.role, maintenance.autodetach'
check "bigfed: no variable, right"           has "$out" '^\[ OK \] GIT_OPTIONAL_LOCKS unset, right while hosts/bigfed.inc arms no reader role and no reader repository'
check "bigfed: the event check does not apply" has "$out" '^\[ OK \] a writer: its own commits write .git'
check "  exit 0"                             is "$r" 0
check "  the daemon was not asked for events" lacks "$(reqs bigfed)" 'events/disk'
GIT_OPTIONAL_LOCKS=0 out=$(GIT_OPTIONAL_LOCKS=0 run guard); r=$(GIT_OPTIONAL_LOCKS=0 rc guard)
check "the variable on a writer: FAIL, the re-stamp named" has "$out" "^\[FAIL\] GIT_OPTIONAL_LOCKS=0 is set on a writer: gpushall's .add -A. would re-stamp pack files"
for v in false ""; do
  out=$(GIT_OPTIONAL_LOCKS="$v" run guard)
  check "GIT_OPTIONAL_LOCKS='$v' on a writer: git reads it as off, FAIL (review 3b-1)" has "$out" '^\[FAIL\] GIT_OPTIONAL_LOCKS=.* is set on a writer'
done
check "  exit 1"                             is "$r" 1
printf 'stranger\n' > "$SB/host"; rm "$HOME/.config/git/host.inc"
out=$(run guard); r=$(rc guard)
check "a stranger: nothing to guard"         has "$out" '^\[ OK \] no host file for stranger in configs/git/hosts: a writer on git.s defaults, nothing to guard'
check "  exit 0"                             is "$r" 0
ln -s ../../Desktop/configs/git/hosts/bigfed.inc "$HOME/.config/git/host.inc"

# ==============================================================================
echo "== push: from bigfed, the writer =="
be bigfed; scenario; unset GIT_OPTIONAL_LOCKS
out=$(run push org); r=$(rc push org)
check "a repository in no folder: nothing to check, the age line" has "$out" '^\[ OK \] org: in no Syncthing folder, nothing to check; origin/main last moved [0-9]+ s ago; nothing unpushed'
check "  exit 0"                             is "$r" 0
check "  the daemon was not read for it"     lacks "$(reqs bigfed)" 'db/'
out=$(run push -q org); r=$(rc push -q org)
check "-q: silent for it"                    is "$out" ""
check "  exit 0"                             is "$r" 0
out=$(run push nousowl); r=$(rc push nousowl)
check "a repository that is a folder, all clear" has "$out" '^\[ OK \] nousowl: folder nousowl up to date, nothing under .git needed, no phantom ref; HEAD equal on fedxps; origin/main last moved [0-9]+ s ago; nothing unpushed'
check "  exit 0"                             is "$r" 0
check "  only that folder scanned"           lacks "$(reqs bigfed)" 'db/scan\?folder=f[13]'
check "  fedxps's HEAD read over ssh under GIT_OPTIONAL_LOCKS=0" has "$(cat "$SB/ssh.log")" "^fedxps: GIT_OPTIONAL_LOCKS=0 git -C ~/'Desktop/nousowl' rev-parse HEAD$"
out=$(run push -q nousowl)
check "-q: the folder repository still gets its line" has "$out" '^\[ OK \] nousowl: folder nousowl up to date'
check "  but no summary"                     lacks "$out" 'all clear'
echo "== push: the age of what GitHub lacks =="
echo more > "$HOME/Desktop/nousowl/more.txt"; git -C "$HOME/Desktop/nousowl" add -A; git -C "$HOME/Desktop/nousowl" commit -qm more
git -C "$SB/ssh/fedxps/home/Desktop/nousowl" pull -q 2>/dev/null; git -C "$SB/ssh/fedxps/home/Desktop/nousowl" reset -q --hard "$(git -C "$HOME/Desktop/nousowl" rev-parse HEAD)" 2>/dev/null
# fedxps's copy carries the same HEAD without a fetch: copy the objects and ref as Syncthing would
rm -rf "$SB/ssh/fedxps/home/Desktop/nousowl"; cp -a "$HOME/Desktop/nousowl" "$SB/ssh/fedxps/home/Desktop/nousowl"
out=$(run push nousowl)
check "one unpushed commit, with its age"    has "$out" 'HEAD equal on fedxps; origin/main last moved [0-9]+ s ago; 1 commit unpushed, the oldest [0-9]+ s old'
echo "== push: the refusals =="
git -C "$SB/ssh/fedxps/home/Desktop/nousowl" commit -q --allow-empty -m "fedxps-only"
out=$(run push nousowl); r=$(rc push nousowl)
check "HEAD differs on fedxps: FAIL"         has "$out" '^\[FAIL\] nousowl: HEAD differs on fedxps \([0-9a-f]{7} here, [0-9a-f]{7} there\)'
check "  fix: the split repair"              has "$out" 'a split of main: do not push'
check "  exit 1"                             is "$r" 1
rm -rf "$SB/ssh/fedxps/home/Desktop/nousowl"; cp -a "$HOME/Desktop/nousowl" "$SB/ssh/fedxps/home/Desktop/nousowl"
touch "$SB/ssh/fedxps/down"
out=$(run push nousowl); r=$(rc push nousowl)
check "fedxps silent: the comparison is skipped, said so, still OK" has "$out" "fedxps did not answer: HEAD comparison skipped, the hub's view of it stands"
check "  exit 0"                             is "$r" 0
rm "$SB/ssh/fedxps/down"
echo "== push: the other workstation answers, but not with a HEAD (review 3b-1) =="
git -C "$SB/ssh/fedxps/home/Desktop/nousowl" symbolic-ref HEAD refs/heads/gone
out=$(run push nousowl); r=$(rc push nousowl)
check "fedxps answers and git there has no HEAD: WARN, not 'did not answer'" has "$out" '^\[WARN\] nousowl: fedxps answered but gave no HEAD'
check "  exit 2"                             is "$r" 2
git -C "$SB/ssh/fedxps/home/Desktop/nousowl" symbolic-ref HEAD refs/heads/main
git -C "$SB/ssh/fedxps/home/Desktop/nousowl" commit -q --allow-empty -m "fedxps-only"
out=$(STUB_SSH_BANNER='Last login: Sat Oct 10 12:00:00 2026' run push nousowl)
check "a differing HEAD behind a shell banner still FAILs" has "$out" '^\[FAIL\] nousowl: HEAD differs on fedxps'
rm -rf "$SB/ssh/fedxps/home/Desktop/nousowl"; cp -a "$HOME/Desktop/nousowl" "$SB/ssh/fedxps/home/Desktop/nousowl"
export STUB_SSH_STDIN="$SB/ssh-stdin"; : > "$STUB_SSH_STDIN"
printf 'y\ny\n' | "$GAUGE" push nousowl >/dev/null 2>&1
check "the HEAD read hands ssh no stdin (gpush's prompts keep their keys)" is "$(wc -c < "$STUB_SSH_STDIN")" 0
unset STUB_SSH_STDIN
mkdir -p "$SB/elsewhere"; git clone -q "$SB/origin-nousowl.git" "$SB/elsewhere/nousowl" 2>/dev/null
cp "$HOME/Desktop/nousowl/.git/refs/heads/main" "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-GE3DRZ3"
out=$(cd "$SB/elsewhere" && run push nousowl)
check "a bare name is ~/Desktop's repository wherever it is typed" has "$out" '^\[FAIL\] nousowl: 1 phantom ref'
rm "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-GE3DRZ3"
printf 'garbage line\n' > "$HOME/Desktop/nousowl/.git/packed-refs"
out=$(run push nousowl)
check "refs git cannot list: WARN, not 'no phantom ref'" has "$out" '^\[WARN\] nousowl: git cannot list the repository.s refs'
rm "$HOME/Desktop/nousowl/.git/packed-refs"
scenario 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=[".git/refs/heads/main"]' 'nousowl.folders.f2.completion.BIG.needItems=1'
out=$(run push nousowl); r=$(rc push nousowl)
check "a path under .git needed: FAIL"       has "$out" '^\[FAIL\] nousowl: 1 path under its .git needed: bigfed -> hub .git/refs/heads/main'
check "  fix: touch exactly those paths on fedxps" has "$out" 'on fedxps, touch exactly these paths'
check "  exit 1"                             is "$r" 1
out=$(run push -q nousowl); r=$(rc push -q nousowl)
check "-q never hides a FAIL: the .git line still printed (review 3b-2's survivor m14)" has "$out" '^\[FAIL\] nousowl: 1 path under its \.git needed'
check "  exit 1 under -q"                    is "$r" 1
scenario 'fedxps.folders.f2.completion.HUB.needItems=1' 'fedxps.folders.f2.completion.HUB.names=[".git/refs/heads/main"]' 'nousowl.folders.f2.completion.FED.needItems=1'
out=$(run push nousowl); r=$(rc push nousowl)
check "a path under .git stranded on fedxps, named from fedxps's own view: FAIL" has "$out" '^\[FAIL\] nousowl: 1 path under its \.git needed: fedxps -> hub \.git/refs/heads/main'
check "  fix: a reader's write, fedxps-3 and 4"  has "$out" 'rules.md -> fedxps-3, fedxps-4'
check "  exit 1"                             is "$r" 1
scenario 'nousowl.folders.f2.completion.FED.needItems=3' 'nousowl.connected.FED=false'; touch "$SB/ssh/fedxps/down"
out=$(run push -v nousowl); r=$(rc push nousowl)
check "fedxps asleep with items for it at the hub: what it lacks is not a refusal (bigfed-2's letter)" has "$out" '^\[ OK \] nousowl: folder nousowl up to date, nothing under .git needed, no phantom ref; fedxps did not answer: HEAD comparison skipped'
check "  the note says what waits for it"    has "$out" 'fedxps is offline: 3 items wait for it at the hub'
check "  no WARN"                            lacks "$out" '^\[WARN\]'
check "  exit 0"                             is "$r" 0
rm -f "$SB/ssh/fedxps/down"
scenario 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=["notes.txt"]' 'nousowl.folders.f2.completion.BIG.needItems=1'
out=$(run push nousowl); r=$(rc push nousowl)
check "a stranded path outside .git still fails ws-1" has "$out" '^\[FAIL\] nousowl: stranded on bigfed: notes.txt'
check "  not reported as under .git"         lacks "$out" 'under its .git'
check "  exit 1"                             is "$r" 1
scenario
# the phantom as Syncthing makes it: a ref file under a conflict name, no reflog
cp "$HOME/Desktop/nousowl/.git/refs/heads/main" "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-GE3DRZ3"
out=$(run push nousowl); r=$(rc push nousowl)
check "a phantom ref: FAIL, the ref and its file both named" has "$out" '^\[FAIL\] nousowl: 1 phantom ref and 1 conflict copy under .git'
check "  listed"                             has "$out" 'refs/heads/main.sync-conflict-20261009-162229-GE3DRZ3'
check "  fix: rename, commit the tree, never delete the file first" has "$out" 'never delete a \*sync-conflict\* file before renaming the ref'
check "  exit 1"                             is "$r" 1
rm "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-GE3DRZ3"
echo x > "$HOME/Desktop/nousowl/.git/index.sync-conflict-20261009-162229-GE3DRZ3"
out=$(run push nousowl)
check "a conflict copy under .git: FAIL"     has "$out" '^\[FAIL\] nousowl: 0 phantom refs and 1 conflict copy under .git'
rm "$HOME/Desktop/nousowl/.git/index.sync-conflict-20261009-162229-GE3DRZ3"
scenario 'bigfed.folders.f2.state="syncing"'
out=$(run push nousowl); r=$(rc push nousowl)
check "the folder still syncing: no OK, exit 1" is "$r" 1
check "  WAIT shown"                         has "$out" '^\[WAIT\] nousowl: syncing on this machine'
check "  the age line only verbose"          lacks "$out" 'origin/main last moved'
scenario; touch "$SB/ssh/nousowl/down"
out=$(run push nousowl); r=$(rc push nousowl)
check "the hub silent: WARN, exit 2"         is "$r" 2
check "  the WARN names the hub"             has "$out" "nousowl's view unread"
rm "$SB/ssh/nousowl/down"
out=$(run push nowhere); r=$(rc push nowhere)
check "not a repository: FAIL"               has "$out" '^\[FAIL\] nowhere: not a git repository'
check "  exit 1"                             is "$r" 1
out=$(run push); r=$(rc push)
check "no name: WARN, exit 2"                is "$r" 2
echo "== push: a repository under a marker no configuration names; the search order (review 3b-2) =="
be bigfed; scenario
mkdir -p "$HOME/Desktop/org/.stfolder"
out=$(SYNC_CHECK_CONFIG="$SB/nowhere.xml" run push -q org); r=$(SYNC_CHECK_CONFIG="$SB/nowhere.xml" rc push -q org)
check "no config.xml, a marker at the repository: WARN, never a silent pass" has "$out" '^\[WARN\] org: Syncthing carries it \(the folder marker at ~/Desktop/org\), but no config.xml was found'
check "  exit 2"                             is "$r" 2
out=$(run push -q org); r=$(rc push -q org)
check "a marker the configuration does not name: WARN" has "$out" 'names no folder there'
check "  exit 2"                             is "$r" 2
rmdir "$HOME/Desktop/org/.stfolder"
mkdir -p "$HOME/.config/syncthing" "$HOME/.local/state/syncthing"
cp "$SYNC_CHECK_CONFIG" "$HOME/.config/syncthing/config.xml"
python3 - "$SYNC_CHECK_CONFIG" "$HOME/.local/state/syncthing/config.xml" <<'PY'
import re, sys
s = open(sys.argv[1]).read(); s = re.sub(r'    <folder id="f2".*?</folder>\n', '', s, flags=re.S); open(sys.argv[2], "w").write(s)
PY
out=$(env -u SYNC_CHECK_CONFIG "$GAUGE" push nousowl 2>&1)
check "with no SYNC_CHECK_CONFIG, ~/.config's copy is read before the state directory's (Syncthing's order)" has "$out" '^\[ OK \] nousowl: folder nousowl up to date'
rm -rf "$HOME/.config/syncthing" "$HOME/.local/state/syncthing"
echo x > "$HOME/Desktop/nousowl/.git/index.sync-conflict-20261009-162229-GE3DRZ3"
mkdir -p "$HOME/Desktop/nousowl/docs"
out=$(run push "$HOME/Desktop/nousowl/docs"); r=$(rc push "$HOME/Desktop/nousowl/docs")
check "a name inside the repository means the repository: the copy under .git found" has "$out" '^\[FAIL\] nousowl: 0 phantom refs and 1 conflict copy under .git'
check "  exit 1"                             is "$r" 1
rm "$HOME/Desktop/nousowl/.git/index.sync-conflict-20261009-162229-GE3DRZ3"; rmdir "$HOME/Desktop/nousowl/docs"
scenario 'nousowl.extra_devices=[{"id":"PIXELXX-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG","name":"pixel"},{"id":"EVILXXX-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG","name":"-oProxyCommand=touch pwned"}]'
out=$(run push nousowl); r=$(rc push nousowl)
check "devices the hub knows but that are on no folder are never ssh hosts (1/2)" lacks "$(cat "$SB/ssh.log")" '^pixel:'
check "devices the hub knows but that are on no folder are never ssh hosts (2/2)" lacks "$(cat "$SB/ssh.log")" 'ProxyCommand'
check "  the push still reads OK"            is "$r" 0

echo "== push: from fedxps, which reads nousowl =="
be fedxps; scenario; export GIT_OPTIONAL_LOCKS=0
out=$(run push nousowl); r=$(rc push nousowl)
check "refused: fedxps reads it"             has "$out" '^\[FAIL\] nousowl: fedxps reads this repository and does not push it'
check "  fix: push from bigfed, with the remote form" has "$out" "fix: push from bigfed: gpush nousowl there, or from here: ssh -t bigfed 'bash -ic \"gpush nousowl\"'"
check "  exit 1"                             is "$r" 1
check "  nothing read from the daemon for it" lacks "$(reqs fedxps)" 'db/'
out=$(run push org); r=$(rc push org)
check "org is still fedxps's to push today: OK" has "$out" '^\[ OK \] org: in no Syncthing folder'
check "  exit 0"                             is "$r" 0
printf '[gsync]\n\trole = reader\n' > "$HOSTS_FED/fedxps.inc"
out=$(run push org); r=$(rc push org)
check "under role = reader every repository is refused, in a folder or not" has "$out" '^\[FAIL\] org: fedxps reads this repository and does not push it'
check "  exit 1"                             is "$r" 1
chmod 000 "$HOSTS_FED/fedxps.inc"
check "a host file that cannot be read: a reader, warned" has "$(run guard)" '^\[WARN\] host file .*fedxps\.inc exists but cannot be read: a reader until it is fixed'
chmod 644 "$HOSTS_FED/fedxps.inc"; printf '%b' "$FEDINC" > "$HOSTS_FED/fedxps.inc"

# ==============================================================================
echo "== all lines at once, and nothing written =="
be fedxps; scenario; export GIT_OPTIONAL_LOCKS=0
snap() { find "$SB/ssh" -path '*/requests.log' -prune -o -printf '%p %i %T@ %s\n' | sort | md5sum; }
before=$(snap)
out=$(run -v); r=$(rc)
after=$(snap)
check "the default runs sync (1/3)"          has "$out" 'alpha: up to date'
check "the default runs conflicts (2/3)"     has "$out" 'under .git: no conflict copy'
check "the default runs guard (3/3)"         has "$out" 'host.inc ->'
check "  exit 0"                             is "$r" 0
check "every file in both homes byte-for-byte and inode-for-inode as before (.git included)" is "$before" "$after"
check "unknown line: exit 2"                 is "$(rc nonsense)" 2
head -c 300 "$SYNC_CHECK_CONFIG" > "$SB/trunc.xml"
out=$(SYNC_CHECK_CONFIG="$SB/trunc.xml" run sync); r=$(SYNC_CHECK_CONFIG="$SB/trunc.xml" rc sync)
check "a config.xml the parser rejects: one WARN line, no traceback (review 3b-1)" has "$out" '^\[WARN\] sync-check could not finish: ParseError'
check "  exit 2"                             is "$r" 2
check "-h: exits 0 and names the four lines" bash -c "'$GAUGE' -h | grep -q 'sync-check push REPO'"

# ==============================================================================
echo "== live: the real gauge on this machine, read-only; tags and exit status agree =="
unset SYNC_CHECK_CONFIG STUB_HOST_FILE; export HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"; PATH="${PATH#"$SB/stub:"}"; hash -r
if [ "$LIVE_GOL" = __unset__ ]; then unset GIT_OPTIONAL_LOCKS; else export GIT_OPTIONAL_LOCKS="$LIVE_GOL"; fi
unset GIT_CONFIG_NOSYSTEM
for line in conflicts guard; do
  out=$("$GAUGE" "$line" 2>&1); r=$?
  if grep -qE '^\[(FAIL|WAIT|DUE)\]' <<<"$out"; then want=1; elif grep -q '^\[WARN\]' <<<"$out"; then want=2; else want=0; fi
  check "live $line: exit $r matches its tags" is "$r" "$want"
done

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
