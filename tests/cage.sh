# tests/cage.sh -- the cage the caged suites run in. Sourced, never run.
#
# A suite that sources this and calls `cage <name> "$@"` re-executes itself
# inside a systemd user scope with a memory ceiling, swap off, a task cap and
# a time cap, and stops that scope on the way out
# (org/claude-config/rules/system-and-server-work.md). "In a cage" is read
# from the cgroup's own memory.max, never from a variable. No user manager, no
# run. Extracted 2026-09-23 from tests/env/run.sh and tests/shell-opts/run.sh
# when tests/prompt/run.sh became the third suite to want it.
#
# The scope's properties, and why each is there:
#   MemoryMax=512M     a hard ceiling; past it the kernel kills inside the
#                      scope and nowhere else
#   MemorySwapMax=0    so the ceiling is one: a runaway dies rather than
#                      paging into zram while the desktop stalls
#   TasksMax=256       processes and threads both; a fork storm stops there
#   RuntimeMaxSec=120  a hang is stopped, not waited out
#   TimeoutStopSec=10  a stop, by the time cap or the suite's own, escalates
#                      to SIGKILL after 10 s rather than systemd's 90
#   OOMPolicy=continue the kernel still kills whatever crosses the ceiling,
#                      but systemd does not then mark the scope failed with
#                      result `oom-kill` -- the result gsd-housekeeping
#                      watches for before telling the desktop "Device memory
#                      is nearly full" (seen 2026-09-22; the user manager's
#                      default is `stop`). Missing from the two preludes this
#                      replaced.
#   --collect          a scope that failed is unloaded, not left listed as
#                      failed in `systemctl --user`
# The same set as adelotype/tools/contain.py, the rule's other worked example.
# The cage line each run prints reads memory.max and pids.max from the cgroup
# and OOMPolicy from the unit, so the run shows its own cage.
#
# Usage, right after `set -u` and CFG_ROOT:
#     source "$CFG_ROOT/tests/cage.sh"
#     cage env "$@"
# Inside the scope, `cage` prints the cage line and returns. Outside it, it
# runs the suite in a fresh scope and exits with the suite's status; with no
# user manager, or under the ceiling plus a 1G floor available, it prints the
# tests/gsync-shaped failure line and exits 2.
#
# A suite that needs more than the defaults names it before calling `cage`,
# in the three variables below (2026-10-26, for tests/sync, whose three
# Syncthing instances and git repositories outgrow 512M and 120 s):
#     CAGE_MEMORY_MAX=1G CAGE_TASKS_MAX=512 CAGE_RUNTIME_MAX_SEC=900
# MemoryMax takes systemd's suffixes, M or G; the floor check reads it.
cage() {
  local name=$1; shift
  local suite=${BASH_SOURCE[1]}
  local cg f
  cg="$(sed -n 's/^0::\(.*\)$/\1/p' /proc/self/cgroup 2>/dev/null)"
  if [[ -n "$cg" ]]; then
    f="/sys/fs/cgroup${cg}/memory.max"
    if [[ -r "$f" && "$(<"$f")" != max ]]; then
      echo "cage: ${cg##*/}  MemoryMax=$(<"$f")  TasksMax=$(<"/sys/fs/cgroup${cg}/pids.max")  OOMPolicy=$(systemctl --user show -p OOMPolicy --value "${cg##*/}" 2>/dev/null || echo unknown)"
      return 0
    fi
  fi
  if ! command -v systemd-run >/dev/null 2>&1 ||
    ! systemctl --user show -p NFailedUnits >/dev/null 2>&1; then
    echo "$name tests: no user manager to cage the run in -- not running" >&2
    echo "passed: 0  failed: 1"
    exit 2
  fi
  local mem="${CAGE_MEMORY_MAX:-512M}" tasks="${CAGE_TASKS_MAX:-256}" runtime="${CAGE_RUNTIME_MAX_SEC:-120}"
  local mem_mb avail_kb
  case "$mem" in
    *G) mem_mb=$(( ${mem%G} * 1024 )) ;;
    *M) mem_mb=${mem%M} ;;
    *) echo "$name tests: CAGE_MEMORY_MAX='$mem' is not NNNM or NG -- not running" >&2; echo "passed: 0  failed: 1"; exit 2 ;;
  esac
  avail_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
  if ((avail_kb < (mem_mb + 1024) * 1024)); then
    echo "$name tests: less than $((mem_mb + 1024))M available; the $mem cage plus a 1G floor does not fit -- not running" >&2
    echo "passed: 0  failed: 1"
    exit 2
  fi
  local unit="$name-tests-$$-$RANDOM" rc
  systemd-run --user --scope --quiet --collect --unit="$unit" \
    -p "MemoryMax=$mem" -p MemorySwapMax=0 -p "TasksMax=$tasks" -p "RuntimeMaxSec=$runtime" \
    -p TimeoutStopSec=10 -p OOMPolicy=continue \
    -- bash "$suite" "$@"
  rc=$?
  systemctl --user stop "$unit.scope" >/dev/null 2>&1 || true
  exit "$rc"
}
