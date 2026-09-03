# --- Stow packages -> targets ---
declare -A STOW_TARGETS=(
  [alacritty]="$HOME/.config/alacritty"
  [bash]="$HOME"
  [ghostty]="$HOME/.config/ghostty"
  [bin]="$HOME/bin"
  [latex]="$HOME/texmf/tex/latex"
  [mako]="$HOME/.config/mako"
  [nvim]="$HOME/.config/nvim"
  # okular ships a single file that lives directly in ~/.config, so the target is
  # ~/.config itself rather than a subdirectory. Stow only links what the package
  # contains, so this does not put ~/.config under stow's control generally.
  [okular]="$HOME/.config"
  [sway]="$HOME/.config/sway"
  [swaylock]="$HOME/.config/swaylock"
  [waybar]="$HOME/.config/waybar"
  [wofi]="$HOME/.config/wofi"
  [wezterm]="$HOME"
)

# Stable run order (optional, but nicer output)
STOW_ORDER=(bash wezterm ghostty alacritty nvim sway swaylock waybar mako wofi latex bin okular)

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
