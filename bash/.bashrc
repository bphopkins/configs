# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# ----- PATH tweaks (keep all PATH edits together) -----

# Ensure ~/.local/bin and ~/bin are at the front
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  PATH="$HOME/.local/bin:$PATH"
fi
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
  PATH="$HOME/bin:$PATH"
fi

# npm global binaries
PATH="$HOME/.local/npm-global/bin:$PATH"

# TeX Live
PATH="/usr/local/texlive/2025/bin/x86_64-linux:$PATH"
MANPATH="/usr/local/texlive/2025/texmf-dist/doc/man:$MANPATH"
INFOPATH="/usr/local/texlive/2025/texmf-dist/doc/info:$INFOPATH"

export PATH MANPATH INFOPATH

# ----- end PATH tweaks -----

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    [ -f "$rc" ] && . "$rc"
  done
fi
unset rc

[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ] && . "$HOME/.nix-profile/etc/profile.d/nix.sh"

alias sysupgrade='sudo dnf upgrade --refresh -y && sudo flatpak update --appstream -y && flatpak update --appstream -y'
alias tl-upgrade='sudo /usr/local/texlive/2025/bin/x86_64-linux/tlmgr update --self --all'
alias lsa='ls -a --group-directories-first'
alias dissertate='cd ~/Desktop/dissertation && nvim'
alias homepage='cd ~/Desktop/bphopkins.github.io && nvim'
alias home='cd ~ && lsa'
alias desktop='cd ~/Desktop && lsa'
alias configs='cd ~/Desktop/configs && lsa'

# --- Configure your repos here (must already be cloned) ---
REPOS_DESKTOP=(
  "$HOME/Desktop/dissertation"
  "$HOME/Desktop/bphopkins.github.io"
  "$HOME/Desktop/llemmma.github.io"
  "$HOME/Desktop/configs"
)

gpullall() {
  local repo name branch ok=0 skipped=0 failed=0
  echo "Pulling all repositories..."
  echo
  for repo in "${REPOS_DESKTOP[@]}"; do
    name="$(basename "$repo")"

    if [[ ! -d "$repo" ]]; then
      echo "[SKIP] $name: directory not found: $repo"
      ((skipped++))
      echo
      continue
    fi
    if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "[SKIP] $name: not a git repository"
      ((skipped++))
      echo
      continue
    fi

    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || printf %s HEAD)"
    if [[ "$branch" == "HEAD" ]]; then
      echo "[SKIP] $name: detached HEAD"
      ((skipped++))
      echo
      continue
    fi

    # Fetch refs/tags; set upstream to origin/<branch> if it exists and none set yet.
    if ! git -C "$repo" fetch --prune --tags >/dev/null 2>&1; then
      echo "[FAIL] $name: fetch failed"
      ((failed++))
      echo
      continue
    fi
    if ! git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
      if git -C "$repo" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
        git -C "$repo" branch -u "origin/$branch" "$branch" >/dev/null 2>&1 ||
          {
            echo "[FAIL] $name: could not set upstream"
            ((failed++))
            echo
            continue
          }
      else
        echo "[SKIP] $name: no upstream and origin/$branch not found"
        ((skipped++))
        echo
        continue
      fi
    fi

    echo "[PULL] $name on $branch"
    if git -C "$repo" pull --ff-only --recurse-submodules=on-demand; then
      if [[ -f "$repo/.gitmodules" ]]; then
        git -C "$repo" submodule update --init --recursive --jobs=4 >/dev/null 2>&1 ||
          echo "[WARN] $name: submodule update reported issues"
      fi
      ((ok++))
    else
      echo "[FAIL] $name: pull failed (non fast-forward or other issue)"
      ((failed++))
    fi
    echo
  done
  echo "Pull complete. updated: $ok  skipped: $skipped  failed: $failed"
  ((failed == 0))
}

