# 00-shell-opts.sh
# Shell behaviour settings (shopt, set), and the history contract
#
# Sourced first, so an option that changes how the later modules are read
# lands here before they parse. A reserved empty slot from the start of the
# modular layout until 2026-09-23, when it took the content below
# (configs/DECISIONS.md, the entry of that date). Interactive shells only:
# ~/.bashrc returns before this directory for any other kind, and
# ~/.bash_profile sources 10-env.sh and 20-path.sh alone.
#
# The system layer this runs after -- /etc/bashrc and the scripts under
# /etc/profile.d, read by ~/.bashrc at line 7 -- already turns on histappend
# and checkwinsize, sets the window-title PROMPT_COMMAND, and, from
# /etc/profile in the login shell only, exports HISTSIZE=1000 and
# HISTCONTROL=ignoredups, which a terminal inside the graphical session
# received by inheritance and nothing else: `ssh host bash -i` showed both
# unset (measured 2026-09-23). So everything about history is stated here,
# and nothing about it is inherited any more. checkwinsize stays the
# system's. Suite: tests/shell-opts/run.sh, after any edit here.

# --- History ----------------------------------------------------------------
#
# The old cap. HISTFILESIZE was never set, so it followed HISTSIZE, and every
# shell start and exit trimmed ~/.bash_history to 1,000 lines (measured
# 2026-09-23: a 1,500-line file, one shell, 1,000 lines). That cap, with no
# dates in the file, is what left the same day's count of alias use with a
# thousand undated lines a machine and nothing safe to prune on.
#
# The new size is 20,000 entries, and its cost was measured on bigfed at a
# terminal shell's start (bash -i to exit, WezTerm's shape, 30 runs each):
# 106 ms with an empty file, +3.5 ms with 10,000 dated entries, +6.5 with
# 20,000 undated, +7.4 with 20,000 dated (40,000 lines), +9.6 with 40,000
# undated. Entries drive it more than lines do. Session two's figures the
# same day, measured another way: +4 at 10,000, +9 at 20,000, +27 at 50,000,
# +53 at 100,000, and +30 for a 100,000-entry file under HISTSIZE=10000.
#
# HISTSIZE counts entries; the file limit is written in lines, two per dated
# entry, so 40000 holds the 20,000. Assigning HISTFILESIZE trims the file at
# once, and done here, during startup, the trim counts the stamp lines too
# (measured: a file of 20,010 dated entries, 40,020 lines, kept 20,000 lines
# and 10,000 entries under a limit of 20000; the same assignment typed at a
# prompt skips the stamps and keeps entries, one short). So every new shell
# cuts the file back to 40,000 lines. Nothing happens at exit: the write
# after every command (below) leaves the exiting shell nothing to save, and
# the trim bash does at exit is part of that save.
HISTSIZE=20000
HISTFILESIZE=40000

# Timestamps. The file gains a `#<epoch>` line ahead of every entry, so its
# line count doubles, and anything that counts commands with `wc -l` must skip
# `#` lines. Entries written before this have no such line and keep none in
# the file; `history` shows each of them with the time the shell that loaded
# them started (measured, bash 5.3). The terminal hooks that read `history 1`
# -- bash-preexec's and Ghostty's -- set HISTTIMEFORMAT='' locally for the
# call, and the file still gains its `#` lines after they have run (the suite
# pins that).
HISTTIMEFORMAT='%F %T '

# ignoredups, restated from /etc/profile so that the contract is whole here.
# Not ignorespace, which cannot work in these terminals: bash-preexec, which
# /etc/profile.d/wezterm.sh installs in every interactive shell whose TERM is
# not linux or dumb, strips it out of HISTCONTROL at the first prompt
# (measured: ignoreboth came back as `ignoredups:`). Not erasedups: it turns
# the log into a set, and the two files held 247 and 172 distinct lines out
# of 1,000 each.
HISTCONTROL=ignoredups

# What never enters the log. `exit` and `clear` were 27 % of bigfed's file
# and 32 % of fedxps's (2026-09-23). A pattern matches the whole line, so
# `exit 1` is still recorded. HISTIGNORE survives bash-preexec where
# ignorespace does not, so a command to keep out of the log goes here and
# nowhere else. Declined the same day: `lsa`, `ls`, `cd ..`. One side effect,
# measured: a hook that learns the running command from `history 1` --
# Ghostty's window title, WezTerm's WEZTERM_PROG -- sees the previous command
# instead while `clear` or `exit` runs, for as long as they take.
HISTIGNORE='exit:clear'

# histappend, restated from /etc/bashrc: an exiting shell with lines still to
# save appends them rather than overwriting the file, so parallel windows
# keep each other's history.
shopt -s histappend

# Write after every command rather than only at exit, so a window that dies
# with the session, a crash or a reboot loses nothing, and a window opened
# later can read what an earlier one ran. Added as an element of the
# PROMPT_COMMAND array, the form /etc/profile.d/80-systemd-osc-context.sh and
# Ghostty's integration use: at the first prompt bash-preexec rewrites
# element 0 of the array -- where /etc/bashrc's title printf sits -- around
# its own hooks and leaves every other element alone, so an element of ours
# survives it where text joined onto element 0 with `;` would be reshaped.
# Elements run in index order; this one lands after systemd's and before
# Ghostty's, and order does not matter to it. The guard is for `reload`,
# which re-sources this file: without it every reload appended another copy
# (measured: two sources, two elements). Deliberately no `history -n` beside
# it: reading other windows' commands into this one would interleave them
# with its own in its recall. Cost: 14 microseconds a prompt with one new
# entry, 2 with none (1,000 appends over a 20,000-entry list, 14 ms;
# 2026-09-23).
[[ " ${PROMPT_COMMAND[*]} " == *" history -a "* ]] || PROMPT_COMMAND+=('history -a')

# --- Shell options ----------------------------------------------------------
#
# The four taken 2026-09-23, each a behaviour of the interactive shell alone:
#   globstar                 `**` in a pattern matches across directory
#                            levels (`**/*.tex`)
#   checkjobs                an exit with jobs still running or stopped lists
#                            them, and a running one holds the exit until a
#                            second `exit`
#   no_empty_cmd_completion  TAB on an empty line does not list every command
#                            on PATH
#   histverify               a history expansion (`!!`, `!$`) is loaded into
#                            the line for a look instead of running at once
# Declined the same day: autocd and cdspell (offered, not taken); lithist
# (with cmdhist, bash's default, a multi-line command is saved joined into
# one line, which reads better in the file).
shopt -s globstar checkjobs no_empty_cmd_completion histverify
