#!/usr/bin/env bash
# Syntax-layer cost gauge for the french-logic highlight scheme.
# Read-only; safe to run while the file is open elsewhere.
#
#   tests/nvim-syntax/perf.sh <file.tex>
#   e.g. perf.sh ~/Desktop/dissertation/completeness/completeness.tex
#
# Prints with/without-layer sweep times and a ms/line verdict; the
# bigfed baseline and the interpretation live in the header of perf.lua
# and in nvim/docs/latex-register-taxonomy.md.
set -euo pipefail
cd "$(dirname "$0")"
if [ $# -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: perf.sh <file.tex>" >&2
  exit 2
fi
NVIM_NOSESSION=1 exec nvim --headless "$1" +"lua dofile('$(pwd)/perf.lua')" +'qa!'
