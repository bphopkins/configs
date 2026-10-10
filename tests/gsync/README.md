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
- `test-role.sh` — the machine's role and the conflict-copy refusal
  (2026-10-10; `org/machines/transport-2026-10`, rules fedxps-2 and ws-5): a
  fake `HOME` with fixture host files under `Desktop/configs/git/hosts/` and a
  `uname` stub naming the machine the suite pretends to be — the pilot's
  `readerRepo`, the cutover's `role = reader`, the writer, a stranger with no
  host file, a typo in the role, two keys at once, every spelling of a name,
  the hostname's forms, the link as a second source, a malformed, unreadable
  or dangling host file, a stale role in the shell; a conflict copy — new,
  renamed, extensionless, tracked, beside a secret — refused and unstaged,
  and the push going through once it is gone; the push gauge (rule bigfed-2,
  step 3b the same day) against a stub `sync-check` — a refusal skips the
  repository with the gauge's lines shown, nothing staged, the rest of the
  batch pushed; an unreadable cluster pushes under a WARN with the lines
  shown (his word, 2026-10-10); the gauge run before `add -A`
  with the repository's path, a pass shown or silent, the gauge missing from
  `PATH` hinted once and pushed, or skipped where a `.stfolder` marker sits
  at or above the repository, a reader's refusal coming first; and, read-only, the
  checkout's own host files and include in `git/config`. Its two reviews of
  2026-10-10 are in `org/machines/transport-2026-10/pilot/build-git.md`.
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
- Every suite puts a `uname` stub first on `PATH` (2026-10-10): the sync module
  reads this machine's role from `configs/git/hosts/$(uname -n).inc`, and a
  suite must not change behaviour with the machine it runs on. The four older
  suites name a host with no file, a writer; `test-role.sh` switches names.
- Every suite also puts a `sync-check` stub there (2026-10-10): `gpush` and
  `gpushall` run the push gauge before `add -A`, and the real one reads this
  machine's Syncthing. The four older suites' stub passes in silence;
  `test-role.sh`'s answers per repository from `STUB_GAUGE_<name>`.
- ⚠ One command per `check`: in `check "d" A && B` the `&&` binds outside
  `check`, so B is never checked and a false B only fails the line's exit
  status silently (found 2026-10-10 in 30 lines of `test-role.sh`). Write two
  checks, or one `bash -c "A && B"` with the values expanded into the string.
- `test-tty-vet.sh`'s driver converts `pty.spawn`'s raw wait status with
  `os.waitstatus_to_exitcode` before `sys.exit`; without it every exit code
  read as 0 (found 2026-10-10).
- `run-all.sh` greps suite output for lines starting with `FAIL` and parses each
  suite's **last line**, which must have the exact shape `passed: N  failed: M`.
  It also imposes a 180-second timeout per suite. New suites must follow both
  conventions and be added to its `for t in ...` list.

Requires: bash 5+, git 2.4x+, python3 (for the pty suite), GNU coreutils.
