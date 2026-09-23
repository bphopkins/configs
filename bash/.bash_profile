# ~/.bash_profile
#
# Read by login shells only: the one GDM starts to launch the graphical
# session, an `ssh host` login, `bash -l`. Not by `ssh host cmd`, by scripts,
# or by terminals inside the session, which read ~/.bashrc directly.
#
# The environment half of the configuration runs from here first (2026-09-23).
# The session inherits the login shell's environment and nothing else of ours:
# ~/.bashrc returns at once for a non-interactive shell, and GDM's login shell
# is one. Fedora's own skeleton reaches the same result the other way round,
# with an unguarded ~/.bashrc; our guard keeps `ssh host cmd` and every script
# cheap, so the two modules that are pure environment run from here instead.
# Both are idempotent (duplicate-guarded PATH; constants), so the interactive
# pass in ~/.bashrc re-sourcing them is a no-op.
#
# What the session gets from this: PATH with TeX Live, npm-global, ~/.local/bin
# and ~/bin (so desktop-launched apps find stowed tools, and Okular's inverse
# search finds okular-inverse and nvr), EDITOR/VISUAL=nvim, NPM_CONFIG_PREFIX,
# and BASH_ENV unset (Lmod's /etc/profile.d/modules.sh sets it just before this
# file runs). Under GNOME the login shell's environment is uploaded to the user
# manager and to D-Bus by gnome-session; under sway it is inherited directly.
# Takes effect at the next login -- except that the upload sets and never
# removes, so on a lingering manager (bigfed) a variable it already holds
# needs `systemctl --user unset-environment NAME` once. The chain:
# org/machines/environment.md. Suite: tests/env/run.sh.
for rc in ~/.bashrc.d/10-env.sh ~/.bashrc.d/20-path.sh; do
  [ -f "$rc" ] && . "$rc"
done
unset rc

# Load interactive configuration
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# Unsorted
