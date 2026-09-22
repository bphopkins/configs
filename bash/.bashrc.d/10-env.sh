# 10-env.sh
# Environment variables (exported, inherited by child processes)

export EDITOR="nvim"
export VISUAL="nvim"

# Lmod's BASH_ENV, disarmed (2026-09-21).
#
# Lmod is installed as a hard dependency of Singular (via carat), so the package
# cannot be removed without taking Singular with it. But its
# /etc/profile.d/modules.sh points BASH_ENV at Lmod's init script, and bash
# sources BASH_ENV at the start of *every non-interactive shell* -- every
# `bash -c`, every `#!/bin/bash` script, every `ssh host cmd`. Measured cost:
# ~10 ms per spawn (1.07 s vs 0.11 s over 100), which is ~7% on a real workload
# like tests/gsync/run-all.sh (5.4 s -> 5.0 s). The feature it buys is `module
# load` inside scripts, which is not used here.
#
# modules.sh sets it only `if [ -z "${BASH_ENV:-}" ]`, and .bashrc sources
# /etc/bashrc before this directory, so unsetting here is the whole fix -- no
# ordering surgery needed. `module` and `ml` are unaffected: they are exported
# shell functions, so they survive into child shells on their own.
#
# Scope: this reaches shells descended from an interactive one. The GNOME
# session still carries BASH_ENV from its own profile pass -- part of the
# larger question of why none of ~/.bashrc.d reaches the session at all.
unset BASH_ENV
