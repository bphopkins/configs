#!/usr/bin/env bash
# Regression suite for bin/sync-check, the transport campaign's gauge
# (org/machines/transport-2026-10/rules.md: ws-1, ws-2, fedxps-3, bigfed-2;
# built 2026-10-10 at the pilot's step 3b, pilot/build-gauge.md there).
#
# Nothing real is reached: three fixture Syncthing instances -- fedxps, bigfed
# and the hub nousowl -- are Python HTTP servers on loopback answering from
# per-case JSON (fixture-server.py), each with a config.xml the gauge parses
# as it would the real one (scenario.py writes both from one spec with dotted
# overrides; the database's per-file records, db/browse and db/file, from the
# same spec); a stub ssh runs the gauge's own remote modes, or the peer's git,
# in that host's sandbox home against that host's fixture, or refuses a door
# marked down (down: both; down-lan, down-vpn, hang-lan: one; no-vpn: the
# alias missing); a stub uname names the machine. The hub's remote mode meets
# stub btrfs, df and systemctl answering from SB/hubfx, and a sandbox
# process standing in for its daemon; a stub ps gives the writer's process
# table. Each workstation home carries a small configs checkout stowed by the
# real stow, a lazy lock over tiny plugin repositories, and a claude-link stub.
# The repositories are local clones under the sandbox homes.
# GIT_OPTIONAL_LOCKS is set per case. Caged (tests/cage.sh), with room for
# about 150 s of gauge runs. The settle is shortened through
# SYNC_CHECK_SETTLE and SYNC_CHECK_POLL. The last section runs the real
# gauge's conflicts and guard lines on this machine, read-only, and asserts
# only that tags and exit status agree.
#
# Run after any edit to bin/sync-check (~2.5 min). SYNC_CHECK=<path> runs the
# suite against another copy of the gauge, which is how it was mutation-tested
# (the breaks are listed in pilot/build-gauge.md) and how each case added at
# step 5a was shown to fail against the gauge before it. Last line follows the
# tests/gsync convention: "passed: N  failed: M"; exit 0 iff nothing failed.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$CFG_ROOT/tests/cage.sh"
CAGE_RUNTIME_MAX_SEC=400
cage sync-check "$@"

HERE="$CFG_ROOT/tests/sync-check"
GAUGE="${SYNC_CHECK:-$CFG_ROOT/bin/sync-check}"
for t in python3 git find stow; do command -v "$t" >/dev/null 2>&1 || {
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
# home, against that host's Syncthing fixture; records every call, and each
# door's ConnectTimeout. <host>-vpn is the same host's second door: down-lan
# refuses <host>, hang-lan holds it for its ConnectTimeout first, hang-cmd-lan
# connects and then never answers, down-vpn
# refuses <host>-vpn, no-vpn leaves the alias undefined, down refuses both.
host="" ct=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) case "$2" in ConnectTimeout=*) ct=${2#ConnectTimeout=} ;; esac; shift 2 ;;
    -p|-i|-l|-F) shift 2 ;; -*) shift ;; *) host=$1; shift; break ;;
  esac
done
printf '%s: %s\n' "$host" "$*" >>"$STUB_SSH_LOG"
printf '%s ConnectTimeout=%s\n' "$host" "$ct" >>"$STUB_SSH_LOG.doors"
base=${host%-vpn}
d="$STUB_SSH_DIR/$base"
[ -d "$d" ] || { echo "ssh: Could not resolve hostname $host: Name or service not known" >&2; exit 255; }
if [ "$base" != "$host" ]; then
  [ -e "$d/no-vpn" ] && { echo "ssh: Could not resolve hostname $host: Name or service not known" >&2; exit 255; }
  [ -e "$d/down-vpn" ] && { echo "ssh: connect to host $host port 22: No route to host" >&2; exit 255; }
else
  [ -e "$d/down-lan" ] && { echo "ssh: connect to host $host port 22: Connection timed out" >&2; exit 255; }
  [ -e "$d/hang-lan" ] && { sleep "${ct:-8}"; echo "ssh: connect to host $host port 22: Connection timed out" >&2; exit 255; }
  [ -e "$d/hang-cmd-lan" ] && exec sleep 120      # connected, then the command hangs
fi
[ -e "$d/down" ] && { echo "ssh: connect to host $host port 22: No route to host" >&2; exit 255; }
if [ -n "${STUB_SSH_STDIN:-}" ] && [[ "$*" != *--remote-* ]]; then cat >> "$STUB_SSH_STDIN"; fi
[ -n "${STUB_SSH_BANNER:-}" ] && echo "$STUB_SSH_BANNER"     # a shell rc that echoes
export HOME="$d/home" SYNC_CHECK_CONFIG="$d/config.xml"
exec bash -c "$*"
STUB
# The hub's own readings (sync-check hub): btrfs, df and systemctl answer from
# SB/hubfx; ps from SB/ps-procs. Nothing real is read: the hub's unit and its
# daemon are the files and the stand-in processes below.
cat >"$SB/stub/btrfs" <<'STUB'
#!/bin/sh
echo "$*" >> "$HUBFX/btrfs.log"
[ -e "$HUBFX/btrfs-fail" ] && { echo "ERROR: not a btrfs filesystem: $4" >&2; exit 1; }
printf 'Overall:\n    Device size:\t\t       34359738368\n    Device unallocated:\t\t       27363639296\n'
printf '    Free (estimated):\t\t       %s\t(min: 14867030016)\n' "$(cat "$HUBFX/free" 2>/dev/null || echo 28548849664)"
printf '    Free (statfs, df):\t\t       28547801088\n    Data ratio:\t\t\t              1.00\n'
echo "WARNING: cannot read detailed chunk info, per-device usage will not be shown, run as root" >&2
STUB
cat >"$SB/stub/df" <<'STUB'
#!/bin/sh
[ -e "$HUBFX/df-fail" ] && { echo "df: cannot read" >&2; exit 1; }
printf '      Avail\n%s\n' "$(cat "$HUBFX/df-free" 2>/dev/null || echo 28547801088)"
STUB
cat >"$SB/stub/systemctl" <<'STUB'
#!/bin/sh
# systemctl [--user] show -p ... UNIT: the unit's Key=Value lines from
# HUBFX/unit-system or HUBFX/unit-user; anything else refused
scope=system
for a in "$@"; do [ "$a" = --user ] && scope=user; done
for a in "$@"; do unit=$a; done
echo "$scope $unit" >> "$HUBFX/systemctl.log"
case " $* " in *" show "*) ;; *) exit 1 ;; esac
if [ -e "$HUBFX/unit-$scope" ]; then cat "$HUBFX/unit-$scope"; else printf 'LoadState=not-found\nActiveState=inactive\nMainPID=0\n'; fi
STUB
cat >"$SB/stub/ps" <<'STUB'
#!/bin/sh
[ -e "$PS_FAIL" ] && exit 1
echo "    PID COMMAND"
cat "$PS_PROCS" 2>/dev/null
exit 0
STUB
chmod +x "$SB/stub/uname" "$SB/stub/ssh" "$SB/stub/btrfs" "$SB/stub/df" "$SB/stub/systemctl" "$SB/stub/ps"
export STUB_HOST_FILE="$SB/host" STUB_SSH_DIR="$SB/ssh" STUB_SSH_LOG="$SB/ssh.log" HUBFX="$SB/hubfx" PS_PROCS="$SB/ps-procs" PS_FAIL="$SB/ps-fail"
PATH="$SB/stub:$PATH"; hash -r
mkdir -p "$HUBFX" "$SB/ssh/nousowl/home/sync" "$SB/ssh/nousowl/index-v2"
printf 'stand-in for the index\n' > "$SB/ssh/nousowl/index-v2/index.db"
# the hub's daemon, twice: started with the drop-in's variable, and without it
env STDBDELETERETENTIONINTERVAL=0 sleep 3600 & RET_PID=$!; SERVERS+=($RET_PID)
env -u STDBDELETERETENTIONINTERVAL sleep 3600 & BARE_PID=$!; SERVERS+=($BARE_PID)
ME_USER="$(id -un)"
unit_props() { # $1 MainPID, $2 the drop-in paths
  printf 'LoadState=loaded\nActiveState=active\nMainPID=%s\nDropInPaths=%s\nEnvironment=STLOGFORMATTIMESTAMP= STDBDELETERETENTIONINTERVAL=0\n' "$1" "$2"
}
DROPINS="/usr/lib/systemd/system/service.d/10-timeout-abort.conf /etc/systemd/system/syncthing@$ME_USER.service.d/30-delete-retention.conf /etc/systemd/system/syncthing@$ME_USER.service.d/override.conf"
hubfx_reset() {
  rm -f "$HUBFX"/btrfs-fail "$HUBFX"/df-fail "$HUBFX"/free "$HUBFX"/df-free "$HUBFX"/unit-user "$SB/ssh/nousowl/index-v2/big" "$PS_PROCS" "$PS_FAIL"
  : > "$HUBFX/btrfs.log"; : > "$HUBFX/systemctl.log"
  unit_props "$RET_PID" "$DROPINS" > "$HUBFX/unit-system"
}
hubfx_reset

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

# a configs checkout in each workstation home, stowed by the real stow
# (ws-8's config line): three packages in 60-stow.sh's map and one the map
# names that the checkout lacks; a lazy lock over three tiny plugin
# repositories, two installed; a claude-link stub answering $STUB_CL_RC
mkconfig() {
  local H=$1 C="$1/Desktop/configs" p
  mkdir -p "$C/bash/.bashrc.d" "$C/tool/themes" "$C/bin" "$C/nvim" "$H/.config/tool" "$H/bin"
  printf '# rc\n[[ $- != *i* ]] && return\n' > "$C/bash/.bashrc"
  printf '# profile\n' > "$C/bash/.bash_profile"
  printf 'export X=1\n' > "$C/bash/.bashrc.d/10-env.sh"
  cat > "$C/bash/.bashrc.d/60-stow.sh" <<'EOF'
declare -A STOW_TARGETS=(
  [bash]="$HOME"
  [tool]="$HOME/.config/tool"
  # a comment between entries
  [bin]="$HOME/bin"
  [absent]="$HOME/.config/absent"
)
EOF
  cp "$CFG_ROOT/bash/.stow-global-ignore" "$C/bash/.stow-global-ignore"
  echo charter > "$C/bash/CLAUDE.md"; echo charter > "$C/tool/CLAUDE.md"
  printf 'a = 1\n' > "$C/tool/config"; printf 't\n' > "$C/tool/themes/one"
  printf '#!/bin/sh\necho "$0|$*" >> "$STUB_CL_LOG"\necho "claude-link -- dry run"\necho "  [LINK] would link x"\n[ -n "$STUB_CL_LINE" ] && echo "  $STUB_CL_LINE"\necho "== summary =="\necho "  already correct : 3"\nexit "${STUB_CL_RC:-0}"\n' > "$C/bin/claude-link"
  chmod +x "$C/bin/claude-link"
  ln -s Desktop/configs/bash/.stow-global-ignore "$H/.stow-global-ignore"
  (cd "$C" && HOME="$H" stow -t "$H" bash && HOME="$H" stow -t "$H/.config/tool" tool && HOME="$H" stow -t "$H/bin" bin) || return 1
  for p in alpha.nvim beta.nvim gamma.nvim; do
    git init -q -b main "$SB/plugin-src/$p"; git -C "$SB/plugin-src/$p" commit -q --allow-empty -m one
  done
  mkdir -p "$H/.local/share/nvim/lazy"
  for p in alpha.nvim beta.nvim; do git clone -q "$SB/plugin-src/$p" "$H/.local/share/nvim/lazy/$p"; done
  python3 - "$SB/plugin-src" "$C/nvim/lazy-lock.json" <<'PY2'
import json, subprocess, sys
src, out = sys.argv[1:3]
lock = {p: {"branch": "main", "commit": subprocess.check_output(["git", "-C", src + "/" + p, "rev-parse", "HEAD"], text=True).strip()}
        for p in ("alpha.nvim", "beta.nvim", "gamma.nvim")}
open(out, "w").write(json.dumps(lock, indent=2) + "\n")
PY2
  rm -rf "$SB/plugin-src"
}
for h in fedxps bigfed; do mkconfig "$SB/ssh/$h/home" || { echo "sync-check tests: the sandbox configs checkout could not be stowed -- not running" >&2; echo "passed: 0  failed: 1"; exit 2; }; done
export STUB_CL_LOG="$SB/claude-link.log"

