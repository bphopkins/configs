#!/usr/bin/env bash
# Regression suite for the session environment: what a login shell hands the
# graphical session, and what the environment.d package hands the user manager.
# Written 2026-09-23 with the login-shell route in bash/.bash_profile and the
# environment.d package. The chain it pins is org/machines/environment.md.
#
# Hermetic: every shell runs under `env -i` with HOME pointed at a fixture that
# links to this checkout's bash files the way stow does, so the real ~ is never
# read; the systemd generator runs against the fixture's XDG_CONFIG_HOME. No
# privileges, no writes outside the sandbox, no network. The one machine-
# dependent input is /etc/profile and /etc/profile.d, which the login shell
# reads exactly as the real session's would -- that is the point.
#
# Caged: tests/cage.sh -- a systemd user scope with a memory ceiling, swap off,
# a task cap and a time cap, stopped on the way out; no user manager, no run.
#
# Run from anywhere after any edit to bash/.bash_profile, 10-env.sh, 20-path.sh
# or environment.d/ (~1 s). Last line follows the tests/gsync convention:
# "passed: N  failed: M"; exit 0 iff nothing failed. Requires bash 5+, systemd.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$CFG_ROOT/tests/cage.sh"
cage env "$@"

# --- the sandbox ------------------------------------------------------------
SB="$(mktemp -d "${TMPDIR:-/tmp}/env-tests.XXXXXX")"
trap 'rm -rf "$SB"' EXIT
H="$SB/home"
mkdir -p "$H/.config/environment.d" "$H/bin" "$H/.local/bin"
ln -s "$CFG_ROOT/bash/.bash_profile" "$H/.bash_profile"
ln -s "$CFG_ROOT/bash/.bashrc" "$H/.bashrc"
ln -s "$CFG_ROOT/bash/.bashrc.d" "$H/.bashrc.d"
for f in "$CFG_ROOT"/environment.d/*.conf; do
  ln -s "$f" "$H/.config/environment.d/$(basename "$f")"
done

pass=0 fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
contains() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }
empty_file() { [[ ! -s "$1" ]]; }
tl_first() { [[ "$1" == /usr/local/texlive/*/bin/* && -x "$1/tlmgr" ]]; }
no_empty_element() { [[ "$1" != *::* && "$1" != :* && "$1" != *: ]]; }
# 1-based position of $2 in the colon list $1; 0 when absent.
pos() { awk -v p="$1" -v e="$2" 'BEGIN { n = split(p, a, ":"); for (i = 1; i <= n; i++) if (a[i] == e) { print i; exit }; print 0 }'; }
field() { sed -n "s/^$1=//p" <<<"$2"; }

BASE=/usr/local/bin:/usr/bin
REPORT='printf "%s\n" "PATH=$PATH" "EDITOR=${EDITOR-unset}" "VISUAL=${VISUAL-unset}" "BASH_ENV=${BASH_ENV-unset}" "NPM_CONFIG_PREFIX=${NPM_CONFIG_PREFIX-unset}" "GIT_OPTIONAL_LOCKS=${GIT_OPTIONAL_LOCKS-unset}"'
# A login shell running one command, non-interactive: the shape GDM starts to
# launch the session (environment.md, stage 2). Its final environment is what
# the session inherits.
login_shell() { env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash TERM=dumb PATH="$BASE" /bin/bash -lc "$1"; }

# --- 1. the login shell, as GDM runs it -------------------------------------
echo "== login shell, non-interactive =="
out="$(login_shell "$REPORT" 2>"$SB/login.err")"
path="$(field PATH "$out")"
check "runs clean: nothing on stderr" empty_file "$SB/login.err"
check "~/.local/npm-global/bin on PATH" contains ":$path:" ":$H/.local/npm-global/bin:"
check "~/.local/bin on PATH" contains ":$path:" ":$H/.local/bin:"
check "~/bin on PATH" contains ":$path:" ":$H/bin:"
check "order: ~/.local/bin before ~/bin" [ "$(pos "$path" "$H/.local/bin")" -lt "$(pos "$path" "$H/bin")" ]
check "order: ~/bin before the system base" [ "$(pos "$path" "$H/bin")" -lt "$(pos "$path" /usr/local/bin)" ]
check "system base kept intact at the end" contains ":$path:" ":$BASE:"
tl_bins=(/usr/local/texlive/[0-9][0-9][0-9][0-9]/bin/*/tlmgr)
if [[ -x "${tl_bins[-1]}" ]]; then
  first="${path%%:*}"
  check "TeX Live first on PATH ($first)" tl_first "$first"
