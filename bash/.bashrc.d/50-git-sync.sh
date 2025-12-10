# --- Configure your repos here (must already be cloned) ---
REPOS_DESKTOP=(
  "$HOME/Desktop/org"
  "$HOME/Desktop/dissertation"
  "$HOME/Desktop/teaching"
  "$HOME/Desktop/bphopkins.net"
  "$HOME/Desktop/nousowl.net"
  "$HOME/Desktop/configs"
  "$HOME/Desktop/llemmma.github.io"
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
