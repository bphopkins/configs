# 20-path.sh
# PATH, MANPATH, INFOPATH configuration
#
# Uses guards to prevent duplicate entries in nested shells.
#
# Sourced twice by design (2026-09-23): from ~/.bash_profile for login shells,
# including the one GDM starts -- which is how the graphical session and every
# desktop-launched app get this PATH, in this order -- and from ~/.bashrc for
# interactive ones, where the guards make it a no-op over the inherited result.
# This file is PATH's one author: no environment.d drop-in sets PATH
# (configs/DECISIONS.md, 2026-09-23), and tests/env/run.sh pins the outcome.

# Personal binaries
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
  PATH="$HOME/bin:$PATH"
fi
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  PATH="$HOME/.local/bin:$PATH"
fi

# npm global binaries
#
# Unguarded on purpose (settled 2026-09-21): `npm install -g` is used, and
# npm's global prefix is ~/.local/npm-global, so this directory exists and a
# guard like bun's below would be a no-op.
if [[ ":$PATH:" != *":$HOME/.local/npm-global/bin:"* ]]; then
  PATH="$HOME/.local/npm-global/bin:$PATH"
fi

# Bun
#
# Guarded on the directory existing: bun is not currently installed on either
# machine, and an unconditional prepend puts a nonexistent directory at the front
# of PATH, which every command lookup then has to stat past. Reinstalling bun
# makes this live again with no edit here.
if [[ -d "$HOME/.bun/bin" ]]; then
  export BUN_INSTALL="$HOME/.bun"
  if [[ ":$PATH:" != *":$BUN_INSTALL/bin:"* ]]; then
    PATH="$BUN_INSTALL/bin:$PATH"
  fi
fi

# TeX Live
#
# The release year is discovered, not hardcoded, so a parallel install
# (2025 -> 2026 -> ...) needs no edit here.
#
# Selection rule: the newest release that actually has working binaries. That
# qualifier matters -- during a parallel install the new year's directory
# exists for a long while before tlmgr appears in it, and naively taking the
# newest directory would drop TeX Live out of PATH entirely mid-install.
#
# To pin an older release, export TEXLIVE_YEAR before this file loads. This is
# how the forall x textbook is still built: it depends on tabu, which broke
# against the rewritten array.sty in TL2026.
#     TEXLIVE_YEAR=2025 bash -l
_tl_root="/usr/local/texlive"
_tl_bin=""
_tl_year=""
# Glob expands in ascending order, so the last qualifying match is the newest.
for _tl_d in "$_tl_root"/[0-9][0-9][0-9][0-9]/; do
  _tl_y="$(basename "$_tl_d")"
  if [[ -n "${TEXLIVE_YEAR:-}" && "$_tl_y" != "$TEXLIVE_YEAR" ]]; then
    continue
  fi
  # Resolve the platform subdirectory rather than assuming x86_64-linux, and
  # require a real tlmgr so half-installed trees are skipped.
  for _tl_p in "$_tl_root/$_tl_y/bin"/*/; do
    if [[ -x "$_tl_p/tlmgr" ]]; then
      _tl_bin="${_tl_p%/}"
      _tl_year="$_tl_y"
    fi
  done
done

if [[ -n "$_tl_bin" ]]; then
  if [[ ":$PATH:" != *":$_tl_bin:"* ]]; then
    PATH="$_tl_bin:$PATH"
  fi
  _tl_man="$_tl_root/$_tl_year/texmf-dist/doc/man"
  if [[ ":$MANPATH:" != *":$_tl_man:"* ]]; then
    MANPATH="$_tl_man:$MANPATH"
  fi
  # INFOPATH is the TeX Live Guide's own line, kept although `info` itself is
  # deliberately not installed (settled 2026-09-21): the line costs nothing,
  # .info files are plain text, and every manual here but the Asymptote FAQ
  # also ships as PDF or HTML under texmf-dist/doc.
  _tl_info="$_tl_root/$_tl_year/texmf-dist/doc/info"
  if [[ ":$INFOPATH:" != *":$_tl_info:"* ]]; then
    INFOPATH="$_tl_info:$INFOPATH"
  fi
elif [[ -n "${TEXLIVE_YEAR:-}" && $- == *i* ]]; then
  # Fires only when a pin was explicitly requested and could not be honoured,
  # so normal shell startup stays silent. Without it the pin fails *quietly*:
  # nothing is added to PATH and commands fall through to the /usr/local/bin
  # symlinks, which point at whichever release was last activated -- i.e. you
  # silently get the wrong year, which defeats the purpose of pinning.
  # Interactive-only so non-interactive shells (scp, rsync, ssh commands)
  # never see unexpected output on stderr.
  printf 'warning: TEXLIVE_YEAR=%s pinned, but no such install under %s -- pin ignored\n' \
         "$TEXLIVE_YEAR" "$_tl_root" >&2
fi
unset _tl_root _tl_bin _tl_year _tl_man _tl_info _tl_d _tl_y _tl_p

export PATH MANPATH INFOPATH
