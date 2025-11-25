# --- Stow packages -> targets ---
declare -A STOW_TARGETS=(
  [alacritty]="$HOME/.config/alacritty"
  [bash]="$HOME"
  [latex]="$HOME/texmf/tex/latex"
  [nvim]="$HOME/.config/nvim"
  [sway]="$HOME/.config/sway"
  [waybar]="$HOME/.config/waybar"
  [wezterm]="$HOME"
)

# Stable run order (optional, but nicer output)
STOW_ORDER=(bash wezterm alacritty nvim sway waybar latex)

STOW_CFG_ROOT="$HOME/Desktop/configs"

stow-all-dry() { # preview (no changes)
  (
    set -Eeuo pipefail
    cd "$STOW_CFG_ROOT"
    for pkg in "${STOW_ORDER[@]}"; do
      [[ -d $pkg ]] || continue
      target=${STOW_TARGETS[$pkg]}
      mkdir -p "$target"
      echo "== $pkg -> $target =="
      stow -nv -t "$target" "$pkg" || true
      echo
    done
  )
}

stow-all() { # pull latest, then (re)stow everything
  (
    set -Eeuo pipefail
    cd "$STOW_CFG_ROOT"
    git pull --ff-only
    for pkg in "${STOW_ORDER[@]}"; do
      [[ -d $pkg ]] || continue
      target=${STOW_TARGETS[$pkg]}
      mkdir -p "$target"
      stow -Rvt "$target" "$pkg"
    done
  )
}

unstow-all() { # unlink everything managed by these packages
  (
    set -Eeuo pipefail
    cd "$STOW_CFG_ROOT"
    for pkg in "${STOW_ORDER[@]}"; do
      [[ -d $pkg ]] || continue
      target=${STOW_TARGETS[$pkg]}
      stow -Dvt "$target" "$pkg" || true
    done
  )
}
