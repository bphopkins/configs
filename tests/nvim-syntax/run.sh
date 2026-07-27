#!/usr/bin/env bash
# Headless regression check for the french-logic VimTeX syntax layer.
# Run from anywhere: ~/Desktop/configs/tests/nvim-syntax/run.sh  (~5 s)
# Exit 0 = all checks pass; non-zero = something regressed (details on
# stderr).  Worth a run after a VimTeX plugin update, or whenever logic
# highlighting looks wrong.
set -euo pipefail
cd "$(dirname "$0")"
NVIM_NOSESSION=1 exec nvim --headless test.tex +'lua dofile("verify.lua")' +'qa!'
