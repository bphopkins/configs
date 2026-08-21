#!/usr/bin/env bash
#
# claude-collect.sh — gather every machine-local Claude Code file into a
# timestamped payload on this flash drive, so two machines can be merged
# from one place.
#
#   Run on EACH machine:  bash /run/media/bph/bph-work/claude-collect.sh
#   Writes to:            <flash>/claude-migration/<host>-<YYYYmmdd-HHMMSS>/
#
# Read-only with respect to the machine. Nothing outside the flash drive is
# created, modified, or deleted. Safe to run more than once: every run gets
# its own timestamped directory.
#
# The flash drive is located relative to this script, so it works from
# whatever mount point the drive happens to get.

set -uo pipefail

# ---------------------------------------------------------------- locate ----
SELF=$(readlink -f "$0" 2>/dev/null || echo "$0")
FLASH=$(dirname "$SELF")
HOST=$(hostname -s 2>/dev/null || echo unknown)
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$FLASH/claude-migration/$HOST-$STAMP"
PAY="$OUT/payload"
MAN="$OUT/MANIFEST.tsv"
INV="$OUT/INVENTORY.txt"

if ! mkdir -p "$PAY" 2>/dev/null; then
  echo "FATAL: cannot write to $OUT" >&2
  echo "       Is the flash drive mounted read-write?" >&2
  exit 1
fi

printf 'size\tmtime\tsha256\tpath\n' > "$MAN"

copied=0 skipped=0
SKIPLOG=$(mktemp)
trap 'rm -f "$SKIPLOG"' EXIT

# record <abs-src> <rel-dest> — copy one file, note it in the manifest
record() {
  local src=$1 rel=$2 dst
  [ -f "$src" ] || return 1
  dst="$PAY/$rel"
  mkdir -p "$(dirname "$dst")" 2>/dev/null
  if cp --preserve=timestamps "$src" "$dst" 2>/dev/null || cp "$src" "$dst" 2>/dev/null; then
    printf '%s\t%s\t%s\t%s\n' \
      "$(stat -c%s "$src" 2>/dev/null || echo 0)" \
      "$(stat -c%y "$src" 2>/dev/null | cut -d. -f1)" \
      "$(sha256sum "$src" 2>/dev/null | cut -c1-16)" \
      "$rel" >> "$MAN"
    copied=$((copied+1)); return 0
  fi
  echo "  copy failed: $src" >> "$SKIPLOG"; skipped=$((skipped+1)); return 1
}

