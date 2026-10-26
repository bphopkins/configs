#!/usr/bin/env bash
# The tests/sync suite: the transport campaign's cases that need Syncthing
# itself (org/machines/transport-2026-10/rules.md, "How to read it" -> Tests;
# built 2026-10-26 at step 5a, seeded from the battery's rigs in
# scratch-2026-10-09/). Three real Syncthing instances on loopback per case
# (rig.py): A plays bigfed, the writer; B plays fedxps, the reader; H plays
# nousowl, the receive-encrypted hub. Phone-home is off before the first
# start, the ports are free ones found at run time, the device IDs are made
# per run and die with the sandbox.
#
# Cases, each on fresh instances and folders, in this order:
#   smoke        the rig: lock-down, loopback only, A -> H -> B, ciphertext on H
#   guard        fedxps-3: the guarded reader writes nothing under .git (disk
#                events, version vectors); the unguarded one rewrites the index
#   maxconflicts ws-7: a folder made by the POST reads maxConflicts 10 everywhere
#   split        him-2's last case and bigfed-2: the split of main through the
#                hub and its repair, SYNC_SPLIT_RUNS times (default 3)
#   retention    hub-1: a deletion lost at a hub maintenance pass, then kept
#                with STDBDELETERETENTIONINTERVAL=0; its two halves in parallel
#   addfolder    mig-4: bin/syncthing-addfolder, fresh and join end to end, its
#                refusals, re-runs, dry run and undo (case_addfolder.py)
# `run.sh CASE...` runs those named; with none, all six.
#
# Sandboxed and caged (tests/cage.sh, at 1G, 512 tasks and 1500 s): HOME, the
# XDG directories and every instance's home under one mktemp directory; git
# reads only the cases' own config files (GIT_CONFIG_GLOBAL, no system file);
# `ssh`, `systemctl`, `sync-check` and `uname` stubbed first on PATH, and the
# real ~/bin left off it, so nothing real is reached; the trap stops any
# syncthing process of the run, matched by the sandbox path in its command
# line (never pkill -f). Asserted at the end: no process of the run left, no
# stub called, the live Syncthing's config.xml unchanged.
#
# Run after any edit to tests/sync/, and after a Syncthing upgrade: the cases
# assert Syncthing's own behaviour, measured on 2.1.6 (the five cases before
# addfolder take about seven minutes). retention's `lost` half asserts the
# hub fault that 2.1.7 fixes upstream (rules.md hub-1, PR #10916), so after
# that upgrade its FAIL is the fix arriving, and the half is to be revised.
# Python runs with -B, so no bytecode is written into the tree. Each case prints
# `ok   - ` / `FAIL - ` lines and `# ` readings; a case that exits non-zero
# without a FAIL line is counted as one, and so is every `skip - ` line: a
# suite that could not decide never ends green. Last line follows the tests/gsync
# convention: "passed: N  failed: M"; exit 0 iff nothing failed.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAGE_MEMORY_MAX=1G CAGE_TASKS_MAX=512 CAGE_RUNTIME_MAX_SEC=1500
source "$CFG_ROOT/tests/cage.sh"
cage sync "$@"

# The rest is one brace group, which bash reads whole before running any of
# it, so an edit saved to this file while a run is under way (bash reads a
# script as it goes) reaches the next run and never the running one.
{
HERE="$CFG_ROOT/tests/sync"
for t in syncthing git python3 ss mktemp; do command -v "$t" >/dev/null 2>&1 || {
  echo "sync tests: $t missing -- not running" >&2; echo "passed: 0  failed: 1"; exit 2; }; done
echo "syncthing: $(syncthing --version | cut -d' ' -f1-2); git: $(git --version | cut -d' ' -f3)"

REAL_HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
live_cfg() { stat -c '%Y %s' "$REAL_HOME/.local/state/syncthing/config.xml" "$REAL_HOME/.config/syncthing/config.xml" 2>/dev/null; }
LIVE_BEFORE="$(live_cfg)"

SB="$(mktemp -d "${TMPDIR:-/tmp}/sync-tests.XXXXXX")" || { echo "sync tests: no sandbox -- not running" >&2; echo "passed: 0  failed: 1"; exit 2; }
case $SB in "${TMPDIR:-/tmp}"/sync-tests.?*) ;; *) echo "sync tests: sandbox '$SB' -- not running" >&2; echo "passed: 0  failed: 1"; exit 2 ;; esac
survivors() { ps -eo pid,args | grep -F -- "$SB/" | grep -F syncthing | grep -v -F 'grep'; }
cleanup() {
  local p
  for p in $(survivors | awk '{print $1}'); do kill -TERM "$p" 2>/dev/null; done
  sleep 1
  for p in $(survivors | awk '{print $1}'); do kill -KILL "$p" 2>/dev/null; done
  rm -rf -- "${SB:?}"
}
trap cleanup EXIT

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
none() { [ -z "$1" ] || { echo "     got:  $(head -c 1500 <<<"$1")"; return 1; }; }
is()   { [ "$1" = "$2" ] || { echo "     got:  $1"; echo "     want: $2"; return 1; }; }