be() { printf '%s\n' "$1" > "$SB/host"; ME=$1; export HOME="$SB/ssh/$1/home" SYNC_CHECK_CONFIG="$SB/ssh/$1/config.xml"; }
# a scenario.py that fails leaves the previous case's fixtures in place, so it
# is a failure of its own, never a silent stale case (2026-10-27)
scenario() { python3 "$HERE/scenario.py" "$SB" "$ME" "$@" || { echo "FAIL - scenario.py could not write the fixtures for: $*"; ((fail+=1)); }; : > "$SB/ssh.log"; : > "$SB/ssh.log.doors"; for h in fedxps bigfed nousowl; do : > "$SB/fx/$h/requests.log"; rm -f "$SB/ssh/$h"/down "$SB/ssh/$h"/down-lan "$SB/ssh/$h"/down-vpn "$SB/ssh/$h"/hang-lan "$SB/ssh/$h"/hang-cmd-lan "$SB/ssh/$h"/no-vpn; done; hubfx_reset; }
run() { "$GAUGE" "$@" 2>&1; }
rc() { "$GAUGE" "$@" >/dev/null 2>&1; echo $?; }
reqs() { cat "$SB/fx/$1/requests.log"; }
# The KNOWN_WRITES entries a vector FAIL prints (settled 79), each parsed as the
# Python literal it must be once pasted: "on label counter since" per line, or a
# traceback (and so no match) when one does not parse or has other keys.
literals() { python3 -I -c '
import ast, sys
for line in sys.stdin.read().splitlines():
    if line.startswith("       {") and line.endswith("},"):
        d = ast.literal_eval(line.strip()[:-1])
        assert isinstance(d, dict) and list(d) == ["on", "label", "counter", "since", "note"], d
        assert type(d["counter"]) is int and d["note"].startswith("<why: "), d
        print("%s %s %d %s" % (d["on"], d["label"], d["counter"], d["since"]))
' <<<"$1" 2>&1; }
# a copy of the gauge with the entries a run printed pasted into KNOWN_WRITES as printed
paste_known() { python3 -I - "$GAUGE" "$2" "$1" <<'PY'
import sys
src, dst, printed = sys.argv[1:4]
t = open(src).read()
lines = [l + "\n" for l in printed.splitlines() if l.startswith("       {") and l.endswith("},")]
assert lines and t.count("\nKNOWN_WRITES = [\n") == 1
open(dst, "w").write(t.replace("\nKNOWN_WRITES = [\n", "\nKNOWN_WRITES = [\n" + "".join(lines), 1))
PY
chmod +x "$2"; }

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
check "  outside any .git: today's repair, the edit" has "$out" "fix: both workstations listing the same path towards the hub means the hub holds a conflict's loser: edit the file once more on the machine whose text is in the conflict copy \(the one whose counter the current version lacks\) and read again \(org/machines/transport-2026-10/rules.md -> him-2\)$"
# under a .git the write is the sanctioned touch, never an edit (settled 79;
# the lead's follow-up, 2026-10-27)
scenario 'fedxps.folders.f2.needTotalItems=2' 'fedxps.folders.f2.needNames=[".git/index",".git/refs/heads/main"]'
out=$(run sync)
check "a need under .git alone: the touch, never an edit" has "$out" "fix: both workstations listing the same path towards the hub means the hub holds a conflict's loser: touch \.git/index, \.git/refs/heads/main on the machine whose counter the current version lacks \(never edit a \.git path\) and read again \(org/machines/transport-2026-10/rules.md -> him-2\)$"
check "  no edit in it"                       lacks "$(grep -A1 'do not arrive' <<<"$out")" 'edit the file|edit \.git'
scenario 'fedxps.folders.f2.needTotalItems=2' 'fedxps.folders.f2.needNames=["notes.txt",".git/index"]'
check "a need mixed: each clause names its paths, the edit outside .git, the touch under it" has "$(run sync)" "conflict's loser: edit notes\.txt once more on the machine whose text is in the conflict copy \(the one whose counter the current version lacks\) and read again; touch \.git/index on the machine whose counter the current version lacks \(never edit a \.git path\) and read again \(org/machines/transport-2026-10/rules.md -> him-2\)$"

echo "== sync: the known stuck item, named, reads OK; anything else fails =="
# KNOWN is empty since its last item was repaired (2026-10-11), so these cases run on a copy of the
# gauge carrying a stand-in entry, the repaired one's; the substitution must match once.
KGAUGE="$SB/sync-check-known"
python3 -I - "$GAUGE" "$KGAUGE" <<'PY' || { echo "sync-check tests: no 'KNOWN = [' line to insert the stand-in after -- not running" >&2; exit 2; }
import sys
src, dst = sys.argv[1:3]
t = open(src).read()
assert t.count("\nKNOWN = [\n") == 1
open(dst, "w").write(t.replace("\nKNOWN = [\n", '\nKNOWN = [\n    {"label": "adelotype-data", "on": "bigfed", "path": "log", "since": "2026-09-30",\n     "note": "a stand-in: the item repaired 2026-10-11"},\n', 1))
PY
chmod +x "$KGAUGE"
REAL_GAUGE=$GAUGE GAUGE=$KGAUGE
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
check "  exit 3: up to date, attention due (settled 37)" is "$r" 3
check "  the other folders OK, the label alone decides" has "$out" '^\[ OK \] alpha: up to date'
GAUGE=$REAL_GAUGE
scenario "$K"; touch "$SB/ssh/nousowl/down"
check "  with the hub unread, no such verdict" lacks "$(run sync)" 'no longer shows'
scenario 'fedxps.folders.f1.watchError="failed to setup inotify handler. Please increase inotify limits"'
out=$(run sync); r=$(rc sync)
check "a dead watcher: DUE, up to date but seen only by scans" has "$out" '^\[DUE\] alpha: up to date; the watcher reports: failed to setup inotify'
check "  fix names the inotify limit"        has "$out" 'fs.inotify.max_user_watches'
check "  exit 3"                             is "$r" 3
# a DUE decides only alone: beside a WARN the run is 2, beside a FAIL 1
scenario 'fedxps.folders.f1.watchError="failed to setup inotify handler. Please increase inotify limits"' 'nousowl.folders.f3.completion.BIG.needItems=1'; touch "$SB/ssh/bigfed/down"
out=$(run sync); r=$(rc sync)
check "a DUE beside a WARN: both shown"      has "$out" '^\[WARN\] gamma: 1 item at the hub for bigfed, unverified'
check "  the DUE too"                        has "$out" '^\[DUE\] alpha: up to date; the watcher reports'
check "  exit 2: the WARN decides"           is "$r" 2
scenario 'fedxps.folders.f1.watchError="failed to setup inotify handler. Please increase inotify limits"' 'fedxps.folders.f2.needTotalItems=2' 'fedxps.folders.f2.needNames=["a.txt","b.txt"]'
out=$(run sync); r=$(rc sync)
check "a DUE beside a FAIL: both shown"      has "$out" '^\[FAIL\] nousowl: needs 2 items that do not arrive'
check "  the DUE too"                        has "$out" '^\[DUE\] alpha: up to date; the watcher reports'
check "  exit 1: the FAIL decides"           is "$r" 1

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
out=$(run sync)
check "the other workstation needing what does not arrive: FAIL, named" has "$out" '^\[FAIL\] alpha: bigfed needs 1 item that do not arrive: late.md'
check "  outside any .git: today's repair, the edit" has "$out" "fix: the hub may hold a conflict's loser: edit the file once more on the machine whose text is in the conflict copy \(org/machines/transport-2026-10/rules.md -> him-2\)$"
scenario 'nousowl.folders.f1.completion.BIG.needItems=1' 'bigfed.folders.f1.needTotalItems=1' 'bigfed.folders.f1.needNames=["sub/.git/index"]'
check "the other workstation needing a .git path: the touch, never an edit (settled 79)" has "$(run sync)" "fix: the hub may hold a conflict's loser: touch sub/\.git/index on the machine whose counter the current version lacks \(never edit a \.git path\) \(org/machines/transport-2026-10/rules.md -> him-2\)$"
scenario 'nousowl.folders.f1.completion.BIG.needItems=2' 'bigfed.folders.f1.needTotalItems=2' 'bigfed.folders.f1.needNames=["late.md","sub/.git/index"]'
check "  mixed: each clause names its paths" has "$(run sync)" "fix: the hub may hold a conflict's loser: edit late\.md once more on the machine whose text is in the conflict copy; touch sub/\.git/index on the machine whose counter the current version lacks \(never edit a \.git path\) \(org/machines/transport-2026-10/rules.md -> him-2\)$"
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
check "  edit once more on the losing machine" has "$out" 'edit the file once more on the machine whose text is in the conflict copy'
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
echo x > "$N/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
touch -d '20 minutes ago' "$N/.git/index.lock"
touch "$N/.git/fresh.lock"
mkdir -p "$HOME/Desktop/org/claude-config/rules" "$HOME/Desktop/configs/environment.d" "$HOME/Desktop/other/rules"
echo r > "$HOME/Desktop/org/claude-config/rules/house.sync-conflict-20261009-195347-HIJKLMN.md"
echo e > "$HOME/Desktop/configs/environment.d/10-x.sync-conflict-20261009-195347-HIJKLMN.conf"
echo o > "$HOME/Desktop/other/rules/notes.sync-conflict-20261009-195347-HIJKLMN.md"
echo d > "$HOME/.local/share/adelotype/log/fedxps.sync-conflict-20261009-195347-HIJKLMN.jsonl"
out=$(run conflicts); r=$(rc conflicts)
check "under .git: one copy and one stale lock" has "$out" '^\[FAIL\] under a .git: 1 conflict copy and 1 lock file older than 10 min'
check "  the phantom ref listed with its time" has "$out" 'main.sync-conflict-20261009-162229-ABCDEFG  20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]'
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
rm -f "$N/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG" "$N/.git/index.lock" "$N/.git/fresh.lock"
rm -rf "$HOME/Desktop/org/claude-config" "$HOME/Desktop/configs/environment.d" "$HOME/Desktop/other" "$HOME/.local/share/adelotype/log/fedxps.sync-conflict-20261009-195347-HIJKLMN.jsonl"
echo o > "$HOME/Desktop/alpha/notes.sync-conflict-20261009-195347-HIJKLMN.md"
out=$(run conflicts); r=$(rc conflicts)
check "one copy elsewhere alone: DUE and exit 3" is "$r" 3
check "  the other two lines OK"             is "$(grep -c '^\[ OK \]' <<<"$out")" 2
rm -f "$HOME/Desktop/alpha/notes.sync-conflict-20261009-195347-HIJKLMN.md"
mkdir -p "$HOME/Desktop/locked"; echo x > "$HOME/Desktop/locked/notes.sync-conflict-20261009-195347-HIJKLMN.md"; chmod 000 "$HOME/Desktop/locked"
out=$(run conflicts); r=$(rc conflicts)
check "a directory find cannot enter: WARN, never a clean sweep (review 3b-1)" has "$out" '^\[WARN\] the sweep could not read everything'
check "  exit 2"                             is "$r" 2
chmod 755 "$HOME/Desktop/locked"; rm -rf "$HOME/Desktop/locked"
printf 'x' > "$HOME/Desktop/alpha/odd$(printf '\n')name.sync-conflict-20261009-195347-HIJKLMN.md"
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
scenario 'bigfed.folders.f2.watchError="failed to setup inotify handler. Please increase inotify limits"'
out=$(run push nousowl); r=$(rc push nousowl)
check "a DUE alone on the folder: the push line's own checks run and its OK line prints (settled 37)" has "$out" '^\[ OK \] nousowl: folder nousowl up to date, nothing under .git needed, no phantom ref; HEAD equal on fedxps'
check "  the DUE shown"                      has "$out" '^\[DUE\] nousowl: up to date; the watcher reports'
check "  exit 3"                             is "$r" 3
cp "$HOME/Desktop/nousowl/.git/refs/heads/main" "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
out=$(run push nousowl); r=$(rc push nousowl)
check "a DUE never excuses a phantom ref: FAIL" has "$out" '^\[FAIL\] nousowl: 1 phantom ref'
check "  exit 1"                             is "$r" 1
rm "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
scenario
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
cp "$HOME/Desktop/nousowl/.git/refs/heads/main" "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
out=$(cd "$SB/elsewhere" && run push nousowl)
check "a bare name is ~/Desktop's repository wherever it is typed" has "$out" '^\[FAIL\] nousowl: 1 phantom ref'
rm "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
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
# the refs unread beside needed .git paths: the fix cannot say "no phantom"
# (the reviewer's finding, 2026-10-27); git's own refusal, a broken packed-refs
printf 'garbage line\n' > "$HOME/Desktop/nousowl/.git/packed-refs"
out=$(run push nousowl)
check "needed .git paths with the refs unread: the fix does not say there is no phantom" has "$out" "fix: a split \(whether a phantom ref is present could not be read, see below\): on fedxps, touch exactly these paths under the repository's \.git \(those listed 'bigfed -> hub'\) and nothing else; the phantom branch then appears here"
check "  never 'a split with no phantom'"     lacks "$out" 'a split with no phantom'
check "  the WARN below says why"             has "$out" '^\[WARN\] nousowl: git cannot list the repository.s refs'
rm "$HOME/Desktop/nousowl/.git/packed-refs"
# a directory among the paths to touch: a touch does not move it for
# Syncthing, so the fix adds the reader's permission change, set back (his
# word at the pause of 5c-b, 2026-10-27); a file or an absent path, nothing
DIRP="$HOME/Desktop/nousowl/.git/objects/ab"; made=0; [ -d "$DIRP" ] || { mkdir "$DIRP"; made=1; }
DIRCL="; .git/objects/ab is a directory, which a touch does not move for Syncthing: on fedxps, change its permissions and set them back (chmod g+w ~/Desktop/nousowl/.git/objects/ab; chmod g-w ~/Desktop/nousowl/.git/objects/ab), the second sanctioned reader write (settled 79, 2026-10-27)"
fixline() { grep -F -- "$2" <<<"$1" | head -1; }
scenario 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=[".git/objects/ab"]' 'nousowl.folders.f2.completion.BIG.needItems=1'
out=$(run push nousowl)
check "a needed .git directory: the push fix ends with the permission change, naming it" has "$(fixline "$out" 'fix: a split with no phantom')" "$(sed 's/[][\.*^$()+?{}|]/\\&/g' <<<"$DIRCL")\$"
check "  the opening intact for R3's case"     has "$out" '^       fix: a split with no phantom: on fedxps, touch exactly these paths'
cp "$HOME/Desktop/nousowl/.git/refs/heads/main" "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
out=$(run push nousowl)
check "  the other opening, a phantom present: the same clause" has "$(fixline "$out" 'fix: the hub holds the loser of these .git paths')" "$(sed 's/[][\.*^$()+?{}|]/\\&/g' <<<"$DIRCL")\$"
rm "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
scenario 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=[".git/refs/heads/main"]' 'nousowl.folders.f2.completion.BIG.needItems=1'
check "  a needed .git file: no clause"        lacks "$(run push nousowl)" 'is a directory'
scenario 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=[".git/objects/zz"]' 'nousowl.folders.f2.completion.BIG.needItems=1'
check "  a needed .git path absent here: no clause" lacks "$(run push nousowl)" 'is a directory'
[ "$made" = 1 ] && rmdir "$DIRP"
# a needed .git path absent here: a deletion the hub refused, since it holds
# fedxps's copy first (the lead's rig run, 2026-10-27): the touch on fedxps,
# then the deletion here again, never "touch ... under the repository's .git"
GONE=".git/refs/heads/x.sync-conflict-20261027-175618-ZHFPJUK"
GONEFIX="$GONE deleted here but refused by the hub, which recorded fedxps's copy first (a concurrent modification beats a deletion): on fedxps, touch exactly these paths; they return here; then delete them here again (rules.md -> him-2)"
scenario 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=["'"$GONE"'"]' 'nousowl.folders.f2.completion.BIG.needItems=1'
out=$(run push nousowl)
check "a needed .git path absent here: the push fix is the deletion's" has "$out" "^       fix: $(sed 's/[][\.*^$()+?{}|]/\\&/g' <<<"$GONEFIX")\$"
check "  not the touch of the paths under .git" lacks "$out" "touch exactly these paths under the repository's \.git"
scenario 'bigfed.folders.f2.completion.HUB.needItems=2' 'bigfed.folders.f2.completion.HUB.names=[".git/refs/heads/main","'"$GONE"'"]' 'nousowl.folders.f2.completion.BIG.needItems=2'
out=$(run push nousowl)
check "  beside a path that exists: today's fix for it, the deletion's for the other" has "$out" '^       fix: a split with no phantom: on fedxps, touch exactly these paths'
check "  and the deletion's"                    has "$out" "^       fix: $(sed 's/[][\.*^$()+?{}|]/\\&/g' <<<"$GONEFIX")\$"
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
cp "$HOME/Desktop/nousowl/.git/refs/heads/main" "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
out=$(run push nousowl); r=$(rc push nousowl)
check "a phantom ref: FAIL, the ref and its file both named" has "$out" '^\[FAIL\] nousowl: 1 phantom ref and 1 conflict copy under .git'
check "  listed"                             has "$out" 'refs/heads/main.sync-conflict-20261009-162229-ABCDEFG'
check "  fix: rename, commit the tree, never delete the file first" has "$out" 'never delete a \*sync-conflict\* file before renaming the ref'
check "  exit 1"                             is "$r" 1
rm "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
echo x > "$HOME/Desktop/nousowl/.git/index.sync-conflict-20261009-162229-ABCDEFG"
out=$(run push nousowl)
check "a conflict copy under .git: FAIL"     has "$out" '^\[FAIL\] nousowl: 0 phantom refs and 1 conflict copy under .git'
rm "$HOME/Desktop/nousowl/.git/index.sync-conflict-20261009-162229-ABCDEFG"
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
echo x > "$HOME/Desktop/nousowl/.git/index.sync-conflict-20261009-162229-ABCDEFG"
mkdir -p "$HOME/Desktop/nousowl/docs"
out=$(run push "$HOME/Desktop/nousowl/docs"); r=$(rc push "$HOME/Desktop/nousowl/docs")
check "a name inside the repository means the repository: the copy under .git found" has "$out" '^\[FAIL\] nousowl: 0 phantom refs and 1 conflict copy under .git'
check "  exit 1"                             is "$r" 1
rm "$HOME/Desktop/nousowl/.git/index.sync-conflict-20261009-162229-ABCDEFG"; rmdir "$HOME/Desktop/nousowl/docs"
scenario 'nousowl.extra_devices=[{"id":"PIXELXX-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG","name":"pixel"},{"id":"EVILXXX-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG","name":"-oProxyCommand=touch pwned"}]'
out=$(run push nousowl); r=$(rc push nousowl)
check "devices the hub knows but that are on no folder are never ssh hosts (1/2)" lacks "$(cat "$SB/ssh.log")" '^pixel:'
check "devices the hub knows but that are on no folder are never ssh hosts (2/2)" lacks "$(cat "$SB/ssh.log")" 'ProxyCommand'
check "  against fresh fixtures: the hub's config.xml names both extra devices" is "$(grep -cE 'name="(pixel|-oProxyCommand=touch pwned)"' "$SB/ssh/nousowl/config.xml")" 2
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
# Step 5a (2026-10-26): the second door, the vector check, him-2's machine, the
# hub and config lines, the writer's maintenance, the snapshot. Each case was
# run against the gauge as it stood before (SYNC_CHECK=<that copy>) and fails
# there.
echo "== doors: the LAN door refused, the tailnet door answers (settled 39) =="
be fedxps; unset GIT_OPTIONAL_LOCKS; scenario 'fedxps.folders.f1.status_seq=[{"needTotalItems":1},{"needTotalItems":1},{"needTotalItems":0}]' 'fedxps.folders.f1.needNames=["late.txt"]'
touch "$SB/ssh/nousowl/down-lan"
out=$(run sync -v); r=$?
check "the hub read through nousowl-vpn: every folder OK" is "$(grep -c '^\[ OK \]' <<<"$out")" 3
check "  exit 0"                             is "$r" 0
check "  -v names the door that answered"    has "$out" 'nousowl \(through nousowl-vpn\): state idle'
check "  the LAN door asked once in a run of several rounds" is "$(grep -c '^nousowl: ' "$SB/ssh.log")" 1
check "  the tailnet door asked every round"  bash -c "[ \$(grep -c '^nousowl-vpn: python3 -I - --remote-views f1 f2 f3$' '$SB/ssh.log') -ge 2 ]"
check "  the LAN door's connect timeout is 2 s" has "$(cat "$SB/ssh.log.doors")" '^nousowl ConnectTimeout=2$'
check "  the tailnet door has the rest of the hub's 8 s" has "$(cat "$SB/ssh.log.doors")" '^nousowl-vpn ConnectTimeout=6$'
scenario 'fedxps.folders.f1.status_seq=[{"needTotalItems":1},{"needTotalItems":1},{"needTotalItems":0}]' 'fedxps.folders.f1.needNames=["late.txt"]'
touch "$SB/ssh/nousowl/hang-lan"
s=$(date +%s%N); out=$(SYNC_CHECK_SETTLE=5 run sync); r=$?; e=$(date +%s%N)
check "a LAN door that hangs: held for its 2 s once, then the tailnet door: OK" is "$r" 0
check "  three rounds read through the tailnet door" bash -c "[ \$(grep -c '^nousowl-vpn: ' '$SB/ssh.log') -ge 3 ]"
check "  under 5.5 s for three rounds (the hang paid once, not per round)" bash -c "[ $(( (e-s)/1000000 )) -lt 5500 ]"
check "  over 2 s (the hang was real)"        bash -c "[ $(( (e-s)/1000000 )) -ge 2000 ]"
scenario; touch "$SB/ssh/nousowl/down-vpn"
out=$(run sync); r=$?
check "the tailnet door down at home: the LAN door alone, OK" is "$r" 0
check "  the tailnet door never asked"        lacks "$(cat "$SB/ssh.log")" '^nousowl-vpn:'
scenario; touch "$SB/ssh/nousowl/down-lan" "$SB/ssh/nousowl/down-vpn"
out=$(run sync); r=$?
check "both doors down: WARN naming both failures" has "$out" "^\[WARN\] alpha: nousowl's view unread: nousowl did not answer over ssh \(nousowl: ssh: connect to host nousowl port 22: Connection timed out; nousowl-vpn: ssh: connect to host nousowl-vpn port 22: No route to host"
check "  exit 2"                             is "$r" 2
check "  each door tried once in the run"     is "$(grep -c '^nousowl' "$SB/ssh.log")" 2
scenario; touch "$SB/ssh/nousowl/down-lan" "$SB/ssh/nousowl/no-vpn"
out=$(run sync)
check "no -vpn alias for the host: the second attempt fails too, said so" has "$out" 'nousowl-vpn: ssh: Could not resolve hostname nousowl-vpn'
be bigfed; scenario; touch "$SB/ssh/fedxps/down-lan"
out=$(run push nousowl); r=$?
check "the peer's HEAD through its second door: equal, and the door named" has "$out" '^\[ OK \] nousowl: folder nousowl up to date, nothing under .git needed, no phantom ref; HEAD equal on fedxps \(through fedxps-vpn\)'
check "  exit 0"                             is "$r" 0
check "  the read went to fedxps-vpn, under GIT_OPTIONAL_LOCKS=0" has "$(cat "$SB/ssh.log")" "^fedxps-vpn: GIT_OPTIONAL_LOCKS=0 git -C ~/'Desktop/nousowl' rev-parse HEAD$"
scenario; touch "$SB/ssh/fedxps/down"
out=$(run push nousowl)
check "the peer down at both doors: skipped and said so, as before" has "$out" "fedxps did not answer: HEAD comparison skipped"
be fedxps; export GIT_OPTIONAL_LOCKS=0; scenario; touch "$SB/ssh/nousowl/hang-cmd-lan"
s=$(date +%s%N); out=$(SYNC_CHECK_SSH_GRACE=1 run); e=$(date +%s%N)
check "the LAN door connects and hangs: the hub's read ends at one wall budget (8 + 1 s)" has "$out" "^\[WARN\] alpha: nousowl's view unread: nousowl did not answer over ssh \(nousowl: no answer within 9 s; nousowl-vpn: not tried, the 9 s allowed for nousowl spent\)"
check "  the run bounded (under 14 s)"        bash -c "[ $(( (e-s)/1000000 )) -lt 14000 ]"
check "  the hung door not tried again: the hub line through the tailnet door" has "$out" '^\[ OK \] hub nousowl \(through nousowl-vpn\): '
check "  the LAN door asked once in the run"  is "$(grep -c '^nousowl: ' "$SB/ssh.log")" 1
unset GIT_OPTIONAL_LOCKS

echo "== guard: the version vectors, fedxps-3's durable form (settled 41; D5) =="
be fedxps; export GIT_OPTIONAL_LOCKS=0; scenario
out=$(run guard); r=$?
check "no .git path carries this machine's counter: OK, the count of paths read" has "$out" "^\[ OK \] no .git path of 12 carries this machine's counter, in the version vectors \(nousowl\); a deletion under .git is seen in the disk events alone, since the daemon started$"
check "  the line says a deletion is the disk events' alone (db/browse lists none)" has "$out" 'a deletion under .git is seen in the disk events alone'
check "  exit 0"                             is "$r" 0
check "  the .git browsed by its prefix"      has "$(reqs fedxps)" '^GET /rest/db/browse\?folder=f2&prefix=\.git$'
check "  every file and directory read, the .git itself too" is "$(grep -c '^GET /rest/db/file?folder=f2&file=' "$SB/fx/fedxps/requests.log")" 12
check "  directories among them"              has "$(reqs fedxps)" 'db/file\?folder=f2&file=\.git%2Frefs%2Fheads$'
check "  nothing outside .git read"           lacks "$(reqs fedxps)" 'file=README'
check "  the disk-event line stays beside it" has "$out" '^\[ OK \] no write under a .git this machine reads, in 0 disk events'
V='{"version":["FEDXPSX:1792640450","BIGFEDX:1791668457"],"modifiedBy":"FEDXPSX","modified":"2026-10-20T10:00:00.5-07:00"}'
scenario "file:fedxps:f2:.git/index=$V"
out=$(run guard); r=$?
check "a .git path carrying this machine's counter, no disk event: FAIL" has "$out" "^\[FAIL\] 1 path under a .git this machine reads carries this machine's counter"
check "  the path, its time and who last modified it" has "$out" "2026-10-20T10:00:00  ~/Desktop/nousowl/.git/index  last modified by fedxps; this machine's counter 1792640450"
check "  fix names fedxps-4's writers"        has "$out" 'fix: find what wrote it \(rules.md -> fedxps-4'
check "  the note: a counter stays for good, KNOWN_WRITES" has "$out" 'note: a counter stays in a path.s vector for good'
check "  exit 1"                             is "$r" 1
scenario 'file:fedxps:f2:.git/refs/heads={"type":"dir","version":["BIGFEDX:1791668457","FEDXPSX:1792640455"]}'
check "a directory under .git carrying it: FAIL, the modifier by its short id when this machine has no name for it" has "$(run guard)" '~/Desktop/nousowl/.git/refs/heads  last modified by BIGFEDX; this machine.s counter 1792640455'
scenario 'file:fedxps:f2:.git/HEAD={"local":{"version":["BIGFEDX:1791668457","FEDXPSX:1792640460"],"modifiedBy":"FEDXPSX"}}'
check "the local version alone carrying it (not yet sent): FAIL" has "$(run guard)" '^\[FAIL\] 1 path under a .git'
scenario 'file:fedxps:f2:README.md={"version":["FEDXPSX:1792640450"],"modifiedBy":"FEDXPSX"}' 'file:fedxps:f2:.git/config={"version":["BIGFEDX:1791668457","HUBHUBH:5"]}'
out=$(run guard); r=$?
check "this machine's counter outside .git, another device's under it: OK" has "$out" "^\[ OK \] no .git path of 12 carries"
check "  exit 0"                             is "$r" 0
args=(); for i in $(seq 1 22); do args+=("file:fedxps:f2:.git/objects/ab/obj$i=$V"); done
scenario "${args[@]}"
out=$(run guard)
check "many paths: 20 listed, the rest counted" has "$out" '^       \.\.\. and 2 more$'
check "  the count of all of them"           has "$out" '^\[FAIL\] 22 paths under a .git this machine reads carry this machine.s counter'
check "  every path read, the new directory too" has "$out" '^       .*/\.git/objects/ab/obj1  '
check "  nothing unreadable"                 lacks "$out" '^\[WARN\]'
# (d) more than 20 paths with a counter that appears only past the 20th: the
# literal lines carry every distinct counter all the same (the reviewer's
# surviving mutant, 2026-10-27); the paths sort obj01..obj22 in the walk
VC() { printf '{"version":["FEDXPSX:%s","BIGFEDX:1791668457"],"modifiedBy":"FEDXPSX"}' "$1"; }
args=(); for i in $(seq -w 1 21); do args+=("file:fedxps:f2:.git/objects/ab/obj$i=$(VC 1792640450)"); done
args+=("file:fedxps:f2:.git/objects/ab/obj22=$(VC 1792640470)")
scenario "${args[@]}"
out=$(run guard); today=$(date +%F)
check "(d) 22 paths, the 22nd alone with its counter: the 20th listed" has "$out" 'objects/ab/obj20  '
check "  the 22nd past the list"               lacks "$out" 'objects/ab/obj22  '
check "  the literal lines carry both counters" is "$(literals "$out")" "fedxps nousowl 1792640450 $today
fedxps nousowl 1792640470 $today"
scenario 'fedxps.files.f2={}'
out=$(run guard); r=$?
check "the .git not in the folder's index: WARN, never OK" has "$out" "^\[WARN\] version vectors unread: ~/Desktop/nousowl: its .git is not in the folder.s index"
check "  exit 2"                             is "$r" 2
scenario 'file:fedxps:f2:.git/index={"version":[{"id":12345,"value":7}]}'
check "a version the gauge cannot parse: WARN" has "$(run guard)" '^\[WARN\] version vectors unread: ~/Desktop/nousowl/\.git/index: a (local|global) version the gauge cannot parse'
scenario
python3 - "$SB/fx/fedxps/responses.json" <<'PY'
import json, sys
p = sys.argv[1]; t = json.load(open(p)); t["GET /rest/db/browse?folder=f2&prefix=.git"] = {"status": 500, "body": "boom"}; json.dump(t, open(p, "w"))
PY
out=$(run guard); r=$?
check "db/browse failing: WARN, exit 2"      has "$out" '^\[WARN\] version vectors unread: ~/Desktop/nousowl: db/browse answered 500'
check "  exit 2"                             is "$r" 2
printf '[gsync]\n\trole = reader\n' > "$HOSTS_FED/fedxps.inc"
scenario
out=$(run guard)
check "under role = reader: every repository, the one in no folder skipped and named" has "$out" "^\[ OK \] no .git path of 12 carries this machine's counter, in the version vectors \(nousowl; in no folder, skipped: ~/Desktop/org\)"
printf '%b' "$FEDINC" > "$HOSTS_FED/fedxps.inc"
be bigfed; unset GIT_OPTIONAL_LOCKS; scenario 'file:bigfed:f2:.git/index={"version":["BIGFEDX:1792640450"]}'
run guard >/dev/null
check "on a writer the vectors are not read"  lacks "$(reqs bigfed)" 'db/(browse|file)'
# a write found and explained, carried by its counter (a copy of the gauge with a stand-in line)
WGAUGE="$SB/sync-check-known-writes"
python3 -I - "$GAUGE" "$WGAUGE" <<'PY' || { echo "sync-check tests: no 'KNOWN_WRITES = [' line to insert the stand-in after -- not running" >&2; exit 2; }
import sys
src, dst = sys.argv[1:3]
t = open(src).read()
assert t.count("\nKNOWN_WRITES = [\n") == 1
open(dst, "w").write(t.replace("\nKNOWN_WRITES = [\n", '\nKNOWN_WRITES = [\n    {"on": "fedxps", "label": "nousowl", "path": ".git/index", "counter": 1792640450, "since": "2026-10-20",\n     "note": "a stand-in"},\n', 1))
PY
chmod +x "$WGAUGE"
be fedxps; export GIT_OPTIONAL_LOCKS=0; scenario "file:fedxps:f2:.git/index=$V"
out=$("$WGAUGE" guard 2>&1); r=$?
check "a known write, its counter matching: OK, named" has "$out" "^\[ OK \] no .git path of 12 carries this machine's counter beyond the known write .git/index in nousowl \(since 2026-10-20: a stand-in\), in the version vectors \(nousowl\); a deletion under .git is seen in the disk events alone, since the daemon started$"
check "  exit 0"                             is "$r" 0
scenario 'file:fedxps:f2:.git/index={"version":["FEDXPSX:1792640999","BIGFEDX:1791668457"]}'
check "the same path written again (a larger counter): FAIL" has "$("$WGAUGE" guard 2>&1)" '^\[FAIL\] 1 path under a .git'
scenario
out=$("$WGAUGE" guard 2>&1); r=$?
check "a known write no longer showing: DUE, delete its line" has "$out" '^\[DUE\] the known write .git/index in nousowl no longer shows'
check "  exit 3"                             is "$r" 3
scenario 'file:fedxps:f2:.git/HEAD={"version":["FEDXPSX:1792640450","BIGFEDX:1791668457"],"modifiedBy":"FEDXPSX"}'
check "an entry naming a path narrows it: the same counter on another path FAILs" has "$("$WGAUGE" guard 2>&1)" '^\[FAIL\] 1 path under a .git this machine reads carries'
# Step 5c-b (2026-10-27, settled 79): KNOWN_WRITES keyed by machine and counter on
# any path. Two more copies, each a counter-keyed stand-in: one whose counter is an
# hour old by the clock, so a deleted record may still carry it, and one older than
# DB_DELETE_RETENTION_HOURS. Each case below was run against the gauge before the
# change (SYNC_CHECK=<that copy>) and fails there.
FRESH=$(( $(date +%s) - 3600 )); LATER=$(( FRESH + 7 ))
WGAUGE2="$SB/sync-check-known-by-counter"; WGAUGE3="$SB/sync-check-known-by-old-counter"
known_copy() { # $1 the copy, $2 its entry's counter, $3 its note, $4 its label (nousowl)
  python3 -I - "$GAUGE" "$1" "$2" "$3" "${4:-nousowl}" <<'PY' || { echo "sync-check tests: no 'KNOWN_WRITES = [' line to insert the stand-in after -- not running" >&2; exit 2; }
import sys
src, dst, c, note, label = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]
t = open(src).read()
assert t.count("\nKNOWN_WRITES = [\n") == 1
open(dst, "w").write(t.replace("\nKNOWN_WRITES = [\n", '\nKNOWN_WRITES = [\n    {"on": "fedxps", "label": "%s", "counter": %d, "since": "2026-10-27", "note": "%s"},\n' % (label, c, note), 1))
PY
  chmod +x "$1"; }