# record_tree <abs-src-dir> <rel-dest-dir> — every regular file beneath it
record_tree() {
  local src=$1 rel=$2 f r
  [ -d "$src" ] || return 1
  while IFS= read -r -d '' f; do
    r=${f#"$src"/}
    record "$f" "$rel/$r"
  done < <(find "$src" -type f -print0 2>/dev/null)
}

echo "claude-collect — $HOST — $STAMP"
echo "  writing to $OUT"
echo

# ------------------------------------------------------- 1. user config ----
# Everything in ~/.claude that is authored config or durable content.
# Deliberately NOT collected (runtime state, regenerable, or huge):
#   projects/*.jsonl  history.jsonl  file-history/  sessions/  session-env/
#   shell-snapshots/  paste-cache/  backups/  cache/  debug/  ide/  downloads/
#   tasks/  jobs/  daemon/  daemon.log  stats-cache.json  plugins/marketplaces/
# Also skipped on purpose: .credentials.json (a live OAuth token; there is
# already a copy of it at the flash root, and a second one helps nobody).
CC="$HOME/.claude"
echo "== user config (~/.claude) =="
for f in CLAUDE.md CLAUDE.local.md settings.json settings.local.json \
         keybindings.json statusline.sh .last-update-result.json; do
  record "$CC/$f" "user/$f" && echo "  + $f"
done
for d in agents commands skills hooks output-styles rules workflows plans; do
  if [ -d "$CC/$d" ] && [ -n "$(ls -A "$CC/$d" 2>/dev/null)" ]; then
    record_tree "$CC/$d" "user/$d" && echo "  + $d/  ($(find "$CC/$d" -type f | wc -l) files)"
  fi
done
for f in plugins/known_marketplaces.json plugins/blocklist.json; do
  record "$CC/$f" "user/$f" && echo "  + $f"
done
echo

# ------------------------------------------------------------ 2. memory ----
# ~/.claude/projects/<mangled-cwd>/memory/ — the durable content. Transcript
# .jsonl files sitting beside them are NOT collected.
echo "== memory =="
mem_files=0 mem_scopes=0
if [ -d "$CC/projects" ]; then
  for scope in "$CC"/projects/*/; do
    [ -d "$scope/memory" ] || continue
    n=$(find "$scope/memory" -type f -name '*.md' 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] || continue
    s=$(basename "$scope")
    record_tree "$scope/memory" "memory/$s"
    mem_files=$((mem_files+n)); mem_scopes=$((mem_scopes+1))
    printf '  + %-46s %3d files\n' "$s" "$n"
  done
fi
[ "$mem_scopes" = 0 ] && echo "  (none)"
echo

# ------------------------------------------------------- 3. repo-level ----
# Per-repo .claude/ directories and CLAUDE.local.md files. These are the ones
# that never reach git: **/.claude/settings.local.json is in the global
# gitignore, and CLAUDE.local.md is local by convention.
echo "== repo-level =="
repo_hits=0
if [ -d "$HOME/Desktop" ]; then
  while IFS= read -r -d '' d; do
    parent=$(dirname "$d"); pname=${parent#"$HOME"/Desktop/}
    [ "$pname" = "$parent" ] && pname="_desktop-root"
    n=$(find "$d" -type f 2>/dev/null | wc -l)
    [ "$n" -gt 0 ] || continue
    record_tree "$d" "repos/$pname/.claude"
    repo_hits=$((repo_hits+1))
    printf '  + %-40s .claude/  %2d files: %s\n' "$pname" "$n" \
      "$(ls -A "$d" | tr '\n' ' ')"
  done < <(find "$HOME/Desktop" -maxdepth 7 \
             \( -name .git -o -name node_modules -o -name archive \
                -o -name 'Deontic Logic' -o -name lecture-recordings \
                -o -name readings -o -name finances \) -prune -o \
             -type d -name '.claude' -print0 2>/dev/null)

  while IFS= read -r -d '' f; do
    parent=$(dirname "$f"); pname=${parent#"$HOME"/Desktop/}
    [ "$pname" = "$parent" ] && pname="_desktop-root"
    record "$f" "repos/$pname/CLAUDE.local.md"
    repo_hits=$((repo_hits+1))
    printf '  + %-40s CLAUDE.local.md\n' "$pname"
  done < <(find "$HOME/Desktop" -maxdepth 7 \
             \( -name .git -o -name node_modules -o -name archive \
                -o -name 'Deontic Logic' -o -name lecture-recordings \
                -o -name readings -o -name finances \) -prune -o \
             -type f -name 'CLAUDE.local.md' -print0 2>/dev/null)
fi
[ "$repo_hits" = 0 ] && echo "  (none)"
echo

# --------------------------------------------------------- 4. home-level ----
# Machine-local by deliberate decision, collected for comparison only.
echo "== home-level (reference) =="
record "$HOME/Desktop/CLAUDE.md" "home/Desktop-CLAUDE.md"       && echo "  + ~/Desktop/CLAUDE.md"
record "$HOME/.config/git/ignore" "home/git-ignore"             && echo "  + ~/.config/git/ignore"

# ~/.claude.json, filtered: the per-project settings are worth merging, the
# identity/telemetry is not. Drops oauthAccount, userID, machineID, every
# cache, and all the last* counters.
if command -v python3 >/dev/null 2>&1 && [ -f "$HOME/.claude.json" ]; then
  python3 - "$HOME/.claude.json" "$PAY/home/claude-json-projects.json" <<'PY' 2>/dev/null && echo "  + ~/.claude.json (projects only, filtered)"
import json, sys, os
keep = {"allowedTools","ignorePatterns","mcpServers","enabledMcpjsonServers",
        "disabledMcpjsonServers","mcpContextUris","hasTrustDialogAccepted",
        "hasClaudeMdExternalIncludesApproved"}
src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
out = {}
for path, v in (d.get("projects") or {}).items():
    f = {k: v[k] for k in keep if k in v and v[k] not in (None, [], {}, False)}
    if f: out[path] = f
os.makedirs(os.path.dirname(dst), exist_ok=True)
json.dump({"projects": out}, open(dst, "w"), indent=2)
PY
  if [ -f "$PAY/home/claude-json-projects.json" ]; then
    printf '%s\t%s\t%s\t%s\n' \
      "$(stat -c%s "$PAY/home/claude-json-projects.json")" \
      "$(stat -c%y "$PAY/home/claude-json-projects.json" | cut -d. -f1)" \
      "$(sha256sum "$PAY/home/claude-json-projects.json" | cut -c1-16)" \
      "home/claude-json-projects.json" >> "$MAN"
    copied=$((copied+1))
  fi
fi
echo

# ---------------------------------------------------------- 5. inventory ----
{
  echo "Claude Code migration inventory"
  echo "==============================="
  echo "machine        : $HOST"
  echo "collected      : $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "claude version : $(claude --version 2>/dev/null || echo 'not on PATH')"
  echo "home           : $HOME"
  echo "files copied   : $copied"
  echo
  echo "-- memory, by scope ------------------------------------------------"
  if [ "$mem_scopes" -gt 0 ]; then
    for scope in "$CC"/projects/*/; do
      [ -d "$scope/memory" ] || continue
      s=$(basename "$scope")
      n=$(find "$scope/memory" -type f -name '*.md' ! -name MEMORY.md 2>/dev/null | wc -l)
      i=$([ -f "$scope/memory/MEMORY.md" ] && echo "yes" || echo "no")
      [ "$n" -gt 0 ] || [ "$i" = yes ] || continue
      printf '%-48s %3d memories   MEMORY.md: %s\n' "$s" "$n" "$i"
    done
    echo
    echo "newest memory files (top 15):"
    find "$CC/projects" -path '*/memory/*.md' -printf '%T+  %p\n' 2>/dev/null \
      | sort -r | head -15 | sed "s|$CC/projects/|  |"
  else
    echo "(none)"
  fi
  echo
  echo "-- project-level memory (a second, older memory location) ----------"
  found_pm=0
  while IFS= read -r -d '' pm; do
    rel=${pm#"$HOME"/Desktop/}
    printf '%-56s %2d files\n' "$rel" "$(find "$pm" -type f | wc -l)"
    found_pm=1
  done < <(find "$HOME/Desktop" -maxdepth 7 \
             \( -name .git -o -name archive -o -name 'Deontic Logic' \
                -o -name lecture-recordings -o -name readings \) -prune -o \
             -type d -path '*/.claude/projects/*/memory' -print0 2>/dev/null)
  [ "$found_pm" = 0 ] && echo "(none)"
  echo
  echo "-- repo-level .claude ----------------------------------------------"
  if [ -d "$PAY/repos" ]; then
    find "$PAY/repos" -type f 2>/dev/null | sed "s|$PAY/repos/|  |" | sort
  else
    echo "(none)"
  fi
  echo
  echo "-- user config -----------------------------------------------------"
  find "$PAY/user" -type f 2>/dev/null | sed "s|$PAY/user/|  |" | sort || echo "(none)"
  echo
  echo "-- deliberately NOT collected --------------------------------------"
  cat <<'NOTE'
  .credentials.json      live OAuth token; one copy already at the flash root
  projects/*.jsonl       session transcripts (large, and teach-logic ones
                         contain exam material)
  history.jsonl          every prompt ever typed
  file-history/          per-file undo snapshots
  sessions/ session-env/ shell-snapshots/ paste-cache/ backups/ cache/
  debug/ ide/ downloads/ tasks/ jobs/ daemon/ daemon.log stats-cache.json
  plugins/marketplaces/  fetched clone, regenerable
NOTE
  if [ -s "$SKIPLOG" ]; then
    echo
    echo "-- copy failures ---------------------------------------------------"
    cat "$SKIPLOG"
  fi
} > "$INV"

# ------------------------------------------------------------- 6. summary ----
echo "== done =="
echo "  copied   : $copied files"
echo "  memory   : $mem_files files across $mem_scopes scopes"
echo "  repos    : $repo_hits repo-level items"
[ "$skipped" -gt 0 ] && echo "  FAILURES : $skipped (see INVENTORY.txt)"
echo
echo "  payload   $PAY"
echo "  inventory $INV"
echo
echo "Nothing on this machine was modified. Take the drive to the other box."
