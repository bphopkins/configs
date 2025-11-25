# 20-path.sh
# PATH, MANPATH, INFOPATH configuration
#
# Uses guards to prevent duplicate entries in nested shells.

# Personal binaries
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
  PATH="$HOME/bin:$PATH"
fi
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  PATH="$HOME/.local/bin:$PATH"
fi

# npm global binaries
if [[ ":$PATH:" != *":$HOME/.local/npm-global/bin:"* ]]; then
  PATH="$HOME/.local/npm-global/bin:$PATH"
fi

# Bun
export BUN_INSTALL="$HOME/.bun"
if [[ ":$PATH:" != *":$BUN_INSTALL/bin:"* ]]; then
  PATH="$BUN_INSTALL/bin:$PATH"
fi

# TeX Live
if [[ ":$PATH:" != *"/usr/local/texlive/2025/bin/x86_64-linux:"* ]]; then
  PATH="/usr/local/texlive/2025/bin/x86_64-linux:$PATH"
fi
if [[ ":$MANPATH:" != *"/usr/local/texlive/2025/texmf-dist/doc/man:"* ]]; then
  MANPATH="/usr/local/texlive/2025/texmf-dist/doc/man:$MANPATH"
fi
if [[ ":$INFOPATH:" != *"/usr/local/texlive/2025/texmf-dist/doc/info:"* ]]; then
  INFOPATH="/usr/local/texlive/2025/texmf-dist/doc/info:$INFOPATH"
fi

export PATH MANPATH INFOPATH