known_copy "$WGAUGE2" "$FRESH" "a stand-in by counter"
known_copy "$WGAUGE3" 1700000000 "an old stand-in"
vf() { printf '{"version":["FEDXPSX:%s","BIGFEDX:1791668457"],"modifiedBy":"FEDXPSX","modified":"2026-10-27T10:00:00.5-07:00"}' "$1"; }
be fedxps; export GIT_OPTIONAL_LOCKS=0; scenario "file:fedxps:f2:.git/refs/heads/main=$(vf $FRESH)"
out=$("$WGAUGE2" guard 2>&1); r=$?
check "a counter-keyed known write on a path it does not name: OK, named by its counter and note" has "$out" "^\[ OK \] no .git path of 12 carries this machine's counter beyond the known write by counter $FRESH in nousowl on 1 path \(since 2026-10-27: a stand-in by counter\), in the version vectors \(nousowl\); a deletion"
check "  exit 0"                             is "$r" 0
# (e) the same counter, the entry's label another folder's: no match (the
# reviewer's surviving mutant ignored the label, 2026-10-27)
WGAUGE4="$SB/sync-check-known-other-folder"; known_copy "$WGAUGE4" "$FRESH" "a stand-in in another folder" alpha
check "(e) a counter-keyed entry whose label is another folder's: no match, FAIL" has "$("$WGAUGE4" guard 2>&1)" "^\[FAIL\] 1 path under a .git this machine reads carries this machine's counter"
scenario "file:fedxps:f2:.git/refs/heads/main=$(vf $FRESH)" "file:fedxps:f2:.git/index=$(vf $FRESH)"
out=$("$WGAUGE2" guard 2>&1); r=$?
check "a second path with the same counter: OK, both counted" has "$out" "^\[ OK \] no .git path of 12 carries this machine's counter beyond the known write by counter $FRESH in nousowl on 2 paths"
check "  exit 0"                             is "$r" 0
scenario "file:fedxps:f2:.git/refs/heads/main=$(vf $FRESH)" "file:fedxps:f2:.git/index=$(vf $LATER)"
out=$("$WGAUGE2" guard 2>&1); r=$?; today=$(date +%F)
check "a different counter beside it: FAIL, that path alone" has "$out" "^\[FAIL\] 1 path under a .git this machine reads carries this machine's counter"
check "  the path named with its counter"     has "$out" "~/Desktop/nousowl/.git/index  last modified by fedxps; this machine's counter $LATER"
check "  the entry for the new counter printed, a Python literal with the five keys" is "$(literals "$out")" "fedxps nousowl $LATER $today"
check "  exit 1"                             is "$r" 1
out=$(run guard); today=$(date +%F)
check "with KNOWN_WRITES empty: one line per counter, in counter order" is "$(literals "$out")" "fedxps nousowl $FRESH $today
fedxps nousowl $LATER $today"
check "  each indented as the gauge's lines are, ready to paste" has "$out" "^       \{\"on\": \"fedxps\", \"label\": \"nousowl\", \"counter\": $FRESH, \"since\": \"$today\", \"note\": \"<why: e.g. him-2's split repair, the sanctioned touch>\"\},$"
check "  the note before them: paste, one per counter, the counter not the path" has "$out" "note: a counter stays in a path's vector for good and returns on a path git writes again \(cutover/rehearsal/refute-b.md -> A9\), so the entry names the counter, not the path: once the write is explained, paste these lines into KNOWN_WRITES in bin/sync-check \(configs\), one per counter$"
check "  then the fix, fedxps-4's hunt"       is "$(grep -E '^       (note|fix):|^       \{' <<<"$out" | sed -E 's/^       (note|fix):.*/\1/; s/^       \{.*/literal/' | paste -sd' ')" "note literal literal fix"
paste_known "$out" "$SB/sync-check-pasted"
out=$("$SB/sync-check-pasted" guard 2>&1); r=$?
check "the printed lines pasted as printed: the guard OK over both paths" has "$out" "^\[ OK \] no .git path of 12 carries this machine's counter beyond the known writes by counter"
check "  each entry named (1/2)"              has "$out" "by counter $FRESH in nousowl on 1 path \(since $today: <why: e.g. him-2's split repair, the sanctioned touch>\)"
check "  each entry named (2/2)"              has "$out" "by counter $LATER in nousowl on 1 path \(since $today: <why: "
check "  exit 0"                             is "$r" 0
scenario
out=$("$WGAUGE2" guard -v 2>&1); r=$?
check "a counter-keyed entry no path shows, its counter fresh: no DUE, since a deleted record may carry it" lacks "$out" '^\[DUE\]'
check "  -v says why its line stays"         has "$out" "the known write by counter $FRESH in nousowl shows on no path; its line stays until 20[0-9-]+ [0-9:]+, while a deleted record may still carry the counter \(10920 h\)"
check "  exit 0"                             is "$r" 0
out=$("$WGAUGE3" guard 2>&1); r=$?
check "one older than the 10920 h a deleted record is kept: DUE, which case it is said" has "$out" '^\[DUE\] the known write by counter 1700000000 \(2023-11-1[45] [0-9:]+\) in nousowl shows on no path, and is older than the 10920 h a workstation keeps a deleted record'
check "  fix: delete its line"                has "$out" 'fix: delete its line from KNOWN_WRITES in bin/sync-check \(configs\): nothing carries it any more'
check "  exit 3"                             is "$r" 3
scenario "file:fedxps:f2:.git/index=$(vf 1700000000)"
out=$("$WGAUGE3" guard 2>&1); r=$?
check "  the old counter still on a path: OK, no DUE" has "$out" "^\[ OK \] no .git path of 12 carries this machine's counter beyond the known write by counter 1700000000 in nousowl on 1 path"
check "  exit 0"                             is "$r" 0

