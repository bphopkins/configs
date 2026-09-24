#!/usr/bin/env bash
# Regression suite for bash/.bashrc.d/00-shell-opts.sh: the history contract
# and the shell options an interactive shell ends up with, on top of the system
# layer (/etc/bashrc, /etc/profile.d) the module runs after. Written 2026-09-23
# when the module took that content (configs/DECISIONS.md, the entry of that
# date; the map of the interactive half is org/machines/environment.md).
#
# Hermetic: every shell runs under `env -i` with HOME pointed at a fixture that
# links to this checkout's bash files the way stow does, and HISTFILE pointed
# into the sandbox -- an interactive shell writes its history file on exit, so
# no shell here may ever see ~/.bash_history. The machine-dependent input is
# /etc/bashrc and /etc/profile.d, read exactly as a terminal's shell reads
# them; that is the point, since bash-preexec (installed by
# /etc/profile.d/wezterm.sh) rewrites PROMPT_COMMAND and HISTCONTROL under the
# module's feet at the first prompt.
#
# The shells read their commands from a file with `bash -i`: unlike
# `bash -ic 'cmd'`, that issues prompts, so PROMPT_COMMAND runs, bash-preexec
# installs itself, and history is loaded and written. Each shell reports on
# fd 3, so the hooks' escape sequences on stdout stay out of the report.
#
# Caged: the suite re-executes itself inside a systemd user scope with a memory
# ceiling, swap off, a task cap and a time cap, and stops that scope on the way
# out (org/claude-config/rules/system-and-server-work.md). "In a cage" is read
# from the cgroup's own memory.max, never from a variable. No user manager, no
# run.
#
# Run from anywhere after any edit to 00-shell-opts.sh (~3 s). Last line
# follows the tests/gsync convention: "passed: N  failed: M"; exit 0 iff
# nothing failed. Requires bash 5.1+ (PROMPT_COMMAND as an array), systemd.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODULE="$CFG_ROOT/bash/.bashrc.d/00-shell-opts.sh"

# --- the cage (as tests/env/run.sh) -----------------------------------------
caged() {
  local cg f
  cg="$(sed -n 's/^0::\(.*\)$/\1/p' /proc/self/cgroup 2>/dev/null)"
  [[ -n "$cg" ]] || return 1
  f="/sys/fs/cgroup${cg}/memory.max"
  [[ -r "$f" ]] && [[ "$(<"$f")" != max ]]
}
if ! caged; then
  if ! command -v systemd-run >/dev/null 2>&1 ||
    ! systemctl --user show -p NFailedUnits >/dev/null 2>&1; then
    echo "shell-opts tests: no user manager to cage the run in -- not running" >&2
    echo "passed: 0  failed: 1"
    exit 2
  fi
  avail_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
  if ((avail_kb < (512 + 1024) * 1024)); then
    echo "shell-opts tests: less than 1.5G available; the 512M cage plus a 1G floor does not fit -- not running" >&2
    echo "passed: 0  failed: 1"
    exit 2
  fi
  unit="shell-opts-tests-$$-$RANDOM"
  systemd-run --user --scope --quiet --unit="$unit" \
    -p MemoryMax=512M -p MemorySwapMax=0 -p TasksMax=256 -p RuntimeMaxSec=120 \
    -- bash "${BASH_SOURCE[0]}" "$@"
  rc=$?
  systemctl --user stop "$unit.scope" >/dev/null 2>&1 || true
  exit "$rc"
fi

cg="$(sed -n 's/^0::\(.*\)$/\1/p' /proc/self/cgroup)"
echo "cage: ${cg##*/}  MemoryMax=$(<"/sys/fs/cgroup${cg}/memory.max")  TasksMax=$(<"/sys/fs/cgroup${cg}/pids.max")"

