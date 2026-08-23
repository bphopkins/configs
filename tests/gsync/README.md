# tests/gsync

Regression suites for the git-sync commands in
`bash/.bashrc.d/50-git-sync.sh` (`gpullall`, `gpushall`, `gpull`,
`gpush`, `gstatall`). Written 2026-07-26 during the sync-command overhaul and
the four-lens audit that followed; every bug found in that process has a test
here that fails against the pre-fix code. (Lived in the `scripts` repo as
`gsync-tests/` until 2026-08-04, when it moved here to sit beside the code it
tests.)

Run everything after any edit to `50-git-sync.sh`:

```bash
./run-all.sh
```

All tests operate on throwaway repos created under `$TMPDIR` — the real
`~/Desktop` repos are never touched and no network is used (each suite stubs
the `github.com:22` probe). Each suite resolves the sync script relative to its
own location (`CFG_ROOT`), so it exercises the checkout it lives in.

- `test-gsync.sh` — core per-repo behaviors: commit shapes (new / modified-only /
  deleted), size and secrets vetting, rebase-conflict auto-abort, merge-in-progress
  guard, offline pend, non-main warning, hints and the queue/flush contract
  behind them, argument parsing, completion.
- `test-two-machine.sh` — the two-machine workflow end to end: repo A ahead on
  machine 1, repo B ahead on machine 2, dashboards, convergence, non-conflicting
  and conflicting divergence, composed `gstatall` verdicts.
- `test-tty-vet.sh` — the interactive y/N vet prompt under a real pseudo-terminal
  (python3 `pty`), including mixed answers and tty colorization.
- `test-audit.sh` — regressions for the 2026-07-26 audit findings: revert guard,
  unborn-branch skip, `:(literal)` unstaging, rename/typechange vetting, embedded
  repos, secret directory components, `GSYNC_MAX_MB` validation, `gpushall` parser,
  offline entry points, diverged-pull remedy, integrated-changes reporting, moved
  tags, detached HEAD, listing truncation, re-flagging. Also carries one later
  behavioral change rather than an audit finding: the 2026-08-22 hint
  consolidation, whose end-to-end section asserts a hint lands *after* both the
  later repos' lines and the summary.

Harness conventions — keep these when adding tests:

- Assertions use the suite-local helpers: `check DESC CMD...` (prints
  `ok   - `/`FAIL - ` and bumps `pass`/`fail`), `contains HAYSTACK NEEDLE`, and
  (in `test-gsync.sh`) `must CMD...` for setup steps that abort the suite.
- `run-all.sh` greps suite output for lines starting with `FAIL` and parses each
  suite's **last line**, which must have the exact shape `passed: N  failed: M`.
  It also imposes a 180-second timeout per suite. New suites must follow both
  conventions and be added to its `for t in ...` list.

Requires: bash 5+, git 2.4x+, python3 (for the pty suite), GNU coreutils.