echo "== sync: him-2's fuller form, the losing machine named (D8) =="
L=('fedxps.folders.f1.completion.HUB.needItems=1' 'fedxps.folders.f1.completion.HUB.names=["x.txt"]' 'bigfed.folders.f1.completion.HUB.needItems=1' 'bigfed.folders.f1.completion.HUB.names=["x.txt"]' 'nousowl.folders.f1.completion.BIG.needItems=1' 'nousowl.folders.f1.completion.FED.needItems=1')
be fedxps; scenario "${L[@]}" 'file:fedxps:f1:x.txt={"version":["BIGFEDX:1792965826"],"modifiedBy":"BIGFEDX"}'
out=$(run sync)
check "the vector carries bigfed alone: edit on fedxps, said so" has "$out" "fix: edit x.txt once more on fedxps \(the current version carries bigfed's counter alone\) and read again \(org/machines/transport-2026-10/rules.md -> him-2\)"
check "  the vector read from this machine's db/file" has "$(reqs fedxps)" '^GET /rest/db/file\?folder=f1&file=x\.txt$'
be bigfed; scenario "${L[@]}" 'file:bigfed:f1:x.txt={"version":["FEDXPSX:1792965950"],"modifiedBy":"FEDXPSX"}'
check "read from bigfed, the vector carrying fedxps alone: edit on bigfed" has "$(run sync)" "edit x.txt once more on bigfed \(the current version carries fedxps's counter alone\)"
be fedxps; scenario "${L[@]}" 'file:fedxps:f1:x.txt={"version":["BIGFEDX:1792965826","FEDXPSX:1792965950"]}'
out=$(run sync)
check "the vector carrying both: today's wording" has "$out" 'edit the file once more on the machine whose text is in the conflict copy'
check "  no machine named"                   lacks "$out" 'edit x.txt once more on'
be fedxps; scenario "${L[@]}"
check "no record of the path: today's wording" has "$(run sync)" 'edit the file once more on the machine whose text is in the conflict copy'
be fedxps; scenario "${L[@]}" 'file:fedxps:f1:x.txt={"version":["ZZZZZZZ:1792965826"]}'
out=$(run sync)
check "a vector carrying a third device alone: today's wording" has "$out" 'edit the file once more on the machine whose text is in the conflict copy'
check "  no machine named"                   lacks "$out" 'edit x.txt once more on'
# under a repository's .git the losing machine's write is the sanctioned touch,
# never an edit; outside .git the edit stays (settled 79, 2026-10-27)
LG=('fedxps.folders.f2.completion.HUB.needItems=1' 'fedxps.folders.f2.completion.HUB.names=[".git/refs/heads/main"]' 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=[".git/refs/heads/main"]' 'nousowl.folders.f2.completion.BIG.needItems=1' 'nousowl.folders.f2.completion.FED.needItems=1')
be fedxps; scenario "${LG[@]}" 'file:fedxps:f2:.git/refs/heads/main={"version":["BIGFEDX:1792965826"],"modifiedBy":"BIGFEDX"}'
out=$(run sync)
check "a .git path whose loser the hub holds: touch it on fedxps, never edit it" has "$out" "fix: touch \.git/refs/heads/main on fedxps \(never edit a \.git path; the current version carries bigfed's counter alone\) and read again \(org/machines/transport-2026-10/rules.md -> him-2\)$"
check "  no edit of it"                       lacks "$out" 'edit \.git/refs/heads/main'
LM=('fedxps.folders.f1.completion.HUB.needItems=2' 'fedxps.folders.f1.completion.HUB.names=["x.txt","sub/.git/index"]' 'bigfed.folders.f1.completion.HUB.needItems=2' 'bigfed.folders.f1.completion.HUB.names=["x.txt","sub/.git/index"]' 'nousowl.folders.f1.completion.BIG.needItems=2' 'nousowl.folders.f1.completion.FED.needItems=2')
scenario "${LM[@]}" 'file:fedxps:f1:x.txt={"version":["BIGFEDX:1792965826"]}' 'file:fedxps:f1:sub/.git/index={"version":["BIGFEDX:1792965826"]}'
check "a plain path and a .git path in one folder: the edit for the one, the touch for the other" has "$(run sync)" "fix: edit x\.txt once more on fedxps \(the current version carries bigfed's counter alone\) and read again; touch sub/\.git/index on fedxps \(never edit a \.git path; the current version carries bigfed's counter alone\) and read again \("
scenario "${LM[@]}" 'file:fedxps:f1:x.txt={"version":["BIGFEDX:1792965826"]}'
out=$(run sync)
check "a .git path whose vector is unread: the touch, on the machine whose counter it lacks" has "$out" "; for sub/\.git/index: touch each on the machine whose counter the current version lacks \(never edit a \.git path\) and read again"
check "  the plain path keeps its edit"         has "$out" "fix: edit x\.txt once more on fedxps"

echo "== sync: a path under a .git stranded, the split repair named (settled 80) =="
# Step 5c-b (2026-10-27): the stranded fix under a repository's .git names him-2's
# split repair or the guard by the machine it is stranded on, the writer read from
# this machine's role (bigfed's host file: role = writer; fedxps's: readerRepo).
G=('bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=[".git/refs/heads/main"]' 'nousowl.folders.f2.completion.BIG.needItems=1')
SPLIT="a split of main: on fedxps, touch exactly these paths under the repository's .git and nothing else (him-2's one sanctioned reader write; never edit them); the phantom branch then appears on bigfed: rename it before deleting any *sync-conflict* file under .git, commit the working tree, then delete the inert copies; sync-check push nousowl names each step (rules.md -> him-2)"
GUARDPTR="a write under a .git on fedxps: run sync-check guard there, which names the write; no touch and no edit (rules.md -> fedxps-3, him-2)"
fixof() { grep -A1 -F -- "$2" <<<"$1" | sed -n 's/^       fix: //p' | head -1; }
before() { local a b; a=$(grep -n -F -- "$2" <<<"$1" | head -1 | cut -d: -f1); b=$(grep -n -F -- "$3" <<<"$1" | head -1 | cut -d: -f1)
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] || { echo "     got:  '$2' at line ${a:-none}, '$3' at line ${b:-none}"; return 1; }; }
be bigfed; unset GIT_OPTIONAL_LOCKS; scenario "${G[@]}"
out=$(run sync); r=$?
check "seen from bigfed, a .git path stranded on bigfed: FAIL, the path named" has "$out" '^\[FAIL\] nousowl: stranded on bigfed: \.git/refs/heads/main$'
check "  the fix is the split repair: the touch on fedxps, the phantom on bigfed, the push line" is "$(fixof "$out" 'stranded on bigfed')" "$SPLIT"
check "  never 'delete the copy'"            lacks "$out" 'merge it into the original and delete the copy'
check "  exit 1"                             is "$r" 1
check "  a file stranded: no directory clause" lacks "$out" 'is a directory'
DIRP="$SB/ssh/bigfed/home/Desktop/nousowl/.git/objects/ab"; made=0; [ -d "$DIRP" ] || { mkdir "$DIRP"; made=1; }
scenario 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=[".git/objects/ab"]' 'nousowl.folders.f2.completion.BIG.needItems=1'
check "a .git directory stranded on bigfed: the split line adds the permission change, naming it" is "$(fixof "$(run sync)" 'stranded on bigfed: .git/objects/ab')" "${SPLIT}${DIRCL}"
scenario 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=[".git/objects/zz"]' 'nousowl.folders.f2.completion.BIG.needItems=1'
# a .git path absent here, stranded on bigfed: the deletion the hub refused,
# its own line, never the split line's touch under .git (2026-10-27)
scenario 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=["'"$GONE"'"]' 'nousowl.folders.f2.completion.BIG.needItems=1'
out=$(run sync)
check "  a .git path absent here: the deletion's text, its own line" is "$(fixof "$out" "stranded on bigfed: $GONE")" "$GONEFIX"
check "  not the split line's touch under .git" lacks "$out" "touch exactly these paths under the repository's \.git and nothing else"
scenario 'bigfed.folders.f2.completion.HUB.needItems=2' 'bigfed.folders.f2.completion.HUB.names=[".git/refs/heads/main","'"$GONE"'"]' 'nousowl.folders.f2.completion.BIG.needItems=2'
out=$(run sync)
check "  beside a path that exists: today's split line for it" is "$(fixof "$out" 'stranded on bigfed: .git/refs/heads/main')" "$SPLIT"
check "  and the deletion's line for the other" is "$(fixof "$out" "stranded on bigfed: $GONE")" "$GONEFIX"
[ "$made" = 1 ] && rmdir "$DIRP"
be fedxps; export GIT_OPTIONAL_LOCKS=0; scenario "${G[@]}"
out=$(run sync)
check "seen from fedxps, the same stranded on bigfed: the same line (the writer read from fedxps's readerRepo)" is "$(fixof "$out" 'stranded on bigfed')" "$SPLIT"
printf '[gsync]\n\trole = reader\n' > "$HOSTS_FED/fedxps.inc"
check "  and under role = reader"             is "$(fixof "$(run sync)" 'stranded on bigfed')" "$SPLIT"
printf '%b' "$FEDINC" > "$HOSTS_FED/fedxps.inc"
scenario 'fedxps.folders.f2.completion.HUB.needItems=1' 'fedxps.folders.f2.completion.HUB.names=[".git/index"]' 'nousowl.folders.f2.completion.FED.needItems=1'
out=$(run sync); r=$?
check "a .git path stranded on fedxps: FAIL"  has "$out" '^\[FAIL\] nousowl: stranded on fedxps: \.git/index$'
check "  the fix sends to the guard there, no touch and no edit" is "$(fixof "$out" 'stranded on fedxps')" "$GUARDPTR"
check "  exit 1"                             is "$r" 1
be bigfed; unset GIT_OPTIONAL_LOCKS; scenario 'fedxps.folders.f2.completion.HUB.needItems=1' 'fedxps.folders.f2.completion.HUB.names=[".git/index"]' 'nousowl.folders.f2.completion.FED.needItems=1'
check "  the same seen from bigfed"           is "$(fixof "$(run sync)" 'stranded on fedxps')" "$GUARDPTR"
# the paths these cases list exist here, as a stranded path does on the writer
# (one absent here is a deletion the hub refused, its own text: 2026-10-27);
# the sandbox's configs is no repository, so its .git/index is made for them
CFGGIT="$SB/ssh/bigfed/home/Desktop/configs/.git"; SUBGIT="$SB/ssh/bigfed/home/Desktop/alpha/sub"
mkdir -p "$CFGGIT" "$SUBGIT/.git"; : > "$CFGGIT/index"; : > "$SUBGIT/.git/index"
scenario 'bigfed.folders.f1.path="'"$SB/ssh/bigfed/home/Desktop"'"' 'bigfed.folders.f1.completion.HUB.needItems=3' 'bigfed.folders.f1.completion.HUB.names=["configs/.git/index","notes.txt","org/.git/refs/heads/main"]' 'nousowl.folders.f1.completion.BIG.needItems=3'
out=$(run sync)
check "a folder at ~/Desktop: a path outside .git keeps today's text" has "$out" '^\[FAIL\] alpha: stranded on bigfed: notes.txt$'
check "  each repository its own line, named as push takes it (1/2)" is "$(fixof "$out" 'stranded on bigfed: configs/.git/index')" "${SPLIT/push nousowl/push configs}"
check "  each repository its own line, named as push takes it (2/2)" is "$(fixof "$out" 'stranded on bigfed: org/.git/refs/heads/main')" "${SPLIT/push nousowl/push org}"
scenario 'bigfed.folders.f1.completion.HUB.needItems=1' 'bigfed.folders.f1.completion.HUB.names=["sub/.git/index"]' 'nousowl.folders.f1.completion.BIG.needItems=1'
check "a repository nested in a folder: named by its path" has "$(run sync)" 'sync-check push ~/Desktop/alpha/sub names each step'
rm -rf "$CFGGIT" "$SUBGIT"
# a third device the hub knows, on no folder (scenario.py's extra_devices,
# which reach the hub's config.xml since its loop was mended, 2026-10-27)
scenario "${G[@]}" 'nousowl.extra_devices=[{"id":"PIXELXX-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG","name":"pixel"}]'
# with no reading of the role, a .git path's fix names no machine and no delete
# (settled 80 forbids "delete the copy" there; the reviewer's finding, 2026-10-27)
NOROLE="under a repository's .git: never edit and never delete a copy there; sync-check push nousowl on the writer names the repair (rules.md -> him-2)"
out=$(run sync)
check "more than two workstations: a .git path's fix names no machine and no delete" is "$(fixof "$out" 'stranded on bigfed: .git/refs/heads/main')" "$NOROLE"
check "  never 'delete the copy'"             lacks "$out" 'delete the copy'
scenario 'bigfed.folders.f2.completion.HUB.needItems=2' 'bigfed.folders.f2.completion.HUB.names=[".git/refs/heads/main","notes.txt"]' 'nousowl.folders.f2.completion.BIG.needItems=2' 'nousowl.extra_devices=[{"id":"PIXELXX-AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG","name":"pixel"}]'
out=$(run sync)
check "  beside a plain path, which keeps the generic text" has "$(fixof "$out" 'stranded on bigfed: notes.txt')" '^edit each listed path on the other workstation, never on bigfed'
check "  and the .git path its own line"       is "$(fixof "$out" 'stranded on bigfed: .git/refs/heads/main')" "$NOROLE"
ln -sfn ../../Desktop/configs/git/hosts/fedxps.inc "$SB/ssh/bigfed/home/.config/git/host.inc"; scenario "${G[@]}"
out=$(run sync)
check "a role read under a warning (host.inc naming another machine's file): the same, no machine, no delete" is "$(fixof "$out" 'stranded on bigfed: .git/refs/heads/main')" "$NOROLE"
check "  never 'delete the copy'"             lacks "$out" 'delete the copy'
ln -sfn ../../Desktop/configs/git/hosts/bigfed.inc "$SB/ssh/bigfed/home/.config/git/host.inc"
be fedxps; export GIT_OPTIONAL_LOCKS=0; scenario 'fedxps.folders.f1.completion.HUB.needDeletes=1' 'fedxps.folders.f1.completion.HUB.names=["gone.txt"]'
check "a path outside any .git: today's text, whole" is "$(fixof "$(run sync)" 'stranded on fedxps: gone.txt')" "edit each listed path on bigfed, never on fedxps (a re-save that only moves its time should do the same, untested); the stranded text then arrives on both as a conflict copy: merge it into the original and delete the copy (org/machines/transport-2026-10/rules.md -> him-2)"

