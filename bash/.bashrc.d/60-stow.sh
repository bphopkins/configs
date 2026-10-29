# --- Stow packages -> targets ---
# A systemd drop-in or .wants dir must be a real directory: systemd 259 skips
# one that is a relative symlink, which is what stow's folding makes of a new
# subdirectory (src/shared/unit-file.c; measured 2026-09-30). Target such a
# dir itself, as environment.d does.
# -g: the commands below source this file again from inside a function, where
# a plain declare would make the array local to it.
declare -gA STOW_TARGETS=(
  [alacritty]="$HOME/.config/alacritty"
  [bash]="$HOME"
  # systemd's user-session drop-ins; the generator reads only this directory
  # (org/machines/environment.md, section 5), and the symlinks stow makes.
  [environment.d]="$HOME/.config/environment.d"
  [fontconfig]="$HOME/.config/fontconfig"
  [git]="$HOME/.config/git"
  [ghostty]="$HOME/.config/ghostty"
  [bin]="$HOME/bin"
  [latex]="$HOME/texmf/tex/latex"
  [mako]="$HOME/.config/mako"
  [nvim]="$HOME/.config/nvim"
  [rofi]="$HOME/.config/rofi"
  # okular ships a single file that lives directly in ~/.config, so the target is
  # ~/.config itself rather than a subdirectory. Stow only links what the package
  # contains, so this does not put ~/.config under stow's control generally.
  [okular]="$HOME/.config"
  [sway]="$HOME/.config/sway"
  [swaylock]="$HOME/.config/swaylock"
  [tmux]="$HOME/.config/tmux"
  [waybar]="$HOME/.config/waybar"
  [wofi]="$HOME/.config/wofi"
  [wezterm]="$HOME"
)

# Stable run order (optional, but nicer output)
STOW_ORDER=(bash git wezterm ghostty alacritty tmux nvim sway swaylock waybar mako wofi rofi latex bin okular fontconfig environment.d)

STOW_CFG_ROOT="$HOME/Desktop/configs"

# The three commands below act on the checkout as it is on disk, and fetch
# nothing (2026-10-26; org/machines/transport-2026-10/rules.md -> ws-8). The
# pull stow-all used to start with is gone on both machines: configs arrives
# by Syncthing since the cutover of 2026-10-28 (before it gpullall pulled it
# and printed the restow hint). Each re-reads the two arrays above from this file
# on disk, in its own subshell, before it iterates, so a package an arrival
# adds or removes is stowed or unlinked by a shell that loaded the old file:
# the re-source this used to need is gone with it. A file that does not parse
# stows nothing. Suite: tests/stow/run.sh.
_stow_reread() { # in the caller's subshell: the arrays from 60-stow.sh on disk
  local f="$STOW_CFG_ROOT/bash/.bashrc.d/60-stow.sh"
  if [[ ! -r "$f" ]] || ! bash -n "$f" 2>/dev/null; then
    echo "stow: $f is missing or does not parse -- nothing stowed; read it, then run the command again" >&2
    return 1
  fi
  # shellcheck source=/dev/null
  source "$f" || return 1
}

# A package whose directory has left the checkout cannot be unstowed (stow -D
# needs the package), so its links would dangle (the battery's S1, measured
# 2026-10-09). After stowing, every target the arrays name -- as read from
# disk, and as this shell loaded them -- is walked three levels deep, and each
# link that dangles into a directory of the checkout that is gone is removed.
# No package name is needed, so a shell opened after the arrival, whose arrays
# never named the package, sweeps it too: a target of its own, such as
# ~/.config/mako, lies within ~/.config, okular's (found 2026-10-26 at step
# 5a's review). Nothing else is touched: a link that resolves, a file, a link
# out of the checkout, a link into a directory still there (a package's stale
# links are stow -R's own). ~/Desktop is pruned, being no stow target and a
# synced tree. A link deeper than three levels is the gauge's to name
# (sync-check config). $1 = rm, or -n for the dry run; $2 = the name of the
# caller's copy of the arrays this shell loaded.
_stow_sweep() { # _stow_sweep rm|-n LOADED_ARRAY_NAME, after _stow_reread
  local mode="$1" root l to top t
  local -n _loaded="$2"
  local -A walk=() seen=()
  root="$(realpath -m -- "$STOW_CFG_ROOT")"
  for t in "${STOW_TARGETS[@]}" "${_loaded[@]}"; do [[ -d "$t" ]] && walk[$t]=1; done
  while IFS= read -r -d '' l; do
    [[ -n "${seen[$l]:-}" ]] && continue
    seen[$l]=1
    [[ -e "$l" ]] && continue
    to="$(readlink -- "$l")" || continue
    [[ "$to" == /* ]] || to="${l%/*}/$to"
    to="$(realpath -m -- "$to")"
    [[ "$to" == "$root"/*/* ]] || continue
    top="${to#"$root"/}"
    top="${top%%/*}"
    [[ -d "$root/$top" ]] && continue
    if [[ "$mode" == rm ]]; then
      rm -f -- "$l" && echo "UNLINK: $l (package $top is gone from the checkout)"
    else
      echo "UNLINK: $l (package $top is gone from the checkout)"
    fi
  done < <(for t in "${!walk[@]}"; do
    find "$t" -xdev -maxdepth 3 -path "$HOME/Desktop" -prune -o -type l -xtype l -print0 2>/dev/null
  done)
}

stow-all-dry() { # preview (no changes)
  (
    set -Eeuo pipefail
    declare -A was=()
    for pkg in "${!STOW_TARGETS[@]}"; do was[$pkg]=${STOW_TARGETS[$pkg]}; done
    _stow_reread
    cd "$STOW_CFG_ROOT"
    for pkg in "${STOW_ORDER[@]}"; do
      [[ -d $pkg ]] || continue
      target=${STOW_TARGETS[$pkg]}
      mkdir -p "$target"
      echo "== $pkg -> $target =="
      stow -nv -t "$target" "$pkg" || true
      echo
    done
    _stow_sweep -n was
  )
}

stow-all() { # (re)stow everything, as the checkout is on disk
  (
    set -Eeuo pipefail
    declare -A was=()
    for pkg in "${!STOW_TARGETS[@]}"; do was[$pkg]=${STOW_TARGETS[$pkg]}; done
    _stow_reread
    cd "$STOW_CFG_ROOT"
    for pkg in "${STOW_ORDER[@]}"; do
      [[ -d $pkg ]] || continue
      target=${STOW_TARGETS[$pkg]}
      mkdir -p "$target"
      stow -Rvt "$target" "$pkg"
    done
    _stow_sweep rm was
  )
}

unstow-all() { # unlink everything managed by these packages
  (
    set -Eeuo pipefail
    _stow_reread
    cd "$STOW_CFG_ROOT"
    for pkg in "${STOW_ORDER[@]}"; do
      [[ -d $pkg ]] || continue
      target=${STOW_TARGETS[$pkg]}
      stow -Dvt "$target" "$pkg" || true
    done
  )
}
