alias sysupgrade='sudo dnf upgrade --refresh -y && flatpak update -y && flatpak uninstall --unused -y'
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

# Move+List Shortcuts
alias lsa='ls -a --group-directories-first'
alias home='cd ~ && lsa'
alias desktop='cd ~/Desktop && lsa'
alias configs='cd ~/Desktop/configs && lsa'
alias teaching='cd ~/Desktop/teaching && lsa'
alias logic='cd ~/Desktop/teach-logic/phi012/Brandon && lsa'

# Editing shortcuts
alias configure='cd ~/Desktop/configs && nvim'
alias dissertate='cd ~/Desktop/dissertation && nvim'
alias homepage='cd ~/Desktop/bphopkins.net && nvim'
alias teach='cd ~/Desktop/teaching && nvim'
alias nousowl='cd ~/Desktop/nousowl.net && nvim'
alias cc='claude --model opus --effort max'
