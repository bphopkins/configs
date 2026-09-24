#!/usr/bin/env bash
# Regression suite for bash/.bashrc.d/30-prompt.sh: the prompt string it
# writes, as a terminal's shell renders it once the integrations have wrapped
# it. Written 2026-09-23, when the module took PS1 over from Fedora's
# bash-color-prompt package (configs/DECISIONS.md, the entry of that date).
#
# Hermetic, as tests/shell-opts/run.sh: every shell runs under `env -i` with
# HOME pointed at a fixture linked to this checkout's bash files the way stow
# does, and HISTFILE in the sandbox. The system layer -- /etc/bashrc,
# /etc/profile.d, the package's own template -- is read as a terminal's shell
# reads it; that is the point, since the package still writes PS1 first and
# the module has to be the one that lands. Shells read their commands from a
# file with `bash -i`, so prompts are issued and the integrations install;
# the rendered prompt, ${PS1@P}, is captured by a PROMPT_COMMAND element
# appended after theirs, so what is compared is what the terminal receives.
# The other machine's colour branch runs here too, since bash keeps an
# inherited HOSTNAME; the root branch runs in a user namespace (unshare -r),
# where EUID is 0 without privilege.
#
# Caged: tests/cage.sh -- a systemd user scope with a memory ceiling, swap off,
# a task cap and a time cap, stopped on the way out; no user manager, no run.
#
# Run from anywhere after any edit to 30-prompt.sh (~2 s). Last line follows
# the tests/gsync convention: "passed: N  failed: M"; exit 0 iff nothing
# failed. Requires bash 5.1+, systemd, unshare(1).
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODULE="$CFG_ROOT/bash/.bashrc.d/30-prompt.sh"
source "$CFG_ROOT/tests/cage.sh"
cage prompt "$@"

# --- the sandbox ------------------------------------------------------------
SB="$(mktemp -d "${TMPDIR:-/tmp}/prompt-tests.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
H="$SB/home"
mkdir -p "$H/odd \$dir"     # a name \w must show literally, never expand
ln -s "$CFG_ROOT/bash/.bash_profile" "$H/.bash_profile"
ln -s "$CFG_ROOT/bash/.bashrc" "$H/.bashrc"
ln -s "$CFG_ROOT/bash/.bashrc.d" "$H/.bashrc.d"

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
starts() { [[ "$1" == "$2"* ]]; }
ends() { [[ "$1" == *"$2" ]]; }
same_file() { cmp -s "$1" "$2"; }

