alias sysupgrade='sudo dnf upgrade --refresh -y && sudo dnf autoremove -y && flatpak update -y && flatpak uninstall --unused -y'
# Updates packages *within* a release; tlmgr refuses to cross a release
# boundary by design. For a new release year, do a parallel install instead.
# tlmgr is resolved through PATH so this never goes stale on a year bump; the
# absolute path is passed to sudo because secure_path would otherwise discard
# the TeX Live PATH entry.
alias tl-upgrade='sudo "$(command -v tlmgr)" update --self --all'

# Typo-proof re-source. Never type `source ~/.bash...` by hand again: tab can
# complete it to ~/.bash_history, and sourcing history REPLAYS every command
# in it. The `;` (not `&&`) keeps the confirmation even if a module returns
# nonzero; any real error prints above it.
alias reload='source ~/.bashrc; echo "~/.bashrc reloaded"'

# Power off now. `shutdown` on its own looks broken but isn't: it's a symlink
# to systemctl, and for SysV compat a bare invocation defaults to `+1`, so it
# SCHEDULES for one minute out rather than acting (cancel with `shutdown -c`).
# `poweroff` is the immediate verb. No sudo -- polkit authorizes power-off for
# an active local session. Block inhibitors are honoured, so this refuses while
# a dnf transaction is mid-flight and names the culprit; override with -i.
alias byebye='systemctl poweroff'

# Move+List Shortcuts
alias lsa='ls -a --group-directories-first'
alias home='cd ~ && lsa'
alias desktop='cd ~/Desktop && lsa'
alias configs='cd ~/Desktop/configs && lsa'
alias teaching='cd ~/Desktop/teaching && lsa'
alias logic='cd ~/Desktop/teaching/logic && lsa'

# Editing shortcuts
alias configure='cd ~/Desktop/configs && nvim'
alias dissertate='cd ~/Desktop/dissertation && nvim'
alias homepage='cd ~/Desktop/bphopkins.net && nvim'
alias teach='cd ~/Desktop/teaching && nvim'
alias nousowl='cd ~/Desktop/nousowl.net && nvim'
alias cc='claude --model opus --effort max'
alias ccf='claude --model fable --effort max'
