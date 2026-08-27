# CLAUDE.md — bash package

Charter for the `bash` stow package: the modular shell configuration stowed to
`~`. `.bashrc` sources every `~/.bashrc.d/*.sh` in numbered order, and
`~/.bashrc.d` is a whole-directory symlink into this package — so `gpullall` +
`source ~/.bashrc` deploys edits on the other machine with no restow. A restow
(`stow -R bash`) is needed only when files are added or removed at the package
top.

## Module map (sourced in numbered order)

- `00-shell-opts.sh` — shopt/set options. **Deliberately empty**, a reserved
  slot; ditto `30-prompt.sh` (inherits the system prompt from `/etc/bashrc`).
  An empty numbered module here is scaffolding, not dead code.
- `10-env.sh` — environment variables (`EDITOR`/`VISUAL` = nvim).
- `20-path.sh` — PATH/MANPATH/INFOPATH additions, duplicate-guarded. Each
  entry prepends, so **effective priority is the reverse of reading order** —
  TeX Live ends up first, `~/bin` last of the personal dirs. **TeX Live is
  auto-detected, not hardcoded**: the newest `/usr/local/texlive/YYYY` that
  contains a working `tlmgr` (half-installed trees are skipped, so a parallel
  install in progress can't knock TeX Live off PATH). Pin an older release
  with `TEXLIVE_YEAR=<year>` — see `bin/CLAUDE.md`, TeX Live release
  upgrades. The bun block is a guarded shim, inert until bun exists.
- `40-aliases.sh` — aliases plus functions: `sysupgrade` and `reboot-check`
  (see "Reboot verdict" below), `tl-upgrade` (within-release TeX Live update;
  resolves `tlmgr` through PATH so it survives year bumps), `reload`
  (typo-proof `source ~/.bashrc`), `cc` / `ccf` (claude with opus/fable at max
  effort), and the `cd`+`ls` navigation shortcuts (`configs`, `dissertate`,
  `teach`, `logic`, …).
- `50-git-sync.sh` — `gpullall` / `gpushall` / `gpull` / `gpush` / `gstatall`
  plus the `_gsync_*` per-repo helpers and vet guards. See "Git sync" below.
- `60-stow.sh` — `stow-all` / `stow-all-dry` / `unstow-all` and the
  `STOW_TARGETS` / `STOW_ORDER` arrays, the source of truth for package →
  target. When adding a stow package, update **both** arrays — and see the
  re-source trap below.
- `70-task-list.sh` — `ls-tasks [PATH]`: recursively lists unchecked `- [ ]`
  items from markdown files.
- `80-clamav.sh` — `clam {update,home,full}` (logs to `~/clam-scan-*.log`;
  requires `clamav` + `clamav-update`). Its PUA detection flags benign
  browser/dev content — read hits skeptically.
- `85-disk.sh` — `disk-check` / `disk-fix`. See "Disk maintenance pair" below.
- `90-nix.sh` — nix profile loader, guarded on nix being installed.
  **Load-bearing on bigfed** (nix since 2025-03-05; this file is the only
  thing putting it on PATH, and it exports `NIX_SSL_CERT_FILE`, without which
  substituter fetches fail TLS). An inert no-op elsewhere, so one file is
  correct on every machine — same guarded-shim pattern as the bun block.

Also in the package: `.bashrc.min` / `.bash_profile.min`, stowed to `~` —
minimal known-good rescue configs for recovering from an edit that breaks
login; sourced by nothing (README §8). And `.stow-global-ignore`, stowed to
`~` — stow's global ignore list. ⚠ When that file exists stow **replaces its
built-in defaults with it**, so it reproduces the defaults verbatim before the
one addition (`CLAUDE\.md`, which keeps per-package charters like this one
from being symlinked into live config dirs); a `.stow-local-ignore` in any
package would replace it for that package — don't add one without reproducing
the patterns.

## The re-source trap (hazard)

`stow-all` iterates the arrays **as loaded in the running shell**. A pull that
adds a new stow package updates `60-stow.sh` on disk but not in memory, so
`stow-all` skips the new package **silently** — no error. `source ~/.bashrc`
(or `reload`) must precede `stow-all` whenever a pull adds or removes
packages. The same trap class applies to every function here: a pulled edit is
inert until re-sourced — which is why `claude-link` / `claude-prune` are
scripts in `bin/`, not bash functions.

## Git sync (`50-git-sync.sh`)

The single-repo and all-repo commands share the same per-repo helpers
(`_gsync_pull_repo` / `_gsync_push_repo`), so their behavior cannot drift
apart:

- `gpullall` — pulls every repo in `REPOS_DESKTOP` (ff-only, prune,
  submodules on demand; tags on fetched history auto-follow — deliberately no
  `--tags`, so a force-moved remote tag can't wedge every future pull)
- `gpushall [-m MSG]` — stages (`git add -A`), vets new paths, commits,
  `pull --rebase=merges`, pushes every repo. Remote commits integrated by the
  rebase are reported (`[PULL] integrated changes from origin`) and fire the
  configs hints — the push path is never silently ahead of what you saw. A
  legacy positional message is accepted and joins all words; unknown flags are
  rejected so `gpushall -f` can't commit 13 repos with the message `-f`
- `gpull <name>...` / `gpush [-m MSG] <name>...` — the same flows for one or
  more repos under `~/Desktop`; names tab-complete from `REPOS_DESKTOP`
- `gstatall [-f]` — read-only dashboard: branch, dirty count, behind/ahead,
  and a STATE verdict in words that composes every applicable flag
  (`needs push` / `needs pull` / `DIVERGED` / `uncommitted` / an in-progress
  op), so dirty work is never elided by a sync verdict. Plain runs read the
  last fetch; `-f` fetches first while still pushing and pulling **nothing**.
  The safe first move whenever the machines may be out of step

Guardrails, shared by the single- and all-repo variants:

- **New-path vetting**: newly added paths — including rename targets and
  typechanges (the listing runs with rename detection off), matched per path
  component so a directory named `.env/` or `credentials/` is caught — larger
  than `GSYNC_MAX_MB` (default 25; a non-numeric override falls back to 25
  with a warning) or matching `GSYNC_SECRET_GLOBS`, plus embedded git
  repositories (which would push as empty gitlinks), get a y/N prompt before
  being committed. Declined files are unstaged via `:(literal)` pathspecs
  (hostile filenames can't dodge or collateral-match the unstage) and
  verified gone before the commit proceeds; when stdin is not a tty they are
  left uncommitted with a warning, and they are flagged again next run. The
  vet **fails closed**: if the staged-file listing itself errors, the repo's
  commit is refused rather than performed unvetted. Know its scope, though:
  it matches **filenames**, and only for paths *new* to the repo
  (`--diff-filter=AT`). A secret pasted into an already-tracked file is never
  checked, and adding `M` to the filter would not help. `.gitignore` is the
  standing second layer; a content scan of the staged diff is the real
  remedy, deferred and written up as **`TODO.md` item 7**.
- **Committed new files are listed** in the output (up to 12, then
  `+N more`), so nothing enters a repo invisibly — this matters because the
  repo is public and `.gitignore` refuses only known name patterns.
- **In-progress rebase/merge/cherry-pick/revert/bisect is detected** and
  reported as such, never auto-committed over; a brand-new repo with no
  commits yet is skipped (`no commits yet`).
- **A rebase conflict is auto-aborted**: the repo returns to a clean state
  with the local commit intact, and the summary names the repo for manual
  resolution. A batch command never leaves a repo mid-rebase.
- **Offline-aware**: one TCP probe of `github.com:22` (all remotes are
  GitHub-over-SSH); when offline, `gpushall` still commits locally and
  reports pushes as `[PEND]`, `gpullall` reports offline once and stops.
- **Non-main branches are synced but flagged** with a warning.
- **Unpushed work is surfaced**: after pulling, `gpullall`/`gpull` warn when
  a repo is still ahead of origin, so "up to date" can never be mistaken for
  "in sync with the other machine".
- **A diverged repo names its remedy**: when a pull can't fast-forward over
  local unpushed commits, the output points at `gpush <name>` (which rebases)
  instead of dumping a raw git error.
- **Post-pull hints**: a `configs` pull — via `gpullall` *or* a `gpushall`
  rebase that integrated remote changes — that changed `bash/` files,
  added/removed files in a stow package, or touched `nvim/lazy-lock.json`
  prints the required follow-up (`source ~/.bashrc`, `stow-all`,
  `nvim --headless "+Lazy! restore" +qa`). The change list is parsed
  NUL-delimited, so non-ASCII filenames can't silently defeat it. **Hints are
  consolidated (2026-08-22)**: queued during the run and printed as one block
  after the summary; the queue is `local` to each command, the flush sits
  before the final status expression so exit codes are unaffected, and only
  the *message* defers — `claude-link --auto` still runs where it arises.
  Known cost: a Ctrl-C mid-run loses the queued hints for good. A pull that
  changes `org/claude-config/` also triggers `claude-link --auto` (`|| true`
  is load-bearing — the linker exits 1 when it makes changes, which `set -e`
  would otherwise abort the pull on).

Summaries name the repos that skipped/failed/are pending; tags are colorized
on a tty. The explicit pre-pull fetch was removed (the pull's own fetch
serves); the only remaining explicit fetch is on the rare set-upstream path.
To add a new repo, append its path to `REPOS_DESKTOP` — note it spans *all*
the Desktop repos, not just this one. Commit messages follow
`{hostname}: {YYYY-MM-DD HH:MM:SS}`; override per-run with `-m`.

**Regression suite:** `tests/gsync/run-all.sh` (168 checks in four suites,
sandboxed under `$TMPDIR`, no network). Run it after **any** edit to
`50-git-sync.sh`. Each suite also runs standalone and tests the checkout it
lives in; `tests/gsync/README.md` has suite scope and the harness conventions
new suites must follow (`passed: N  failed: M` last line, registration in
`run-all.sh`).

## Reboot verdict (`40-aliases.sh`, added 2026-08-08)

`sysupgrade` (dnf upgrade + autoremove + flatpak update/uninstall-unused —
mark keepers with `dnf mark user <pkg>`, autoremove runs `-y`) ends by
printing whether the upgrade earned a reboot; `reboot-check` runs the same
verdict standalone, unprivileged. The signal is `dnf needs-restarting` from
**`dnf5-plugins`** — and ⚠ the dependency is on a version new enough to have
`--json`: on an older Fedora (43's 5.2.18.0) the package is present yet the
check reports `[WARN] Reboot status unknown` forever, and installing
`dnf5-plugins` is *not* the remedy there. Full findings and design record:
`docs/reboot-verdict-findings-2026-08.md`.

Four verdicts, exit status matching (`0`/`1`/`2`/`3`):

| Verdict | Meaning |
|---------|---------|
| `[REBOOT]` | Core packages updated since boot — or a stale **system** service, which names `systemctl restart <unit>` as the surgical alternative |
| `[RELOGIN]` | Nothing core changed, but **session** services are running stale code — a logout clears it |
| `[ OK ]` | Nothing has changed since boot — or, degraded, no core updates or stale services since boot with advisories unconsulted (flagged in-line, remedy included) |
| `[WARN]` | Status genuinely unknown — plugin failure or a dead service scan; each case gets a distinct message with the stderr excerpt |

Operative facts that must survive edits (each measured; reasoning in the
record):

- The verdict is parsed from `--json`, **never** from the exit status
  (`needs-restarting` exits 1 for "reboot required" *and* for its own
  errors), and there is no `-C` (cold-cache false positive).
- Both dnf calls take `</dev/null` — with a tty on stdin dnf5 can block
  invisibly on an OpenPGP key question.
- On any unparseable verdict the check retries with `--disable-repo='*'` and
  reports the core-package verdict flagged **degraded**; the service scan
  runs `--disable-repo='*'` unconditionally and is judged by stdout shape,
  never exit status.
- Stale-service scope is asked of systemd via `systemctl show -p` (never
  `list-units`), system manager first, so a unit-name collision resolves to
  `system` — the safe direction.
- The `unalias sysupgrade` line guarding the definition is **load-bearing**;
  keep it until both machines have started a fresh login shell. `sysupgrade`
  returns the *chain's* status, so `sysupgrade && …` still means "the upgrade
  succeeded".

**Regression suite:** `tests/reboot-verdict/run.sh` (75 checks, ~7 s,
PATH-stubbed, mutation-verified — inventory in the record). Run it after any
edit to the verdict functions, or when a dnf5 update makes a verdict look
wrong.

## Disk maintenance pair (`85-disk.sh`, added 2026-08-09)

Born of the bigfed ENOSPC incident: btrfs committed every byte to data chunks
while `df` showed 91G free — deleting files cannot help in that state, and
nothing was watching. **Philosophy (deliberate, discussed 2026-08-09):**
automatic *watching* is fine (smartd, kernel counters); automatic *writing*
is not — no timers, no background actions, no root in the steady state.

- **`disk-check`** — one verdict line per subsystem (`[ OK ]`/`[DUE]`/
  `[FAIL]`/`[WARN]`, exit 0/1/2 matching): chunk headroom (the incident
  class), metadata headroom (low unalloc + full metadata = "ENOSPC
  imminent"), lifetime device error counters, scrub age, smartd verdicts from
  the **system** journal (`--system` is load-bearing — without it rc 0 is a
  false OK), and plain df fullness. Unprivileged, from
  `/sys/fs/btrfs/<uuid>/`; never writes, never elevates; safe on a
  filesystem already wedged at ENOSPC.
- **`disk-fix`** — consults the *same* threshold table (top of `85-disk.sh`),
  announces the full plan, primes sudo once, runs only what is due: a
  filtered data balance (`-dusage=0` then `-dusage=50`) when unallocated is
  low, a scrub (`btrfs scrub start -Bd`) when none is on record or older
  than 90 days. Nothing due → no sudo, no writes, exit 0. Guarantees: never
  a full balance, never metadata balance, never defrag, never deletes. After
  a balance it re-measures and says honestly when the filesystem is
  *genuinely* filling. The scrub date is recorded **only when the scrub
  comes back clean**, so trouble keeps nagging.

**Thresholds are absolute, not percentages, on purpose** — btrfs needs
GiB-scale unallocated room regardless of device size, so one rule serves
every machine: balance due < 16G unallocated, crit < 4G, metadata crit <
512M, scrub due > 90 days, df warn ≥ 90%. State lives in
`~/.local/state/disk-maint/scrub-<uuid>` — machine-local, deliberately
unsynced; a scrub run outside `disk-fix` is invisible to the nag, so let the
nag drive scrubs. Plain-Fedora dependencies only; degrades gracefully — no
btrfs, smartd off, unreadable journal or sysfs each get a named verdict,
never a silent pass.

**Regression suite:** `tests/disk/run.sh` (59 checks, ~2 s, PATH-stubbed
against a fake sysfs via `DISK_SYSFS`/`DISK_STATE_DIR`; ends with a live
read-only run asserting the tag/exit contract). Run after any edit to
`85-disk.sh`. **Fire drill:** `tests/disk/live-drill.sh` (interactive sudo,
~2 min, ~3.5G of writes) loop-mounts a throwaway 4G btrfs image and lets the
*real* `disk-fix` balance and scrub it, real filesystems shielded and
asserted untouched — run once per machine, or after changing the disk-fix
action paths.