echo "== hub: free space, errors, index, the retention drop-in (hub-4, hub-1) =="
be fedxps; scenario
out=$(run hub); r=$?
check "four OK lines"                        is "$(grep -c '^\[ OK \] hub nousowl: ' <<<"$out")" 4
check "  free space, btrfs's estimate"       has "$out" '^\[ OK \] hub nousowl: .*/ssh/nousowl/home/sync has 28.5 GB free \(btrfs, Free \(estimated\)\), above the 10.0 GB floor$'
check "  the pull errors of every hub folder" has "$out" '^\[ OK \] hub nousowl: no pull error and no folder error in 3 folders$'
check "  the index's size"                   has "$out" '^\[ OK \] hub nousowl: the index is 0.0 MB \(.*/ssh/nousowl/index-v2\)$'
check "  the drop-in, and the daemon running with it" has "$out" "^\[ OK \] hub nousowl: syncthing@$ME_USER.service carries 30-delete-retention.conf, and its daemon runs with STDBDELETERETENTIONINTERVAL=0$"
check "  exit 0"                             is "$r" 0
check "  one ssh, the hub's remote mode"      is "$(cat "$SB/ssh.log")" 'nousowl: python3 -I - --remote-hub'
check "  btrfs read in bytes, for the folders' parent" has "$(cat "$HUBFX/btrfs.log")" '^filesystem usage -b .*/ssh/nousowl/home/sync$'
check "  the unit asked for is the user's instance of syncthing@" has "$(cat "$HUBFX/systemctl.log")" "^system syncthing@$ME_USER.service$"
check "  every hub folder's errors read"     is "$(grep -c '^GET /rest/folder/errors?folder=f' "$SB/fx/nousowl/requests.log")" 3
check "  this machine's own Syncthing not asked for errors" lacks "$(reqs fedxps)" 'folder/errors'
scenario; echo 10000000000 > "$HUBFX/free"
check "free space exactly at the floor: OK"  has "$(run hub)" '^\[ OK \] hub nousowl: .* has 10.0 GB free .*, above the 10.0 GB floor$'
echo 9999999999 > "$HUBFX/free"
out=$(run hub)
check "a byte under the floor: FAIL"         has "$out" '^\[FAIL\] hub nousowl: .* has 9.9 GB free .*, under the 10.0 GB floor'
scenario; echo 8200000000 > "$HUBFX/free"
out=$(run hub); r=$?
check "under the 10 GB floor: FAIL"          has "$out" '^\[FAIL\] hub nousowl: .*/home/sync has 8.2 GB free \(btrfs, Free \(estimated\)\), under the 10.0 GB floor: grow it now \(rules.md -> hub-4\)'
fixl=$(grep '^       fix: ' <<<"$out" | head -1 | sed 's/^       fix: //')
check "  the fix is hub-4's growth, the command alone" is "$fixl" "ssh -t nousowl 'sudo lvextend -L +32G fedora/sync && sudo btrfs filesystem resize max $(realpath "$SB")/ssh/nousowl/home/sync'"
check "  and it parses as a shell command"   bash -n -c "$fixl"
check "  printed right under the line it repairs, its note between" is "$(grep -A2 '^\[FAIL\] hub nousowl: .* under the' <<<"$out" | sed -n '2s/^       \(note\):.*/\1/p;3s/^       \(fix\):.*/\1/p' | paste -sd' ')" "note fix"
check "  exit 1"                             is "$r" 1
scenario; touch "$HUBFX/btrfs-fail"
out=$(run hub); r=$?
check "btrfs refusing: df's figure, said so"  has "$out" '^\[ OK \] hub nousowl: .* has 28.5 GB free \(df, since btrfs gave none: exit 1: ERROR: not a btrfs filesystem'
check "  exit 0"                             is "$r" 0
echo 9000000000 > "$HUBFX/df-free"
check "  df's figure under the floor: FAIL"   has "$(run hub)" '^\[FAIL\] hub nousowl: .* has 9.0 GB free \(df'
touch "$HUBFX/df-fail"
out=$(run hub); r=$?
check "neither readable: WARN"              has "$out" '^\[WARN\] hub nousowl: the free space of .* cannot be read'
check "  exit 2"                             is "$r" 2
scenario 'nousowl.folders.f2.pullErrorList=[{"path":"M.syncthing-enc/QE/OPAQUE","error":"insufficient space in folder nousowl (/home/bph/sync/nousowl): 9.9 GB < 10 GB"}]'
out=$(run hub); r=$?
check "a pull error reading insufficient space: FAIL" has "$out" '^\[FAIL\] hub nousowl: 1 pull error in nousowl \(1\): insufficient space \(rules.md -> hub-4\)'
check "  the error's text shown"             has "$out" '^       nousowl: insufficient space in folder nousowl'
check "  the growth commands, under that line" has "$(grep -A3 '^\[FAIL\] hub nousowl: 1 pull error' <<<"$out" | sed -n '4p')" "^       fix: ssh -t nousowl 'sudo lvextend -L \+32G fedora/sync && sudo btrfs filesystem resize max "
check "  exit 1"                             is "$r" 1
scenario 'nousowl.folders.f1.error="insufficient space in folder alpha: 1 %"'
check "a folder error reading insufficient space: FAIL with the growth" has "$(run hub)" 'fix: ssh -t nousowl .sudo lvextend'
scenario 'nousowl.folders.f3.pullErrorList=[{"path":"M.syncthing-enc/X","error":"file modified but not rescanned; will try again later"}]'
out=$(run hub)
check "another pull error: FAIL, no growth"  has "$out" '^\[FAIL\] hub nousowl: 1 pull error in gamma \(1\)$'
check "  no growth command for it"           lacks "$out" 'lvextend'
scenario; truncate -s 1100000000 "$SB/ssh/nousowl/index-v2/big"
out=$(run hub); r=$?
check "the index at 1.1 GB, under hub-4's 2 GB: OK (settled 83)" has "$out" '^\[ OK \] hub nousowl: the index is 1100.0 MB \('
check "  exit 0"                             is "$r" 0
scenario; truncate -s 2100000000 "$SB/ssh/nousowl/index-v2/big"
out=$(run hub); r=$?
check "the index past 2 GB: DUE (attention, nothing broken)" has "$out" '^\[DUE\] hub nousowl: the index is 2.1 GB, past 2.0 GB'
check "  exit 3"                             is "$r" 3
scenario; unit_props "$RET_PID" "/etc/systemd/system/syncthing@$ME_USER.service.d/override.conf" > "$HUBFX/unit-system"
out=$(run hub); r=$?
check "the drop-in missing: FAIL (hub-1)"    has "$out" "^\[FAIL\] hub nousowl: syncthing@$ME_USER.service carries no 30-delete-retention.conf"
check "  the note gives its path and content" has "$out" "note: the drop-in is /etc/systemd/system/syncthing@$ME_USER.service.d/30-delete-retention.conf, two lines: \[Service\] and Environment=STDBDELETERETENTIONINTERVAL=0"
fixl=$(grep '^       fix: ' <<<"$out" | head -1 | sed 's/^       fix: //')
check "  the fix writes it, reloads, restarts" is "$fixl" "ssh -t nousowl 'sudo mkdir -p /etc/systemd/system/syncthing@$ME_USER.service.d && printf \"[Service]\\nEnvironment=STDBDELETERETENTIONINTERVAL=0\\n\" | sudo tee /etc/systemd/system/syncthing@$ME_USER.service.d/30-delete-retention.conf >/dev/null && sudo systemctl daemon-reload && sudo systemctl restart syncthing@$ME_USER.service'"
check "  and parses as a shell command"      bash -n -c "$fixl"
check "  the remote half writes exactly the drop-in's two lines" is "$(bash -c "$(sed -e "s/^ssh -t nousowl '//" -e "s/'\$//" <<<"$fixl" | sed -e 's/sudo //g' -e 's/ && systemctl.*//' -e "s#/etc/systemd/system#$SB/etc#g")" && cat "$SB/etc/syncthing@$ME_USER.service.d/30-delete-retention.conf")" $'[Service]\nEnvironment=STDBDELETERETENTIONINTERVAL=0'
check "  exit 1"                             is "$r" 1
scenario; unit_props "$BARE_PID" "$DROPINS" > "$HUBFX/unit-system"
out=$(run hub)
check "the drop-in in place, the daemon started before it: FAIL, restart" has "$out" "^\[FAIL\] hub nousowl: syncthing@$ME_USER.service carries 30-delete-retention.conf, but its running daemon \(pid $BARE_PID\) lacks STDBDELETERETENTIONINTERVAL=0"
check "  fix: reload and restart"            has "$out" "fix: ssh -t nousowl 'sudo systemctl daemon-reload && sudo systemctl restart syncthing@$ME_USER.service'$"
scenario; printf 'LoadState=loaded\nActiveState=active\nMainPID=1\nDropInPaths=%s\nEnvironment=STLOGFORMATTIMESTAMP=\n' "$DROPINS" > "$HUBFX/unit-system"
out=$(run hub); r=$?
check "the daemon's environment unread (pid 1), the unit's lacking the variable: FAIL" has "$out" "^\[FAIL\] hub nousowl: syncthing@$ME_USER.service carries 30-delete-retention.conf, but the unit.s environment lacks STDBDELETERETENTIONINTERVAL=0"
check "  exit 1"                             is "$r" 1
unit_props 1 "$DROPINS" > "$HUBFX/unit-system"
check "the daemon's environment unread, the unit's carrying it: OK, said so" has "$(run hub)" "carries 30-delete-retention.conf, and its environment sets \(the daemon.s own unread\) STDBDELETERETENTIONINTERVAL=0$"
scenario; rm "$HUBFX/unit-system"; unit_props "$RET_PID" "$HOME/.config/systemd/user/syncthing.service.d/30-delete-retention.conf" > "$HUBFX/unit-user"
check "a user unit carrying it: OK, named"   has "$(run hub)" '^\[ OK \] hub nousowl: syncthing.service carries 30-delete-retention.conf'
scenario; rm "$HUBFX/unit-system"
out=$(run hub); r=$?
check "no running Syncthing unit: WARN, never OK" has "$out" "^\[WARN\] hub nousowl: no running Syncthing unit for $ME_USER"
check "  exit 2"                             is "$r" 2
scenario; touch "$SB/ssh/nousowl/down"
out=$(run hub); r=$?
check "the hub silent at both doors: WARN"   has "$out" '^\[WARN\] hub nousowl: its readings unread: nousowl did not answer over ssh'
check "  exit 2"                             is "$r" 2
scenario; touch "$SB/ssh/nousowl/down-lan"
check "the hub through its second door: the lines say so" has "$(run hub)" '^\[ OK \] hub nousowl \(through nousowl-vpn\): '
scenario 'fedxps.hub_enc=false'
check "no folder with a hub: OK, said so"    has "$(run hub)" '^\[ OK \] no hub: no folder here is shared with a device that carries an encryption password'

echo "== config: stow's links, the lazy lock, claude-link, bash -n (ws-8) =="
be fedxps; scenario; C="$HOME/Desktop/configs"
out=$(run config); r=$?
check "stow: every entry linked"             has "$out" '^\[ OK \] stow: every top-level entry of 3 packages linked into place, no dangling link into ~/Desktop/configs$'
check "lazy: the installed plugins at the shared lock's commits" has "$out" '^\[ OK \] lazy: 2 installed plugins at the commits of the lock ~/Desktop/configs/nvim/lazy-lock.json$'
check "claude-link's dry run: nothing to change" has "$out" '^\[ OK \] claude-link: its dry run has nothing to change$'
check "bash -n: the rc files and the modules" has "$out" '^\[ OK \] bash -n: ~/.bashrc and ~/.bash_profile and 2 modules in ~/.bashrc.d parse$'
check "  exit 0"                             is "$r" 0
check "  the charter is not asked to be linked (stow ignores it)" lacks "$out" 'CLAUDE.md'
stowfix() { grep '^       fix: ' <<<"$1" | head -1 | sed 's/^       fix: //'; }
rm "$HOME/.config/tool/config"
out=$(run config); r=$?
check "a link missing: FAIL, named"          has "$out" '^\[FAIL\] stow: 1 entry not linked into place \(rules.md -> ws-8\)$'
check "  the entry, why, the package"         has "$out" '^       ~/.config/tool/config  missing \(tool\)$'
check "  fix: restow that package at its target, the command alone" is "$(stowfix "$out")" 'cd ~/Desktop/configs && stow -Rt ~/.config/tool tool'
check "  exit 1"                             is "$r" 1
bash -c "$(stowfix "$out")" >/dev/null 2>&1
check "  the fix, pasted whole, clears it"   has "$(run config)" '^\[ OK \] stow: every top-level entry'
printf 'set -o vi\n' > "$C/bash/.inputrc"
out=$(run config)
check "an arrival: a new top-level file in a package, unlinked: FAIL" has "$out" '^       ~/.inputrc  missing \(bash\)$'
check "  fix: restow bash at ~"              is "$(stowfix "$out")" 'cd ~/Desktop/configs && stow -Rt ~ bash'
bash -c "$(stowfix "$out")" >/dev/null 2>&1
check "  cleared by it"                      has "$(run config)" '^\[ OK \] stow: every top-level entry'
printf 'b\n' > "$C/tool/themes/two"
check "a file arriving inside a folded directory needs nothing" has "$(run config)" '^\[ OK \] stow: every top-level entry'
rm "$C/tool/config"
out=$(run config)
check "a file removed from a package: its dangling link, FAIL" has "$out" '^\[FAIL\] stow: 1 dangling link into ~/Desktop/configs'
check "  named with its destination"         has "$out" '^       ~/.config/tool/config  dangling, to .*Desktop/configs/tool/config \(tool\)$'
bash -c "$(stowfix "$out")" >/dev/null 2>&1
check "  stow -R removes it, as the fix says" has "$(run config)" '^\[ OK \] stow: every top-level entry'
printf 'a = 1\n' > "$C/tool/config"; bash -c 'cd ~/Desktop/configs && stow -Rt ~/.config/tool tool' >/dev/null 2>&1
# themes/ unfolded: a real directory at the target, stow's links inside it
bash -c 'cd ~/Desktop/configs && stow -Dt ~/.config/tool tool && mkdir -p ~/.config/tool/themes && stow -t ~/.config/tool tool' >/dev/null 2>&1
check "an unfolded directory, its entries linked into it" bash -c "[ -d '$HOME/.config/tool/themes' ] && [ ! -L '$HOME/.config/tool/themes' ] && [ -L '$HOME/.config/tool/themes/one' ]"
check "  reads OK"                           has "$(run config)" '^\[ OK \] stow: every top-level entry'
mv "$C/tool/themes" "$SB/themes.keep"
out=$(run config); r=$?
check "the package's subdirectory gone: the links in the unfolded one dangle, FAIL" has "$out" '^\[FAIL\] stow: 2 dangling links into ~/Desktop/configs'
check "  each named"                         has "$out" '^       ~/.config/tool/themes/one  dangling, to .*Desktop/configs/tool/themes/one \(tool\)$'
check "  fix: remove them by name, then restow" is "$(stowfix "$out")" 'rm -- ~/.config/tool/themes/one ~/.config/tool/themes/two && cd ~/Desktop/configs && stow -Rt ~/.config/tool tool'
check "  exit 1"                             is "$r" 1
bash -c "$(stowfix "$out")" >/dev/null 2>&1
check "  the fix, pasted whole, clears it"   has "$(run config)" '^\[ OK \] stow: every top-level entry'
rmdir "$HOME/.config/tool/themes"; mv "$SB/themes.keep" "$C/tool/themes"; bash -c 'cd ~/Desktop/configs && stow -Rt ~/.config/tool tool' >/dev/null 2>&1
ln -s ../configs/tool/nothing "$HOME/Desktop/alpha/broken"; ln -s /nonexistent/elsewhere "$HOME/.config/tool/elsewhere"
check "a dangling link inside ~/Desktop, or one into elsewhere, is not stow's: OK" has "$(run config)" '^\[ OK \] stow: every top-level entry'
rm -f "$HOME/Desktop/alpha/broken" "$HOME/.config/tool/elsewhere"
rm "$HOME/.bash_profile"; printf '# a real file\n' > "$HOME/.bash_profile"
out=$(run config)
check "a real file where stow would link: FAIL" has "$out" '^       ~/.bash_profile  a real file where stow would link \(bash\)$'
check "  the fix moves it aside, then restows" is "$(stowfix "$out")" 'mv ~/.bash_profile ~/.bash_profile.pre-stow && cd ~/Desktop/configs && stow -Rt ~ bash'
check "  with a note saying why"             has "$out" 'note: stow refuses to link over a real file'
bash -c "$(stowfix "$out")" >/dev/null 2>&1
check "  cleared by it, the real file kept beside" bash -c "[ -L '$HOME/.bash_profile' ] && [ -f '$HOME/.bash_profile.pre-stow' ]"
rm -f "$HOME/.bash_profile.pre-stow"
check "  and reads OK"                       has "$(run config)" '^\[ OK \] stow: every top-level entry'
cp "$C/bash/.bashrc.d/60-stow.sh" "$SB/60-stow.sh.keep"; printf 'declare -A STOW_TARGETS=()\n' > "$C/bash/.bashrc.d/60-stow.sh"
out=$(run config); r=$?
check "a map that names nothing: WARN, never OK" has "$out" '^\[WARN\] stow: no package map read from ~/Desktop/configs/bash/.bashrc.d/60-stow.sh'
check "  exit 2"                             is "$r" 2
cp "$SB/60-stow.sh.keep" "$C/bash/.bashrc.d/60-stow.sh"
git -C "$HOME/.local/share/nvim/lazy/alpha.nvim" commit -q --allow-empty -m two
out=$(run config); r=$?
check "a plugin off the lock's commit: FAIL, named" has "$out" '^\[FAIL\] lazy: 1 plugin of 2 installed away from the commits of the lock ~/Desktop/configs/nvim/lazy-lock.json: alpha.nvim \([0-9a-f]{7}, the lock [0-9a-f]{7}\)$'
check "  fix: Lazy's restore, the command alone" is "$(grep '^       fix: nvim' <<<"$out" | sed 's/^       fix: //')" 'nvim --headless "+Lazy! restore" +qa'
check "  exit 1"                             is "$r" 1
mkdir -p "$HOME/.local/state/nvim"
python3 - "$C/nvim/lazy-lock.json" "$HOME/.local/state/nvim/lazy-lock.json" "$(git -C "$HOME/.local/share/nvim/lazy/alpha.nvim" rev-parse HEAD)" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["alpha.nvim"]["commit"] = sys.argv[3]; open(sys.argv[2], "w").write(json.dumps(d))
PY
out=$(run config)
check "a reader's own copy agreeing with the plugins plays no part: the shared lock decides, FAIL" has "$out" '^\[FAIL\] lazy: 1 plugin of 2 installed away from the commits of the lock ~/Desktop/configs/nvim/lazy-lock.json: alpha.nvim'
check "  the copy is not named"               lacks "$out" 'state/nvim'
be bigfed; scenario; mkdir -p "$HOME/.local/state/nvim"; cp "$SB/ssh/fedxps/home/.local/state/nvim/lazy-lock.json" "$HOME/.local/state/nvim/"
git -C "$HOME/.local/share/nvim/lazy/alpha.nvim" commit -q --allow-empty -m two
check "a writer ignores such a copy: the shared lock decides, FAIL" has "$(run config)" '^\[FAIL\] lazy: 1 plugin of 2 installed away from the commits of the lock ~/Desktop/configs/nvim/lazy-lock.json'
git -C "$HOME/.local/share/nvim/lazy/alpha.nvim" reset -q --hard HEAD~1
be fedxps; scenario; A="$HOME/.local/share/nvim/lazy/alpha.nvim"
arrived=$(git -C "$A" rev-parse HEAD); git -C "$A" reset -q --hard HEAD~1; installed=$(git -C "$A" rev-parse HEAD)
# a lock that has just arrived, ahead of the installed plugin; the reader's
# copy, rewritten by lazy's install pass, names what is installed
cp "$C/nvim/lazy-lock.json" "$SB/lazy-lock.keep"
python3 - "$SB/lazy-lock.keep" "$C/nvim/lazy-lock.json" "$arrived" "$HOME/.local/state/nvim/lazy-lock.json" "$installed" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["alpha.nvim"]["commit"] = sys.argv[3]; open(sys.argv[2], "w").write(json.dumps(d))
d["alpha.nvim"]["commit"] = sys.argv[5]; open(sys.argv[4], "w").write(json.dumps(d))
PY
out=$(run config); r=$?
check "a lock just arrived, the plugin behind it, the reader's copy at the plugin: FAIL" has "$out" "^\[FAIL\] lazy: 1 plugin of 2 installed away from the commits of the lock ~/Desktop/configs/nvim/lazy-lock.json: alpha.nvim \(${installed:0:7}, the lock ${arrived:0:7}\)$"
check "  exit 1"                             is "$r" 1
cp "$SB/lazy-lock.keep" "$C/nvim/lazy-lock.json"; rm -f "$HOME/.local/state/nvim/lazy-lock.json"
check "  the lock as it was: OK"             has "$(run config)" '^\[ OK \] lazy: 2 installed plugins'
: > "$STUB_CL_LOG"
out=$(STUB_CL_RC=1 run config); r=$(STUB_CL_RC=1 rc config)
check "claude-link with changes pending (exit 1): FAIL" has "$out" '^\[FAIL\] claude-link: its dry run has changes pending \(exit 1\)$'
check "  its own lines shown"                has "$out" '^       \[LINK\] would link x$'
check "  fix: --apply, the command alone"     has "$out" '^       fix: claude-link --apply$'
check "  exit 1"                             is "$r" 1
check "  the dry run ran with no argument (it changes nothing)" has "$(cat "$STUB_CL_LOG")" '/bin/claude-link\|$'
out=$(STUB_CL_RC=2 run config)
check "claude-link with conflicts (exit 2): FAIL, read by hand" has "$out" '^\[FAIL\] claude-link: its dry run reports conflicts or errors \(exit 2\)$'
check "  fix: the dry run, to read"          has "$out" '^       fix: claude-link$'
W='[WARN] exists and is not a link: ~/.claude/agents   (re-run with --adopt)'
out=$(STUB_CL_RC=0 STUB_CL_LINE="$W" run config); r=$(STUB_CL_RC=0 STUB_CL_LINE="$W" rc config)
check "claude-link exits 0 but warns (a copy where its link should be): WARN, never OK" has "$out" '^\[WARN\] claude-link: its dry run exits 0 but warns: 1 line$'
check "  the warning shown"                  has "$out" '^       \[WARN\] exists and is not a link: ~/.claude/agents'
check "  no OK line for it"                  lacks "$out" '^\[ OK \] claude-link'
check "  fix: the dry run, to read each step" has "$out" '^       fix: claude-link$'
check "  exit 2"                             is "$r" 2
out=$(STUB_CL_RC=0 STUB_CL_LINE='[FAIL] cannot read x' run config)
check "exit 0 with a [FAIL] line: WARN too"  has "$out" '^\[WARN\] claude-link: its dry run exits 0 but warns'
out=$(STUB_CL_RC=1 STUB_CL_LINE="$W" run config)
check "exit 1 with a warning: FAIL, as for exit 1" has "$out" '^\[FAIL\] claude-link: its dry run has changes pending \(exit 1\)$'
printf 'if then\n' > "$C/bash/.bashrc.d/50-bad.sh"
printf 'if then\n' > "$C/bash/.bashrc.d/40-x.sync-conflict-20261009-195347-ABCDEFG.sh"
out=$(run config); r=$?
check "a module that does not parse: FAIL, named" has "$out" '^\[FAIL\] bash -n: 1 file does not parse: ~/.bashrc.d/50-bad.sh$'
check "  fix: open it at the line"           has "$out" '^       fix: nvim \+1 ~/.bashrc.d/50-bad.sh$'
check "  a conflict copy among the modules is left to ws-2" lacks "$out" 'sync-conflict'
check "  exit 1"                             is "$r" 1
rm -f "$C/bash/.bashrc.d/50-bad.sh" "$C/bash/.bashrc.d/40-x.sync-conflict-20261009-195347-ABCDEFG.sh"