# --- the sandbox ------------------------------------------------------------
SB="$(mktemp -d "${TMPDIR:-/tmp}/shell-opts-tests.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
H="$SB/home"
mkdir -p "$H"
ln -s "$CFG_ROOT/bash/.bash_profile" "$H/.bash_profile"
ln -s "$CFG_ROOT/bash/.bashrc" "$H/.bashrc"
ln -s "$CFG_ROOT/bash/.bashrc.d" "$H/.bashrc.d"

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
field() { sed -n "s/^$1=//p" <<<"$2"; }
# The number of lines in $1 matching the anchored pattern $2 (grep -c, but 0
# on no match instead of a failing status).
count() { grep -c -- "$2" "$1" 2>/dev/null || true; }
entries() { grep -vc '^#' "$1" 2>/dev/null || true; }    # history entries, not timestamp lines
stamps() { count "$1" '^#[0-9]'; }                        # timestamp lines

BASE=/usr/local/bin:/usr/bin
# An interactive non-login shell, reading its commands from $1 with history
# file $2 and reporting on fd 3 into $3: what a WezTerm window runs.
# TERM=xterm-256color is what makes /etc/bashrc set its title printf and
# wezterm.sh install bash-preexec; TERM=dumb (what `ssh host cmd` has) skips
# both, and would test the module against a system layer no terminal has.
ishell() { env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash TERM=xterm-256color PATH="$BASE" HISTFILE="$2" /bin/bash -i <"$1" 3>"$3" >/dev/null 2>&1; }
# The same through Ghostty's launch: POSIX mode, ENV pointed at its
# integration script, which restores normal mode, sources the rc chain itself
# and appends its own hooks (the feature list is bigfed's and fedxps's).
GHOSTTY_BASH=/usr/share/ghostty/shell-integration/bash/ghostty.bash
gshell() { env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash TERM=xterm-ghostty TERM_PROGRAM=ghostty PATH="$BASE" HISTFILE="$2" GHOSTTY_BASH_UNEXPORT_HISTFILE=1 ENV="$GHOSTTY_BASH" GHOSTTY_BASH_INJECT=1 GHOSTTY_SHELL_FEATURES=path,ssh-env,ssh-terminfo,title GHOSTTY_RESOURCES_DIR=/usr/share/ghostty /bin/bash --posix -i <"$1" 3>"$3" >/dev/null 2>&1; }
# One line per report: how many PROMPT_COMMAND elements are exactly `history -a`.
HIST_A_COUNT='__n() { local c=0 e; for e in "${PROMPT_COMMAND[@]}"; do [[ $e == "history -a" ]] && c=$((c + 1)); done; printf "%s=%s\n" "$1" "$c"; }'

# --- 0. the module itself ---------------------------------------------------
echo "== the module =="
check "parses (bash -n)" bash -n "$MODULE"
out="$(env -i HOME="$H" PATH="$BASE" /bin/bash -c "source '$MODULE'" 2>&1)"
check "sourcing it prints nothing" [ -z "$out" ]

# --- 1. the contract, after the first prompt --------------------------------
echo "== an interactive shell, after its first prompt =="
cat >"$SB/s1" <<'S'
{ declare -p HISTSIZE HISTFILESIZE HISTTIMEFORMAT HISTCONTROL HISTIGNORE; shopt -p histappend globstar checkjobs no_empty_cmd_completion histverify checkwinsize; } >&3
exit
S
: >"$SB/h1"
ishell "$SB/s1" "$SB/h1" "$SB/r1"
r="$(<"$SB/r1")"
check "HISTSIZE=20000" contains "$r" 'HISTSIZE="20000"'
check "HISTFILESIZE=40000 (lines: two per dated entry)" contains "$r" 'HISTFILESIZE="40000"'
check "HISTTIMEFORMAT='%F %T '" contains "$r" 'HISTTIMEFORMAT="%F %T "'
check "HISTCONTROL=ignoredups, after bash-preexec has had its say" contains "$r" 'HISTCONTROL="ignoredups"'
check "HISTIGNORE=exit:clear" contains "$r" 'HISTIGNORE="exit:clear"'
for o in histappend globstar checkjobs no_empty_cmd_completion histverify checkwinsize; do
  check "shopt -s $o" contains "$r"$'\n' "shopt -s $o"$'\n'
done

