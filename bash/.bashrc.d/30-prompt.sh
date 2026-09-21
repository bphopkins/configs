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
# Added 2026-09-14, moved off the palette 2026-09-20. Until the first of those
# dates every box was PROMPT_COLOR=32, so an ssh session was told apart from a
# local one only by the characters in \h.
#
# These three are machine IDENTITIES, not decoration. The job is to stop a
# command meant for fedxps being run on nousowl, so the colour has to be
# unmistakable, which means it must not be a colour anything else on screen
# can be. Both halves of the scheme, kept in step by hand:
#
#     fedxps    #73daca  mint     this file
#     bigfed    #ff5fd1  rose     this file
#     nousowl   #ff9e64  orange   nousowl/configs/bash/.bashrc.d/30-prompt.sh
#     root      35       magenta  the package, untouched -- see the guard below
#
# SUPERSEDED 2026-09-20 -- this file used to say: "Plain ANSI numbers rather
# than hex. The terminals run TokyoNight Night, whose palette maps 32/31/33 to
# #9ece6a / #f7768e / #e0af68, so the numbers already *are* the theme colours;
# spelling them as 38;2;R;G;B would give the theme a second source of truth and
# freeze the prompt if the theme ever moved." That reasoning was sound for a
# prompt whose job was to look like the theme. It is the wrong reasoning for a
# prompt whose job is to be unique: an ANSI index is BY CONSTRUCTION the same
# colour as everything else that asks for that index, so 31 was always going to
# collide -- with dircolors' ARCHIVE at 01;31, with git's errors, with every
# red in every program. The second source of truth is the price, and the table
# above is what pays it: check these three against the theme if it ever moves.
#
# How they were chosen. TokyoNight's sixteen occupy only six hue positions --
# red 12, yellow 78, green 125, cyan 249, blue/white/black 281-287, magenta 306
# -- because the bright set sits almost on top of the normal set. That leaves
# three wide gaps, centred at 45 (orange), 187 (teal) and 339 (rose). One
# colour was taken from each gap, so no palette entry shares a hue with any of
# them: CIEDE2000 from the nearest of the sixteen is 13.3 at worst, against 0.0
# for the old indices, and the three are 41.4 apart from each other, against
# 26.5 before. #73daca and #ff9e64 are tokyonight's own green1 and orange;
# #ff5fd1 is constructed, since the rose gap holds no tokyonight colour.
# Unborrowed replacements for the first two exist (#19fde5, #fccdbe) and were
# declined 2026-09-20 -- they clear every threshold but cost the contrast and
# the character the set was picked for.
#
# Contrast on #1a1b26: 6.4 / 10.3 / 8.4. Root's magenta is 13.3 away or more
# from all three, so `sudo -i` stays a fourth distinguishable state.
#
# The COLORTERM test is what keeps this honest on a terminal that cannot draw
# it. Fedora ships `SendEnv COLORTERM` in /etc/ssh/ssh_config.d/50-redhat.conf
# and nousowl's sshd accepts it, so the variable arrives over ssh intact --
# measured 2026-09-20, it reads `truecolor` on the far side. A VT console, or
# any terminal that does not advertise, drops to the old index, which is why
# the indices are still here.
#
# bigfed held 34 blue for the first hours of 2026-09-14. Bold blue is not
# merely close to a directory in ls output, it is the same SGR: dircolors' DIR
# is 01;34. That collision is what started the whole line of thought, and the
# hex above is where it ends.
#
# Cyan 36 and 37 were declined as index choices on 2026-09-14. Note also that
# this file used to say "Brights 9-14 are byte-identical to 1-6 in this theme,
# so no bright variant offers a colour the list above does not already have."
# That stopped being true on 2026-09-20, when ghostty/themes/tokyonight-night-bph
# was rebased onto folke's generated palette and 9-14 became six distinct
# colours. It no longer matters here, the prompt having left the palette, but
# the sentence was load-bearing for the old choice and should not be trusted if
# this decision is ever revisited.
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
  fedxps) _pc_rgb='38;2;115;218;202' _pc_ansi=32 ;;
  bigfed) _pc_rgb='38;2;255;95;209' _pc_ansi=31 ;;
  *) ;;
  esac
  if [[ -n ${_pc_rgb:-} ]]; then
    case "$COLORTERM" in
    truecolor | 24bit) PROMPT_COLOR=$_pc_rgb ;;
    *) PROMPT_COLOR=$_pc_ansi ;;
    esac
  fi
  unset _pc_rgb _pc_ansi
fi
