# --- Daily multi-repo git sync ---------------------------------------------
# Modeled on VS Code's "Sync" (commit -> pull --rebase -> push), across every
# repo in REPOS_DESKTOP. The single-repo and all-repo commands share the same
# per-repo helpers, so their behavior cannot drift apart.
#
#   gpullall                pull every repo (ff-only)
#   gpushall [-m MSG]       stage + vet + commit + rebase + push every repo
#   gpull NAME...           pull one or more ~/Desktop repos by name
#   gpush [-m MSG] NAME...  stage + vet + commit + rebase + push by name
#   gstatall [-f]           one-line-per-repo status dashboard; -f fetches
#                           first for current counts (still read-only)
#
# Vetting: newly added paths (including rename targets and typechanges)
# larger than GSYNC_MAX_MB or matching GSYNC_SECRET_GLOBS get a y/N prompt
# before they are committed. A declined file (or any flagged file when stdin
# is not a tty) is unstaged, stays in the working tree, and will be flagged
# again on the next run. Committed new files are listed in the output so
# nothing enters a repo invisibly.

# --- Configure your repos here (must already be cloned) ---
REPOS_DESKTOP=(
  "$HOME/Desktop/org"
  "$HOME/Desktop/dissertation"
  "$HOME/Desktop/n-cube"
  "$HOME/Desktop/teaching"
  "$HOME/Desktop/bphopkins.net"
  "$HOME/Desktop/nousowl.net"
  "$HOME/Desktop/configs"
  "$HOME/Desktop/llemmma.github.io"
  "$HOME/Desktop/teach-logic"
  "$HOME/Desktop/dissertation-template"
  "$HOME/Desktop/opuscula"
  "$HOME/Desktop/sonnerie"
  "$HOME/Desktop/sylloge"
)

# Vet thresholds. GSYNC_MAX_MB may be overridden in the environment; the
# globs are matched against each new file's basename and repo-relative path.
: "${GSYNC_MAX_MB:=25}"
GSYNC_SECRET_GLOBS=(
  '*.pem' '*.key' '*.p12' '*.pfx' '*.kdbx'
  'id_rsa*' 'id_ed25519*' 'id_ecdsa*' 'id_dsa*'
  '.env' '.env.*' '*.env' '.netrc' '.npmrc' '.pypirc'
  '*credentials*' '*_token*' '*apikey*' '*api_key*'
)

_gsync_say() { # $1 = tag, rest = message; tag colorized on a tty
  local tag="$1" label color="" reset=""
  shift
  label="$tag"
  [[ "$tag" == OK ]] && label=" OK "
  if [[ -t 1 ]]; then
    case "$tag" in
      FAIL) color=$'\e[31m' ;;
      WARN | SKIP | PEND) color=$'\e[33m' ;;
      OK | PULL | SYNC) color=$'\e[32m' ;;
      HINT) color=$'\e[36m' ;;
    esac
    [[ -n "$color" ]] && reset=$'\e[0m'
  fi
  printf '%s[%s]%s %s\n' "$color" "$label" "$reset" "$*"
}

_gsync_detail() { # indent captured git output under its status line
  printf '%s\n' "$1" | sed 's/^/    /'
}

_gsync_in_progress() { # print the operation under way, if any; else return 1
  local repo="$1" g
  g="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  if [[ -d "$g/rebase-merge" || -d "$g/rebase-apply" ]]; then
    echo "rebase in progress"
  elif [[ -f "$g/MERGE_HEAD" ]]; then
    echo "merge in progress"
  elif [[ -f "$g/CHERRY_PICK_HEAD" ]]; then
    echo "cherry-pick in progress"
  elif [[ -f "$g/REVERT_HEAD" ]]; then
    echo "revert in progress"
  elif [[ -f "$g/BISECT_LOG" ]]; then
    echo "bisect in progress"
  else
    return 1
  fi
}