# --- 2. the write: after every command, dated, exit and clear left out ------
echo "== the history file =="
printf 'seed one\nseed two\nseed three\n' >"$SB/h2"
cat >"$SB/s2" <<'S'
echo alpha
grep -c '^echo alpha$' "$HISTFILE" >&3
clear
echo beta
echo beta
history 1 >&3
exit
S
ishell "$SB/s2" "$SB/h2" "$SB/r2"
r="$(<"$SB/r2")"
check "a command is in the file before the next one runs (history -a per prompt)" [ "$(sed -n 1p <<<"$r")" = 1 ]
check "history shows the new entry with a date and time" grep -qE '^ *[0-9]+ +[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} history 1' <<<"$r"
check "the three undated entries stay undated, at the top" [ "$(head -n 4 "$SB/h2" | tr '\n' '|')" = "seed one|seed two|seed three|#$(sed -n 4p "$SB/h2" | tr -d '#')|" ] && [ "$(sed -n 4p "$SB/h2" | cut -c1)" = '#' ]
check "every new entry carries a timestamp line" [ "$(stamps "$SB/h2")" = "$(( $(entries "$SB/h2") - 3 ))" ]
check "clear is not in the file" [ "$(count "$SB/h2" '^clear$')" = 0 ]
check "exit is not in the file" [ "$(count "$SB/h2" '^exit$')" = 0 ]
check "echo beta twice in a row is in the file once (ignoredups)" [ "$(count "$SB/h2" '^echo beta$')" = 1 ]
check "the file ends with the last recorded command" [ "$(tail -n 1 "$SB/h2")" = 'history 1 >&3' ]

# --- 3. the cap: 40,000 lines, trimmed at every shell start ----------------
echo "== the cap =="
# 20,010 dated entries = 40,020 lines. Assigned during startup, HISTFILESIZE
# counts lines, stamp lines included (the module's comment has the
# measurement), so this comes back as 40,000 lines and 20,000 entries.
awk 'BEGIN { for (i = 1; i <= 20010; i++) printf "#%d\ncmd %d\n", 1790000000 + i, i }' >"$SB/h3"
cat >"$SB/s3" <<'S'
printf 'LINES=%s\nENTRIES=%s\n' "$(grep -c . "$HISTFILE")" "$(grep -vc '^#' "$HISTFILE")" >&3
printf 'MEM=%s\n' "$(history | wc -l)" >&3
echo omega
exit
S
ishell "$SB/s3" "$SB/h3" "$SB/r3"
r="$(<"$SB/r3")"
check "40,020 lines are trimmed to 40,000 when HISTFILESIZE is assigned at startup" [ "$(field LINES "$r")" = 40000 ]
check "which is 20,000 dated entries" [ "$(field ENTRIES "$r")" = 20000 ]
check "20,000 entries in memory (HISTSIZE counts entries)" [ "$(field MEM "$r" | tr -d ' ')" = 20000 ]
check "the session's 3 commands were appended and nothing was trimmed at exit" [ "$(entries "$SB/h3")" = 20003 ] && [ "$(count "$SB/h3" '^cmd 1$')" = 0 ]
check "the file ends with the last recorded command" [ "$(tail -n 1 "$SB/h3")" = 'echo omega' ]
cat >"$SB/s3b" <<'S'
printf 'LINES=%s\n' "$(grep -c . "$HISTFILE")" >&3
exit
S
ishell "$SB/s3b" "$SB/h3" "$SB/r3b"
check "the next shell start cuts it back to 40,000 lines" [ "$(field LINES "$(<"$SB/r3b")")" = 40000 ]
check "and keeps the newest entries" [ "$(count "$SB/h3" '^echo omega$')" = 1 ] && [ "$(count "$SB/h3" '^cmd 20010$')" = 1 ]