# --- the sandbox --------------------------------------------------------------
mkdir -p "$SB/home" "$SB/stub" "$SB/cases"
export HOME="$SB/home" XDG_CONFIG_HOME="$SB/home/.config" XDG_STATE_HOME="$SB/home/.local/state" \
  XDG_DATA_HOME="$SB/home/.local/share" XDG_CACHE_HOME="$SB/home/.cache"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GIT_OPTIONAL_LOCKS GIT_DIR GIT_WORK_TREE SYNC_CHECK_CONFIG STGUIAPIKEY STGUIADDRESS STHOMEDIR STCONFDIR STDATADIR
for s in ssh systemctl sync-check; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" "%s" "$*" >> "%s/stub.log"\necho "%s: stubbed in tests/sync" >&2\nexit 255\n' \
    "$s" "$SB" "$s" > "$SB/stub/$s"
done
printf '#!/bin/sh\nprintf "uname %%s\\n" "$*" >> "%s/stub.log"\necho rig\n' "$SB" > "$SB/stub/uname"
chmod +x "$SB"/stub/*
: > "$SB/stub.log"
PATH="$SB/stub:/usr/bin:/bin:/usr/sbin"; hash -r

# run_case NAME SCRIPT ARGS...: the case's lines shown as they come, then counted
run_case() {
  local name=$1 script=$2; shift 2
  local out="$SB/cases/$name.out" t0 rc
  t0=$(date +%s)
  python3 -I -B "$HERE/$script" "$SB/cases/$name" "$@" 2>&1 | tee "$out"
  rc=${PIPESTATUS[0]}
  tally "$name" "$out" "$rc" "$(( $(date +%s) - t0 ))"
}
tally() {
  local name=$1 out=$2 rc=$3 secs=$4 p f s line
  p=$(grep -c '^ok   - ' "$out"); f=$(grep -c '^FAIL - ' "$out"); s=$(grep -c '^skip - ' "$out")
  ((pass += p)); ((fail += f))
  # a case that could not decide is never a pass: each skip line is a failure
  while IFS= read -r line; do
    echo "FAIL - $name could not decide (a skip is never a pass): ${line#skip - }"; ((fail += 1))
  done < <(grep '^skip - ' "$out")
  if ((rc != 0 && f == 0 && s == 0)); then
    echo "FAIL - $name exited $rc with no failing check (a crash: its output is above)"; ((fail += 1))
  elif ((p + f + s == 0)); then
    echo "FAIL - $name ran no check"; ((fail += 1))
  fi
  check "$name: no syncthing process of the case left" none "$(ps -eo pid,args | grep -F -- "$SB/cases/$name" | grep -F syncthing | grep -v -F grep)"
  echo "== $name: ${secs} s"
}

CASES=("$@")
((${#CASES[@]})) || CASES=(smoke guard maxconflicts split retention addfolder)
T0=$(date +%s)
for c in "${CASES[@]}"; do
  case $c in
    smoke)        echo "== smoke: the rig itself";                       run_case smoke case_smoke.py ;;
    guard)        echo "== guard: fedxps-3 on a real reader";            run_case guard case_guard.py ;;
    maxconflicts) echo "== maxconflicts: ws-7";                          run_case maxconflicts case_maxconflicts.py ;;
    split)        echo "== split: him-2's split of main and its repair, ${SYNC_SPLIT_RUNS:-3} runs"
                  run_case split case_split.py "${SYNC_SPLIT_RUNS:-3}" ;;
    retention)
      echo "== retention: hub-1, its two halves in parallel (output when both are done)"
      t0=$(date +%s)
      python3 -I -B "$HERE/case_retention.py" "$SB/cases/retention-lost" lost > "$SB/cases/retention-lost.out" 2>&1 & pl=$!
      python3 -I -B "$HERE/case_retention.py" "$SB/cases/retention-kept" kept > "$SB/cases/retention-kept.out" 2>&1 & pk=$!
      wait $pl; rl=$?; wait $pk; rk=$?
      secs=$(( $(date +%s) - t0 ))
      cat "$SB/cases/retention-lost.out"; tally retention-lost "$SB/cases/retention-lost.out" "$rl" "$secs"
      cat "$SB/cases/retention-kept.out"; tally retention-kept "$SB/cases/retention-kept.out" "$rk" "$secs"
      ;;
    addfolder)    echo "== addfolder: mig-4, bin/syncthing-addfolder";   run_case addfolder case_addfolder.py ;;
    *) echo "sync tests: no case '$c' (smoke guard maxconflicts split retention addfolder)" >&2; echo "passed: 0  failed: 1"; exit 2 ;;
  esac
done

echo "== the run as a whole"
check "no syncthing process of the run left" none "$(survivors)"
check "no stub was called (ssh, systemctl, sync-check, uname)" none "$(cat "$SB/stub.log")"
check "the live Syncthing's config.xml untouched (mtime and size)" is "$(live_cfg)" "$LIVE_BEFORE"
cg="$(sed -n 's/^0::\(.*\)$/\1/p' /proc/self/cgroup)"
echo "# whole run $(( $(date +%s) - T0 )) s; the cage's memory peak $(( $(cat "/sys/fs/cgroup$cg/memory.peak" 2>/dev/null || echo 0) / 1048576 )) MiB"

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
exit
}
