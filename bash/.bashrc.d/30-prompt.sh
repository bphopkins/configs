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