# Every remote is SSH to github.com, so one TCP probe of github.com:22 answers
# "can we fetch/push at all". Cached for the duration of the calling command.
_gsync_online() {
  if [[ -z "${_GSYNC_ONLINE_CACHE:-}" ]]; then
    if timeout 4 bash -c 'exec 3<>/dev/tcp/github.com/22' 2>/dev/null; then
      _GSYNC_ONLINE_CACHE=1
    else
      _GSYNC_ONLINE_CACHE=0
    fi
  fi
  [[ "$_GSYNC_ONLINE_CACHE" == 1 ]]
}

# Shared validation. Sets _GSYNC_BRANCH on success.
# Returns 0 ok / 1 fail / 2 skip (message already printed for 1/2).
_gsync_preflight() {
  local name="$1" repo="$2" state
  _GSYNC_BRANCH=""
  if [[ ! -d "$repo" ]]; then
    _gsync_say SKIP "$name: directory not found: $repo"
    return 2
  fi
  if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _gsync_say SKIP "$name: not a git repository"
    return 2
  fi
  # An unresolved merge would pass the detached-HEAD check below, and add -A
  # + commit would then commit conflict markers. Catch every in-progress op.
  if state="$(_gsync_in_progress "$repo")"; then
    _gsync_say FAIL "$name: $state — resolve or abort it, then re-run"
    return 1
  fi
  # Unborn branch (fresh init, no commits yet): rev-parse prints HEAD *and*
  # fails, which would corrupt the capture below — and there is nothing to
  # sync yet, so skip before any mutation can happen.
  if ! git -C "$repo" rev-parse --verify --quiet HEAD >/dev/null; then
    _gsync_say SKIP "$name: no commits yet"
    return 2
  fi
  _GSYNC_BRANCH="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)" || _GSYNC_BRANCH="HEAD"
  if [[ "$_GSYNC_BRANCH" == "HEAD" ]]; then
    _gsync_say SKIP "$name: detached HEAD"
    return 2
  fi
  if [[ "$_GSYNC_BRANCH" != main && "$_GSYNC_BRANCH" != master ]]; then
    _gsync_say WARN "$name: on branch '$_GSYNC_BRANCH' (not main) — syncing that branch"
  fi
}

# Ensure the branch has an upstream, adopting origin/<branch> if it exists
# (fetching first so the remote-tracking ref is present — the only path that
# still needs an explicit fetch; everywhere else the pull's own fetch serves).
# $4 = required|optional. Returns 0 upstream set / 1 fail / 2 no upstream.
_gsync_ensure_upstream() {
  local name="$1" repo="$2" branch="$3" mode="$4"
  git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 && return 0
  # Full ref, not --heads pattern: 'main' would suffix-match 'feature/main'.
  if git -C "$repo" ls-remote --exit-code origin "refs/heads/$branch" >/dev/null 2>&1; then
    git -C "$repo" fetch --prune --tags >/dev/null 2>&1
    if git -C "$repo" branch -u "origin/$branch" "$branch" >/dev/null 2>&1; then
      return 0
    fi
    _gsync_say FAIL "$name: could not set upstream"
    return 1
  fi
  if [[ "$mode" == required ]]; then
    _gsync_say SKIP "$name: no upstream and origin/$branch not found (or origin unreachable)"
  fi
  return 2
}