else
  echo "skip - TeX Live first on PATH (no TeX Live under /usr/local/texlive here)"
fi
check "no duplicate PATH entries" [ -z "$(tr ':' '\n' <<<"$path" | sort | uniq -d)" ]
check "no empty PATH element" no_empty_element "$path"
check "EDITOR=nvim" [ "$(field EDITOR "$out")" = nvim ]
check "VISUAL=nvim" [ "$(field VISUAL "$out")" = nvim ]
check "BASH_ENV unset (Lmod disarmed for the session)" [ "$(field BASH_ENV "$out")" = unset ]
check "NPM_CONFIG_PREFIX=~/.local/npm-global" [ "$(field NPM_CONFIG_PREFIX "$out")" = "$H/.local/npm-global" ]
check "GIT_OPTIONAL_LOCKS unset with no host file" [ "$(field GIT_OPTIONAL_LOCKS "$out")" = unset ]

# --- 2. the same PATH survives the interactive passes -----------------------
echo "== idempotence =="
# An interactive login shell (`ssh host`): .bash_profile, then .bashrc's whole
# module chain on top.
ipath="$(env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash TERM=dumb PATH="$BASE" /bin/bash -lic 'printf "%s" "$PATH"' 2>/dev/null </dev/null)"
check "interactive login shell: PATH identical" [ "$ipath" = "$path" ]
# A terminal inside the session: interactive, non-login, seeded with the
# session's PATH that the login shell produced.
tpath="$(env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash TERM=dumb PATH="$path" /bin/bash -ic 'printf "%s" "$PATH"' 2>/dev/null </dev/null)"
check "terminal seeded with the session PATH: unchanged" [ "$tpath" = "$path" ]
check "~/bin exactly once in that terminal" [ "$(tr ':' '\n' <<<"$tpath" | grep -cx "$H/bin")" = 1 ]

# --- 3. `ssh host cmd` stays cheap ------------------------------------------
echo "== ssh host cmd =="
sout="$(env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash SSH_CLIENT='203.0.113.1 1 22' PATH="$BASE" /bin/bash -c "$REPORT" 2>/dev/null)"
check "non-login non-interactive shell: PATH untouched" [ "$(field PATH "$sout")" = "$BASE" ]
check "non-login non-interactive shell: EDITOR unset" [ "$(field EDITOR "$sout")" = unset ]

# --- 4. the environment.d package, through the real generator ---------------
echo "== environment.d generator =="
G=/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator
if [[ -x "$G" ]]; then
  gout="$(env -i HOME="$H" XDG_CONFIG_HOME="$H/.config" "$G" 2>"$SB/gen.err")"
  check "generator runs clean" empty_file "$SB/gen.err"
  check "generator reads the stowed symlinks: EDITOR=nvim" contains "$gout"$'\n' $'EDITOR=nvim\n'
  check "generator: VISUAL=nvim" contains "$gout"$'\n' $'VISUAL=nvim\n'
  check "generator: SDL_JOYSTICK_HIDAPI=0" contains "$gout"$'\n' $'SDL_JOYSTICK_HIDAPI=0\n'
  check "generator emits no PATH (PATH has one author, 20-path.sh)" lacks $'\n'"$gout" $'\nPATH='
else
  check "generator present at $G" false
fi
check "no drop-in in the package sets PATH" [ -z "$(grep -l '^PATH=' "$CFG_ROOT"/environment.d/*.conf 2>/dev/null)" ]
check "every drop-in line is a comment, blank, or NAME=value" [ -z "$(grep -hvE '^(#|;|$|[A-Za-z_][A-Za-z0-9_]*=)' "$CFG_ROOT"/environment.d/*.conf)" ]

