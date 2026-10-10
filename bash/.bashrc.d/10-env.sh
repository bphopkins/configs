# 10-env.sh
# Environment variables (exported, inherited by child processes)
#
# Sourced twice by design: from ~/.bash_profile for login shells -- including
# the one GDM starts, whose environment the graphical session inherits
# (2026-09-23) -- and from ~/.bashrc for interactive ones. Everything here is a
# constant, an unset, or an export decided by a file, so the second pass is a
# no-op.

export EDITOR="nvim"
export VISUAL="nvim"

# npm's global prefix (2026-09-23). Replaces ~/.npmrc, which held only this
# line -- `prefix=/home/bph/.local/npm-global`, 35 bytes, mode 600, identical on
# both machines -- a hand-made dotfile the repo depended on but could not carry:
# .npmrc is also where npm keeps auth tokens, so .gitignore refuses it. npm reads
# NPM_CONFIG_<key> for any config key, and the environment outranks the user
# file (measured: NPM_CONFIG_PREFIX=/tmp/x npm config get prefix -> /tmp/x). The
# matching PATH entry is in 20-path.sh. Reaches wherever this file does; a
# shell with neither (`ssh host cmd`) sees npm's built-in prefix, /usr.
export NPM_CONFIG_PREFIX="$HOME/.local/npm-global"

# Lmod's BASH_ENV, disarmed (2026-09-21).
#
# Lmod is installed as a hard dependency of Singular (via carat), so the package
# cannot be removed without taking Singular with it. But its
# /etc/profile.d/modules.sh points BASH_ENV at Lmod's init script, and bash
# sources BASH_ENV at the start of every non-interactive shell that inherits
# it -- every `bash -c` and every `#!/bin/bash` script under a terminal, and
# under the GNOME session (see Scope below). Not `ssh host cmd`: that runs no
# profile, so BASH_ENV is unset there (measured 2026-09-21). Measured cost:
# ~10 ms per spawn (1.07 s vs 0.11 s over 100), which is ~7% on a real workload
# like tests/gsync/run-all.sh (5.4 s -> 5.0 s). The feature it buys is `module
# load` inside scripts, which is not used here.
#
# modules.sh sets it only `if [ -z "${BASH_ENV:-}" ]`, and .bashrc sources
# /etc/bashrc before this directory, so unsetting here is the whole fix -- no
# ordering surgery needed. `module` and `ml` are unaffected: they are exported
# shell functions, so they survive into child shells on their own.
#
# Scope: shells descended from an interactive one, and, since 2026-09-23, the
# login shell GDM starts (this file runs from ~/.bash_profile), so the session
# no longer picks BASH_ENV up from its own profile pass either. One caveat:
# bigfed's user manager lingers (loginctl: Linger=yes), so it outlives a
# logout, and the session-start upload sets variables but never removes one --
# a BASH_ENV the manager already holds survives every re-login until
# `systemctl --user unset-environment BASH_ENV` is run once, or the machine
# reboots. fedxps does not linger, and has no Lmod.
unset BASH_ENV

# The reader guard's environment half (2026-10-10; org/machines/transport-2026-10,
# rules.md fedxps-1). Syncthing carries each repository's .git between the
# machines and bigfed alone writes it; on fedxps a plain `git status` would
# still rewrite .git/index on a copy Syncthing delivered, and that write races
# bigfed's through the hub. GIT_OPTIONAL_LOCKS=0 stops it, and has no config
# form, so it rides here: this file reaches login shells, the GNOME session
# and what it starts, interactive shells, and Claude Code's Bash tool. The
# rest of the guard is git configuration, configs/git/hosts/fedxps.inc through
# the link ~/.config/git/host.inc.
#
# Exported when either of the two host files 50-git-sync.sh reads -- the one
# for this hostname (short, lowercased), and the one ~/.config/git/host.inc
# points at, which is what git itself reads -- names this machine a reader
# (`gsync.role` anything but `writer`) or names a reader repository
# (`gsync.readerRepo`, the pilot's nousowl); and on a host file that exists
# but cannot be read or parsed, or a dangling link: the safe side. bigfed,
# the writer, never gets it: there it would make gpushall's `add -A` re-stamp
# pack files after a stat-only arrival. Never unset here: a role change takes
# a new login, like everything in this file, and reaches only the shells and
# sessions started after it. `git -C /`: `git config -f` still discovers a
# repository from the current directory, and a dangling .git file there is
# fatal. Suite: tests/env/run.sh.
_env_host="$(uname -n 2>/dev/null)"
_env_host="${_env_host%%.*}"; _env_host="${_env_host,,}"; _env_host="${_env_host//[[:space:]]/}"
_env_files="$HOME/Desktop/configs/git/hosts/$_env_host.inc"
_env_link="$HOME/.config/git/host.inc"
if [ -L "$_env_link" ] || [ -e "$_env_link" ]; then
  if _env_target="$(readlink -e -- "$_env_link" 2>/dev/null)"; then
    _env_files="$_env_files
$_env_target"
  else
    export GIT_OPTIONAL_LOCKS=0
  fi
fi
if command -v git >/dev/null 2>&1; then
  while read -r _env_f; do
    [ -n "$_env_host" ] || [ "$_env_f" != "$HOME/Desktop/configs/git/hosts/.inc" ] || continue
    [ -e "$_env_f" ] || [ -L "$_env_f" ] || continue
    if [ ! -f "$_env_f" ] || [ ! -r "$_env_f" ]; then
      export GIT_OPTIONAL_LOCKS=0
      continue
    fi
    _env_keys="$(git -C / config -f "$_env_f" --includes --get-regexp '^gsync\.' 2>/dev/null)"
    _env_rc=$?
    if [ "$_env_rc" -gt 1 ]; then
      export GIT_OPTIONAL_LOCKS=0
      continue
    fi
    while read -r _env_key _env_val; do
      case "$_env_key" in
        gsync.role) if [ "$_env_val" != writer ]; then export GIT_OPTIONAL_LOCKS=0; fi ;;
        gsync.readerrepo) if [ -n "$_env_val" ]; then export GIT_OPTIONAL_LOCKS=0; fi ;;
      esac
    done <<EOF_KEYS
$_env_keys
EOF_KEYS
  done <<EOF_FILES
$_env_files
EOF_FILES
fi
unset _env_host _env_files _env_link _env_target _env_f _env_keys _env_rc _env_key _env_val
