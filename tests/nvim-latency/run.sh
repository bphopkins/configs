#!/usr/bin/env bash
# Regression check for the insert-mode latency work of 2026-08-22.
# Run from anywhere: ~/Desktop/configs/tests/nvim-latency/run.sh  (~40 s)
#
# Exit 0 = the speed-up's structure is intact and nothing it touched broke.
# Nothing here asserts milliseconds -- timings belong to ./bench.sh, which is
# a measurement tool rather than a pass/fail gate.
#
# Worth a run after a VimTeX or blink.cmp update, after editing
# lua/plugins/{vimtex,completions}.lua or lua/config/autocmds.lua, or whenever
# typing in a long LaTeX paragraph starts feeling heavy again.
set -uo pipefail
cd "$(dirname "$0")"

if ! command -v python3 >/dev/null; then
  echo "python3 not found" >&2
  exit 2
fi
if ! python3 -c 'import pynvim' 2>/dev/null; then
  echo "pynvim not installed. Install it with:" >&2
  echo "    python3 -m pip install --user pynvim" >&2
  exit 2
fi

exec python3 verify.py