echo "== guard: the hook a reader's host file arms (fedxps-6) =="
be fedxps; export GIT_OPTIONAL_LOCKS=0; scenario; C="$HOME/Desktop/configs"
check "no hooksPath in the host file: no hook line" lacks "$(run guard)" 'hooksPath'
printf '%b[core]\n\thooksPath = ~/.config/git/hooks-reader\n' "$FEDINC" > "$HOSTS_FED/fedxps.inc"
mkdir -p "$C/git/hooks-reader"; printf '#!/bin/sh\nexit 0\n' > "$C/git/hooks-reader/reference-transaction"; chmod +x "$C/git/hooks-reader/reference-transaction"
out=$(run guard); r=$?
check "hooksPath armed, the package not restowed: FAIL" has "$out" '^\[FAIL\] core.hooksPath names ~/.config/git/hooks-reader, which holds no reference-transaction'
check "  the key itself resolves (the key check passes it)" has "$out" '^\[ OK \] git resolves every setting in hosts/fedxps.inc from the link: core.checkstat, core.hookspath'
check "  fix: restow the git package, the command alone" is "$(grep '^       fix: ' <<<"$out" | grep stow | sed 's/^       fix: //')" 'cd ~/Desktop/configs && stow -Rt ~/.config/git git'
check "  exit 1"                             is "$r" 1
bash -c 'cd ~/Desktop/configs && stow -Rt ~/.config/git git' >/dev/null 2>&1
out=$(run guard); r=$?
check "the fix, pasted whole: the hook in place, OK" has "$out" '^\[ OK \] core.hooksPath = ~/.config/git/hooks-reader holds an executable reference-transaction \(fedxps-6\)$'
check "  exit 0"                             is "$r" 0
chmod -x "$C/git/hooks-reader/reference-transaction"
out=$(run guard); r=$?
check "the hook linked but not executable: FAIL" has "$out" '^\[FAIL\] ~/.config/git/hooks-reader/reference-transaction is not executable'
check "  a note names the package's file"    has "$out" '^       note: the bit belongs on the package.s file, which the link resolves to: ~/Desktop/configs/git/hooks-reader/reference-transaction$'
check "  fix: the bit on that file"          has "$out" '^       fix: chmod \+x ~/Desktop/configs/git/hooks-reader/reference-transaction$'
check "  exit 1"                             is "$r" 1
bash -c "$(grep '^       fix: chmod' <<<"$out" | sed 's/^       fix: //')"
check "  the fix, pasted whole, clears it"   has "$(run guard)" '^\[ OK \] core.hooksPath = '
printf '%b' "$FEDINC" > "$HOSTS_FED/fedxps.inc"
be bigfed; unset GIT_OPTIONAL_LOCKS; scenario
check "a writer's host file arms no hook: no hook line" lacks "$(run guard)" 'hooksPath'

echo "== guard on a writer: no git maintenance running or cut short (bigfed-1) =="
be bigfed; unset GIT_OPTIONAL_LOCKS; scenario
out=$(run guard); r=$?
check "nothing running, no lock: OK"         has "$out" '^\[ OK \] no git maintenance running, and no maintenance.lock under ~/Desktop/\*/.git \(bigfed-1\)$'
check "  exit 0"                             is "$r" 0
printf '   4241 /usr/libexec/git-core/git maintenance run --auto --no-quiet\n' > "$PS_PROCS"
check "git under any path, by argv[0]'s name: FAIL" has "$(run guard)" '^\[FAIL\] git maintenance is running \(pid 4241\)'
printf '   4242 /usr/bin/git maintenance run --auto --no-quiet\n   4243 /bin/bash -c eval '"'"'git maintenance run'"'"'\n' > "$PS_PROCS"
out=$(run guard); r=$?
check "git maintenance running: FAIL, the pid" has "$out" '^\[FAIL\] git maintenance is running \(pid 4242\): a power-off now would cut the repack short'
check "  fix: wait for it, the command alone" has "$out" '^       fix: tail --pid=4242 -f /dev/null$'
check "  the wrapper carrying the words is not counted" lacks "$out" '4243'
check "  exit 1"                             is "$r" 1
printf '   4243 /bin/bash -c eval '"'"'git maintenance run'"'"'\n' > "$PS_PROCS"
check "a command line carrying the words alone: OK" has "$(run guard)" '^\[ OK \] no git maintenance running'
for argv in 'git -C /home/x/Desktop/nousowl maintenance run --task=gc' 'git -c a=b maintenance run' '/usr/bin/git --git-dir=/x/.git maintenance run' 'git --git-dir /x/.git --no-pager maintenance run --auto'; do
  printf '   4250 %s\n' "$argv" > "$PS_PROCS"
  check "'$argv' is a running maintenance: FAIL" has "$(run guard)" '^\[FAIL\] git maintenance is running \(pid 4250\)'
done
printf '   4253 less maintenance\n   4254 git log maintenance\n' > "$PS_PROCS"
check "'less maintenance' and 'git log maintenance' are not: OK" has "$(run guard)" '^\[ OK \] no git maintenance running'
: > "$PS_PROCS"
for i in 1 2 3; do echo "o$i" > "$HOME/Desktop/nousowl/o$i"; git -C "$HOME/Desktop/nousowl" add "o$i"; git -C "$HOME/Desktop/nousowl" commit -qm "o$i"; done
loose_before=$(git -C "$HOME/Desktop/nousowl" count-objects | cut -d' ' -f1)
touch "$HOME/Desktop/nousowl/.git/objects/maintenance.lock"
out=$(run guard); r=$?
check "a lock with nothing running: FAIL, a repack cut short" has "$out" '^\[FAIL\] ~/Desktop/nousowl/.git/objects/maintenance.lock stands with no git maintenance running'
fixl=$(grep '^       fix: ' <<<"$out" | head -1 | sed 's/^       fix: //')
check "  fix: the lock first, then the repack" is "$fixl" 'rm ~/Desktop/nousowl/.git/objects/maintenance.lock && git -C ~/Desktop/nousowl maintenance run --task=gc'
check "  the note says why the lock goes first" has "$out" 'note: git skips maintenance while the lock stands'
check "  exit 1"                             is "$r" 1
printf '   4242 /usr/bin/git maintenance run --auto\n' > "$PS_PROCS"
check "the lock held by a running maintenance: the running FAIL" has "$(run guard)" '^\[FAIL\] git maintenance is running \(pid 4242\)'
printf '   4255 git -C /home/x/Desktop/nousowl maintenance run --task=gc\n' > "$PS_PROCS"
out=$(run guard)
check "the lock held by 'git -C <repo> maintenance run': the running FAIL" has "$out" '^\[FAIL\] git maintenance is running \(pid 4255\)'
check "  never the fix that removes a live lock" lacks "$out" 'fix: rm '
: > "$PS_PROCS"
bash -c "$fixl" >/dev/null 2>&1
check "  the fix, pasted whole, removes the lock" bash -c "[ ! -e '$HOME/Desktop/nousowl/.git/objects/maintenance.lock' ]"
check "  and repacks: fewer loose objects than the three commits left" bash -c "[ \$(git -C '$HOME/Desktop/nousowl' count-objects | cut -d' ' -f1) -lt $loose_before ]"
check "  and reads OK"                       has "$(run guard)" '^\[ OK \] no git maintenance running'
touch "$PS_FAIL"
out=$(run guard); r=$?
check "the process table unreadable: WARN"  has "$out" '^\[WARN\] the process table cannot be read'
check "  exit 2"                             is "$r" 2
rm -f "$PS_FAIL"
be fedxps; export GIT_OPTIONAL_LOCKS=0; scenario; printf '   4242 /usr/bin/git maintenance run\n' > "$PS_PROCS"
check "a reader has no maintenance line"     lacks "$(run guard)" 'git maintenance running'
mkrepos     # the commits and the repack above moved bigfed's HEAD past fedxps's

echo "== push: another machine's counter under the repository's .git (D5 from the writer's side) =="
be bigfed; unset GIT_OPTIONAL_LOCKS
VF='{"version":["BIGFEDX:1791668457","FEDXPSX:1793037467"],"modifiedBy":"FEDXPSX","modified":"2026-10-26T10:57:53.0-07:00"}'
scenario "file:bigfed:f2:.git/index=$VF"
out=$(run push nousowl); r=$?
check "a .git path carrying the reader's counter: the push FAILs" has "$out" "^\[FAIL\] nousowl: 1 path under its .git carries another machine's counter: a write there, which a commit here would carry"
check "  the path, its modifier, the counter's time" has "$out" "^       2026-10-26T10:57:53  ~/Desktop/nousowl/.git/index  last modified by fedxps; fedxps's counter 1793037467 \(20[0-9-]+ [0-9:]+\)$"
check "  the note: the index and working tree may hold the reader's change" has "$out" 'note: a reader.s refused checkout or reset moves the index and the working tree'
check "  fix: read the status here, the command alone" has "$out" '^       fix: git -C ~/Desktop/nousowl status$'
check "  read from this machine's database"   has "$(reqs bigfed)" '^GET /rest/db/browse\?folder=f2&prefix=\.git$'
check "  and no OK line beside the FAIL"      lacks "$out" '^\[ OK \] nousowl: folder'
check "  exit 1"                             is "$r" 1
scenario 'file:bigfed:f2:.git/HEAD={"local":{"version":["BIGFEDX:1791668457","FEDXPSX:1793037470"],"modifiedBy":"FEDXPSX"}}'
check "the local version alone carrying it: FAIL" has "$(run push nousowl)" '^\[FAIL\] nousowl: 1 path under its .git carries'
scenario 'file:bigfed:f2:README.md={"version":["BIGFEDX:1791668457","FEDXPSX:1793037470"]}'
check "the reader's counter outside .git: the push OK" has "$(run push nousowl)" '^\[ OK \] nousowl: folder nousowl up to date, nothing under .git needed, no phantom ref; HEAD equal on fedxps;'
# (d) from the writer's side: 22 paths, the 22nd alone with its counter
VP() { printf '{"version":["BIGFEDX:1791668457","FEDXPSX:%s"],"modifiedBy":"FEDXPSX"}' "$1"; }
args=(); for i in $(seq -w 1 21); do args+=("file:bigfed:f2:.git/objects/ab/obj$i=$(VP 1793037467)"); done
args+=("file:bigfed:f2:.git/objects/ab/obj22=$(VP 1793037480)")
scenario "${args[@]}"
out=$(run push nousowl); today=$(date +%F)
check "(d) the push line, 22 paths, the 22nd alone with its counter: the 20th listed" has "$out" 'objects/ab/obj20  '
check "  the 22nd past the list"               lacks "$out" 'objects/ab/obj22  '
check "  the literal lines carry both counters" is "$(literals "$out")" "fedxps nousowl 1793037467 $today
fedxps nousowl 1793037480 $today"
scenario 'file:bigfed:f2:.git/index={"version":["BIGFEDX:1791668457","FEDXPSX:1792640450"],"modifiedBy":"FEDXPSX"}'
out=$("$WGAUGE" push nousowl 2>&1); r=$?
check "the write carried in KNOWN_WRITES: the push OK, the known write named" has "$out" '^\[ OK \] nousowl: folder nousowl up to date, nothing under .git needed, no phantom ref; HEAD equal on fedxps; the known write .git/index from fedxps \(since 2026-10-20: a stand-in\);'
check "  exit 0"                             is "$r" 0
scenario 'file:bigfed:f2:.git/index={"version":["BIGFEDX:1791668457","FEDXPSX:1792640999"],"modifiedBy":"FEDXPSX"}'
check "  a later write on the same path: FAIL" has "$("$WGAUGE" push nousowl 2>&1)" '^\[FAIL\] nousowl: 1 path under its .git carries'
# Step 5c-b (settled 79): the same matching from the writer's side, by machine and counter
vb() { printf '{"version":["BIGFEDX:1791668457","FEDXPSX:%s"],"modifiedBy":"FEDXPSX","modified":"2026-10-27T10:00:00.5-07:00"}' "$1"; }
scenario "file:bigfed:f2:.git/refs/heads/main=$(vb $FRESH)"
out=$("$WGAUGE2" push nousowl 2>&1); r=$?
check "a counter-keyed known write: the push OK, the write named by its counter and note" has "$out" "^\[ OK \] nousowl: folder nousowl up to date, nothing under .git needed, no phantom ref; HEAD equal on fedxps; the known write by counter $FRESH from fedxps on 1 path \(since 2026-10-27: a stand-in by counter\);"
check "  exit 0"                             is "$r" 0
scenario "file:bigfed:f2:.git/refs/heads/main=$(vb $FRESH)" "file:bigfed:f2:.git/objects/pack=$(vb $FRESH)"
check "  a second path with the same counter: OK" has "$("$WGAUGE2" push nousowl 2>&1)" "^\[ OK \] nousowl: .*the known write by counter $FRESH from fedxps on 2 paths"
scenario "file:bigfed:f2:.git/refs/heads/main=$(vb $FRESH)" "file:bigfed:f2:.git/index=$(vb $LATER)"
out=$("$WGAUGE2" push nousowl 2>&1); r=$?; today=$(date +%F)
check "  a different counter: FAIL, that path alone" has "$out" "^\[FAIL\] nousowl: 1 path under its .git carries another machine's counter"
check "  the entry printed with on: fedxps, a Python literal" is "$(literals "$out")" "fedxps nousowl $LATER $today"
check "  exit 1"                             is "$r" 1
scenario "file:bigfed:f2:.git/index=$VF"
out=$(run push nousowl); today=$(date +%F)
check "the push line's FAIL prints the entry for the reader's counter" is "$(literals "$out")" "fedxps nousowl 1793037467 $today"
check "  the note: read the status first, then paste these lines, one per counter" has "$out" "note: a reader's refused checkout or reset moves the index and the working tree before its hook refuses, so read the status here before any commit; once the write is explained, paste these lines into KNOWN_WRITES in bin/sync-check \(configs\), one per counter: a counter stays in a path's vector for good and returns on a path git writes again \(cutover/rehearsal/refute-b.md -> A9\), so the entry names the counter, not the path$"
check "  the note, the entry, then the fix, the command alone" is "$(grep -E '^       (note|fix):|^       \{' <<<"$out" | sed -E 's/^       (note|fix):.*/\1/; s/^       \{.*/literal/' | paste -sd' ')" "note literal fix"
paste_known "$out" "$SB/sync-check-pasted-push"
check "  pasted as printed: the push OK"       has "$("$SB/sync-check-pasted-push" push nousowl 2>&1)" "^\[ OK \] nousowl: .*the known write by counter 1793037467 from fedxps on 1 path \(since $today: <why: "
# the push line's .git fix when a phantom is present too (settled 79; refute-b.md -> F1)
G=('bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=[".git/refs/heads/main"]' 'nousowl.folders.f2.completion.BIG.needItems=1')
LOSER="the hub holds the loser of these .git paths (a split with the direct link up): on fedxps, touch exactly these paths under the repository's .git (those listed 'bigfed -> hub') and nothing else; then the phantom repair below (org/machines/transport-2026-10/rules.md -> him-2)"
scenario "${G[@]}"
cp "$HOME/Desktop/nousowl/.git/refs/heads/main" "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261027-022459-FEDXPSX"
out=$(run push nousowl); r=$?
check "needed .git paths beside a phantom ref: the hub holds the loser, the touch on fedxps first" is "$(fixof "$out" 'under its .git needed')" "$LOSER"
check "  never 'a split with no phantom'"      lacks "$out" 'a split with no phantom'
check "  the phantom FAIL as it is"            has "$out" '^\[FAIL\] nousowl: 1 phantom ref and 1 conflict copy under .git$'
check "  and its fix, rename first"            has "$out" 'fix: once the folder is quiet 15 s and `git fsck --connectivity-only` passes: rename the phantom to a name without sync-conflict'
check "  the phantom repair printed below the touch" before "$out" 'the hub holds the loser' 'phantom ref and'
check "  exit 1"                             is "$r" 1
rm "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261027-022459-FEDXPSX"
echo x > "$HOME/Desktop/nousowl/.git/index.sync-conflict-20261027-022459-FEDXPSX"
check "a conflict copy under .git alone beside them: the same opening" is "$(fixof "$(run push nousowl)" 'under its .git needed')" "$LOSER"
rm "$HOME/Desktop/nousowl/.git/index.sync-conflict-20261027-022459-FEDXPSX"
out=$(run push nousowl)
check "with no phantom: today's opening"      is "$(fixof "$out" 'under its .git needed')" "a split with no phantom: on fedxps, touch exactly these paths under the repository's .git (those listed 'bigfed -> hub') and nothing else; the phantom branch then appears here, rename it, commit the working tree, delete the inert copies (org/machines/transport-2026-10/rules.md -> him-2)"
check "  never the loser's"                    lacks "$out" 'the hub holds the loser'
N7='[".git/COMMIT_EDITMSG",".git/index",".git/logs/HEAD",".git/logs/refs/heads/main",".git/objects/b6",".git/objects/pack/pack-1.pack",".git/refs/heads/main"]'
# the seven exist here, as a split's do on the writer (a path absent here is a
# refused deletion, its own line since 2026-10-27): those the sandbox clone
# lacks are made for the case, and only they removed after it
made7=()
for p in .git/COMMIT_EDITMSG .git/logs/HEAD .git/logs/refs/heads/main .git/objects/pack/pack-1.pack; do
  q="$HOME/Desktop/nousowl/$p"; [ -e "$q" ] || { : > "$q"; made7+=("$q"); }