# Vet the newly added staged paths against the size and secrets guards;
# unstage any that are declined. Rename detection is disabled for the listing
# so a rename's target is vetted as the new path it is, and typechanges (T)
# are included so e.g. a symlink swapped for a real file still meets the size
# guard. Fills _GSYNC_NEW_FILES with the files that stay in the commit.
_gsync_vet_new_files() {
  local name="$1" repo="$2" f d reason glob size ans limit
  local new=() drop=()
  _GSYNC_NEW_FILES=()
  if [[ "$GSYNC_MAX_MB" =~ ^[0-9]+$ ]]; then
    limit=$((GSYNC_MAX_MB * 1024 * 1024))
  else
    _gsync_say WARN "GSYNC_MAX_MB='$GSYNC_MAX_MB' is not a number — using 25"
    limit=$((25 * 1024 * 1024))
  fi
  while IFS= read -r -d '' f; do new+=("$f"); done \
    < <(git -C "$repo" -c diff.renames=false diff --cached --name-only --diff-filter=AT -z)
  # Fail CLOSED: if the listing itself failed, nothing was vetted, so nothing
  # may be committed. (wait "$!" retrieves the process substitution's status.)
  if ! wait "$!"; then
    _gsync_say FAIL "$name: could not list staged files — refusing to commit unvetted"
    return 1
  fi
  ((${#new[@]})) || return 0
  for f in "${new[@]}"; do
    reason=""
    if [[ -e "$repo/$f/.git" ]]; then
      reason="embedded git repository (would sync as an empty pointer, not files)"
    else
      size="$(stat -c %s -- "$repo/$f" 2>/dev/null || echo 0)"
      if ((size > limit)); then
        reason="$((size / 1024 / 1024)) MB (guard: GSYNC_MAX_MB=$GSYNC_MAX_MB)"
      else
        for glob in "${GSYNC_SECRET_GLOBS[@]}"; do
          # shellcheck disable=SC2053  # unquoted RHS is deliberate: pattern
          # match; the slash-wrapped arm matches every path component.
          if [[ "$f" == $glob || "/$f/" == */$glob/* ]]; then
            reason="matches secrets pattern '$glob'"
            break
          fi
        done
      fi
    fi
    if [[ -z "$reason" ]]; then
      _GSYNC_NEW_FILES+=("$f")
      continue
    fi
    _gsync_say WARN "$name: new file '$f' — $reason"
    if [[ -t 0 ]]; then
      # If stdout is being captured, the WARN above is invisible — repeat the
      # context on stderr so the prompt is never answered blind.
      [[ -t 1 ]] || printf '[WARN] %s: new file %s — %s\n' "$name" "$f" "$reason" >&2
      read -r -p "        commit it? [y/N] " ans
      if [[ "$ans" == [yY]* ]]; then
        _GSYNC_NEW_FILES+=("$f")
        continue
      fi
    fi
    drop+=("$f")
  done
  if ((${#drop[@]})); then
    # :(literal) pathspecs: a name with glob characters or a leading ':' must
    # unstage exactly itself — nothing else, and never silently nothing.
    local specs=()
    for f in "${drop[@]}"; do specs+=(":(literal)$f"); done
    git -C "$repo" reset -q -- "${specs[@]}" 2>/dev/null
    # Verify the unstage took: a declined file still staged would be committed.
    while IFS= read -r -d '' f; do
      for d in "${drop[@]}"; do
        if [[ "$f" == "$d" ]]; then
          _gsync_say FAIL "$name: could not unstage declined file '$f' — refusing to commit"
          return 1
        fi
      done
    done < <(git -C "$repo" -c diff.renames=false diff --cached --name-only --diff-filter=AT -z)
    if ! wait "$!"; then
      _gsync_say FAIL "$name: could not re-check staged files — refusing to commit"
      return 1
    fi
    _gsync_say WARN "$name: left uncommitted: ${drop[*]}"
  fi
  return 0
}

# After a configs pull/rebase moved HEAD, surface the follow-ups the sync
# itself can't do: stow-all iterates the arrays already loaded in this shell,
# so a pulled-in package addition is skipped silently until a re-source.
# Parsed NUL-delimited: core.quotePath (default on) C-quotes non-ASCII names
# in plain output, which would defeat the path matching below.
_gsync_pull_hints() {
  local name="$1" repo="$2" old="$3" st p q i bash_hit=0
  [[ "$name" == configs ]] || return 0
  local toks=()
  while IFS= read -r -d '' p; do toks+=("$p"); done \
    < <(git -C "$repo" diff --name-status -z "$old" HEAD 2>/dev/null)
  ((${#toks[@]})) || return 0
  local -A is_pkg=() pkg_hit=()
  if declare -p STOW_ORDER >/dev/null 2>&1; then
    for p in "${STOW_ORDER[@]}"; do is_pkg[$p]=1; done
  fi
  i=0
  while ((i < ${#toks[@]})); do
    st="${toks[i]}"
    p="${toks[i + 1]:-}"
    q=""
    if [[ "$st" == [RC]* ]]; then # renames/copies carry two paths
      q="${toks[i + 2]:-}"
      i=$((i + 3))
    else
      i=$((i + 2))
    fi
    for p in "$p" "$q"; do
      [[ -n "$p" ]] || continue
      [[ "$p" == bash/* ]] && bash_hit=1 # any change to bash/ needs a re-source
      # adds/deletes/renames/typechanges inside a stow package need a restow
      case "$st" in
        A* | C* | D | R* | T) ;;
        *) continue ;;
      esac
      [[ "$p" == */* ]] || continue
      [[ -n "${is_pkg[${p%%/*}]:-}" ]] && pkg_hit[${p%%/*}]=1
    done
  done
  if ((bash_hit)); then
    _gsync_say HINT "configs: bash files changed — run: source ~/.bashrc"
  fi
  if ((${#pkg_hit[@]})); then
    _gsync_say HINT "configs: files added/removed in stow package(s): ${!pkg_hit[*]} — run: stow-all (re-source first)"
  fi
}

# Per-repo pull (ff-only). Returns 0 ok / 1 fail / 2 skip.
_gsync_pull_repo() {
  local name="$1" repo="$2" branch old out ahead
  local _GSYNC_BRANCH
  _gsync_preflight "$name" "$repo" || return $?
  branch="$_GSYNC_BRANCH"
  if ! _gsync_online; then
    _gsync_say SKIP "$name: offline"
    return 2
  fi
  _gsync_ensure_upstream "$name" "$repo" "$branch" required || return $?
  old="$(git -C "$repo" rev-parse HEAD)"
  # No --tags: tags on fetched history auto-follow, and an explicit --tags
  # makes one force-moved remote tag wedge every future pull of the repo.
  if ! out="$(git -C "$repo" -c fetch.prune=true pull --ff-only --recurse-submodules=on-demand 2>&1)"; then
    ahead="$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
    if [[ "$out" == *[Ff]ast-forward* && "${ahead:-0}" -gt 0 ]]; then
      _gsync_say FAIL "$name: diverged — $ahead local unpushed commit(s) vs origin; run: gpush $name (it rebases)"
    else
      _gsync_say FAIL "$name: pull failed:"
      _gsync_detail "$out"
    fi
    return 1
  fi
  if [[ "$(git -C "$repo" rev-parse HEAD)" == "$old" ]]; then
    _gsync_say OK "$name: up to date"
  else
    _gsync_say PULL "$name: updated"
    _gsync_detail "$out"
    if [[ -f "$repo/.gitmodules" ]]; then
      git -C "$repo" submodule update --init --recursive --jobs=4 >/dev/null 2>&1 ||
        _gsync_say WARN "$name: submodule update reported issues"
    fi
    _gsync_pull_hints "$name" "$repo" "$old"
  fi
  # The pull just fetched, so this count is current: surface unpushed work so
  # "up to date" can never be mistaken for "in sync with origin".
  ahead="$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  if [[ "${ahead:-0}" -gt 0 ]]; then
    _gsync_say WARN "$name: ahead by $ahead unpushed commit(s) — push when ready"
  fi
}

# Per-repo push: stage -> vet -> commit -> rebase-pull -> push.
# Returns 0 ok / 1 fail / 2 skip / 3 committed, push pending (offline).
_gsync_push_repo() {
  local name="$1" repo="$2" msg="$3"
  local branch committed=0 staged_count=0 new_note="" out ahead have_up prepull integrated=0
  local _GSYNC_BRANCH _GSYNC_NEW_FILES=()
  _gsync_preflight "$name" "$repo" || return $?
  branch="$_GSYNC_BRANCH"

  if ! git -C "$repo" add -A; then
    _gsync_say FAIL "$name: git add -A failed"
    return 1
  fi
  _gsync_vet_new_files "$name" "$repo" || return 1

  if ! git -C "$repo" diff --cached --quiet; then
    staged_count="$(git -C "$repo" diff --cached --name-only | wc -l | tr -d '[:space:]')"
    if ! out="$(git -C "$repo" commit -m "$msg" 2>&1)"; then
      _gsync_say FAIL "$name: commit failed:"
      _gsync_detail "$out"
      return 1
    fi
    committed=1
    if ((${#_GSYNC_NEW_FILES[@]})); then
      local shown=("${_GSYNC_NEW_FILES[@]:0:12}") extra=$((${#_GSYNC_NEW_FILES[@]} - 12))
      printf -v new_note '%s, ' "${shown[@]}"
      new_note="${new_note%, }"
      ((extra > 0)) && new_note+=" +$extra more"
    fi
  fi

  # Offline: the commit above still landed; report the push as pending.
  if ! _gsync_online; then
    if ((committed)); then
      _gsync_say PEND "$name: committed $staged_count path(s); push pending (offline)"
      [[ -n "$new_note" ]] && printf '        new: %s\n' "$new_note"
      return 3
    fi
    # No upstream means never pushed — "0 ahead" would misreport that.
    if ! git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
      _gsync_say PEND "$name: no upstream yet — initial push pending (offline)"
      return 3
    fi
    ahead="$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
    if [[ "${ahead:-0}" -gt 0 ]]; then
      _gsync_say PEND "$name: $ahead unpushed commit(s); push pending (offline)"
      return 3
    fi
    _gsync_say OK "$name: nothing to push (offline)"
    return 0
  fi

  _gsync_ensure_upstream "$name" "$repo" "$branch" optional
  case $? in
    0) have_up=1 ;;
    2) have_up=0 ;;
    *) return 1 ;;
  esac

  if ((have_up == 0)); then
    if out="$(git -C "$repo" push -u origin "$branch" --follow-tags --recurse-submodules=on-demand 2>&1)"; then
      if ((committed)); then
        _gsync_say SYNC "$name: initial push to origin/$branch — committed $staged_count path(s)"
        if [[ -n "$new_note" ]]; then
          printf '        new: %s\n' "$new_note"
        fi
      else
        _gsync_say SYNC "$name: initial push to origin/$branch"
      fi
      return 0
    fi
    _gsync_say FAIL "$name: initial push failed:"
    _gsync_detail "$out"
    return 1
  fi

  # Rebase onto the remote, VS Code Sync style. On conflict, abort so no batch
  # command ever leaves a repo mid-rebase; the commit stays intact locally.
  # (No --tags on the fetch — see the pull helper.)
  prepull="$(git -C "$repo" rev-parse HEAD)"
  if ! out="$(git -C "$repo" -c fetch.prune=true pull --rebase=merges --recurse-submodules=on-demand 2>&1)"; then
    if [[ "$(_gsync_in_progress "$repo")" == rebase* ]]; then
      if git -C "$repo" rebase --abort >/dev/null 2>&1; then
        _gsync_say FAIL "$name: rebase conflict with origin/$branch — aborted; your commit is intact locally. Sync manually: git -C ~/Desktop/$name pull --rebase=merges"
      else
        _gsync_say FAIL "$name: rebase conflict AND the abort failed — repo left mid-rebase; inspect: git -C ~/Desktop/$name status"
      fi
    else
      _gsync_say FAIL "$name: pull --rebase failed:"
      _gsync_detail "$out"
    fi
    return 1
  fi
  # The rebase-pull may have integrated remote commits (fast-forward when we
  # had nothing local). Report it and fire the configs hints — this must not
  # be silent for someone whose only daily command is gpushall.
  if [[ "$(git -C "$repo" rev-parse HEAD)" != "$prepull" ]]; then
    integrated=1
    _gsync_say PULL "$name: integrated changes from origin"
    _gsync_pull_hints "$name" "$repo" "$prepull"
  fi

  ahead="$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  if [[ "${ahead:-0}" -eq 0 ]]; then
    ((integrated)) || _gsync_say OK "$name: up to date"
    return 0
  fi

  if ! out="$(git -C "$repo" push --follow-tags --recurse-submodules=on-demand 2>&1)"; then
    _gsync_say FAIL "$name: push failed:"
    _gsync_detail "$out"
    return 1
  fi
  if ((committed)); then
    _gsync_say SYNC "$name: committed $staged_count path(s); pushed"
    if [[ -n "$new_note" ]]; then
      printf '        new: %s\n' "$new_note"
    fi
  else
    _gsync_say SYNC "$name: pushed $ahead commit(s)"
  fi
  return 0
}

gpull() {
  local name failed=0
  local _GSYNC_ONLINE_CACHE=""
  if (($# == 0)); then
    echo "Usage: gpull NAME...   (repos under ~/Desktop)"
    return 1
  fi
  for name in "$@"; do
    _gsync_pull_repo "$name" "$HOME/Desktop/$name" || ((failed += 1))
  done
  ((failed == 0))
}

gpush() {
  local msg="" names=() name rc failed=0
  local _GSYNC_ONLINE_CACHE=""
  while (($#)); do
    case "$1" in
      -m)
        if (($# < 2)); then
          echo "Usage: gpush [-m MSG] NAME..."
          return 1
        fi
        msg="$2"
        shift
        ;;
      *) names+=("$1") ;;
    esac
    shift
  done
  if ((${#names[@]} == 0)); then
    echo "Usage: gpush [-m MSG] NAME..."
    return 1
  fi
  [[ -n "$msg" ]] || msg="$(hostname): $(date '+%Y-%m-%d %H:%M:%S')"
  for name in "${names[@]}"; do
    _gsync_push_repo "$name" "$HOME/Desktop/$name" "$msg"
    rc=$?
    # For an explicitly named repo even a skip is a failure; a pending
    # offline push (3) is the one benign nonzero outcome.
    ((rc != 0 && rc != 3)) && ((failed += 1))
  done
  ((failed == 0))
}

gpullall() {
  local repo name ok=0 skipped=0 failed=0
  local fail_list=() skip_list=()
  local _GSYNC_ONLINE_CACHE=""
  if ! _gsync_online; then
    _gsync_say WARN "offline — nothing pulled"
    return 1
  fi
  echo "Pulling ${#REPOS_DESKTOP[@]} repositories..."
  for repo in "${REPOS_DESKTOP[@]}"; do
    name="$(basename "$repo")"
    _gsync_pull_repo "$name" "$repo"
    case $? in
      0) ((ok += 1)) ;;
      2)
        ((skipped += 1))
        skip_list+=("$name")
        ;;
      *)
        ((failed += 1))
        fail_list+=("$name")
        ;;
    esac
  done
  echo
  echo "Pull complete. ok: $ok  skipped: $skipped  failed: $failed"
  ((${#skip_list[@]})) && _gsync_say SKIP "skipped: ${skip_list[*]}"
  ((${#fail_list[@]})) && _gsync_say FAIL "needs attention: ${fail_list[*]}"
  ((failed == 0))
}

gpushall() {
  local msg="" repo name ok=0 skipped=0 failed=0 pending=0
  local fail_list=() skip_list=() pend_list=()
  local _GSYNC_ONLINE_CACHE=""
  if [[ "${1:-}" == "-m" ]]; then
    if [[ -z "${2:-}" ]]; then
      echo "Usage: gpushall [-m MSG]"
      return 1
    fi
    msg="$2"
  elif [[ "${1:-}" == -* ]]; then
    # Refuse unknown flags: 'gpushall -f' must not commit 13 repos with the
    # literal message '-f' (the dashboard flag belongs to gstatall).
    echo "Usage: gpushall [-m MSG]   (for the dashboard, use gstatall -f)"
    return 1
  elif (($# > 0)); then
    msg="$*" # legacy positional message — all words, not just the first
  fi
  [[ -n "$msg" ]] || msg="$(hostname): $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Committing and pushing ${#REPOS_DESKTOP[@]} repositories..."
  for repo in "${REPOS_DESKTOP[@]}"; do
    name="$(basename "$repo")"
    _gsync_push_repo "$name" "$repo" "$msg"
    case $? in
      0) ((ok += 1)) ;;
      2)
        ((skipped += 1))
        skip_list+=("$name")
        ;;
      3)
        ((pending += 1))
        pend_list+=("$name")
        ;;
      *)
        ((failed += 1))
        fail_list+=("$name")
        ;;
    esac
  done
  echo
  echo "Push complete. ok: $ok  skipped: $skipped  failed: $failed  pending: $pending"
  ((${#skip_list[@]})) && _gsync_say SKIP "skipped: ${skip_list[*]}"
  ((${#pend_list[@]})) && _gsync_say PEND "push pending (offline): ${pend_list[*]} — re-run gpushall when online"
  ((${#fail_list[@]})) && _gsync_say FAIL "needs attention: ${fail_list[*]}"
  ((failed == 0))
}

gstatall() { # read-only dashboard; -f/--fetch refreshes BEHIND/AHEAD from origin first
  local repo name branch dirty behind ahead state parts fetch=0 fetch_fail
  local _GSYNC_ONLINE_CACHE=""
  if [[ "${1:-}" == "-f" || "${1:-}" == "--fetch" ]]; then
    fetch=1
    if ! _gsync_online; then
      _gsync_say WARN "offline — showing counts vs the last fetch instead"
      fetch=0
    fi
  fi
  printf '%-22s %-10s %6s %7s %6s  %s\n' "REPO" "BRANCH" "DIRTY" "BEHIND" "AHEAD" "STATE"
  for repo in "${REPOS_DESKTOP[@]}"; do
    name="$(basename "$repo")"
    if [[ ! -d "$repo" ]] || ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf '%-22s %s\n' "$name" "-- missing or not a repo --"
      continue
    fi
    fetch_fail=0
    if ((fetch)); then
      git -C "$repo" fetch --prune --tags >/dev/null 2>&1 || fetch_fail=1
    fi
    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
    # -uall enumerates files inside untracked directories, so DIRTY equals
    # the number of paths gpushall would commit (a pending rename counts as
    # two paths here and one in the commit — the lone exception).
    dirty="$(git -C "$repo" status --porcelain -uall 2>/dev/null | wc -l | tr -d '[:space:]')"
    behind="-"
    ahead="-"
    if git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
      read -r behind ahead < <(git -C "$repo" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
      [[ -n "$behind" ]] || behind="-"
      [[ -n "$ahead" ]] || ahead="-"
    fi
    # STATE composes every applicable verdict; the numbers are the detail.
    parts=()
    state="$(_gsync_in_progress "$repo" || true)"
    [[ -n "$state" ]] && parts+=("$state")
    ((fetch_fail)) && parts+=("fetch failed")
    ((dirty > 0)) && parts+=("uncommitted")
    if [[ "$behind" != - && "$ahead" != - ]]; then
      if ((behind > 0 && ahead > 0)); then
        parts+=("DIVERGED")
      elif ((ahead > 0)); then
        parts+=("needs push")
      elif ((behind > 0)); then
        parts+=("needs pull")
      fi
    fi
    if ((${#parts[@]})); then
      printf -v state '%s; ' "${parts[@]}"
      state="${state%; }"
    else
      state="-"
    fi
    printf '%-22s %-10s %6s %7s %6s  %s\n' "$name" "$branch" "$dirty" "$behind" "$ahead" "$state"
  done
  if ((fetch)); then
    echo "(fetched — BEHIND/AHEAD are current vs origin; nothing was pulled or pushed)"
  else
    echo "(local view — BEHIND/AHEAD are vs the last fetch; gstatall -f refreshes them)"
  fi
}

_gsync_complete() { # tab-complete repo names for gpull/gpush
  local cur="${COMP_WORDS[COMP_CWORD]}" names=() r
  for r in "${REPOS_DESKTOP[@]}"; do names+=("$(basename "$r")"); done
  mapfile -t COMPREPLY < <(compgen -W "${names[*]}" -- "$cur")
}
complete -F _gsync_complete gpull gpush