# --- 5. the reader guard's environment half (10-env.sh, 2026-10-10) ---------
# GIT_OPTIONAL_LOCKS=0 is exported only on a machine whose host file,
# configs/git/hosts/<hostname>.inc, names it a reader or names a reader
# repository (org/machines/transport-2026-10, rules.md fedxps-1). The fixture
# gets a host file under this machine's real hostname, since the login shell
# reads it by `uname -n`.
echo "== GIT_OPTIONAL_LOCKS from the host file =="
HF="$H/Desktop/configs/git/hosts/$(uname -n).inc"
mkdir -p "$(dirname "$HF")"
hostfile() { printf '%b' "$1" > "$HF"; }
hostfile '[gsync]\n\trole = writer\n'
out="$(login_shell "$REPORT" 2>"$SB/login-w.err")"
check "writer: unset"                                   [ "$(field GIT_OPTIONAL_LOCKS "$out")" = unset ]
check "writer: runs clean"                              empty_file "$SB/login-w.err"
hostfile '[gsync]\n\treaderRepo = nousowl\n'
out="$(login_shell "$REPORT" 2>"$SB/login-p.err")"
check "a reader repository (the pilot's key): =0"       [ "$(field GIT_OPTIONAL_LOCKS "$out")" = 0 ]
check "pilot key: runs clean"                           empty_file "$SB/login-p.err"
hostfile '[gsync]\n\trole = reader\n'
out="$(login_shell "$REPORT" 2>"$SB/login-r.err")"
check "reader: =0"                                      [ "$(field GIT_OPTIONAL_LOCKS "$out")" = 0 ]
check "reader: runs clean"                              empty_file "$SB/login-r.err"
check "reader: PATH unchanged by the block"             [ "$(field PATH "$out")" = "$path" ]
iout="$(env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash TERM=dumb PATH="$BASE" /bin/bash -lic 'printf "%s" "${GIT_OPTIONAL_LOCKS-unset}"' 2>/dev/null </dev/null)"
check "reader: the interactive pass keeps it"           [ "$iout" = 0 ]
tout="$(env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash TERM=dumb PATH="$BASE" /bin/bash -ic 'printf "%s" "${GIT_OPTIONAL_LOCKS-unset}"' 2>/dev/null </dev/null)"
check "reader: a terminal inside the session has it"    [ "$tout" = 0 ]
sout="$(env -i HOME="$H" USER="$USER" LOGNAME="$USER" SHELL=/bin/bash SSH_CLIENT='203.0.113.1 1 22' PATH="$BASE" /bin/bash -c "$REPORT" 2>/dev/null)"
check "reader: ssh host cmd gets nothing (no profile)"  [ "$(field GIT_OPTIONAL_LOCKS "$sout")" = unset ]
hostfile '[gsync]\n\trole = readr\n'
out="$(login_shell "$REPORT" 2>/dev/null)"
check "any role but writer counts as reader: =0"        [ "$(field GIT_OPTIONAL_LOCKS "$out")" = 0 ]
hostfile '# a host file with no gsync section\n[core]\n\tcheckStat = minimal\n'
out="$(login_shell "$REPORT" 2>/dev/null)"
check "host file without a role: unset"                 [ "$(field GIT_OPTIONAL_LOCKS "$out")" = unset ]
hostfile '[core]\n\tcheck_stat = minimal\n[gsync]\n\trole = reader\n'
out="$(login_shell "$REPORT" 2>"$SB/login-m.err")"
check "a host file git cannot parse: =0 (fails safe)"   [ "$(field GIT_OPTIONAL_LOCKS "$out")" = 0 ]
check "malformed: still runs clean (git's error swallowed)" empty_file "$SB/login-m.err"
hostfile '[gsync]\n\trole = reader\n'
chmod 000 "$HF"
out="$(login_shell "$REPORT" 2>/dev/null)"
check "a host file this user cannot read: =0 (fails safe)" [ "$(field GIT_OPTIONAL_LOCKS "$out")" = 0 ]
chmod 644 "$HF"
rm -f "$HF"
# the second source: the file ~/.config/git/host.inc points at, which git reads
OTHER="$(dirname "$HF")/other.inc"
printf '[gsync]\n\trole = reader\n' > "$OTHER"
mkdir -p "$H/.config/git"
ln -s ../../Desktop/configs/git/hosts/other.inc "$H/.config/git/host.inc"
out="$(login_shell "$REPORT" 2>"$SB/login-l.err")"
check "no hostname file, link to a reader file: =0"     [ "$(field GIT_OPTIONAL_LOCKS "$out")" = 0 ]
check "link case: runs clean"                           empty_file "$SB/login-l.err"
ln -sfn /nowhere "$H/.config/git/host.inc"
out="$(login_shell "$REPORT" 2>/dev/null)"
check "a dangling host link: =0 (fails safe)"           [ "$(field GIT_OPTIONAL_LOCKS "$out")" = 0 ]
rm "$H/.config/git/host.inc"
out="$(login_shell "$REPORT" 2>/dev/null)"
check "link removed, no hostname file: unset again"     [ "$(field GIT_OPTIONAL_LOCKS "$out")" = unset ]
# an [include] inside the host file counts, as it does for git
hostfile '[include]\n\tpath = other.inc\n'
out="$(login_shell "$REPORT" 2>/dev/null)"
check "a role reached through an include in the host file: =0" [ "$(field GIT_OPTIONAL_LOCKS "$out")" = 0 ]
rm -f "$HF" "$OTHER"

echo
echo "passed: $pass  failed: $fail"
((fail == 0))
