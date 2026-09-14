# 30-prompt.sh
# Prompt configuration (PS1, PS2, PROMPT_COMMAND)
#
# PS1 defines the primary prompt displayed before each command.
# PS2 defines the continuation prompt (when a command spans lines).
# PROMPT_COMMAND, if set, runs before each prompt is displayed.
#
# PS1 itself is still the system default from /etc/bashrc. On Fedora that is
# not a fixed string: the bash-color-prompt package
# (/etc/profile.d/bash-color-prompt.sh) assembles it out of live PROMPT_*
# variables, which bash re-expands at every prompt. So setting one of them
# here -- long after profile.d has run -- takes effect on the very next
# prompt, with no need to re-source the framework or rebuild PS1.
#
# PROMPT_HIGHLIGHT is an SGR parameter spliced in ahead of PROMPT_COLOR, and
# 1 is bold. Left unset, the package picks for us:
#
#     prompt_default_highlight() {
#         if [ "$DESKTOP_SESSION" = "gnome" ]; then
#             prompt_highlight "${1:-1}"
#         else
#             unset PROMPT_HIGHLIGHT
#         fi
#     }
#
# A literal string comparison against one desktop environment's name, which
# is why the prompt came out bold under GNOME on bigfed and plain under sway
# on fedxps -- the same repo, the same shell, two different looks, decided by
# a package default rather than by anything here. Pinned 2026-09-05 so the two
# machines agree and the answer stops depending on someone else's opinion
# about desktop environments. Set it to 7 for reverse video, or comment the
# line out to hand the decision back to the package.
PROMPT_HIGHLIGHT=1


# --- One colour per machine -------------------------------------------------
#
# Added 2026-09-14. Until then every box was PROMPT_COLOR=32, so an ssh session
# was told apart from a local one only by the characters in \h -- and the one
# visible difference between here and nousowl, bold against not-bold, was not a
# machine signal at all. It was this file's absence: nousowl is headless, so
# DESKTOP_SESSION is unset there and the package default above unset the
# highlight. "Not bold" meant "configuration not deployed", which is exactly
# the fact a prompt should not be reporting.
#
# The scheme spans two repos, because nousowl's shell config deliberately is
# not this one (nousowl/configs/README.md). Both halves, kept in step by hand:
#
#     fedxps    32  green    this file
#     bigfed    34  blue     this file
#     nousowl   33  amber    nousowl/configs/bash/.bashrc.d/30-prompt.sh
#     root      35  magenta  the package, untouched -- see the guard below
#
# Plain ANSI numbers rather than hex. The terminals run TokyoNight Night, whose
# palette maps 32/34/33 to #9ece6a / #7aa2f7 / #e0af68, so the numbers already
# *are* the theme colours; spelling them as 38;2;R;G;B would give the theme a
# second source of truth and freeze the prompt if the theme ever moved. It also
# keeps the prompt sane on a VT console and through a terminal that is not ours.
#
# The EUID guard exists so root keeps the package's magenta on every machine,
# which makes `sudo -i` a fourth distinguishable state rather than a lost one.
# It is cheap insurance in the direction that fails safe: root's own ~/.bashrc
# does not source this file, but `sudo -s` preserves HOME under some sudoers
# configurations, and there the machine colour would otherwise overwrite the
# one signal worth keeping.
#
# The default branch leaves PROMPT_COLOR as the package set it, so an
# unregistered machine looks like fedxps rather than losing its prompt. Give a
# new box its own line here rather than relying on that.
if [[ $EUID -ne 0 ]]; then
  case "$HOSTNAME" in
  fedxps) PROMPT_COLOR=32 ;;
  bigfed) PROMPT_COLOR=34 ;;
  *) ;;
  esac
fi
