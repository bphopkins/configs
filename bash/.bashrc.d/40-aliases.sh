alias sysupgrade='sudo dnf upgrade --refresh -y && flatpak update -y && flatpak uninstall --unused -y'
alias tl-upgrade='sudo /usr/local/texlive/2025/bin/x86_64-linux/tlmgr update --self --all'

# Move+List Shortcuts
alias lsa='ls -a --group-directories-first'
alias home='cd ~ && lsa'
alias desktop='cd ~/Desktop && lsa'
alias configs='cd ~/Desktop/configs && lsa'
alias teaching='cd ~/Desktop/teaching && lsa'

# Editing shortcuts
alias configure='cd ~/Desktop/configs && nvim'
alias dissertate='cd ~/Desktop/dissertation && nvim'
alias homepage='cd ~/Desktop/bphopkins.net && nvim'
alias teach='cd ~/Desktop/teaching && nvim'
alias nousowl='cd ~/Desktop/nousowl.net && nvim'
