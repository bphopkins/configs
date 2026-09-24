# 30-prompt.sh
# The prompt: PS1, written here in full
#
# PS1 is the string bash re-reads before every command line: \u, \h and \w
# stand for the user, the host and the working directory, \$ for the prompt
# character, and the colour codes sit around them. Until 2026-09-23 this file
# did not write it. Fedora's bash-color-prompt package
# (/etc/profile.d/bash-color-prompt.sh, read by /etc/bashrc before this
# directory) replaced Fedora's traditional `[\u@\h \W]\$ ` with a template of
# PROMPT_* variables that bash re-expands at every prompt, and this file
# filled two of them: PROMPT_HIGHLIGHT=1 for bold, PROMPT_COLOR for the
# machine's colour. So the prompt's shape, user@host:directory$, was the
# package's, and it appeared only where the package's activation test passed:
# PS1 still exactly Fedora's, and COLORTERM set, or TERM ending in "color", or
# TERM=linux. Where the test failed -- a terminal that sends TERM=xterm and no
# COLORTERM -- the prompt stayed `[user@host dir]$ ` and both variables did
# nothing. The package's README calls the direct use of its variables "being
# deprecated" and its functions "subject to change until 1.0".
#
# This file now assembles the same string from the same pieces, and the
# package's variables decide nothing: setting PROMPT_COLOR at a prompt changes
# nothing, which the suite checks. The package still runs from /etc/bashrc
# and still sets its template, which the assignment below overwrites -- its
# switch, bash_color_prompt_disable, would have to be set before /etc/bashrc
# is read, and nothing here runs that early (configs/TODO.md item 25). Before
# the change the bytes reaching the terminal were compared against the
# package's in every shape a shell here takes: WezTerm's, Ghostty's launch
# with both integrations' marks wrapped around the prompt, the VT console,
# each machine's colour, an unregistered host, PROMPT_DIRTRIM -- identical in
# all of them. A plain string expands in 7 microseconds against the template's
# 34. Record: configs/DECISIONS.md, the entry of 2026-09-23.
# Suite: tests/prompt/run.sh, after any edit here.
#
# Left to right: a reset, so a command that left the terminal bold or coloured
# does not bleed into the prompt; bold and the machine colour on user@host; a
# plain colon; bold and colour again on the directory; a reset; `$ ` plain.
# That is the package's default shape with bold pinned, as both machines have
# shown it since 2026-09-05.
#
# Bold is written here rather than left to a default because the package
# decided it by a string comparison against one desktop environment's name:
#
#     prompt_default_highlight() {
#         if [ "$DESKTOP_SESSION" = "gnome" ]; then
#             prompt_highlight "${1:-1}"
#         else
#             unset PROMPT_HIGHLIGHT
#         fi
#     }
#
# which is why the prompt came out bold under GNOME on bigfed and plain under
# sway on fedxps -- the same repo, the same shell, two different looks. Pinned
# 2026-09-05 so the two machines agree; part of the string itself since
# 2026-09-23.
#
# NO_COLOR (https://no-color.org) is honoured since 2026-09-23: set, the
# prompt is bold and uncoloured. The package honoured it too, and this file
# used to defeat it by re-setting PROMPT_COLOR after the package had cleared
# it -- an accident, never a decision. Not set on any of the three machines.


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
# one signal worth keeping. Inside the guard, root's PS1 is never touched.
#
# An unregistered machine takes 32, the package's own green for a user, so it
# looks like fedxps on a console rather than losing its prompt. Give a new box
# its own line here rather than relying on that.
#
# \[ and \] around each code tell readline that the bytes between them take
# no columns, so a line being edited or redrawn does not misalign.
if [[ $EUID -ne 0 ]]; then
  case "$HOSTNAME" in
  fedxps) _pc_rgb='38;2;115;218;202' _pc_ansi=32 ;;
  bigfed) _pc_rgb='38;2;255;95;209' _pc_ansi=31 ;;
  *) _pc_rgb='' _pc_ansi=32 ;;
  esac
  case "$COLORTERM" in
  truecolor | 24bit) _pc_sgr=${_pc_rgb:-$_pc_ansi} ;;
  *) _pc_sgr=$_pc_ansi ;;
  esac
  [[ -n ${NO_COLOR:-} ]] && _pc_sgr=''
  _pc_on='\[\e[1m\]'${_pc_sgr:+"\[\e[${_pc_sgr}m\]"}
  _pc_off='\[\e[0m\]'
  PS1=${_pc_off}${_pc_on}'\u@\h'${_pc_off}':'${_pc_on}'\w'${_pc_off}'\$ '
  unset _pc_rgb _pc_ansi _pc_sgr _pc_on _pc_off
fi