BASE=/usr/local/bin:/usr/bin
GHOSTTY_BASH=/usr/share/ghostty/shell-integration/bash/ghostty.bash
me="$(id -un)"; host="$(env -i /bin/bash -c 'printf %s "${HOSTNAME%%.*}"')"   # what \h shows: bash's own value, no hostname(1)
declare -A RGB=([fedxps]='38;2;115;218;202' [bigfed]='38;2;255;95;209')
declare -A ANSI=([fedxps]=32 [bigfed]=31)
if [[ -n "${RGB[$host]:-}" ]]; then this=$host; else this=bigfed; fi   # an unregistered machine tests the table as bigfed
[[ $this = bigfed ]] && other=fedxps || other=bigfed
off=$'\001\e[0m\002'
# The bytes the module's prompt renders to, for a colour SGR ('' for bold
# alone) and the directory as \w shows it: the package's default shape with
# bold pinned. Only the OSC wraps the integrations add sit outside this.
core() { local on=$'\001\e[1m\002'; [[ -n $1 ]] && on+=$'\001\e['"$1"$'m\002'; printf '%s%s%s@%s%s:%s%s%s$ ' "$off" "$on" "$me" "$host" "$off" "$on" "$2" "$off"; }
strip_osc() { sed 's/\x01\x1b\][^\x02]*\x02//g' "$1"; }          # the rendered prompt minus the integrations' marks
WEZ_P=$'\001\e]133;P;k=i\a\002' WEZ_B=$'\001\e]133;B\a\002'
# The script every shell reads. Records ${PS1@P} at each prompt once __rep is
# in place: 1-3 in ~, 4 in the odd directory, 5 back in ~, 6 and 7 after the
# package's variables were changed at the prompt.
cat >"$SB/script" <<'S'
__n=0; __rep() { __n=$((__n+1)); printf '%s' "${PS1@P}" >"$REP/exp.$__n"; }
PROMPT_COMMAND+=(__rep)
:
:
cd "$HOME/odd \$dir"
cd "$HOME"
PROMPT_COLOR=31; PROMPT_HIGHLIGHT=7
:
printf 'USERHOST=%s\nVERSION=%s\n' "${PROMPT_USERHOST-unset}" "${BASH_COLOR_PROMPT_VERSION-unset}" >"$REP/vars"
exit
S
# One interactive non-login shell, started in the fixture home, reporting into
# $1; the rest is its environment (TERM, COLORTERM, HOSTNAME, NO_COLOR).
ishell() { local r=$1; shift; mkdir -p "$r"; (cd "$H" && env -i HOME="$H" USER="$me" LOGNAME="$me" SHELL=/bin/bash PATH="$BASE" HISTFILE="$SB/hist.$RANDOM" REP="$r" "$@" /bin/bash -i <"$SB/script" >/dev/null 2>&1); }
# The same through Ghostty's launch (the feature list is both machines').
gshell() { local r=$1; shift; mkdir -p "$r"; (cd "$H" && env -i HOME="$H" USER="$me" LOGNAME="$me" SHELL=/bin/bash PATH="$BASE" HISTFILE="$SB/hist.$RANDOM" REP="$r" TERM=xterm-ghostty TERM_PROGRAM=ghostty COLORTERM=truecolor GHOSTTY_BASH_UNEXPORT_HISTFILE=1 ENV="$GHOSTTY_BASH" GHOSTTY_BASH_INJECT=1 GHOSTTY_SHELL_FEATURES=path,ssh-env,ssh-terminfo,title GHOSTTY_RESOURCES_DIR=/usr/share/ghostty "$@" /bin/bash --posix -i <"$SB/script" >/dev/null 2>&1); }
# The checks every shape shares: the core bytes, stability, the odd
# directory, and the package's variables deciding nothing.
common() { # $1 report dir, $2 colour SGR, $3 label
  local r=$1 sgr=$2 l=$3
  check "$l: the rendered prompt is the module's, in the machine colour" [ "$(strip_osc "$r/exp.1")" = "$(core "$sgr" '~')" ]
  check "$l: stable across three prompts (no growth under the integrations)" same_file "$r/exp.1" "$r/exp.2" && same_file "$r/exp.2" "$r/exp.3"
  check "$l: \\w shows the odd directory literally" [ "$(strip_osc "$r/exp.4")" = "$(core "$sgr" '~/odd $dir')" ]
  check "$l: PROMPT_COLOR and PROMPT_HIGHLIGHT set at a prompt change nothing" same_file "$r/exp.5" "$r/exp.6" && same_file "$r/exp.5" "$r/exp.7"
}

# --- 0. the module itself ---------------------------------------------------
echo "== the module =="
check "parses (bash -n)" bash -n "$MODULE"
out="$(env -i HOME="$H" PATH="$BASE" /bin/bash -c "source '$MODULE'" 2>&1)"
check "sourcing it prints nothing" [ -z "$out" ]
check "ASCII only" [ -z "$(LC_ALL=C grep -P '[^\x00-\x7F]' "$MODULE")" ]
check "sets none of the package's PROMPT_* variables" [ -z "$(grep -E '^[[:space:]]*(export[[:space:]]+)?PROMPT_[A-Z_]+=' "$MODULE")" ]
check "assigns PS1 exactly once" [ "$(grep -cE '^[[:space:]]*PS1=' "$MODULE")" = 1 ]
check "leaves no helper variable behind" [ -z "$(env -i HOME="$H" HOSTNAME=$this COLORTERM=truecolor /bin/bash -c "source '$MODULE'; compgen -v _pc_")" ]

# --- 1. WezTerm's shape, truecolor advertised --------------------------------
echo "== TERM=xterm-256color COLORTERM=truecolor =="
ishell "$SB/r1" TERM=xterm-256color COLORTERM=truecolor HOSTNAME=$this
common "$SB/r1" "${RGB[$this]}" "truecolor"
if [[ -r /etc/profile.d/wezterm.sh ]]; then
  r="$(<"$SB/r1/exp.1")"
  check "truecolor: WezTerm's mark opens the prompt and closes it" starts "$r" "$WEZ_P" && ends "$r" "$WEZ_B"
  check "truecolor: exactly one wrap (\\001 count)" [ "$(tr -cd '\001' <"$SB/r1/exp.1" | wc -c)" = 9 ]
else
  echo "skip - WezTerm wrap checks (no /etc/profile.d/wezterm.sh here)"
fi