done
q="$HOME/Desktop/nousowl/.git/objects/b6"; [ -e "$q" ] || { mkdir "$q"; made7+=("$q"); }
scenario 'bigfed.folders.f2.completion.HUB.needItems=7' "bigfed.folders.f2.completion.HUB.names=$N7" 'nousowl.folders.f2.completion.BIG.needItems=7'
out=$(run push nousowl)
check "seven .git paths needed: the push line lists all seven, the touch being of exactly these" has "$out" '^\[FAIL\] nousowl: 7 paths under its \.git needed: bigfed -> hub \.git/COMMIT_EDITMSG; .*; bigfed -> hub \.git/refs/heads/main$'
check "  and the sync line all seven"         has "$out" '^\[FAIL\] nousowl: stranded on bigfed: \.git/COMMIT_EDITMSG, .*, \.git/objects/pack/pack-1\.pack, \.git/refs/heads/main$'
for q in "${made7[@]}"; do rm -rf -- "$q"; done
scenario "file:bigfed:f2:.git/index={\"version\":[\"BIGFEDX:1791668457\",\"ZZZZZZZ:$FRESH\"],\"modifiedBy\":\"ZZZZZZZ\"}"
out=$("$WGAUGE2" push nousowl 2>&1)
check "the entry's counter written by another device: FAIL, the entry names its machine" has "$out" "^\\[FAIL\\] nousowl: 1 path under its .git carries another machine's counter"
check "  the line printed for that device"    is "$(literals "$out")" "ZZZZZZZ nousowl $FRESH $(date +%F)"
scenario "file:bigfed:f2:.git/index=$(vb $LATER)" "file:bigfed:f2:.git/config=$(vb $LATER)" "file:bigfed:f2:.git/HEAD=$(vb $LATER)"
out=$(run push nousowl)
check "three paths, one counter: three paths listed, one line to paste" is "$(grep -c "fedxps's counter $LATER" <<<"$out") $(literals "$out")" "3 fedxps nousowl $LATER $(date +%F)"
scenario
python3 - "$SB/fx/bigfed/responses.json" <<'PY'
import json, sys
p = sys.argv[1]; t = json.load(open(p)); t["GET /rest/db/browse?folder=f2&prefix=.git"] = {"status": 500, "body": "boom"}; json.dump(t, open(p, "w"))
PY
out=$(run push nousowl); r=$?
check "the vectors unreadable: WARN, never OK" has "$out" '^\[WARN\] nousowl: the version vectors under its .git cannot be read: ~/Desktop/nousowl: db/browse answered 500'
check "  no OK line beside it"                lacks "$out" '^\[ OK \] nousowl: folder'
check "  exit 2"                             is "$r" 2
scenario; SNAP="$SB/snapshot.json"; rm -f "$SNAP"; (umask 077; : > "$SNAP")
SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl >/dev/null
scenario "file:bigfed:f2:.git/index=$VF"
out=$(SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl)
check "with a fresh snapshot the vectors are still read live: FAIL" has "$out" '^\[FAIL\] nousowl: 1 path under its .git carries'
check "  the folder from the snapshot, no scan" lacks "$(reqs bigfed)" 'db/scan'
rm -f "$SNAP"

echo "== push: the folder-once snapshot for gpushall (build-gauge reading 6) =="
be bigfed; unset GIT_OPTIONAL_LOCKS; scenario
SNAP="$SB/snapshot.json"; rm -f "$SNAP"; (umask 077; : > "$SNAP")
out1=$(SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl); r1=$?
out2=$(SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl); r2=$?
check "two pushes with the variable: both OK" is "$r1 $r2" "0 0"
check "  the folder scanned once"            is "$(grep -c '^POST /rest/db/scan?folder=f2$' "$SB/fx/bigfed/requests.log")" 1
check "  the hub read once"                  is "$(grep -c '^nousowl: python3 -I - --remote-views' "$SB/ssh.log")" 1
check "  the hub's daemon asked once"        is "$(grep -c '^GET /rest/system/status$' "$SB/fx/nousowl/requests.log")" 1
check "  the peer's HEAD still read live, each time" is "$(grep -c '^fedxps: GIT_OPTIONAL_LOCKS=0 git' "$SB/ssh.log")" 2
check "  the second says where its folder reading came from" has "$out2" '^\[ OK \] nousowl: folder nousowl up to date from the snapshot taken [0-9]+ s ago, nothing under .git needed, no phantom ref; HEAD equal on fedxps'
check "  the first does not"                 lacks "$out1" 'snapshot'
check "  the file is 0600"                   is "$(stat -c %a "$SNAP")" 600
check "  it holds no key"                    lacks "$(cat "$SNAP")" "$KEY"
check "  it is JSON with the folder's readings" bash -c "python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert \"f2\" in d[\"folders\"]' '$SNAP'"
cp "$HOME/Desktop/nousowl/.git/refs/heads/main" "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
out=$(SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl); r=$?
check "a phantom ref after the snapshot: found live, FAIL" has "$out" '^\[FAIL\] nousowl: 1 phantom ref'
check "  exit 1"                             is "$r" 1
rm "$HOME/Desktop/nousowl/.git/refs/heads/main.sync-conflict-20261009-162229-ABCDEFG"
python3 - "$SNAP" <<'PY'
import json, sys, time
p = sys.argv[1]; d = json.load(open(p)); d["folders"]["f2"]["taken"] = time.time() - 400; json.dump(d, open(p, "w"))
PY
SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl >/dev/null
check "a snapshot past its 300 s: the folder read again" is "$(grep -c '^POST /rest/db/scan?folder=f2$' "$SB/fx/bigfed/requests.log")" 2
sleep 1.2
SYNC_CHECK_SNAPSHOT="$SNAP" SYNC_CHECK_SNAPSHOT_TTL=1 run push nousowl >/dev/null
check "  SYNC_CHECK_SNAPSHOT_TTL shortens it" is "$(grep -c '^POST /rest/db/scan?folder=f2$' "$SB/fx/bigfed/requests.log")" 3
python3 - "$SNAP" <<'PY'
import json, sys, time
p = sys.argv[1]; d = json.load(open(p)); d["folders"]["f2"]["taken"] = time.time() + 100; json.dump(d, open(p, "w"))
PY
SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl >/dev/null
check "a snapshot dated in the future: not used, the folder read again" is "$(grep -c '^POST /rest/db/scan?folder=f2$' "$SB/fx/bigfed/requests.log")" 4
scenario 'bigfed.folders.f2.state="syncing"'
rm -f "$SNAP"; (umask 077; : > "$SNAP")
SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl >/dev/null
scenario
out=$(SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl); r=$?
check "a WAIT from the snapshot says so on its line" has "$out" '^\[WAIT\] nousowl: syncing on this machine \(from the snapshot taken [0-9]+ s ago\)$'
check "  exit 1"                             is "$r" 1
printf '{not json' > "$SNAP"
out=$(SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl); r=$?
check "an unreadable snapshot: the cluster read, OK, no traceback" is "$r" 0
check "  and the file written whole again"    bash -c "python3 -c 'import json,sys; json.load(open(sys.argv[1]))' '$SNAP'"
scenario 'bigfed.folders.f2.completion.HUB.needItems=1' 'bigfed.folders.f2.completion.HUB.names=[".git/refs/heads/main"]' 'nousowl.folders.f2.completion.BIG.needItems=1'
rm -f "$SNAP"; (umask 077; : > "$SNAP")
SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl >/dev/null
scenario
out=$(SYNC_CHECK_SNAPSHOT="$SNAP" run push nousowl); r=$?
check "the .git needs read from the stored views: still FAIL, the cluster unread" has "$out" '^\[FAIL\] nousowl: 1 path under its \.git needed: bigfed -> hub \.git/refs/heads/main'
check "  no scan this time"                  lacks "$(reqs bigfed)" 'db/scan'
check "  exit 1"                             is "$r" 1
scenario
run push nousowl >/dev/null
check "without the variable nothing is written: no snapshot beside it" bash -c "! ls '$SB'/.sync-check-snapshot.* >/dev/null 2>&1"

