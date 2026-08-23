#!/usr/bin/env bash
# Run the full git-sync regression battery (156 checks as of 2026-08-22).
# Run after any edit to configs/bash/.bashrc.d/50-git-sync.sh.
# Everything executes against throwaway repos under $TMPDIR — the real
# ~/Desktop repos are never touched, and no network is used (the online
# probe is stubbed inside each suite).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
total_pass=0 total_fail=0 bad=0
for t in test-gsync test-two-machine test-tty-vet test-audit; do
  echo "== $t =="
  out="$(timeout 180 bash "$here/$t.sh" 2>&1)" || bad=1
  echo "$out" | grep -E "^FAIL" || true
  line="$(echo "$out" | tail -1)"
  echo "$line"
  total_pass=$((total_pass + $(echo "$line" | sed -E 's/passed: ([0-9]+).*/\1/')))
  total_fail=$((total_fail + $(echo "$line" | sed -E 's/.*failed: ([0-9]+)/\1/')))
done
echo
echo "TOTAL passed: $total_pass  failed: $total_fail"
((total_fail == 0 && bad == 0))