# --- 2. the same terminal, COLORTERM not advertised ------------------------
echo "== TERM=xterm-256color, no COLORTERM =="
ishell "$SB/r2" TERM=xterm-256color HOSTNAME=$this
common "$SB/r2" "${ANSI[$this]}" "index"

# --- 3. a terminal the package stays out of --------------------------------
echo "== TERM=xterm, no COLORTERM =="
ishell "$SB/r3" TERM=xterm HOSTNAME=$this
common "$SB/r3" "${ANSI[$this]}" "xterm"
check "xterm: the package did not activate, and the prompt has its shape anyway" [ "$(sed -n 's/^USERHOST=//p' "$SB/r3/vars")" = unset ]

# --- 4. the VT console -------------------------------------------------------
echo "== TERM=linux =="
ishell "$SB/r4" TERM=linux HOSTNAME=$this
common "$SB/r4" "${ANSI[$this]}" "linux"
check "linux: no OSC marks at all" [ "$(<"$SB/r4/exp.1")" = "$(core "${ANSI[$this]}" '~')" ]

# --- 5. Ghostty's launch -----------------------------------------------------
echo "== Ghostty's launch =="
if [[ -r "$GHOSTTY_BASH" ]]; then
  gshell "$SB/r5" HOSTNAME=$this
  common "$SB/r5" "${RGB[$this]}" "ghostty"
  r="$(<"$SB/r5/exp.1")"
  check "ghostty: wrapped by both integrations, its title last" starts "$r" "$WEZ_P$WEZ_P" && ends "$r" "$WEZ_B$WEZ_B"$'\001\e]2;~\a\002'
else
  echo "skip - Ghostty's launch (no $GHOSTTY_BASH here)"
fi

# --- 6. NO_COLOR -----------------------------------------------------------
echo "== NO_COLOR=1 =="
ishell "$SB/r6" TERM=xterm-256color COLORTERM=truecolor NO_COLOR=1 HOSTNAME=$this
common "$SB/r6" "" "NO_COLOR"

# --- 7. the other machine, and an unregistered one ---------------------------
echo "== the colour table =="
ishell "$SB/r7" TERM=xterm-256color COLORTERM=truecolor HOSTNAME=$other
check "$other: its truecolor" [ "$(strip_osc "$SB/r7/exp.1")" = "$(core "${RGB[$other]}" '~')" ]
ishell "$SB/r7b" TERM=xterm-256color HOSTNAME=$other
check "$other: its index without COLORTERM" [ "$(strip_osc "$SB/r7b/exp.1")" = "$(core "${ANSI[$other]}" '~')" ]
ishell "$SB/r8" TERM=xterm-256color COLORTERM=truecolor HOSTNAME=elsewhere
check "unregistered host: the package's green, 32" [ "$(strip_osc "$SB/r8/exp.1")" = "$(core 32 '~')" ]

# --- 8. root -----------------------------------------------------------------
echo "== root (EUID 0 in a user namespace) =="
if unshare -r true 2>/dev/null; then
  out="$(env -i HOME="$H" PATH="$BASE" HOSTNAME=$this COLORTERM=truecolor unshare -r /bin/bash -c "PS1=SENTINEL; source '$MODULE'; printf '%s|%s' \"\$EUID\" \"\$PS1\"" 2>&1)"
  check "as root the module leaves PS1 alone" [ "$out" = "0|SENTINEL" ]
  # the whole chain as root: the package's magenta stands
  mkdir -p "$SB/r9"
  (cd "$H" && env -i HOME="$H" USER=root LOGNAME=root SHELL=/bin/bash PATH="$BASE" HISTFILE="$SB/hist.root" REP="$SB/r9" TERM=xterm-256color COLORTERM=truecolor HOSTNAME=$this unshare -r /bin/bash -i <"$SB/script" >/dev/null 2>&1)
  r="$(strip_osc "$SB/r9/exp.1" 2>/dev/null)"
  check "as root the package's prompt stands, in its magenta" contains "$r" $'\001\e[35m\002' && lacks "$r" "${RGB[$this]}"
else
  echo "skip - root branch (unshare -r unavailable here)"
fi

# --- 9. the module is interactive-only --------------------------------------
echo "== non-interactive shells =="
out="$(env -i HOME="$H" USER="$me" LOGNAME="$me" SHELL=/bin/bash SSH_CLIENT='203.0.113.1 1 22' PATH="$BASE" /bin/bash -c 'printf "%s" "${PS1-unset}"' 2>/dev/null)"
check "ssh host cmd: PS1 untouched" [ "$out" = unset ]

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
