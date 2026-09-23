# 10-env.sh
# Environment variables (exported, inherited by child processes)
#
# Sourced twice by design: from ~/.bash_profile for login shells -- including
# the one GDM starts, whose environment the graphical session inherits
# (2026-09-23) -- and from ~/.bashrc for interactive ones. Everything here is a
# constant or an unset, so the second pass is a no-op.

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
