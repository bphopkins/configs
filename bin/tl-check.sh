#!/usr/bin/env bash
# tl-check.sh <label> <bindir> [rootlist]
#
# Compile every LaTeX root with the given TeX Live bin directory and record a
# comparable fingerprint per document. Builds go to a state tree via
# -output-directory, so the repos are never written to -- several of them track
# their build artifacts, and a stray recompile would dirty tracked PDFs.
#
# Emits TSV: status  pages  texthash  warns  errs  path
#   status   ok      -> a PDF was produced
#            nopdf   -> engine ran but emitted no PDF
#            timeout -> exceeded the per-pass time limit
#   pages    page count (pdfinfo)
#   texthash md5 of pdftotext output -- stable across runs, unlike a raw PDF
#            hash, which embeds creation timestamps
#   warns    LaTeX/package Warning lines in the log
#   errs     hard error lines ("! ...") in the log
set -uo pipefail

SP="${TL_STATE:-$HOME/.cache/tl-newyear}"
LABEL="${1:?usage: tl-check.sh <label> <bindir> [rootlist]}"
BINDIR="${2:?usage: tl-check.sh <label> <bindir> [rootlist]}"
ROOTLIST="${3:-$SP/roots.txt}"

[ -d "$BINDIR" ]    || { echo "no such bindir: $BINDIR" >&2; exit 1; }
[ -f "$ROOTLIST" ]  || { echo "no root list: $ROOTLIST (run tl-roots.sh)" >&2; exit 1; }

BUILD="$SP/build-$LABEL"
RESULTS="$SP/results-$LABEL.tsv"
LOGDIR="$SP/logs-$LABEL"
JOBS="${TL_JOBS:-12}"
TIMEOUT="${TL_TIMEOUT:-240}"

rm -rf "$BUILD" "$LOGDIR"
mkdir -p "$BUILD" "$LOGDIR"
: > "$RESULTS"

export BINDIR BUILD LOGDIR TIMEOUT

compile_one() {
  local tex="$1"
  local dir base slug out engine status pages hash warns errs log rc

  dir=$(dirname "$tex")
  base=$(basename "$tex" .tex)
  slug=$(printf '%s' "$tex" | md5sum | cut -c1-12)   # stable key from full path
  out="$BUILD/$slug"
  mkdir -p "$out"

  # Unicode/OpenType documents need lualatex; everything else gets pdflatex.
  if grep -qE '\\usepackage(\[[^]]*\])?\{(fontspec|unicode-math|polyglossia)\}' "$tex" 2>/dev/null; then
    engine="$BINDIR/lualatex"
  else
    engine="$BINDIR/pdflatex"
  fi

  status=ok
  (
    cd "$dir" || exit 99
    # Search order matters. The output directory MUST come first: source trees
    # accumulate stale .aux files from editor builds (gitignored, so they
    # linger), and if kpathsea finds one of those before the freshly written
    # one, a later pass dies reading a mismatched aux. Recursive '//' on the
    # document's own directory is avoided for the same reason. Non-recursive
    # ancestors are kept because shared .sty files often sit a level or two up.
    export TEXINPUTS="$out:.:$dir/..:$dir/../..:"
    export BIBINPUTS="$out:.:$dir/..:$dir/../..:"
    export PATH="$BINDIR:$PATH"

    run() { timeout "$TIMEOUT" "$engine" -interaction=nonstopmode \
                    -file-line-error -output-directory="$out" "$base.tex" \
                    >/dev/null 2>&1; }

    run; [ $? -eq 124 ] && exit 124

    # Nothing usable came out of pass 1 -- further passes won't help.
    [ -f "$out/$base.pdf" ] || exit 0

    if grep -qE '\\usepackage(\[[^]]*\])?\{biblatex\}|\\addbibresource' "$base.tex" 2>/dev/null; then
      timeout "$TIMEOUT" "$BINDIR/biber" --input-directory="$out" \
              --output-directory="$out" "$base" >/dev/null 2>&1
      run; [ $? -eq 124 ] && exit 124
    fi
    # Settle cross-references, TOC and page numbers.
    run; [ $? -eq 124 ] && exit 124
    exit 0
  )
  rc=$?
  [ "$rc" -eq 124 ] && status=timeout

  log="$out/$base.log"
  warns=0; errs=0
  if [ -f "$log" ]; then
    # -a because logs can contain NUL bytes, which makes grep treat them binary.
    warns=$(grep -ac 'LaTeX Warning\|Warning:' "$log" 2>/dev/null) || warns=0
    errs=$(grep -ac '^!' "$log" 2>/dev/null) || errs=0
    cp "$log" "$LOGDIR/$slug.log" 2>/dev/null
  fi

  if [ -f "$out/$base.pdf" ]; then
    pages=$(pdfinfo "$out/$base.pdf" 2>/dev/null | awk '/^Pages:/{print $2}')
    hash=$(pdftotext "$out/$base.pdf" - 2>/dev/null | md5sum | cut -c1-16)
    : "${pages:=-}" "${hash:=-}"
  else
    pages='-'; hash='-'
    [ "$status" = ok ] && status=nopdf
  fi

  # Keep the PDF so tl-visdiff.sh can compare renderings; drop intermediates.
  find "$out" -maxdepth 1 -type f ! -name '*.pdf' -delete 2>/dev/null

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$status" "$pages" "$hash" "$warns" "$errs" "$tex"
}
export -f compile_one

echo "[$LABEL] compiling $(wc -l < "$ROOTLIST") documents with $BINDIR (jobs=$JOBS)"
xargs -d '\n' -P "$JOBS" -I{} bash -c 'compile_one "$@"' _ {} \
  < "$ROOTLIST" >> "$RESULTS" 2>/dev/null

sort -t$'\t' -k6 -o "$RESULTS" "$RESULTS"
echo "[$LABEL] done -> $RESULTS"
awk -F'\t' '{c[$1]++} END {for (s in c) printf "  %-8s %d\n", s, c[s]}' "$RESULTS"
