# ~/.bashrc

# If not running interactively, do nothing
[[ $- != *i* ]] && return

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# Load modular configuration. A Syncthing conflict copy of a module keeps its
# .sh and sorts after the original in every locale, so it would win; it is
# never sourced (org/machines/transport-2026-10/rules.md -> ws-4).
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*.sh; do
    [[ $rc == *.sync-conflict-* ]] && continue
    [ -f "$rc" ] && . "$rc"
  done
  unset rc
fi

# Arrivals (rules.md -> ws-8): a module changed under an open shell -- by
# Syncthing, a pull, an edit -- stays unloaded in it until `reload`. The inode
# and ctime of these files are recorded now, and before each command PS0
# compares them and prints one line on a change, then records again: once per
# change. ctime, since Syncthing keeps the sender's mtime; -L, since the files
# are links. PS0 calls the check by a function substitution (bash 5.3), which
# runs in this shell, so the new record persists; one stat a command, about
# 1.5 ms. Suite: tests/bashrc/run.sh.
if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] >= 503)); then
  _bashrc_stamp() { # into _BASHRC_NOW: ~/.bashrc, ~/.bash_profile, each module the loop sources
    local f files=(~/.bashrc ~/.bash_profile)
    for f in ~/.bashrc.d/*.sh; do
      [[ $f != *.sync-conflict-* && -f $f ]] && files+=("$f")
    done
    _BASHRC_NOW="$(stat -L -c '%i %.9Z' -- "${files[@]}" 2>/dev/null)"
  }
  _bashrc_arrivals() {
    _bashrc_stamp
    [[ $_BASHRC_NOW == "$_BASHRC_STAMP" ]] && return
    _BASHRC_STAMP=$_BASHRC_NOW
    printf '%s\n' "bash modules changed since this shell loaded them: run reload" >&2
  }
  _bashrc_stamp
  _BASHRC_STAMP=$_BASHRC_NOW
  [[ ${PS0-} == *_bashrc_arrivals* ]] || PS0+='${ _bashrc_arrivals; }'
fi

# Unsorted
