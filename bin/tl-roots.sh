#!/usr/bin/env bash
# tl-roots.sh <outfile>
#
# Generate the canonical list of compilable LaTeX roots across the workspace.
# Written once and reused by every run, so the old-release and new-release
# sweeps cover exactly the same document set.
#
# A "root" is any .tex that declares its own \documentclass. Chapter fragments
# and \input-ed pieces are therefore excluded automatically.
#
# Override the workspace with TL_WORKSPACE; override the repo list with
# TL_REPOS (space-separated, relative to the workspace).
set -uo pipefail

ROOT="${TL_WORKSPACE:-$HOME/Desktop}"
REPOS="${TL_REPOS:-dissertation dissertation-template teach-logic teaching opuscula n-cube org}"
OUT="${1:?usage: tl-roots.sh <outfile>}"

mkdir -p "$(dirname "$OUT")"
: > "$OUT"

for r in $REPOS; do
  [[ -d "$ROOT/$r" ]] || continue
  # -print0 throughout: several directories here contain spaces.
  find "$ROOT/$r" -name '*.tex' -not -path '*/.git/*' -print0 2>/dev/null \
  | while IFS= read -r -d '' f; do
      if grep -qE '^[[:space:]]*\\documentclass' "$f" 2>/dev/null; then
        printf '%s\n' "$f" >> "$OUT"
      fi
    done
done

sort -o "$OUT" "$OUT"
printf 'roots: %s\n' "$(wc -l < "$OUT")"