# ==============================================================================
echo "== session: the newest full reading with its age, the cheap lines live (settled 76, 77) =="
# Step 5c-b (2026-10-27): the hook's line reprints each folder's newest full
# reading from the reading file, which every live read of the sync line's
# folders writes, and reads conflicts, guard without the version vectors,
# config without claude-link and hub live; no scan, no --remote-views.
be fedxps; export GIT_OPTIONAL_LOCKS=0; scenario; : > "$STUB_CL_LOG"
rm -rf "$SB"/ssh/*/home/.local/state/sync-check
RDIR="$SB/ssh/fedxps/home/.local/state/sync-check"; RF="$RDIR/readings.json"
out=$(run session); r=$?
check "no reading file: one WARN per folder, no full reading on record" is "$(grep -cE '^\[WARN\] (alpha|nousowl|gamma): no full reading on record$' <<<"$out")" 3
check "  each with its fix, a full run"       is "$(grep -c '^       fix: sync-check sync$' <<<"$out")" 3
check "  exit 2"                             is "$r" 2
check "  no scan"                            lacks "$(reqs fedxps)" 'db/scan'
check "  no db/browse or db/file: the guard's vectors left out" lacks "$(reqs fedxps)" 'db/(browse|file)'
check "  no --remote-views over ssh"         lacks "$(cat "$SB/ssh.log")" 'remote-views'
check "  conflicts read live"                has "$out" '^\[ OK \] under .git: no conflict copy'
check "  guard read live, its disk events too" has "$out" '^\[ OK \] no write under a .git this machine reads, in 0 disk events'
check "  config read live, without claude-link" has "$out" '^\[ OK \] stow: every top-level entry'
check "  the claude-link stub never started" is "$(cat "$STUB_CL_LOG" 2>/dev/null)" ""
check "  hub read live by its own ssh, last" has "$(grep '^\[' <<<"$out" | tail -1)" '^\[ OK \] hub nousowl: '
check "  the hub asked by --remote-hub alone" has "$(cat "$SB/ssh.log")" '^nousowl: python3 -I - --remote-hub$'
check "  nothing written by it"              bash -c "[ ! -e '$RDIR' ]"
check "  -v says where the vectors are read (settled 77)" has "$(run session -v)" 'the version vectors are read by `sync-check guard`, the bare run and the push line'
: > "$SB/fx/fedxps/requests.log"; run guard >/dev/null
check "  while guard alone still reads them"  has "$(reqs fedxps)" '^GET /rest/db/browse\?folder=f2&prefix=\.git$'
run sync >/dev/null
check "a sync run writes the reading file"   bash -c "[ -f '$RF' ]"
check "  mode 600"                           is "$(stat -c %a "$RF")" 600
check "  in a directory of mode 700"         is "$(stat -c %a "$RDIR")" 700
check "  nothing else beside it"             is "$(ls -A "$RDIR")" readings.json
check "  JSON, one record per folder"        bash -c "python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert sorted(d[\"folders\"])==[\"f1\",\"f2\",\"f3\"], d' '$RF'"
check "  it holds no key"                    lacks "$(cat "$RF")" "$KEY"
: > "$SB/fx/fedxps/requests.log"; : > "$SB/ssh.log"
out=$(run session); r=$?
check "session: each folder OK by the stored reading, its caller and age" is "$(grep -cE '^\[ OK \] (alpha|nousowl|gamma): up to date \(the newest full reading, by sync-check sync [0-9]+ s ago\)$' <<<"$out")" 3
check "  the hook's count regex matches each" is "$(grep -cE '^\[ OK \] [^:]+: up to date' <<<"$out")" 3
check "  none before this boot"              lacks "$out" 'before this boot'
check "  exit 0"                             is "$r" 0
check "  still no scan, no db/browse, no --remote-views" bash -c "! grep -qE 'db/(scan|browse|file)' '$SB/fx/fedxps/requests.log' && ! grep -q remote-views '$SB/ssh.log'"
check "  the daemon answering: no word of it" lacks "$out" 'not answering|system/status answered'
# the daemon itself (the lead's follow-up, 2026-10-27): one GET of
# system/status first, the only request beyond guard's own disk-event pair
check "  of this machine's daemon: system/status, then guard's two reads, nothing else" is "$(reqs fedxps)" "GET /rest/system/status
GET /rest/events/disk?since=0&limit=1000&timeout=0
GET /rest/system/status"
DEAD=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
sed "s#<address>127.0.0.1:$P_FED</address>#<address>127.0.0.1:$DEAD</address>#" "$SYNC_CHECK_CONFIG" > "$SB/dead-daemon.xml"
out=$(SYNC_CHECK_CONFIG="$SB/dead-daemon.xml" run session); r=$?
check "a daemon that does not answer: a WARN, the first line" is "$(grep '^\[' <<<"$out" | head -1)" "[WARN] Syncthing is not answering at http://127.0.0.1:$DEAD/rest/"
check "  its fix as read_live prints it"       is "$(sed -n 2p <<<"$out")" "       fix: systemctl --user status syncthing   # then read again"
check "  the stored readings still print after it" is "$(grep -cE '^\[ OK \] (alpha|nousowl|gamma): up to date \(the newest full reading' <<<"$out")" 3
check "  exit 2"                              is "$r" 2
# the hook's cut: the hub's command hangs, timeout ends the run at 4 s as the
# hook does, and what printed before it must have reached the pipe
touch "$SB/ssh/nousowl/hang-cmd-lan"
out=$(timeout 4 "$GAUGE" session 2>&1); r=$?
check "a session cut at 4 s by a hung hub: timeout's 124" is "$r" 124
check "  the stored readings reached the pipe before the cut" is "$(grep -cE '^\[ OK \] (alpha|nousowl|gamma): up to date \(the newest full reading' <<<"$out")" 3
check "  and the live lines before the hub's" has "$out" '^\[ OK \] bash -n: '
check "  the hub's lines alone lost"          lacks "$out" 'hub nousowl'
rm -f "$SB/ssh/nousowl/hang-cmd-lan"
SYNC_CHECK_CALLER=byebye run sync >/dev/null
check "a caller the shell names: by byebye"  has "$(run session)" '^\[ OK \] alpha: up to date \(the newest full reading, by byebye [0-9]+ s ago\)$'
SYNC_CHECK_CALLER=$'by\nhand' run sync >/dev/null
check "  a caller with a newline: one line"  has "$(run session)" '^\[ OK \] alpha: up to date \(the newest full reading, by by hand [0-9]+ s ago\)$'
run >/dev/null
check "the bare run's reading: by sync-check" has "$(run session)" '^\[ OK \] alpha: up to date \(the newest full reading, by sync-check [0-9]+ s ago\)$'
scenario 'fedxps.folders.f1.completion.HUB.needDeletes=1' 'fedxps.folders.f1.completion.HUB.names=["gone.txt"]'
run sync >/dev/null
scenario
out=$(run session); r=$?
check "a stored FAIL, the fixture since cleared: reprinted with its age" has "$out" '^\[FAIL\] alpha: stranded on fedxps: gone.txt \(the newest full reading, by sync-check sync [0-9]+ s ago\)$'
check "  its fix line under it, as the live run printed it" is "$(grep -A1 '^\[FAIL\] alpha: stranded' <<<"$out" | tail -1)" "       fix: edit each listed path on bigfed, never on fedxps (a re-save that only moves its time should do the same, untested); the stranded text then arrives on both as a conflict copy: merge it into the original and delete the copy (org/machines/transport-2026-10/rules.md -> him-2)"
check "  the other folders still OK"         has "$out" '^\[ OK \] nousowl: up to date \(the newest full reading'
check "  exit 1"                             is "$r" 1
out=$(run sync); r=$?
check "  while a live sync reads OK"         is "$r" 0
check "  and the next session reads that"    has "$(run session)" '^\[ OK \] alpha: up to date \(the newest full reading'
python3 - "$RF" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
bt = [int(l.split()[1]) for l in open("/proc/stat") if l.startswith("btime ")][0]
d["folders"]["f1"]["taken"] = bt - 7200; json.dump(d, open(p, "w"))
PY
out=$(run session)
# an uptime past a week makes that reading too old to reprint (READING_MAX_AGE_DAYS):
# "before this boot" is then on the WARN it prints instead
if [ $(( $(date +%s) - $(awk '/^btime /{print $2}' /proc/stat) + 7200 )) -le $(( 7 * 86400 )) ]; then
  check "a reading taken before this boot says so" has "$out" '^\[ OK \] alpha: up to date \(the newest full reading, by sync-check sync [0-9]+ (h|d) ago, before this boot\)$'
  check "  the hook's count regex still matches it" has "$out" '^\[ OK \] alpha: up to date'
else
  check "a reading taken before this boot says so (on the too-old WARN, this boot being over a week old)" has "$out" '^\[WARN\] alpha: the newest full reading is [0-9]+ d old \(by sync-check sync, before this boot\): too old to stand as a reading$'
  check "  and reprints no OK for it"           lacks "$out" '^\[ OK \] alpha: '
fi
check "  the folders read since, not"         has "$out" '^\[ OK \] nousowl: up to date \(the newest full reading, by sync-check sync [0-9]+ s ago\)$'
python3 - "$RF" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["folders"]["f2"]["taken"] = "yesterday"; json.dump(d, open(p, "w"))
PY
check "a record not whole: that folder has no reading on record" has "$(run session)" '^\[WARN\] nousowl: no full reading on record$'
# round four (the reviewer's findings, 2026-10-27): a taken from the future, not
# finite, far past; an empty lines list; another device's record; a scan WARN
# kept; a folder paused since its reading
setrec() { python3 - "$RF" "$1" "$2" <<'PY'
import json, sys, time
p, fid, expr = sys.argv[1:4]; d = json.load(open(p))
exec(expr, {"rec": d["folders"][fid], "time": time}); json.dump(d, open(p, "w"))
PY
}
run sync >/dev/null
setrec f1 'rec["taken"] = time.time() + 86400'
out=$(run session); r=$?
check "a reading dated a day ahead of the clock: a WARN of its own" has "$out" '^\[WARN\] alpha: the newest full reading is dated (23|24) h ahead of this clock \(by sync-check sync\): the clock has moved since it was taken$'
check "  its fix a full run"                  is "$(grep -A1 'ahead of this clock' <<<"$out" | tail -1)" "       fix: sync-check sync"
check "  no '0 s ago' for it"                 lacks "$out" '^\[ OK \] alpha: '
check "  exit 2"                              is "$r" 2
setrec f1 'rec["taken"] = float("nan")'
check "a taken of NaN: no reading on record"   has "$(run session)" '^\[WARN\] alpha: no full reading on record$'
setrec f1 'rec["taken"] = 1e20'
out=$(run session)
check "  nor of 1e20, and no traceback"        has "$out" '^\[WARN\] alpha: no full reading on record$'
check "  (no traceback)"                       lacks "$out" 'Traceback|could not finish'
setrec f1 'rec["taken"] = 0'
check "a far-past reading: too old, its age and before this boot on the WARN" has "$(run session)" '^\[WARN\] alpha: the newest full reading is [0-9]+ d old \(by sync-check sync, before this boot\): too old to stand as a reading$'
# older than READING_MAX_AGE_DAYS, 7: a WARN of its own, the stored verdict
# under -v alone (his word at the pause of 5c-b, 2026-10-27)
setrec f1 'rec["taken"] = time.time() - 8 * 86400'
out=$(run session -v); r=$(rc session)
check "a reading 8 d old: too old to stand, a WARN" has "$out" '^\[WARN\] alpha: the newest full reading is 8 d old \(by sync-check sync(, before this boot)?\): too old to stand as a reading$'
check "  its fix a full run"                   is "$(grep -A1 'too old to stand' <<<"$out" | tail -1)" "       fix: sync-check sync"
check "  no OK reprinted for it"               lacks "$out" '^\[ OK \] alpha: '
check "  -v shows the stored verdict"          has "$out" '^       alpha: its stored verdict: \[ OK \] alpha: up to date$'
check "  exit 2"                               is "$r" 2
setrec f1 'rec["taken"] = time.time() - 6 * 86400'
check "a reading 6 d old: reprinted with its age, as before" has "$(run session)" '^\[ OK \] alpha: up to date \(the newest full reading, by sync-check sync 6 d ago(, before this boot)?\)$'
setrec f1 'rec["lines"] = []'
check "(g) a record with no lines: no reading on record" has "$(run session)" '^\[WARN\] alpha: no full reading on record$'
run sync >/dev/null
check "a record names the device that took it, this daemon's ID's first seven" is "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["folders"]["f1"]["device"])' "$RF")" FEDXPSX
setrec f1 'rec["device"] = "BIGFEDX"'
out=$(run session -v)
check "another device's record (a file carried here): no reading on record" has "$out" '^\[WARN\] alpha: no full reading on record$'
check "  -v says whose it was"                has "$out" 'alpha: the stored reading was taken by device BIGFEDX, not this one \(FEDXPSX\): not reprinted'
check "  this device's records still reprinted" has "$out" '^\[ OK \] nousowl: up to date \(the newest full reading'
python3 - "$SB/fx/fedxps/responses.json" <<'PY'
import json, sys
p = sys.argv[1]; t = json.load(open(p)); t["POST /rest/db/scan?folder=f1"] = {"status": 500, "body": "boom"}; json.dump(t, open(p, "w"))
PY
run sync >/dev/null
check "(b) a folder's scan answering 500: session reprints its WARN" has "$(run session)" '^\[WARN\] alpha: scan answered 500: boom \(the newest full reading, by sync-check sync [0-9]+ s ago\)$'
check "  and its record's ok is false"         is "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["folders"]["f1"]["ok"])' "$RF")" False
scenario; run sync >/dev/null
scenario 'fedxps.folders.f1.paused=true'
out=$(run session)
check "(c) a folder paused since its reading: WAIT, read from config.xml" has "$out" '^\[WAIT\] alpha: paused on this machine$'
check "  not its stored OK"                    lacks "$out" '^\[ OK \] alpha: '
scenario
printf '{not json' > "$RF"
out=$(run session); r=$?
check "a corrupt reading file: one WARN per folder" is "$(grep -c 'no full reading on record$' <<<"$out")" 3
check "  no traceback"                       lacks "$out" 'Traceback|could not finish'
check "  exit 2"                             is "$r" 2
ALT="$SB/alt/readings.json"; rm -rf "$SB/alt"
SYNC_CHECK_READINGS="$ALT" run sync >/dev/null
check "SYNC_CHECK_READINGS names the file: written there, 0600" is "$(stat -c %a "$ALT" 2>/dev/null)" 600
check "  read from there"                    has "$(SYNC_CHECK_READINGS="$ALT" run session)" '^\[ OK \] alpha: up to date \(the newest full reading'
check "  the default file left as it was"    is "$(cat "$RF")" '{not json'
SYNC_CHECK_READINGS= run sync >/dev/null
check "set empty: nothing written"           is "$(cat "$RF")" '{not json'
check "  and none read"                      has "$(SYNC_CHECK_READINGS="" run session)" '^\[WARN\] alpha: no full reading on record$'
XDG_STATE_HOME="$SB/xdg-state" run sync >/dev/null
check "XDG_STATE_HOME: the file under it"    is "$(stat -c %a "$SB/xdg-state/sync-check/readings.json" 2>/dev/null)" 600
rm -rf "$SB/xdg-state" "$SB/alt"
# the other workstation read over ssh: its --remote-views writes no file there
rm -rf "$SB"/ssh/*/home/.local/state/sync-check
scenario 'nousowl.folders.f3.completion.BIG.needItems=1' 'bigfed.folders.f3.completion.HUB.needItems=1' 'bigfed.folders.f3.completion.HUB.names=["late.txt"]'
run sync >/dev/null
check "a sync that reads the hub and bigfed remotely: both asked" bash -c "grep -q '^bigfed: python3 -I - --remote-views' '$SB/ssh.log' && grep -q '^nousowl: python3 -I - --remote-views' '$SB/ssh.log'"
check "  no reading file in bigfed's home or the hub's" bash -c "[ ! -e '$SB/ssh/bigfed/home/.local/state/sync-check' ] && [ ! -e '$SB/ssh/nousowl/home/.local/state/sync-check' ]"
check "  this machine's written"             bash -c "[ -f '$RF' ]"
scenario; touch "$SB/ssh/nousowl/down"; rm -f "$RF"
run sync >/dev/null
check "the hub unread (a WARN): the WARN is the reading kept" has "$(run session)" "^\[WARN\] alpha: nousowl's view unread: .*\(the newest full reading, by sync-check sync [0-9]+ s ago\)$"
# push, from bigfed, the writer: its one folder; the snapshot's folders, nothing
be bigfed; unset GIT_OPTIONAL_LOCKS; scenario
RFB="$SB/ssh/bigfed/home/.local/state/sync-check/readings.json"; rm -f "$RFB"
SYNC_CHECK_CALLER=gpush run push nousowl >/dev/null
check "push stores its one folder"           bash -c "python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert list(d[\"folders\"])==[\"f2\"], d' '$RFB'"
: > "$SB/fx/bigfed/requests.log"
out=$(run session); r=$?
check "  session from bigfed: that folder by gpush" has "$out" '^\[ OK \] nousowl: up to date \(the newest full reading, by gpush [0-9]+ s ago\)$'
check "  of a writer's daemon it asks system/status, once, and nothing else" is "$(reqs bigfed)" "GET /rest/system/status"
check "  the others: no full reading on record" is "$(grep -c 'no full reading on record$' <<<"$out")" 2
check "  exit 2"                             is "$r" 2
run push nousowl >/dev/null
check "  without the variable: by sync-check push" has "$(run session)" '^\[ OK \] nousowl: up to date \(the newest full reading, by sync-check push [0-9]+ s ago\)$'
taken() { python3 -c 'import json,sys; print(repr(json.load(open(sys.argv[1]))["folders"]["f2"]["taken"]))' "$RFB"; }
SNAP2="$SB/snapshot2.json"; rm -f "$SNAP2"; (umask 077; : > "$SNAP2")
SYNC_CHECK_SNAPSHOT="$SNAP2" SYNC_CHECK_CALLER=gpushall run push nousowl >/dev/null; t1=$(taken)
out=$(SYNC_CHECK_SNAPSHOT="$SNAP2" SYNC_CHECK_CALLER=elsewhere run push nousowl); t2=$(taken)
check "a folder read from the snapshot (said so)" has "$out" 'from the snapshot taken [0-9]+ s ago'
check "  stores nothing new: the record's time unchanged" is "$t2" "$t1"
check "  nor its caller"                     has "$(run session)" '^\[ OK \] nousowl: up to date \(the newest full reading, by gpushall [0-9]+ s ago\)$'
SYNC_CHECK_SNAPSHOT="$SNAP2" SYNC_CHECK_CALLER=mixed run sync >/dev/null; t3=$(taken)
check "a run reading two folders live and one from the snapshot: that one's record unchanged" is "$t3" "$t1"
out=$(run session)
check "  the live ones stored, by their caller" is "$(grep -cE '^\[ OK \] (alpha|gamma): up to date \(the newest full reading, by mixed [0-9]+ s ago\)$' <<<"$out")" 2
rm -f "$SNAP2"

# ==============================================================================
echo "== all lines at once, and nothing written =="
be fedxps; scenario; export GIT_OPTIONAL_LOCKS=0; : > "$STUB_CL_LOG"
# The reading file is the one designed write (settled 76, 2026-10-27): the
# gauge's directory under ~/.local/state is left out of the comparison, and
# ~/.local/state itself is compared by name alone, since its mtime moves when
# the gauge's directory is made (the reviewer's patch, the same day); the new
# entries are checked on their own -- the gauge's directory and the file, 0600
mkdir -p "$SB"/ssh/{fedxps,bigfed,nousowl}/home/.local/state; rm -rf "$SB"/ssh/*/home/.local/state/sync-check
snap() { find "$SB/ssh" -path '*/requests.log' -prune -o -path '*/home/.local/state/sync-check' -prune -o -path '*/home/.local/state' -printf '%p\n' -o -printf '%p %i %T@ %s\n' | sort | md5sum; }
entries() { find "$SB/ssh" -path '*/requests.log' -prune -o -printf '%p\n' | sort; }
before=$(snap); before_entries=$(entries)
out=$(run -v); hub_ssh=$(grep -c '^nousowl' "$SB/ssh.log"); r=$(rc)
after=$(snap); new_entries=$(comm -13 <(printf '%s\n' "$before_entries") <(entries))
check "the default runs sync (1/5)"          has "$out" 'alpha: up to date'
check "the default runs conflicts (2/5)"     has "$out" 'under .git: no conflict copy'
check "the default runs guard (3/5)"         has "$out" 'host.inc ->'
check "  its guard with the version vectors (settled 77)" has "$out" "^\[ OK \] no \.git path of [0-9]+ carries this machine's counter"
check "the default runs hub (4/5)"           has "$out" '^\[ OK \] hub nousowl: the index is'
check "the default runs config (5/5)"        has "$out" '^\[ OK \] stow: every top-level entry'
check "  but not claude-link's dry run (1.8 s, past the budget)" lacks "$out" 'claude-link:'
check "  the claude-link stub never started" is "$(cat "$STUB_CL_LOG" 2>/dev/null)" ""
check "  one ssh to the hub, the hub's readings riding on the sync line's" is "$hub_ssh" 1
check "  that one asked for them"            has "$(cat "$SB/ssh.log")" '^nousowl: python3 -I - --remote-views --with-hub f1 f2 f3$'
check "  exit 0"                             is "$r" 0
check "every file in both homes byte-for-byte and inode-for-inode as before (.git included), the state directory aside" is "$before" "$after"
check "the only new entries in any home: fedxps's reading file and its directory" is "$new_entries" "$SB/ssh/fedxps/home/.local/state/sync-check
$SB/ssh/fedxps/home/.local/state/sync-check/readings.json"
check "  the file 0600"                      is "$(stat -c %a "$SB/ssh/fedxps/home/.local/state/sync-check/readings.json")" 600
check "unknown line: exit 2"                 is "$(rc nonsense)" 2
head -c 300 "$SYNC_CHECK_CONFIG" > "$SB/trunc.xml"
out=$(SYNC_CHECK_CONFIG="$SB/trunc.xml" run sync); r=$(SYNC_CHECK_CONFIG="$SB/trunc.xml" rc sync)
check "a config.xml the parser rejects: one WARN line, no traceback (review 3b-1)" has "$out" '^\[WARN\] sync-check could not finish: ParseError'
check "  exit 2"                             is "$r" 2
check "-h: exits 0 and names the four lines" bash -c "'$GAUGE' -h | grep -q 'sync-check push REPO'"
check "-h names the hub and config lines"    bash -c "'$GAUGE' -h | grep -q 'sync-check hub' && '$GAUGE' -h | grep -q 'sync-check config'"
check "-h names the session line"            bash -c "'$GAUGE' -h | grep -q '^  sync-check session '"
check "-h gives the exit codes"              bash -c "'$GAUGE' -h | grep -q '^Exit: 0 all clear'"

# ==============================================================================
echo "== live: the real gauge on this machine, read-only; tags and exit status agree =="
unset SYNC_CHECK_CONFIG STUB_HOST_FILE; export HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"; PATH="${PATH#"$SB/stub:"}"; hash -r
if [ "$LIVE_GOL" = __unset__ ]; then unset GIT_OPTIONAL_LOCKS; else export GIT_OPTIONAL_LOCKS="$LIVE_GOL"; fi
unset GIT_CONFIG_NOSYSTEM
for line in conflicts guard; do
  out=$("$GAUGE" "$line" 2>&1); r=$?
  if grep -qE '^\[(FAIL|WAIT)\]' <<<"$out"; then want=1; elif grep -q '^\[WARN\]' <<<"$out"; then want=2; elif grep -q '^\[DUE\]' <<<"$out"; then want=3; else want=0; fi
  check "live $line: exit $r matches its tags" is "$r" "$want"
done

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