# --- 4. reload: the history -a element is added once ------------------------
echo "== reload =="
cat >"$SB/s4" <<S
$HIST_A_COUNT
__n first >&3
source ~/.bashrc
source ~/.bashrc
__n after >&3
for e in "\${PROMPT_COMMAND[@]}"; do printf 'PC_ELEM=%q\n' "\$e"; done >&3
exit
S
: >"$SB/h4"
ishell "$SB/s4" "$SB/h4" "$SB/r4"
r="$(<"$SB/r4")"
check "exactly one history -a element after the first prompt" [ "$(field first "$r")" = 1 ]
check "still exactly one after sourcing ~/.bashrc twice more" [ "$(field after "$r")" = 1 ]
check "still exactly one, counted from the element list" [ "$(grep -cx 'PC_ELEM=history\\ -a' <<<"$r")" = 1 ]
if [[ -r /etc/profile.d/wezterm.sh ]]; then
  check "bash-preexec took element 0" contains "$(grep -m1 '^PC_ELEM=' <<<"$r")" "PC_ELEM=\$'__bp_precmd_invoke_cmd"
  check "bash-preexec's own element is still last" [ "$(grep '^PC_ELEM=' <<<"$r" | tail -n 1)" = 'PC_ELEM=__bp_interactive_mode' ]
else
  echo "skip - bash-preexec checks (no /etc/profile.d/wezterm.sh here)"
fi

# --- 5. the same shell through Ghostty's launch -----------------------------
echo "== Ghostty's launch =="
if [[ -r "$GHOSTTY_BASH" ]]; then
  cat >"$SB/s5" <<S
echo alpha
echo beta
$HIST_A_COUNT
__n ghostty >&3
{ declare -p HISTSIZE HISTFILESIZE HISTTIMEFORMAT HISTCONTROL HISTIGNORE; shopt -p globstar checkjobs no_empty_cmd_completion histverify; } >&3
for e in "\${PROMPT_COMMAND[@]}"; do printf 'PC_ELEM=%q\n' "\$e"; done >&3
printf 'STAMPS=%s\nENTRIES=%s\n' "\$(grep -c '^#' "\$HISTFILE")" "\$(grep -vc '^#' "\$HISTFILE")" >&3
exit
S
  : >"$SB/h5"
  gshell "$SB/s5" "$SB/h5" "$SB/r5"
  r="$(<"$SB/r5")"
  check "contract holds under Ghostty: sizes" contains "$r" 'HISTFILESIZE="40000"'
  check "contract holds under Ghostty: HISTIGNORE" contains "$r" 'HISTIGNORE="exit:clear"'
  check "contract holds under Ghostty: HISTCONTROL" contains "$r" 'HISTCONTROL="ignoredups"'
  check "contract holds under Ghostty: the four shopts" [ "$(grep -c '^shopt -s' <<<"$r")" = 4 ]
  check "Ghostty's hook is in PROMPT_COMMAND" [ "$(grep -cx 'PC_ELEM=__ghostty_hook' <<<"$r")" = 1 ]
  check "exactly one history -a element beside it" [ "$(field ghostty "$r")" = 1 ]
  check "entries written after Ghostty's PS0 hook ran still carry timestamps" [ "$(field STAMPS "$r")" = "$(field ENTRIES "$r")" ] && [ "$(field ENTRIES "$r")" -ge 4 ]
  check "clear/exit absent, the rest present, after exit" [ "$(count "$SB/h5" '^exit$')" = 0 ] && [ "$(count "$SB/h5" '^echo beta$')" = 1 ]
else
  echo "skip - Ghostty's launch (no $GHOSTTY_BASH here)"
fi

# --- 6. the module is interactive-only --------------------------------------
echo "== non-interactive shells =="
out="$(env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash SSH_CLIENT='203.0.113.1 1 22' PATH="$BASE" /bin/bash -c 'printf "%s\n" "HISTSIZE=${HISTSIZE-unset}" "$(shopt -p globstar)"' 2>/dev/null)"
check "ssh host cmd: HISTSIZE untouched" [ "$(field HISTSIZE "$out")" = unset ]
check "ssh host cmd: globstar off" contains "$out" 'shopt -u globstar'
out="$(env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash TERM=dumb PATH="$BASE" /bin/bash -lc 'printf "%s\n" "HISTFILESIZE=${HISTFILESIZE-unset}" "$(shopt -p histverify)"' 2>/dev/null)"
check "the login shell GDM starts: HISTFILESIZE untouched" [ "$(field HISTFILESIZE "$out")" = unset ]
check "the login shell GDM starts: histverify off" contains "$out" 'shopt -u histverify'

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
