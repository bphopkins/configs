#!/usr/bin/env bash
# tests/french-logic/units.sh — load each unit ON ITS OWN and typeset every member it
# defines.  This is the test of "dependencies ride with the code": a unit that needs
# a package it does not load, or a member from a unit it does not require, fails here
# even though the hub, which loads everything, would hide it.
#   ./units.sh [--sty DIR]      exit 0 if every unit passes, 1 otherwise
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build="$here/build/units"; sty_dir=""
[ "${1:-}" = --sty ] && { sty_dir="$(cd "$2" && pwd)"; export TEXINPUTS="$sty_dir:"; }
hub="$(kpsewhich french-logic.sty)" || { echo "french-logic.sty not found" >&2; exit 2; }
rm -rf "$build"; mkdir -p "$build"; fail=0
for u in $(grep -o '\\RequirePackage{french-logic-[a-z-]*}' "$hub" | sed 's/.*{french-logic-\(.*\)}/\1/'); do
  f="$(kpsewhich "french-logic-$u.sty")" || { echo "MISSING french-logic-$u.sty"; fail=1; continue; }
  d="$build/$u"; mkdir -p "$d"
  skip=""; [ "$u" = proof ] && skip="--skip qed,qedsymbol"   # defined only when amsthm is present (deon16 keeps its own)
  python3 "$here/gen-fixture.py" --sty "$f" --modes "$here/modes.tsv" --out "$d" --package "french-logic-$u" $skip >/dev/null || { echo "$u: fixture generation failed"; fail=1; continue; }
  ( cd "$d" && pdflatex -interaction=nonstopmode -halt-on-error fixture.tex >/dev/null 2>&1 )
  n=$(grep -a -c '^!' "$d/fixture.log" 2>/dev/null); n=${n:-1}; pages=$(sed -n '2,$p' "$d/pages.tsv" | wc -l)
  if [ "$n" = 0 ]; then printf '%-14s ok   %3s pages\n' "$u" "$pages"; else fail=1; printf '%-14s FAIL %s\n' "$u" "$(grep -a -m1 -A1 '^!' "$d/fixture.log" | tr '\n' ' ' | cut -c1-110)"; fi
done
exit $fail
