# ~/.bashrc

# If not running interactively, do nothing
[[ $- != *i* ]] && return

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# Load modular configuration
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*.sh; do
    [ -f "$rc" ] && . "$rc"
  done
  unset rc
fi

# Unsorted