# Auto-commit modified tracked files AND new untracked files (respecting .gitignore), then push.
# - Uses `git add -A` (adds untracked files except those ignored; stages deletions/renames).
# - Commit message includes date/time; can be overridden by passing an argument.
gpushall() {
  local repo name branch msg ok=0 skipped=0 failed=0 staged_count ahead
  msg="${1:-$(hostname): $(date '+%Y-%m-%d %H:%M:%S')}"

  echo "Auto-committing (tracked + untracked, ignoring .gitignore) and pushing all repositories..."
  echo
  for repo in "${REPOS_DESKTOP[@]}"; do
    name="$(basename "$repo")"

    if [[ ! -d "$repo" ]]; then
      echo "[SKIP] $name: directory not found: $repo"
      ((skipped++))
      echo
      continue
    fi
    if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "[SKIP] $name: not a git repository"
      ((skipped++))
      echo
      continue
    fi

    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || printf %s HEAD)"
    if [[ "$branch" == "HEAD" ]]; then
      echo "[SKIP] $name: detached HEAD"
      ((skipped++))
      echo
      continue
    fi

    # Stage all changes: tracked mods/deletes + new untracked files; respects .gitignore by default.
    if ! git -C "$repo" add -A; then
      echo "[FAIL] $name: git add -A failed"
      ((failed++))
      echo
      continue
    fi

    # Commit only if something is staged.
    if ! git -C "$repo" diff --cached --quiet; then
      staged_count="$(git -C "$repo" diff --cached --name-only | wc -l | tr -d '[:space:]')"
      if git -C "$repo" commit -m "$msg" >/dev/null 2>&1; then
        echo "[COMMIT] $name: committed $staged_count path(s)"
      else
        echo "[FAIL] $name: commit failed"
        ((failed++))
        echo
        continue
      fi
    else
      echo "[COMMIT] $name: nothing to commit"
    fi

    # Make sure we know the remote state and have/choose an upstream sensibly.
    if ! git -C "$repo" fetch --prune --tags >/dev/null 2>&1; then
      echo "[FAIL] $name: fetch failed"
      ((failed++))
      echo
      continue
    fi

    # If no upstream but origin/<branch> exists, track it so we can pull before pushing.
    if ! git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
      if git -C "$repo" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
        git -C "$repo" branch -u "origin/$branch" "$branch" >/dev/null 2>&1 ||
          {
            echo "[FAIL] $name: could not set upstream"
            ((failed++))
            echo
            continue
          }
      fi
    fi

    # Rebase to mimic VS Code's "Sync" behavior and avoid merge commits.
    if git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
      if ! git -C "$repo" pull --rebase=merges --recurse-submodules=on-demand; then
        echo "[FAIL] $name: pull --rebase failed (manual intervention required)"
        ((failed++))
        echo
        continue
      fi
    fi

    # First push sets upstream if still needed.
    if ! git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
      echo "[PUSH] $name: initial push to origin/$branch"
      if git -C "$repo" push -u origin "$branch" --follow-tags --recurse-submodules=on-demand; then
        ((ok++))
        echo
        continue
      else
        echo "[FAIL] $name: push failed"
        ((failed++))
        echo
        continue
      fi
    fi

    # If ahead, push; otherwise report up-to-date.
    ahead="$(git -C "$repo" rev-list --count @{u}..HEAD 2>/dev/null || echo 0)"
    if [[ "${ahead:-0}" -eq 0 ]]; then
      echo "[PUSH] $name: up to date (nothing to push)"
      ((ok++))
      echo
      continue
    fi

    echo "[PUSH] $name on $branch (ahead by $ahead)"
    if git -C "$repo" push --follow-tags --recurse-submodules=on-demand; then
      ((ok++))
    else
      echo "[FAIL] $name: push failed"
      ((failed++))
    fi
    echo
  done
  echo "Push complete. ok: $ok  skipped: $skipped  failed: $failed"
  ((failed == 0))
}

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
