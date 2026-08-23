#!/usr/bin/env bash
# Hermetic regression suite for the live-server root wrapper
# (nvim/lua/plugins/live-server.lua). 27 checks, ~10 s.
#
# Run from anywhere: ~/Desktop/configs/tests/live-server/run.sh
# Exit 0 = all checks pass; 1 = a check failed; 2 = cannot run (plugin or
# spec missing). Last line follows the tests/gsync convention
# (`passed: N  failed: M`).
#
# Sandboxed: fixture repos and XDG state under a mktemp dir (removed on
# exit), loopback traffic only on a port picked free at runtime,
# browser=false so nothing opens, no real repo touched. Needs the plugin
# checkout lazy.nvim keeps at ~/.local/share/nvim/lazy/live-server.nvim.
#
# LIVE_SERVER_SPEC=<file> substitutes the spec under test (used by the
# mutation checks in README.md); default is the checkout this suite lives in.
# Run after editing the wrapper or after a live-server.nvim update — the
# incident that created the wrapper's design notes was an upstream rewrite
# (v0.1.7 → v0.3.0) breaking the config silently.
set -euo pipefail
cd "$(dirname "$0")"

PLUGIN="${LIVE_SERVER_PLUGIN:-$HOME/.local/share/nvim/lazy/live-server.nvim}"
if [[ ! -f "$PLUGIN/lua/live-server/init.lua" ]]; then
  echo "live-server.nvim not found at $PLUGIN — open nvim once so lazy.nvim installs it" >&2
  exit 2
fi

SPEC="${LIVE_SERVER_SPEC:-$PWD/../../nvim/lua/plugins/live-server.lua}"
if [[ ! -f "$SPEC" ]]; then
  echo "spec under test not found: $SPEC" >&2
  exit 2
fi

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/live-server-suite.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

LS_SANDBOX="$SANDBOX" LS_SPEC="$SPEC" LS_PLUGIN="$PLUGIN" \
  XDG_STATE_HOME="$SANDBOX/state" \
  nvim --clean --headless -i NONE -l check.lua
