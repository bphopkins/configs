#!/usr/bin/env bash
# tl-visdiff.sh <doc.tex> <oldlabel> <newlabel> [dpi]
#
# Rasterize two builds of one document and compare page images pixel-for-pixel.
#
# This is the tool that distinguishes a cosmetic change from a real one. A
# text-hash change with zero pixel difference means only the PDF's embedded
# Unicode mapping changed -- the document *looks* identical and text extraction
# merely improved. That is the common case across a release bump and is not a
# regression. A large pixel count is a genuine visual change worth reading.
#
# Calibration: at 100dpi a single character is roughly 100 pixels of ink, so
# single-digit pixel counts are antialiasing noise at glyph edges.
#
# Requires poppler-utils (pdftoppm) and ImageMagick (compare).
set -uo pipefail

SP="${TL_STATE:-$HOME/.cache/tl-newyear}"
tex="${1:?usage: tl-visdiff.sh <doc.tex> <oldlabel> <newlabel> [dpi]}"
old="${2:?usage: tl-visdiff.sh <doc.tex> <oldlabel> <newlabel> [dpi]}"
new="${3:?usage: tl-visdiff.sh <doc.tex> <oldlabel> <newlabel> [dpi]}"
dpi="${4:-100}"

command -v pdftoppm >/dev/null || { echo "need pdftoppm (poppler-utils)" >&2; exit 1; }
command -v compare  >/dev/null || { echo "need compare (ImageMagick)" >&2; exit 1; }

slug=$(printf '%s' "$tex" | md5sum | cut -c1-12)
base=$(basename "$tex" .tex)
a="$SP/build-$old/$slug/$base.pdf"
b="$SP/build-$new/$slug/$base.pdf"
for f in "$a" "$b"; do
  [ -f "$f" ] || { echo "missing build: $f" >&2; exit 1; }
done

w="$SP/visdiff/$slug"; rm -rf "$w"; mkdir -p "$w"
trap 'rm -rf "$w"' EXIT

pdftoppm -r "$dpi" -png "$a" "$w/a" 2>/dev/null
pdftoppm -r "$dpi" -png "$b" "$w/b" 2>/dev/null

na=$(ls "$w"/a-*.png 2>/dev/null | wc -l)
nb=$(ls "$w"/b-*.png 2>/dev/null | wc -l)
printf '%s: %s vs %s pages @ %sdpi\n' "$(basename "$tex")" "$na" "$nb" "$dpi"
[ "$na" -ne "$nb" ] && { echo "  PAGE COUNT DIFFERS -- inspect manually"; exit 2; }

diffpages=0; totalpx=0; maxpx=0
for pa in "$w"/a-*.png; do
  pb="${pa/\/a-/\/b-}"
  [ -f "$pb" ] || continue
  # AE = absolute error, i.e. the count of differing pixels.
  px=$(compare -metric AE "$pa" "$pb" null: 2>&1 | grep -oE '^[0-9.e+]+' | head -1)
  px=${px%%.*}; px=${px:-0}
  if [ "$px" -gt 0 ]; then
    diffpages=$((diffpages+1)); totalpx=$((totalpx+px))
    [ "$px" -gt "$maxpx" ] && maxpx=$px
    [ "$diffpages" -le 5 ] && printf '  page %s: %s differing pixels\n' \
      "$(basename "$pa" .png | sed 's/^a-0*//')" "$px"
  fi
done

if [ "$diffpages" -eq 0 ]; then
  echo "  VISUALLY IDENTICAL -- all $na pages match exactly"
elif [ "$maxpx" -lt 50 ]; then
  echo "  $diffpages of $na pages differ ($totalpx px total, max $maxpx/page)"
  echo "  -> below the antialiasing threshold; treat as identical"
else
  echo "  $diffpages of $na pages differ ($totalpx px total, max $maxpx/page)"
  echo "  -> REAL VISUAL CHANGE, inspect these pages"
fi
