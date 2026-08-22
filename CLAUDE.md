# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A GNU Stow-based dotfiles repository for Fedora Linux, synced across multiple machines (fedxps, bigfed) via git. **This is a public GitHub repo** (`github.com/bphopkins/configs`) — anything committed is published (see Pitfalls). Configs are stored here at `~/Desktop/configs` and symlinked to their live locations. The user is an academic working in logic/philosophy — the LaTeX and Neovim configs are heavily tailored to dissertation writing.

`TODO.md` at the repo root is the planned-work tracker: each open item is written up in enough detail to brief a fresh session, and its notes record decisions that were considered and **declined** (plus things that look stale but are deliberate). Read it before starting a work session here or proposing structural changes.

## Stow Deployment

Each top-level directory (except `wallpapers/` and `tests/`) is a stow "package" with a specific target. The source of truth for targets is the associative array in `bash/.bashrc.d/60-stow.sh`:

| Package    | Stow Target                  |
|------------|------------------------------|
| bash       | `~`                          |
| wezterm    | `~`                          |
| alacritty  | `~/.config/alacritty`        |
| nvim       | `~/.config/nvim`             |
| sway       | `~/.config/sway`             |
| swaylock   | `~/.config/swaylock`         |
| mako       | `~/.config/mako`             |
| waybar     | `~/.config/waybar`           |
| wofi       | `~/.config/wofi`             |
| latex      | `~/texmf/tex/latex`          |
| bin        | `~/bin`                      |
| okular     | `~/.config`                  |

Key commands (defined in `bash/.bashrc.d/60-stow.sh`):
- `stow-all` — `git pull --ff-only`, then restow every package (`stow -R`). On a conflict (an untracked real file already sitting at a target) it **errors out** rather than resolving it — adopt or remove the file manually (README §8 covers `stow --adopt`), then rerun.
- `stow-all-dry` — preview what stow-all would do (no changes)
- `unstow-all` — remove all managed symlinks (`stow -D`)

When adding a new stow package, update both the target map and the ordering array in `60-stow.sh`. Editing existing symlinked files requires no restow; adding new files to a package does.

`README.md` is the authoritative from-scratch walkthrough for standing this up on a new machine (import live dotfiles → seed commit → dry-run stow → link → verify → reload); its §8 covers conflict resolution (`stow --adopt`), per-package restow, and unlinking.

## Daily Sync Workflow

Start of session: `gpullall` → `source ~/.bashrc` (if bash files changed) → `stow-all` (if files added/deleted). End of session: `gpushall`.

**The re-source is not optional when a pull adds a stow package.** `60-stow.sh` is itself a bash file, so a pull that adds a package updates it on disk but not the arrays in the running shell — and `stow-all` iterates the in-memory arrays, so it skips the new package **silently**, with no error. This bit the `bin` package and applies again to `okular`. When in doubt, re-source.

## Git Sync Workflow

Defined in `bash/.bashrc.d/50-git-sync.sh`. The single-repo and all-repo commands share the same per-repo helpers (`_gsync_pull_repo` / `_gsync_push_repo`), so their behavior cannot drift apart:
- `gpullall` — pulls every repo in the `REPOS_DESKTOP` array (ff-only, prune, submodules on demand; tags on fetched history auto-follow — deliberately no `--tags`, so a force-moved remote tag can't wedge every future pull)
- `gpushall [-m MSG]` — stages (`git add -A`), vets new paths, commits, `pull --rebase=merges`, pushes every repo. Remote commits integrated by the rebase are reported (`[PULL] integrated changes from origin`) and fire the configs hints — the push path is never silently ahead of what you saw. A legacy positional message is accepted and joins all words (`gpushall fixed the thing`); unknown flags are rejected so `gpushall -f` can't commit 13 repos with the message `-f`
- `gpull <name>...` / `gpush [-m MSG] <name>...` — same flows for one or more repos under `~/Desktop`; names tab-complete from `REPOS_DESKTOP`
- `gstatall [-f]` — read-only dashboard: branch, dirty count, behind/ahead, and a STATE verdict in words that composes every applicable flag (`needs push` / `needs pull` / `DIVERGED` / `uncommitted` / an in-progress op — e.g. `uncommitted; needs pull`), so dirty work is never elided by a sync verdict. Plain runs read the last fetch; `-f` fetches first so verdicts are current vs origin while still pushing and pulling **nothing**. The safe first move whenever the machines may be out of step

Guardrails, shared by the single- and all-repo variants:
- **New-path vetting**: newly added paths — including rename targets and typechanges (the listing runs with rename detection off), matched per path component so a directory named `.env/` or `credentials/` is caught — larger than `GSYNC_MAX_MB` (default 25; a non-numeric override falls back to 25 with a warning) or matching `GSYNC_SECRET_GLOBS`, plus embedded git repositories (which would push as empty gitlinks), get a y/N prompt before being committed. Declined files are unstaged via `:(literal)` pathspecs (hostile filenames can't dodge or collateral-match the unstage) and verified gone before the commit proceeds; when stdin is not a tty they are left uncommitted with a warning, and they are flagged again next run. The vet **fails closed**: if the staged-file listing itself errors, the repo's commit is refused rather than performed unvetted. Know its scope, though: it matches **filenames**, and only for paths *new* to the repo (`--diff-filter=AT`). A secret pasted into an already-tracked file — `CLAUDE.md`, `TODO.md`, any `bashrc.d` module — is never checked, and adding `M` to the filter would not help, since a modified file's name has not changed. `.gitignore` is the standing second layer; a content scan of the staged diff is the real remedy, deferred and written up as **`TODO.md` item 7**.
- **Committed new files are listed** in the output (up to 12, then `+N more`), so nothing enters a repo invisibly. This matters because the repo is public and `.gitignore` refuses only known name patterns — a novel name sails through.
- **In-progress rebase/merge/cherry-pick/revert/bisect is detected** and reported as such — previously an unresolved merge or revert could have conflict markers committed by `add -A` + `commit`. A brand-new repo with no commits yet is skipped (`no commits yet`), never auto-committed.
- **A rebase conflict is auto-aborted**: the repo is returned to a clean state with the local commit intact, and the summary names the repo for manual resolution. A batch command never leaves a repo mid-rebase.
- **Offline-aware**: one TCP probe of `github.com:22` (all remotes are GitHub-over-SSH); when offline, `gpushall` still commits locally and reports pushes as `[PEND]`, `gpullall` reports offline once and stops.
- **Non-main branches are synced but flagged** with a warning.
- **Unpushed work is surfaced**: after pulling, `gpullall`/`gpull` warn when a repo is still ahead of origin, so "up to date" can never be mistaken for "in sync with the other machine".
- **A diverged repo names its remedy**: when `gpullall` can't fast-forward because the repo has local unpushed commits, it says so and points at `gpush <name>` (which rebases) instead of dumping a raw git error.
- **Post-pull hints**: a `configs` pull — via `gpullall` *or* a `gpushall` rebase that integrated remote changes — that changed `bash/` files or added/removed files in a stow package prints the required follow-up (`source ~/.bashrc`, `stow-all`) — the silent-skip trap from "Daily Sync Workflow" above. The change list is parsed NUL-delimited, so non-ASCII filenames (which git C-quotes in plain output) can't silently defeat it.

Summaries name the repos that skipped/failed/are pending, and tags are colorized on a tty. The explicit pre-pull fetch was removed (the pull's own fetch serves), halving network round-trips; the only remaining explicit fetch is on the rare set-upstream path. To add a new repo, append its path to the `REPOS_DESKTOP` array. Commit messages follow `{hostname}: {YYYY-MM-DD HH:MM:SS}`; override per-run with `-m`. Note that `REPOS_DESKTOP` spans *all* the user's Desktop repos (dissertation, teaching, etc.), not just this one.

**Regression suite:** `tests/gsync/run-all.sh` (153 checks in four suites, sandboxed under `$TMPDIR`, no network) covers all of the above — vetting, guards, hints, the two-machine workflow, the tty prompt, and every 2026-07-26 audit finding. Run it after any edit to `50-git-sync.sh`. A single suite also runs standalone (e.g. `bash tests/gsync/test-audit.sh`) — each resolves the sync script relative to its own location, so it tests the checkout it lives in. See `tests/gsync/README.md` for suite scope and the harness conventions new suites must follow (`passed: N  failed: M` last line, registration in `run-all.sh`'s loop).

## Bash Configuration

Modular design: `.bashrc` sources all `~/.bashrc.d/*.sh` files. The numbered prefix controls load order:
- `00-shell-opts.sh` — shopt/set options. **Deliberately empty**, reserved so there's an obvious home for such options when one is wanted; ditto `30-prompt.sh`. Much of the bash tree is scaffolding like this — an empty numbered module is not dead code to be removed.
- `10-env.sh` — environment variables (`EDITOR`/`VISUAL` = nvim)
- `20-path.sh` — PATH/MANPATH/INFOPATH additions (guards against duplicates via substring matching); prepends `~/bin`, `~/.local/bin`, `~/.local/npm-global/bin`, and `~/.bun/bin` if bun is installed (it currently isn't on either machine, so that block is guarded on the directory existing rather than prepending a nonexistent path). Each entry prepends, so the **effective priority is the reverse of the reading order** — TeX Live ends up first, `~/bin` last of the personal dirs. **TeX Live is auto-detected, not hardcoded**: it picks the newest `/usr/local/texlive/YYYY` that actually contains a working `tlmgr` (half-installed trees are skipped, so a parallel install in progress can't knock TeX Live out of PATH). Override with `TEXLIVE_YEAR=<year>` to pin an older release — see "TeX Live release upgrades" below
- `30-prompt.sh` — prompt config. Empty by design; inherits the system default from `/etc/bashrc`. See `00-shell-opts.sh` above.
- `40-aliases.sh` — aliases, plus two functions: `sysupgrade` (dnf upgrade + dnf autoremove + flatpak update + flatpak uninstall --unused, then a reboot verdict; autoremove added 2026-08-07 — mark keepers with `dnf mark user <pkg>` since it runs `-y`) and `reboot-check` (the verdict on its own — see "Reboot verdict" below), `tl-upgrade` (TeX Live `tlmgr` self+all update; resolves `tlmgr` through PATH so it survives year bumps — note this only updates *within* a release, see "TeX Live release upgrades" below), `reload` (typo-proof `source ~/.bashrc` — guards against tab-completing into `~/.bash_history`, which would replay every command in it), `cc` (`claude --model opus --effort max`), `ccf` (`claude --model fable --effort max` — the most capable model, for work that must be done properly), plus `cd`+`ls` navigation/edit shortcuts (`configs`, `dissertate`, `teach`, `logic`, …)
- `50-git-sync.sh` — git sync functions (`gpullall`, `gpushall`, `gpull`, `gpush`, `gstatall`) plus the `_gsync_*` per-repo helpers, new-file vet guards (`GSYNC_MAX_MB`, `GSYNC_SECRET_GLOBS`), and repo-name tab completion — see "Git Sync Workflow" above
- `60-stow.sh` — stow functions (`stow-all`, `unstow-all`)
- `70-task-list.sh` — `ls-tasks [PATH]`: recursively lists unchecked `- [ ]` items from markdown files
- `80-clamav.sh` — `clam {update,home,full}`: ClamAV signature refresh and scan helpers (logs to `~/clam-scan-{home,full}-<ts>.log`). Requires `clamav` + `clamav-update`.
- `85-disk.sh` — the disk maintenance pair: `disk-check` (read-only, unprivileged, sub-second scorecard) and `disk-fix` (runs only what is due, under interactive sudo) — see "Disk maintenance pair" below
- `90-nix.sh` — nix profile loader (conditional; only if nix is installed). **Load-bearing on bigfed**, where nix has been installed since 2025-03-05 and `~/.bash_profile` carries no nix line — this file is the only thing putting nix on PATH, and bigfed is the machine that builds Carnap. Sourcing it also exports `NIX_SSL_CERT_FILE`, without which nix's bundled curl cannot verify TLS against `cache.nixos.org` and substituter fetches fail. The guard makes it an inert no-op elsewhere, so one file is correct on every machine: fedxps gains a working nix the moment one is installed, with no config change; nousowl had nix removed 2026-08-17 and is deliberately not a build box. Same guarded-shim pattern as the bun block in `20-path.sh`. **Corrected 2026-08-17** — this entry previously said nix was "not installed on either machine right now", which was false when written (2026-07-26): nix predated that claim on bigfed by 17 months. It was written from fedxps, where nix genuinely is absent, and generalised without checking the other machine — a failure mode of a two-machine setup rather than ordinary staleness.

Also in the `bash` package, stowed to `~/.bashrc.min` and `~/.bash_profile.min`: minimal known-good rescue configs, for recovering from an edit that breaks login. Not sourced by anything; see README §8.

### Reboot verdict (added 2026-08-08)

`sysupgrade` ends by printing whether the upgrade actually earned a reboot, replacing a reboot-every-day habit with dnf's own hint. `reboot-check` runs the same verdict standalone, unprivileged (it reads the rpmdb — no sudo prompt), so "do I need to reboot?" is answerable any time.

The signal is `dnf needs-restarting` from **`dnf5-plugins`** (a dependency worth knowing about — the verdict degrades to `[WARN] Reboot status unknown` without it). It compares install times of a core package set against boot time: kernel, systemd, the [Red Hat core-libs list](https://access.redhat.com/solutions/27943), plus anything carrying a `reboot_suggested` advisory. Output is one line, tagged and colorized like the gsync helpers.

⚠ **The dependency is on a `dnf5-plugins` new enough to have `--json`, not merely on the package being installed** — added 2026-08-17. `reboot-check` needs a parseable JSON verdict, and `needs-restarting` only grew `--json` partway through the dnf5 series: bigfed (Fedora 44, `dnf5-plugins` 5.4.2.1) has it, while Fedora 43's 5.2.18.0 rejects the flag outright and offers only `-s` and `-r`. On such a machine the package is present, `command -v dnf` succeeds, and the function nonetheless reports `[WARN] Reboot status unknown` **forever**, with the stderr excerpt reading `Unknown argument "--json"` rather than anything suggesting a version problem. The degraded path handles it correctly — it is a genuine "could not tell" — but the cause is worth naming here, because "install `dnf5-plugins`" is the obvious remedy and on an older Fedora it is not the remedy at all. Found by checking both machines rather than inferring from one; the text-parsing alternative written for that case lives in the `nousowl` repo (`configs/bash/.bashrc.d/40-aliases.sh`) and is deliberately **not** a port of this function.

Four verdicts, and the exit status matches (`0` nothing, `1` reboot, `2` could not tell, `3` re-login):

| Verdict | Meaning |
|---------|---------|
| `[REBOOT]` | Core packages updated since boot — or a stale **system** service, which names `systemctl restart <unit>` as the surgical alternative |
| `[RELOGIN]` | Nothing core changed, but **session** services are running stale code — a logout clears it |
| `[ OK ]` | Nothing has changed since boot — or, degraded, no core updates or stale services since boot with advisories unconsulted (flagged in-line, remedy included) |
| `[WARN]` | Status genuinely unknown — either `dnf needs-restarting` failed *even with repos disabled* (plugin missing? the stderr excerpt is printed in-line), or the core check came back clean but the *service scan* failed; each case gets a distinct message |

Findings baked into the implementation — each measured, and each a way this could have been written wrong:

- **The verdict is parsed from `--json`, never from the exit status.** `needs-restarting` exits 1 both for "reboot required" *and* for its own errors — `dnf -C needs-restarting` on a cold cache exits 1 with "no cache for repository". An exit-code test therefore reports a phantom reboot on any failure. `reboot_required` is a documented JSON field; the human-readable text is neither a contract nor untranslated.
- **No `-C`.** With any existing metadata cache the check works offline (verified under `unshare -n`, with both fresh and expired caches), so cacheonly buys nothing and reintroduces the cold-cache false positive above.
- **`sysupgrade` is a function now, not an alias** — an alias can't run anything *after* its chain. The `unalias sysupgrade` line guarding the definition is **load-bearing**: aliases expand at parse time, so in a shell that still holds the old alias, `reload` would die with a syntax error on `sysupgrade() {` and silently drop every definition below it in the file (`reload`, `byebye`, the navigation aliases). Keep it until both machines have started a fresh login shell. `sysupgrade` returns the *chain's* status, not the verdict's, so `sysupgrade && …` still means "the upgrade succeeded".

- **Scope of a stale service is reconstructed, because dnf doesn't report it.** `needs-restarting -s --json` carries only `type` and `unit` — no scope — yet unit names genuinely collide across the two managers (`systemd-tmpfiles-setup.service` and `uresourced.service` are loaded in *both* system and user scope here). Scope is asked of systemd, **system manager first**, so a collision resolves to `system`. Ambiguity always resolves that way: telling you a re-login suffices when it doesn't is the one genuinely wrong answer this can give.
- **Scope is asked via `systemctl show -p`, not `list-units`** — deliberately, and the two are not interchangeable in durability. `show` is systemd's property interface (the same data as its D-Bus API, `Key=Value` in blank-line-separated blocks); `list-units` prints a human table, the kind of output `systemctl(1)` flags as unsuitable for programmatic consumption. Both gave an identical classification when compared, so this costs nothing and removes a column-parse from the maintenance surface. The block parse is order-**independent** because systemd emits properties in its own canonical order, not the requested one — `-p LoadState -p Id` comes back `Id` first (verified), so anything zipping by position would be silently wrong. `Id=` is echoed even for unknown units, so blocks self-identify.
- **The service scan only runs when no reboot is already recommended.** It costs ~1.5s (the whole check goes 1.7s → 3.2s), and if a reboot is warranted anyway, whether a logout would *also* have sufficed is moot. The common post-upgrade path never pays for it.
- **The service scan fails loud too, judged by stdout shape — never by exit status** (added 2026-08-08; before this, a failed scan read as an empty result and produced a false `[ OK ]`). The exit status can't discriminate: the man page documents that `-s` exits 1 for "services need restarting" as well as for its own failures — the same overload the first bullet describes for the main check. What does discriminate is the documented output contract: on success `-s --json` emits a JSON array (`[]` when nothing is stale); on failure stdout is empty with errors on stderr (both measured). So "no array on stdout" → `[WARN]`/rc 2. This matters more here than for the main check, because the `[RELOGIN]`/stale-service verdicts fire rarely *by design* (see below) — a silently dead scan would be indistinguishable from a healthy machine indefinitely. The check binds only to the same man-page contract the `unit` parse already relies on, so it can't break in any way the existing code doesn't already break.
- **Both dnf calls take `</dev/null`; the prompt streams are not a contract (2026-08-09).** After a real 6-minute silent hang: with a tty on stdin, dnf5 blocks on an OpenPGP key-import question for a `repo_gpgcheck=1` repo whose key is missing from the *user-level* cache keyring (tailscale, after `~/.cache/libdnf5` was cleared) — and a pty reproduction showed the question never even flushes through a captured stdout, so the hang is signless. Closing stdin makes blocking structurally impossible. Measured aftermath on dnf5 5.4.2.1: the question lands on *stderr* instead, EOF declines it, and dnf **skips the unverifiable repo and succeeds** — a declined key silently costs that one repo's advisories, by dnf's own choice; it does not fail the check.
- **Repo metadata can vanish; the verdict survives it (the hybrid, 2026-08-09).** Advisories are a documented input, so repos stay enabled — but on any unparseable verdict the check retries with `--disable-repo='*'` (no metadata, no keyring, works with zero cache) and reports the core-package verdict flagged **degraded**: exit codes stay verdict-matched (rc 2 remains "no verdict at all"), and the message shrinks its claim to its evidence ("no core updates or stale services since boot"), carries the failing call's stderr excerpt, and displays its own remedy (`dnf needs-restarting`, run interactively, shows and settles the cause). A degraded REBOOT is certain — advisories only ever add packages to the important set. The service scan runs `--disable-repo='*'` **unconditionally**: the man page defines `-s` by rpmdb facts alone, no advisory input (measured byte-identical, ~1.2s faster, 2026-08-09). Live-verified: cold cache behind a dead proxy → flagged core verdict with the true cause in-line, in 2.9s.

The `-s` check is the one the man page calls "quite aggressive" — on this machine it lists ~23 units, mostly GNOME session ones. That aggressiveness is tolerable *because* of the gating above: those units go stale mainly when systemd or glibc is updated, which already trips the core-package hint, so they rarely reach the `[RELOGIN]` branch on their own. Flatpaks are not consulted at all: sandboxed userspace can't oblige a reboot, at most an app restart.

**Regression suite:** `tests/reboot-verdict/run.sh` (75 checks, ~7 s) covers all of the above with PATH-stubbed `dnf`/`systemctl`/`sudo`/`flatpak` under `$TMPDIR` — every verdict and its exit status, both fail-loud paths, the hybrid fallback (the healthy path leaves repos enabled and never degrades; degraded OK/REBOOT/RELOGIN wording, rc, stderr excerpt, and remedy; the suppressed-prompt incident end to end; the `-s` repo-disable), scope classification (collision, unknown unit, unreachable user manager), dedup and list truncation, `sysupgrade`'s returns-the-chain's-status contract, and the load-bearing `unalias` guard (sourced in a shell that still holds the old alias) — plus a final live section that runs the real `reboot-check` read-only and cross-checks the printed tag against the exit status and this machine's actual dnf JSON. Run it after any edit to the verdict functions in `40-aliases.sh`, or when a dnf5 update makes a verdict look wrong. Mutation-verified in every direction that matters: pre-fix service-scan code fails exactly the fail-loud checks; deleting the `unalias` guard fails exactly the three old-alias-shell checks; disabling the hybrid retry fails exactly the 15 fallback checks; re-enabling repos on `-s` fails exactly 1; silencing the degraded note fails exactly 5; and each of the two `</dev/null` guards is pinned by its own stdin probe. Last line follows the `tests/gsync` convention (`passed: N  failed: M`).

### Disk maintenance pair (added 2026-08-09)

`disk-check` and `disk-fix` in `85-disk.sh`, born of the bigfed ENOSPC incident (2026-08): a TeX Live install died with "No space left on device" while `df` showed 91G free, because every byte of the device was committed to data chunks (~80% full) and btrfs had no unallocated room left for a new metadata chunk. Deleting files cannot help in that state — only a filtered balance returns chunks to the unallocated pool — and nothing was watching, so nothing warned.

**Philosophy (deliberate, discussed 2026-08-09):** automatic *watching* is fine (smartd, the kernel's error counters — passive, already running); automatic *writing* is not. No timers, no background actions, no root in the steady state. The pair replaces scheduled maintenance with a manual gauge + a manual actor.

- **`disk-check`** — one verdict line per subsystem (`[ OK ]`/`[DUE]`/`[FAIL]`/`[WARN]`, reboot-check tag semantics; exit 0/1/2 matching). Checks, per mounted btrfs filesystem: **chunk headroom** (the incident class — unallocated space, with the reclaimable-slack estimate in the warning), **metadata headroom** (folded into the crit verdict: low unalloc + full metadata = "ENOSPC imminent"), **lifetime device error counters**, and **scrub age**; plus **smartd verdicts** greped from the system journal (the daemon's mail path is a black hole with no MTA — this is the missing wire; `--system` is load-bearing, without it journalctl silently shows only the user journal and rc 0 = false OK), and **plain df fullness**. Every btrfs number comes unprivileged from `/sys/fs/btrfs/<uuid>/` — the check never writes, never elevates, and is safe to run on a filesystem already wedged with ENOSPC since it allocates nothing.
- **`disk-fix`** — consults the *same* threshold table (top of `85-disk.sh`), announces the full plan, primes sudo once, then runs only what is due: a filtered data balance (`-dusage=0` then `-dusage=50`) when unallocated is low, a scrub (`btrfs scrub start -Bd`) when none is on record or it is older than 90 days. Nothing due → no sudo, no writes, exit 0. Guarantees: never a full balance, never metadata balance, never defrag, never deletes. After a balance it re-measures and says honestly when the filesystem is *genuinely* filling (balance ran, headroom still low). The scrub date is recorded **only when the scrub comes back clean**, so trouble keeps nagging.

**Thresholds are absolute, not percentages, on purpose**: btrfs needs GiB-scale unallocated room to carve chunks regardless of device size, so one rule serves every machine — fullness changes *when* it fires, never *what* is deployed. Defaults: balance due < 16G unallocated, crit < 4G, metadata crit < 512M, scrub due > 90 days, df warn ≥ 90%.

**State**: scrub dates live in `~/.local/state/disk-maint/scrub-<uuid>` — machine-local per-machine facts, deliberately not synced. A scrub run *outside* `disk-fix` is invisible to the nag (the kernel's own last-scrub record is not reliably readable without root); let the nag drive scrubs through `disk-fix` and the record stays true.

**Portability**: plain-Fedora dependencies only (util-linux, systemd, coreutils, sysfs; btrfs-progs only inside `disk-fix`). Degrades gracefully — no btrfs → chunk checks report that and the rest still runs; smartd off → `[DUE]` with the enable hint; journal or sysfs unreadable → `[WARN]`, never a silent pass. Because `~/.bashrc.d` is stowed as a whole-directory symlink, `gpullall` + `source ~/.bashrc` is enough on another machine — no restow.

**Regression suite:** `tests/disk/run.sh` (59 checks, ~2 s) — PATH-stubbed findmnt/systemctl/journalctl/df/sudo/btrfs against a fake sysfs tree via the `DISK_SYSFS`/`DISK_STATE_DIR` overrides. Covers the exhaustion ladder (healthy → DUE → crit → ENOSPC-imminent), error counters, scrub aging and corrupt-record handling, the fail-loud journal/df/sysfs paths, disk-fix's announce-then-act flow (including that the stub log shows `-dusage=0` before `-dusage=50`), the records-only-on-clean-scrub rule, the no-root and refuse-to-act-blind paths, and — for both commands — that a healthy machine incurs **zero** sudo invocations. Ends with a live read-only run asserting the tag/exit-status contract on the real machine. Run after any edit to `85-disk.sh`.

**Fire drill:** `tests/disk/live-drill.sh` (needs interactive sudo, ~2 min, ~3.5G of writes) is the end-to-end test the hermetic suite cannot perform: it loop-mounts a throwaway 4G btrfs image, lets the *real* `disk-fix` run a *real* balance and scrub against it (real filesystems shielded and asserted untouched), watches the chunk reclaim happen in sysfs, and verifies an md5 manifest of every file afterwards. Run it once per machine for peace of mind, or after any change to the disk-fix action paths.

## Neovim Configuration

LazyVim-based setup. Entry point: `nvim/init.lua` bootstraps lazy.nvim via `lua/config/lazy.lua`.

### Directory layout
- `lua/config/` — core settings (options, keymaps, autocmds, markdown_tasks, pandoc)
- `lua/plugins/` — plugin specs (each file returns a lazy.nvim plugin spec table)
- `lua/plugins/inactive/` — disabled plugins (not loaded by lazy.nvim)
- `lua/snippets/` — LuaSnip snippet libraries (plus the `sty-lua-snippets.py` generator)
- `after/ftplugin/` — filetype overrides (tex.lua is ~200 lines of custom highlight-group colours)
- `after/syntax/` — syntax additions layered on VimTeX (tex.lua: per-family environment-name matches)

### LaTeX toolchain
VimTeX with latexmk compiler and Okular PDF viewer (forward/reverse sync via neovim-remote). The `/tmp/nvimsocket` serverstart in `vimtex.lua` is wrapped in `pcall` — a second Neovim instance would otherwise throw ("address already in use") and abort the entire `init()`, silently dropping every vimtex setting in that instance (this actually happened; found 2026-07-26). Treesitter highlighting is disabled for LaTeX — VimTeX's syntax engine is the sole highlighter.

Custom syntax in `lua/plugins/vimtex.lua` registers 219 literal command names plus 31 regex patterns across 7 semantic highlight groups (axioms, frame conditions, logic systems, semantic notation, modal operators, proof rules, set notation), coloured in `after/ftplugin/tex.lua`; `after/syntax/tex.lua` additionally colours environment *names* by family (theorem-family orange, proof/derivation magenta, list/layout envs keep the default cyan). Measured 2026-07-26 after the coverage overhaul: 504 of the `.sty`'s 509 commands are covered; the 5 exclusions (`\versal`, `\sketchqed`, `\remarkqed`, `\inf`, `\infer`) are deliberate and listed in the `vimtex.lua` header comment.

Three VimTeX API traps, each of which had silently bitten this config:

- Every `vimtex_syntax_custom_cmds` entry **requires `name`** (it derives the syntax-group names); `cmdre` only overrides the match pattern. A nameless `cmdre` entry is **silently dropped** — until 2026-07-26 every pattern registration was dead for exactly this reason.
- `cmdre` patterns are embedded into a very-magic match with **no implicit trailing `>`** — add one whenever a pattern must not prefix-match longer command names (see the de-family entry vs `\defby`).
- `argstyle` accepts only `bold`/`ital`/... keywords, never highlight groups. Argument colouring by group goes through the `arglink()` helper instead, which records the generated arg-group → colour-group links in `vim.g.french_logic_arg_links`; `after/ftplugin/tex.lua` applies them (after the colorscheme, so they survive its `:hi clear`).

Note for testing: custom cmds are applied by VimTeX's `init_custom()`, which runs only once at least one package's syntax loads — a buffer whose project has no recognised packages shows none of the custom colours (headless tests need a `\usepackage{amsmath}`).

**Regression suite:** `tests/nvim-syntax/run.sh` (~5 s, headless, read-only) verifies all of the above — the env-name families, one representative command per registered family, the de-family/`\defby` anchoring, and the argument links. Run it after a VimTeX plugin update or whenever logic highlighting looks wrong; exit 0 means the syntax layer is intact.

### Completion stack (for TeX filetypes)
blink.cmp (UI) → blink.compat (adapter) → cmp-vimtex (source) → VimTeX (scanner). TeX filetypes only use snippets + VimTeX completions (no LSP). Configured in `lua/plugins/completions.lua`.

### Snippets
`lua/snippets/french-logic.lua` (auto-generated from `french-logic.sty` by `sty-lua-snippets.py`; covers commands, `\newenvironment`s incl. optional arguments, and `\newtheorem` environments) and `latex-workshop.lua` (BibTeX templates). Loaded via filetype extensions in `lua/plugins/snippets.lua`.

**Regeneration is automatic**: the generator stamps the `.sty`'s sha256 into the output header (`-- sty-sha256:`), and `snippets.lua` compares stamps when LuaSnip loads — on mismatch it re-runs the generator (with a notification) before snippets load, so completions cannot silently drift from the package. The write goes through the stow symlink into the repo, so the regenerated file is then committed by the next `gpushall` — expected. Manual regeneration still works, and `--check` diffs without writing (exit 1 on drift):

```bash
cd ~/Desktop/configs
python3 nvim/lua/snippets/sty-lua-snippets.py -i latex/french-logic/french-logic.sty -o nvim/lua/snippets/french-logic.lua [--check]
```

The generator also has `--coverage`: it cross-references the `.sty` against `vimtex.lua`'s highlight registrations and lists any command with no registration (exit 1; the 5 deliberate exclusions are allowlisted in `KNOWN_UNREGISTERED`, which mirrors the `vimtex.lua` header). The auto-regen hook runs it whenever the `.sty` has changed and raises a notification, so a newly added macro that lacks highlighting is flagged the next time Neovim starts — purely informational, the macro just renders in the default command colour until registered.

### Markdown tasks
Custom task system in `lua/config/markdown_tasks.lua` with keybindings in `lua/plugins/markdown_tasks.lua`:
- `<localleader>mt` — toggle `[ ]`/`[x]`
- `<localleader>md` — toggle `@done(timestamp)`
- `<localleader>ms` — toggle `@started(timestamp)`
- `<localleader>mD` — toggle checkbox + @done synced
- `<localleader>mc` — insert `- [ ] ` at the cursor
- `<CR>` in insert mode — smart newline (continues checkbox lists)

### Session persistence
`lua/plugins/persistence.lua` auto-loads a session on empty start (`nvim` with no args) for any CWD under `~/Desktop` (a six-repo allowlist until 2026-07-26). Sessions are *saved* per-CWD everywhere regardless — the gate controls only autoload — and `<leader>qs` restores manually anywhere. Bypass autoload with `NVIM_NOSESSION=1`.

**Headless runs neither autoload nor save.** Before 2026-07-26, *any* headless nvim run (test suite, agent probe, script) silently overwrote the session of whatever directory it ran in on exit — this actually clobbered a real session. The guard is an init()-registered `VimLeavePre` autocmd that calls `persistence.stop()` when `nvim_list_uis()` is empty; it must live on VimLeavePre and be registered *before* the plugin loads, because `nvim --headless +qa!` exits before VimEnter ever fires, so a VimEnter-only guard misses the most common scripted invocation. Verified against both headless exit patterns and, via a pynvim `ui_attach` instance, that UI-attached (interactive) saving is unaffected.

### Formatter
stylua (config in `nvim/stylua.toml`: 2-space indent, 100 columns). **It is load-bearing and invisible**: LazyVim's format-on-save runs it (through conform.nvim) on every in-editor save of a Lua file — which the auto-save autocmd makes near-continuous — using the Mason-installed binary (`~/.local/share/nvim/mason/bin/stylua`; **not on the shell PATH**). Hand-written Lua therefore stays formatted automatically; drift appears only in files last written outside Neovim (e.g. by tools/agents). Manual run from repo root: `~/.local/share/nvim/mason/bin/stylua nvim/` (`--check` to diff without writing). The two auto-generated snippet files are excluded via `nvim/.styluaignore`, honored by both the CLI walk and the in-editor path (conform passes `--respect-ignores`), so the generator's output is never reflowed.

Note for headless testing: format-on-save — and everything else LazyVim registers in its `User VeryLazy` callback — is inert under `nvim --headless`, because VeryLazy hangs off the UI attaching. A headless probe that needs those behaviors must fire it manually (`vim.api.nvim_exec_autocmds("User", {pattern="VeryLazy"})`); otherwise "works headless" and "works interactively" can genuinely differ.

## LaTeX Packages

Custom `.sty` and `.cls` files in `latex/` are stowed into `~/texmf/tex/latex`. Key package:

- **french-logic** — 509 commands and 25 environments (counted 2026-07-26; 14 `\newenvironment` + 11 `\newtheorem`) for modal/deontic logic (semantic notation, modal operators, axiom schemas, logic system labels). Single `\usepackage{french-logic}` replaces a 100+ line preamble. Has a `deon` option for DEON conference submissions. **Shared dependency:** sibling repos (`dissertation/`, `dissertation-template/`, `teaching/`, `teach-logic/`) load it from the stowed copy, so edits here ripple into all of them. It is also the source for the auto-generated Neovim snippets — these regenerate automatically on the next Neovim start after a macro change (see Snippets above).
- **bph-paper** — article class with BibLaTeX Chicago style and custom quotation environments
- **logic-hw**, **mod-cv**, **tufte-compact** — homework, CV, and handout classes

## The `bin` package

Everything in `bin/` is stowed to `~/bin` and is on PATH via `20-path.sh`. This is the home for homegrown executables; **pip/npm-installed console scripts stay in `~/.local/bin` and must not be moved here** — their package managers rewrite them on upgrade.

- `tl-newyear` + `tl-{roots,check,compare,visdiff}.sh` — TeX Live release migration. See "TeX Live release upgrades" below.
- `okular-forward` / `okular-inverse` — SyncTeX bridge between VimTeX and Okular. See below.
- `claude-link` — links this machine's Claude Code configuration to the shared copy in `org/claude-config`. See "Claude Code configuration" below.
- `claude-prune` — drops dead weight from the shared per-repo permission lists. Run it after `claude-link --adopt`; see the same section for why that ordering is not optional.
- `claude-collect.sh` — one-shot inventory/collector, written to a flash drive during the 2026-08-20 two-machine merge. Kept because it is the tool for auditing what a machine holds that is *not* synced; re-runnable read-only on either box.
- `sysinfo.sh` — root-run hardware/OS summary generator (`sudo ~/bin/sysinfo.sh`); writes an HTML fragment to a hard-bound `/home/bph/Desktop/sysinfo.html` for pasting into a website, and deliberately omits security-sensitive identifiers (serials, MAC addresses) — keep that property when editing. Moved here from the retired `scripts` repo 2026-08-04.
- `battlog` / `battreport` / `battcal-restore` — battery instrumentation from the 2026-08-11 fedxps pack swap (effectively fedxps-only: all three hardcode `BAT0`, and bigfed has no battery). `battreport` writes a one-shot snapshot — sysfs dump, computed Wh and health, upower, SMBIOS type 22 (wants sudo) — to `~/Desktop/battery-<ts>.txt`; `battlog` is the companion curve, sampling once a minute into a daily CSV until killed; `battcal-restore` undoes a calibration run's temporary settings (`--check` is a read-only audit). Worth knowing from its header: stock `CriticalPowerAction=Auto` resolves to **Sleep** on fedxps, where zram-only swap means no hibernation — so at critical battery the stock setting suspends, then drains to the pack's hard protection cutoff. `--keep-poweroff` keeps the kinder `PowerOff`, and the daemon's actual intent is read with `GetCriticalAction`, never the config file alone.

**`~/bin` also holds untracked files that do not belong in this repo.** `~/bin/isabelle` and `~/bin/isabelle_java` are generated by Isabelle's own installer — `isabelle install ~/bin` writes them (and `mkdir -p`s `~/bin`, which is how the directory first appeared). They hardcode the release path, are regenerated by re-running that one command, and are correctly machine-local, since `~/opt/Isabelle2025` isn't synced either. Leave them untracked. Note the trap in the other direction: `isabelle install` does `rm -f` on its targets, so if a same-named file were ever tracked here, re-running it after an Isabelle upgrade would silently replace the stow symlink with a real file and the next `stow -R bin` would fail with a conflict.

### The Okular SyncTeX bridge

Two halves, and both must agree on the Neovim socket path:

- **Forward** (tex → PDF): VimTeX calls `okular-forward <pdf> <line> <tex>`, configured in `nvim/lua/plugins/vimtex.lua` via `vimtex_view_general_viewer`. The wrapper does two jobs. **Path rebasing:** Okular resolves a SyncTeX source path *relative to the PDF's directory*, so the absolute path VimTeX supplies has to be rebased first or the jump silently does nothing. **Routing:** it finds the tab that already holds the PDF and jumps *into* it, instead of letting Okular replace or duplicate documents — see "Several documents open at once" below.
- **Inverse** (PDF → tex): Okular calls `okular-inverse <file> <line>`, set in `~/.config/okularpartrc` as `ExternalEditorCommand`. It percent-decodes the path and hands it to `nvr` (pip: `neovim-remote`) at `/tmp/nvimsocket` — the same socket `vimtex.lua` opens with `vim.fn.serverstart`. Change one, change the other.

### Several documents open at once — reworked 2026-07-26

The forward wrapper used to end in `exec okular --unique …`. That is why only one PDF was ever viewable: `--unique` makes the running instance **replace** its current document on every call, so compiling a second deck evicted the first. It also bypasses "Open new files in tabs" entirely, which is why toggling that preference appeared to do nothing.

Okular offers only two CLI behaviours and **both are wrong** for a VimTeX loop spanning more than one document:

| invocation | behaviour | failure |
|------------|-----------|---------|
| `okular --unique <pdf>` | reuses one window, replaces the document | deck B evicts deck A |
| `okular <pdf>` | honours the tabs preference, but has **no already-open check** | every forward search into the *same* doc appends *another* tab (measured 1 → 2 → 3) |

So the already-open check is done in the wrapper, over D-Bus. The enabling fact: **each open tab exports its own object** — `/okular`, `/okular2`, `/okular3`, … on service `org.kde.okular-<pid>` — and each answers `currentDocument()`. Calling `openDocument()` on the object that already holds the PDF performs the SyncTeX jump *inside that tab*, creating nothing; `tryRaise()` on `/okularshell` brings the window forward. Only genuinely-unopened documents fall through to the CLI.

Note the service name depends on launch flags: a `--unique` instance claims the well-known name `org.kde.okular`, a normal one registers `org.kde.okular-<pid>`. The wrapper matches both, so a stray `--unique` instance from an older session is still found. A per-document `flock` in `$XDG_RUNTIME_DIR` closes the startup race (two searches fired at a still-launching document would otherwise both decide it is absent). Detection costs ~70 ms.

**Tabs vs. separate windows is not hardcoded** — the wrapper is mode-agnostic and both were tested. Flip it in Okular: Settings → Configure Okular → General → "Open new files in tabs" (`okularpartrc`, `[General] ShellOpenFileInTabs`). Toggle it *through the GUI*, not by editing the file, since Okular rewrites `okularpartrc` on exit and would clobber a hand edit. It governs only where *newly opened* documents land; already-open ones do not rearrange, so close Okular and let the next forward search reopen them.

**Measured limitation, tabs mode:** a forward search into a *background* tab lands on the correct page but does **not** switch to that tab — you get no visible feedback until you switch, at which point it is already in the right place. Confirmed by triggering the exported `file_close` action over D-Bus and seeing which document vanished. There is no clean fix: Okular exports only 11 actions and none is tab-related (it *has* `activateNextTab` / `Switch to Tab %1` internally, just not on the bus); the one call that does activate a tab (`shell.openDocument`) always appends a new one, and `file_close` only closes the *active* tab, so the stale duplicate cannot be cleaned up. Key injection is out too — Okular here is a native Wayland client (`libqwayland.so`, not `libqxcb.so`), so `xdotool` cannot reach it, and `wtype` needs `zwp_virtual_keyboard_v1`, which GNOME does not implement. **Separate-windows mode is the likely fix if the silent jump ever grates, but it is unconfirmed.** There, each document gets its own process and so its own `/okularshell`, and `tryRaise()` was verified to succeed and to target the right window — but whether GNOME actually *raises* it was never tested. Doubt it: the wrapper passes an empty activation token (`tryRaise s ""`), and Wayland focus-stealing prevention will generally refuse to activate without a valid `xdg-activation-v1` token, marking the window as demanding attention instead. GNOME exposes no setting to relax this, and its `Introspect.ActivateWindow` D-Bus route is access-denied. **Settled under Sway on 2026-08-13 — and the answer closes the question rather than fixing it.** The hoped-for knob was sway's `focus_on_window_activation`, on the theory that sway would honour what GNOME refused. It does not apply: sway's **default is `urgent`**, so any activation request that arrives gets flagged urgent — and a recording of sway's `window`/`workspace` event stream across a real forward search into an off-screen Okular showed **zero `urgent=True` events**, alongside no focus change. The request is not being refused by the compositor; it is not reaching it at all. So the knob governs a request that never arrives, and setting it would change nothing.

What *does* work, verified the same day: **the SyncTeX jump itself is fine.** With Okular parked on page 10 and the real wrapper invoked for line 1, the page moved to 1 and the wrapper exited 0. Only `tryRaise` silently no-ops.

**Verdict: deliberately not fixed.** The failure does not occur in the way this machine is actually used (Okular sits beside Neovim on one workspace, so the jump is visible and no raise is needed); it only shows up when Okular is hidden. And every fix that would work costs more than the defect: `swaymsg '[app_id="org.kde.okular"] focus'` in the wrapper *would* raise it reliably — sway focusing its own window needs no activation token — but in the side-by-side layout that pulls keyboard focus out of Neovim on every `\lv`, trading a silent success for a disruptive one. A conditional variant (raise only when Okular is on another workspace) is ~8 lines and permanently couples a compositor-agnostic wrapper to sway, to buy a case that does not arise. If the silent jump ever does grate, the cheaper answer is feedback rather than focus — `notify-send` from the wrapper, which is now non-intrusive since mako auto-dismisses after 5s.

### The `okular` package — and what is deliberately excluded

`~/.config/okularpartrc` **is** stowed (added 2026-07-26), so the `ExternalEditorCommand` above travels with the repo, along with the hand-built `QuickAnnotationTools` toolbar (highlighters on shortcuts 1/2/3, underline 4, insert-text 5, notes 6/7) — the part that would be tedious to rebuild through the GUI — and `ShellOpenFileInTabs=true`, which selects tabs over separate windows for the multi-document workflow above. Everything in that file is durable preference: no paths, no window geometry, no resolution-keyed values.

**Nothing else Okular writes belongs in this repo**, and `.gitignore` guards against it:

- `~/.config/okularrc` — window state plus a `[Recent Files]` list rewritten every session. Under `gpushall`'s `git add -A` that means a commit a day, and since both machines rewrite the same ten lines it would collide on every `pull --rebase=merges`. It also has resolution-keyed `[Print Preview]` sizes, and it names refereeing and teaching PDFs — into a public remote.
- `~/.local/share/okular/docdata/` — ~13MB across ~3,200 XML files of per-document bookmarks, annotations, and page positions. Constantly rewritten, and keyed by filename+size against `~/Desktop/readings/`, which isn't synced — so it would be inert on the other machine anyway.

**`okularpartrc` is the only stowed file that the *application itself* rewrites** — everything else here is written only by an editor. That was the open risk when the package was added, since KConfig saves by atomic replace, which could swap the symlink for a real file and silently un-stow it. **Tested over two write cycles on 2026-07-26 and it survives**, but be precise about the mechanism: KConfig *does* replace-and-rename — the target file's inode changes on each write — it just resolves the symlink first and replaces the file inside the repo rather than clobbering the link in `~/.config`. The link stayed intact, both paths kept reporting the same inode *as each other*, the changed key appeared in the repo file, and every other key was preserved. Toggling a setting back removed its key entirely rather than writing `=false`, so the file returned byte-identical to its prior state.

To re-verify at any time: `[ "$(stat -Lc%i ~/.config/okularpartrc)" = "$(stat -c%i ~/Desktop/configs/okular/okularpartrc)" ]` should hold, and `~/.config/okularpartrc` should still be a symlink.

The practical consequence of replace-and-rename: don't assume anything holding an open file descriptor on the repo copy will see updates, and don't be surprised that `git` reports a whole-file change.

Two consequences. First, changing an Okular preference now dirties the repo, and `gpushall` will commit it — expected, and it only happens on a deliberate change, since this file carries no session state. Second, if Okular settings ever *do* stop syncing after a KDE upgrade, check `ls -l ~/.config/okularpartrc` before anything else; if it is no longer a symlink, move the file back into `okular/` and restow.

**Pulling a change to this file while Okular is running is safe** — tested 2026-07-26 by writing a new key underneath a live Okular and quitting it. KConfig writes back only the keys it changed *that session*, so it merges rather than overwriting, and the pulled value survives. The one caveat is the running process, not the file: it keeps its old in-memory value until restarted, so a pulled preference does not take effect in an already-open Okular.

**Where `okular-inverse` resolves from — measured, 2026-07-26.** Okular finds it via the PATH of whatever launched it, and only one of the two cases works:

- **Launched by VimTeX** (the normal path): inherits the interactive shell's PATH, so `~/bin/okular-inverse` resolves and inverse search works.
- **Launched from the desktop** (app grid, Files, `xdg-open`): inherits the session PATH, which is `/usr/local/bin:/usr/bin` — `gnome-shell`'s actual environ, matching `systemctl --user show-environment`. `okular-inverse` is not found and inverse search silently does nothing.

Neither `~/bin` nor `~/.local/bin` is on that session PATH; both come only from `20-path.sh`, which runs for interactive shells only. So this is a property of how Okular is launched, not of where the script lives — verified by resolving the old `~/.local/bin` location against the same session PATH, which also fails. Moving these scripts into the repo changed nothing either way.

If inverse search from a desktop-launched Okular is ever wanted, the fix is a `~/.config/environment.d/*.conf` adding both directories (`PATH=$HOME/bin:$HOME/.local/bin:$PATH` — expansion confirmed working). Deliberately **not** done: it would give PATH a second source of truth that does not reproduce `20-path.sh`'s TeX-Live-first ordering, so a GUI process and a terminal process could disagree about which `pdflatex` wins mid-`tl-newyear`. Only add it against a concrete failure.

## Claude Code configuration

**The configuration itself is not in this repo — only the mechanism is.** It lives in
`~/Desktop/org/claude-config/`, which is private; this repo carries `bin/claude-link`,
which links it into place. Same split as `tl-newyear`, whose 13GB TeX tree also lives
outside any repo.

The reason is positional rather than per-file: **publicity is a property of location.**
This repo is public, so anything in it is public, and deciding case by case which
Claude memory or permission entry is safe to publish is a judgment that will eventually
be got wrong. Putting the whole lot somewhere private removes the judgment. The
2026-08-20 merge vindicated that immediately — it found a live Carnap instructor API key
captured inside two saved `Bash(...)` permission entries.

Set up before this, the two machines had **zero** memory files in common and `fedxps`
had no global `CLAUDE.md` at all.

### What is linked

Around sixty symlinks — the exact count moves as repos come and go, so ask
`claude-link` rather than trusting a number written here. All point into
`org/claude-config`; all are created by `claude-link`:

| what | where it lands |
|---|---|
| `CLAUDE.md`, `settings.json`, `plans/` | `~/.claude/` |
| `agents/ commands/ skills/ hooks/ output-styles/ rules/ workflows/` | `~/.claude/` |
| `memory/<scope>/`, one per project scope | `~/.claude/projects/<scope>/memory/` |
| `repos/<path>/settings.local.json`, one per repo | `<repo>/.claude/` |

Everything else in `~/.claude` — transcripts, `history.jsonl`, `file-history/`,
`sessions/`, caches, `plugins/`, `.credentials.json`, about 62MB — stays machine-local
and untracked. Transcripts are excluded permanently: large, unmergeable append-only
JSONL, and the `teach-logic` ones contain exam material.

Repo `CLAUDE.md` files are **not** touched. They document their repo and must version
with it.

### Commands

```bash
claude-link              # dry run — says what would change, changes nothing
claude-link --apply      # create the links
claude-link --adopt      # first run on a machine that already has its own memory
claude-link --unlink     # reverse it; keeps the merged content

claude-prune             # dry run over the shared permission lists
claude-prune --apply     # drop the dead weight, logging each drop to PRUNED.txt
```

**`claude-prune` must follow the first `--adopt` on each machine, and this is not
optional.** Adoption is deliberately *lossless*: it unions the machine's own permission
list into the shared one and cannot know which entries were previously dropped on
purpose, so the first adopt re-admits every one of them — **including a secret**. Both
live runs proved it: bigfed went 1637 → 1878 on adopt and back to 1637 on prune, fedxps
1637 → 1811 → 1637. Landing on the same number from two different directions is the
evidence that both passes are deterministic. Afterwards there is nothing local left to
re-admit, and `claude-prune` reports `0 of N` forever.

Prune rules: `secret` (a `NAME=value` credential, **or a bare high-entropy literal** —
that second rule exists because a name-based scan missed `Bash(printf %s '<key>')`),
`literal-pid`, `pid-echo`, `tmp-file`, `tracked-var`, and `subsumed` (an exact command
already covered by a wildcard in the same list). Every drop is appended to `PRUNED.txt`
with its rule; re-approving one in a session simply adds it back.

It is a script rather than a bash function on purpose: a pull can never leave a stale
copy loaded in a running shell, which is the trap `stow-all` has with `60-stow.sh`.
`stow-all` covers this repo only and does not touch Claude configuration.

### Measuring which entries still earn their place

`claude-prune` only catches what is mechanically dead. Deciding whether a *live* entry
is still worth carrying is a measurement, and the transcripts hold the evidence. This
is the procedure used on 2026-08-20 to take 1628 entries to 92; repeat it when the
list has drifted again.

**The corpus** is `~/.claude/projects/<scope>/*.jsonl` — one directory per project
scope, machine-local and untracked, so each machine holds only its own history. Each
line is a JSON message; tool calls appear as `tool_use` blocks inside `message.content`.
Take `input.command` from the ones named `Bash`, and `input.file_path` from `Read`.

**Split the sessions by permission mode**, because the answer differs sharply either
side of the line. Scan each transcript for a `permissionMode` field at any depth and
count the session as auto mode if any occurrence is `auto`. Auto became the default
here on 2026-08-10; before that the modes were `default` and `acceptEdits`, where an
allowlist genuinely does suppress prompts. Only the auto-mode sessions answer the
question being asked.

**Drop the rules auto mode strips before computing anything.** On entering auto mode,
Claude Code removes "classifier-bypassing" allow rules — `Bash(*)` and any rule whose
prefix is an interpreter or shell (`python`, `node`, `bash`, `sh`, `ssh`, `perl`,
`eval`, `exec`, `env`, `xargs`, `sudo`, `npx`, `npm run` …) — and restores them on
exit. Skip this step and the results invert: the single most-matched rule in the
2026-08-20 pass was one auto mode had already stripped, so it never fired at all.

**Count a rule as fired** if its content matches a command. Parse `Bash(<content>)`;
content ending `:*`, ` *` or `*` is a prefix match, anything else an exact match. Match
`Read(<glob>)` against the path with `fnmatch`. Two numbers are worth having: what
fraction of *commands* a rule covered, and what fraction of *rules* ever fired — in
that pass 3.9% of rules had ever fired, because a handful of broad prefixes did all
the work.

**Two things will inflate the coverage number if you skip them, and together they
inflated it tenfold.** Split each command on `&&`, `||`, `;` and `|` and require
**every** sub-command to be covered, not any one of them — Claude Code allows a
pipeline only when all of it is allowed. Then net out the built-in read-only command
list, which is auto-allowed in every permission mode and owes nothing to the
allowlist:

```
ls cat head tail wc stat grep egrep fgrep diff du df echo strings hexdump od nl
cut column tr tac rev cmp basename dirname realpath readlink sha256sum sha1sum
md5sum cd
```

Measured loosely, the 2026-08-20 pass showed rules covering 9.3% of commands. Measured
strictly and net of the built-ins: 10.2% of commands were entirely built-in and free
regardless, **zero** were covered by allow rules alone, 11.1% ran without the
classifier via built-ins and rules together — so the allowlist's marginal contribution
was **0.9%**. Two of the three rules that appeared to do all the work, `Bash(grep:*)`
and `Bash(cd *)`, are on the built-in list and were never doing anything. The built-in
list is also why a shell-prefix allowlist for read-only utilities is not worth
writing: almost everything a sane one would contain is already there.

**Read rules need one extra step**: reads inside the session's own project root never
need a rule, so compare each path against the scope's root first and count only the
out-of-root ones. Two thirds of reads were in-root, and the whole `/dev`, `/proc`,
`/sys`, `/etc`, `/usr`, `/var` group turned out never to have been touched by the Read
tool at all — those trees are reached through Bash, which Read rules do not govern.

**Three caveats, all of which understate what should be cut.** It sees auto-mode
sessions only, so it says nothing about how a list would behave if the mode changed
back. Transcripts are per-machine, so a rule granted on the other box looks unused
here — run it on both before deciding, or treat a zero as "unused on this machine".
And the matcher above is an approximation of Claude Code's real prefix extractor,
which parses command trees and resolves sub-commands; it over-counts matches, never
under-counts them — by a wide margin if the two corrections above are skipped.

### It maintains itself

Two hooks in `settings.json`, both living in `org/claude-config/hooks/`:

- **`SessionEnd`** runs `claude-link --auto`. Anything the session created that the
  shared copy lacks — a memory scope for a directory used for the first time, a new
  repo's permission file — is absorbed and linked, ready for the next `gpushall`.
  `--auto` is deliberately narrow: it acts **only** where nothing could conflict,
  refuses to write into a repo that is mid-rebase, prints nothing, and logs to
  `~/.claude/claude-link-auto.log`. Anything needing a decision waits for `--adopt`.
  Measured 191 ms on bigfed, 23 ms of that the `~/Desktop` scan (849 directories).
- **`SessionStart`** reports the machine name and warns if `CLAUDE.md` or
  `settings.json` has stopped resolving into `org/claude-config`, or if memory scopes
  remain unadopted. No `python3` dependency, sets its own `PATH`, escapes its output,
  15 ms.

  **The two output channels are not interchangeable, and getting this wrong makes the
  check useless.** `additionalContext` is documented in the binary as *"Text injected
  into model context"* — the user never sees it. `systemMessage` is *"Display a message
  to the user"*. The health check emitted only `additionalContext` until 2026-08-20, so
  a broken link warned the assistant and nobody else. Warnings now go to both.

**A deleted shared file leaves a dangling link on the other machine, and the link
passes cannot see it** — they iterate `org/claude-config`, so a link whose target is
gone is never visited. It matters beyond untidiness: a dangling path still fails an
`O_NOFOLLOW` write, so it keeps blocking "don't ask again" even though the file it
pointed at was deliberately removed. `claude-link` sweeps these, but only links that
point *into* the shared config — foreign symlinks are never touched. Hit on 2026-08-20
when a curation pass deleted seven emptied permission files on one machine.

**Ephemeral scopes are excluded, and this was a real bug.** Claude creates a project
scope for whatever cwd a session runs in — including the per-session scratchpad under
`/tmp/claude-1000/…`. `--auto` harvested one into the repo on 2026-08-20, and after it
was cleaned up by hand it recurred the same day. `claude-link` now skips any scope whose
mangled name begins `-tmp-`, `-var-tmp-`, `-run-`, `-dev-shm-` or `-private-tmp-`, in
both the harvest and the link pass. Without the guard, six checks in `tests/claude`
fail.

**Conditional rules key on `paths:`, not `globs:`** — and getting it wrong fails
*silently*. `globs` is only the internal field name; a rule file that uses it loads
unconditionally with no error at all. Verified live against 2.1.238: with `paths:`, a
`.txt` read leaves a LaTeX rule out and a `.tex` read pulls it in, deterministically
across four runs. Patterns are gitignore-style, matched against the path relative to the
project root. One consequence worth designing around: a conditional rule fires on **file
access**, so a session that runs `latexmk` without first reading a `.tex` never loads it
— anything that must always bind belongs in an unconditional rule file regardless.

**Verifying the hooks actually fire is not obvious, because a healthy run is
indistinguishable from no run at all** — `SessionEnd` is silent by contract and
`SessionStart` emits nothing when everything resolves. Both were confirmed live on
2026-08-20, and these are the two checks to repeat if a Claude update ever makes them
look inert:

- **`SessionEnd`**: open a session, close it, and check that
  `~/.claude/claude-link-auto.log` gained a `--- <timestamp> <host> auto ---` entry.
  Three quick open/close cycles produced exactly three entries.
- **`SessionStart`**: break one link on purpose — `rm ~/.claude/CLAUDE.md` and put a
  plain file there — then open a session. The `systemMessage` should appear in the UI,
  not merely in the model's context. Restore with `claude-link --apply`. Do **not**
  infer this one from `SessionEnd` working: they are separate entries, and a healthy
  `SessionStart` is silent, so a malformed one fails invisibly.

A third trigger lives outside Claude entirely: **`_gsync_pull_hints` in
`50-git-sync.sh` runs `claude-link --auto` when a pull or rebase changes
`claude-config/`**, and says so on the same `[HINT]` channel as the `configs:` hints.
It fires for `gpullall`, `gpull org`, `gpushall` and `gpush org` alike, because both
per-repo helpers call it. This closes an edge case the SessionEnd hook cannot: a memory
scope pulled from the other machine had nothing linking it until some session happened
to end, so working in that scope first would create a real directory and a conflict.
The `|| true` on that call is load-bearing — `claude-link` exits 1 when it makes
changes, which under `set -e` would abort the pull.

Together these close both directions: local work is harvested up, and a scope pulled
from the other machine is linked down at the next session start. The steady state is
`gpullall` … work … `gpushall`, with no Claude-specific command at all.

### The lists are frozen once linked — measured, not inferred

A repo's `.claude/settings.local.json`, once it is a symlink into `org/claude-config`,
**can no longer be written**. Claude Code's settings writer opens with `O_NOFOLLOW`
unless `allowSymlink` is set, and that flag is set only for `~/.claude/settings.json` —
never for a repo's local file. So "Yes, and don't ask again" silently fails to persist
in any linked repo.

Verified 2026-08-20 by controlled experiment, after three earlier attempts failed on
test design rather than on the mechanism:

| repo | symlinked | same command, same prompt choice | grant persisted |
|---|---|---|---|
| `LogiKEy` | no | `curl …` → "don't ask again for: curl *" | **yes** |
| `opuscula` | yes | identical | **no** |

Both transcripts show the command running, so approval happened in both cases; only
the write differed. The control is what makes it a result — an earlier run without one
produced "no grant" for the mundane reason that the wrong prompt option had been
chosen.

Three traps that made this hard to test, each worth knowing on its own:

- **A built-in read-only command list is auto-allowed in every permission mode.** The
  list, and what it does to the coverage figures, is in "Measuring which entries still
  earn their place" above — kept in one place because two copies would drift.
- **A command with no side effect at all runs freely** regardless of mode — `uname -a`
  is not on that list and still never prompts.
- **Not every prompt yields a rule.** `touch /tmp/x` offers "grant access to /tmp",
  which is a session-scoped sandbox grant and persists nowhere. Only a command-shaped
  prompt — "Yes, and don't ask again for: `curl *`" — writes to `permissions.allow`.
  Note that Claude Code proposes the **wildcard** itself, which is how broad grants
  like `Bash(git *)` and `Bash(scp *)` accumulated.

Consequence: the seven repos whose permission file was deleted in the 2026-08-20
curation are the only ones where a grant can still land — and each stops accepting
them the moment `SessionEnd` harvests the first one and links it.

### The deny block, and what it does not reach

`settings.json` carries `permissions.deny: ["Bash(git commit:*)", "Bash(git push:*)"]`.
Only those two, deliberately: auto mode's own `Git Destructive` soft-deny already
covers force-push, branch deletion and history rewrite, and its `Git Push Destination`
**allow** rule is why an ordinary push needed denying — the classifier permits what
CLAUDE.md forbids, and an instruction is not a machine guard.

Verified live 2026-08-20: `git status --short` runs unprompted, `git commit --dry-run`
and `git push --dry-run` are both refused as *"blocked by the permission layer"*, and
the assistant declined in both cases to reshape the command to dodge the matcher —
the classifier is separately told to catch exactly that circumvention.

Two limits worth knowing. It is a **hard block, not a prompt**: asking for a commit
explicitly does not get one, and the escape hatch in `CLAUDE.md` is therefore
aspirational — undo is deleting the two lines. And matching is **prefix-based**, so
`git -C <path> commit` does not match `Bash(git commit:*)`. Denying `Bash(git -C:*)`
would fix that but would also block `git -C … status`, which is explicitly allowed, so
the gap is left open and `CLAUDE.md` remains the backstop for intent.

### Two gitignore rules carry weight

`~/.config/git/ignore` (machine-local, so it is *not* in this repo — keep both machines
in step by hand):

- `**/.claude/settings.local.json` — the per-repo permission cache. Symlinked into
  `org/claude-config`, so it must never be committed to the repo it sits in.
- `**/.claude/projects/` — a **superseded** memory location. Claude wrote memories to
  `<repo>/.claude/projects/` in early 2026; `Carnap/` still holds a set from
  2026-03-30 that had never left that machine, since `Carnap` is not in
  `REPOS_DESKTOP`. Nothing stops it recurring, and in a public repo `git add -A`
  would publish them.

### Regression suite

`tests/claude/run.sh` (92 checks, ~15 s, sandboxed under `$TMPDIR` with a fake `HOME`,
fake `org/claude-config` and fake `~/Desktop`; no network). Covers preflight refusals,
dry-run inertness, linking, idempotency, adoption (union not overwrite; differing files
backed up and skipped; conflicting memories kept side by side), harvest, `--auto`'s
narrowness and silence, the busy-repo guard across all five in-progress git states,
`--unlink`, foreign symlinks, both hooks including hostile-hostname JSON escaping and the
`systemMessage`/`additionalContext` split, and that the gsync hint fires on a new scope
but not on a mere edit.

Mutation-verified. Note one honest result: removing the explicit scope-directory
`mkdir` changes **no** test outcome, because `link_one` creates the parent itself. The
stow-style folding hazard is structurally absent here — the link target is always
`<scope>/memory`, never `<scope>` — and pointing it one level up does fail 7 checks.

## TeX Live release upgrades

TeX Live is installed from the CTAN mirrors (not RPM), under `/usr/local/texlive/YYYY`.

**`tlmgr` cannot cross a release boundary.** It updates packages *within* a release — which it does continuously, since the tlnet repo refreshes daily — but refuses year-to-year upgrades by design. Crossing a year means a **parallel install**: the new release goes in alongside the old, both are verified to produce identical output, and only then does PATH move. Multiple releases coexist happily.

**`tl-newyear` (in the `bin` package) automates this.** Stages are separate subcommands because there is a human go/no-go decision in the middle:

```bash
tl-newyear status              # installed releases, which is active, baseline on file
tl-newyear preflight           # disk + btrfs headroom check
tl-newyear baseline            # fingerprint every document on the CURRENT release
tl-newyear install 2027        # parallel install; does NOT touch PATH
tl-newyear compare 2027        # recompile, diff against baseline
tl-newyear visdiff <doc.tex>   # pixel-compare one document across releases
tl-newyear switch 2027         # migrate symlinks, only after a clean compare
```

State (root lists, fingerprints, per-run logs and PDFs) lives in `~/.cache/tl-newyear`; the helper scripts are `tl-roots.sh`, `tl-check.sh`, `tl-compare.sh`, `tl-visdiff.sh`. Builds always go to that state tree via `-output-directory` — never in-place, because `teach-logic/` and `opuscula/` track their build artifacts and an in-place recompile would dirty tracked PDFs.

The procedure it implements, in order:

1. **Baseline first.** Compile every document on the *current* release and record page counts plus a `pdftotext | md5` fingerprint. Without this you cannot tell "the new release broke it" from "it was already broken."
2. **Check btrfs headroom.** The root filesystem is btrfs, and a `scheme-full` install writes ~180k files. If `btrfs filesystem usage /` shows little **Device unallocated**, the install dies with `No space left on device` *even though `df` reports plenty free* — free space inside already-allocated data chunks cannot be used for metadata. Fix with `sudo btrfs balance start -dusage=0 /` then `-dusage=50 /`. This bit the 2025→2026 upgrade.
3. **Install with `instopt_adjustpath 0`** so `/usr/local/bin` symlinks (~500 of them) keep pointing at the old release and the old toolchain stays active.
4. **Re-compile and diff** against the baseline. Expect many `pdftotext` hash changes that are *not* regressions — newer releases fix glyph-to-Unicode mappings, so logic symbols extract correctly where they previously came out as garbage. Confirm with a pixel comparison (`pdftoppm` + `compare -metric AE`) rather than trusting the text hash.
5. **Switch** with `tlmgr path remove` on the old release then `tlmgr path add` on the new. `20-path.sh` picks up the new year automatically. Keep the old tree until confident.

**Known casualty: the *forall x* textbook.** `tabu` v2.9 (unmaintained since 2019) patches `array.sty`'s internals, and `array` was rewritten in TL2026 (`1995/06/01` → `2026/06/01`). This breaks all `forallxyyc*` builds in `teach-logic/` with `TeX capacity exceeded [grouping levels]`, and shifts the solutions documents by one page. `tabu` is used nowhere else — the dissertation, `opuscula/`, `org/`, `teaching/`, and `n-cube/` are unaffected. Until upstream *forall x: Calgary* migrates to `tabularray`, build the textbook pinned to the old release:

```bash
TEXLIVE_YEAR=2025 make      # in any forallx-yyc-build/ directory
```

A pin naming a release that isn't installed **warns** (interactive shells only) and is otherwise ignored — PATH gets no TeX Live entry and commands fall through to the `/usr/local/bin` symlinks, which point at whichever release is active. So a pin only works on a machine that still has the pinned release.

### Rolling a release out to the second machine

The scripts and dotfiles travel in git; the ~13GB TeX Live tree does not. Order matters:

```bash
# on the machine that already upgraded
gpushall

# on the other machine
gpullall
source ~/.bashrc            # MUST precede stow-all -- see below
stow-all
tl-newyear status
tl-newyear preflight
tl-newyear install <year>
tl-newyear switch <year>
source ~/.bashrc
```

**Why the re-source must come first.** `stow-all` iterates `STOW_ORDER` / `STOW_TARGETS` as loaded in the *running shell*. A pull that adds a **new** stow package (as `bin` was) updates `60-stow.sh` on disk but not the arrays in memory, so `stow-all` skips the new package **silently** — no error, it simply isn't in the list being iterated. Applies to any newly added package, not just this one.

**Re-verifying on the second machine is optional.** TeX Live is deterministic given the same inputs, so a release verified on one machine behaves the same on the other. Run `baseline` + `compare` there only to catch machine-specific divergence — a different `~/texmf`, or repos sitting at a different commit. If you do, `baseline` must run *before* `install`, since it fingerprints whichever release is currently active.

**Revision drift between machines.** Two machines installing the same release on different days get different tlnet snapshots, so package versions differ slightly. Harmless in general, but run `tl-upgrade` on both before generating a final dissertation PDF so the output doesn't depend on which machine you happened to use.

**`~/.cache/tl-newyear` is machine-local** — per-machine fingerprints plus ~130MB of build artifacts. Deliberately not synced, and shouldn't be.

## Sway/Waybar

Sway uses vim-style navigation (hjkl). Mod4 (Super) is the primary modifier. Waybar config is JSON + `style.css`. The binding grammar is stated at the top of `sway/config` itself — read that before adding a binding, and note that every motion is bound for **both** vim keys and arrow keys, deliberately.

**Sway is a `fedxps` -only environment (confirmed 2026-08-13).** `bigfed` runs a multi-monitor setup that sway does not suit, and sway is never booted there. So the sway/swaylock/mako packages are effectively single-machine, cross-machine drift is not a concern for them, and laptop-specific settings in them need no guard. (This is why `waybar/config` can hardcode `"device": "intel_backlight"` without consequence, and why the touchpad block and `$mod+m` need no no-touchpad fallback.)

**`fedxps` dual-boots GNOME and Sway, so check which compositor is live before testing anything here.** `pgrep -x gnome-shell` / `pgrep -x sway` settles it; `swaymsg` fails confusingly under GNOME. Much of this repo's sway work was done from a GNOME session against `sway --validate` plus a headless nested sway (see "Verifying a sway config" below), which covers everything except what needs a real seat — locking, lid behaviour, and anything cursor- or notification-related.

**The two bars do not share an accent, on purpose.** Sway's focused-window border is dodger blue (`$accent`, `#0088FF`); Waybar's active workspace is still forest green (`@accent`, `#228B22`). `sway/config` also defines `$forest #228B22`, unused, kept so the old accent can be swapped back in one word — don't "clean it up."

Note `$mod+b` is a launcher here (Brave), not upstream sway's horizontal split; splits live on `$mod+Ctrl+h` / `$mod+Ctrl+v`. `$mod+v` was a VS Code launcher until 2026-08-09, when VS Code was uninstalled and the binding removed — the key is now **free**, and deliberately not rebound to the vertical split, so the split pair stays uniform under `$mod+Ctrl`.

`waybar/config` hardcodes `"device": "intel_backlight"` — laptop-specific, and harmless given sway is `fedxps`-only.

**One urgent colour across the whole desktop.** `#d08770` is now the "something needs you" signal in four places: sway's `client.urgent` (via `$urgent`), Waybar's urgent workspace and `#battery.critical`, mako's `[urgency=critical]` border, and swaylock's wrong-password ring. Changing it means changing all four — they are deliberately not derived from one another, because they live in four different config languages.

**`"interval"` in Waybar's clock is load-bearing if the format shows seconds.** It defaults to **60**, and Waybar polls on the minute — so `%T` rendered its seconds field as `00` permanently and the clock looked frozen rather than slow. `"interval": 1` fixes it (verified by diffing two `grim` captures of the clock region 1.6 s apart). This is the whole explanation for "GNOME ticks, Sway doesn't"; nothing about the format string was wrong.

**Low-battery notifications come from Waybar itself, not a daemon.** `waybar-battery(5)`'s `events` object runs a command on entering a state (`on-discharging-warning` / `on-discharging-critical`), which is the mechanism the man page's own example uses for exactly this. So there is no timer, script, or background process to maintain — the module was already polling. The critical one is sent at `urgency=critical`, which mako is configured to keep on screen until dismissed.

Note `{icon}` in a Waybar format requires a `format-icons` array of glyphs from an icon font. The battery module used `{icon}` with no such array until 2026-08-13, so it silently rendered nothing. This bar is deliberately all plain text — no icon font is installed — so `{icon}` was dropped rather than fed.

**Waybar format strings take libfmt width specifiers, and that is the clean way to stop the right-hand modules reflowing.** `{capacity:>3}%` right-aligns the number in a 3-character field, so `0%`, `20%` and `100%` all render as a constant 4 characters. Combined with the monospace font that makes each module a fixed-width slot, so a value changing digit count no longer shoves its neighbours sideways — the same property that makes the clock sit still, achieved the same way (constant string length) rather than via CSS `min-width`. Applied to `pulseaudio`, `backlight` and `battery` on 2026-08-13.

Worth knowing for the general case: GTK3 accepts `px`, `em` and `rem` for `min-width` but **rejects `ch`**, so a character-grid width cannot be expressed in CSS here — which is the other reason the format-string route is better. Source Code Pro's advance is exactly `0.6em` (measured: 8.89 px at 11pt ≈ 14.67 px), if a px calculation is ever needed.

**A CSS parse error makes Waybar exit, and nothing tells you why.** Learned the hard way on 2026-08-13: an invalid property *value* in `style.css` left the session with **no bar at all**, and sway did not bring it back. The journal is no help — it logs `Using CSS file …` and then simply stops, with no error line and no coredump. So the failure looks like "the bar vanished", not "the stylesheet is wrong". **Parse-check before reloading**, which needs no display and no bar:

```bash
python3 -c 'import gi;gi.require_version("Gtk","3.0");from gi.repository import Gtk;Gtk.CssProvider().load_from_data(open("waybar/style.css","rb").read())'
```

Silence means it parses. This matters because Waybar is sway's bar (`swaybar_command`), so the blast radius of a typo here is the whole status bar.

**Waybar is GTK3, and its CSS dialect is narrower than the web's.** Measured with the checker above: `font-feature-settings: "tnum"` is **accepted**, the CSS-spec form `font-feature-settings: "tnum" 1` is **rejected** ("Junk at end of value"), and `font-variant-numeric: tabular-nums` is not a recognised property at all. Don't assume a property that works in a browser works here.

**The bar is monospace (Source Code Pro), matching WezTerm and Alacritty.** Adopted 2026-08-13, replacing the inherited GTK default (Adwaita Sans 11). The reasoning: the bar is almost entirely numbers — a clock and three percentages — so fixed advance widths suit its content, and aligning it with the terminals is a more useful allegiance than aligning it with GTK apps. Bar height was unchanged at 27px, so nothing reflowed. Reverting is deleting one `font-family` line.

This also fixed an inconsistency introduced the same day: `tnum` had been applied to `#clock` only, so the centre of the bar had tabular digits while the right-hand percentages stayed proportional. Monospacing the whole bar makes that uniform, and leaves `tnum` redundant — it is kept anyway, documented in-line, precisely so that dropping `font-family` is a safe one-line revert rather than a silent return of the jitter.

**The clock uses tabular figures for a measured reason.** With the default proportional font, the rendered time string changed width as the seconds ticked (145 ↔ 146 px), and because `clock` sits in `modules-center` that width change became visible horizontal jitter — the clock wobbled once a second. `font-feature-settings: "tnum"` on `#clock` gives every digit one advance width; re-measured across 8 consecutive seconds the string is now a constant 155 px at a constant offset. Monospacing the module would also have worked but would have changed the typeface; this does not.

### Locking: swaylock + swayidle (added 2026-08-13)

**The lock is `before-sleep` only — it is not an idle timer, and that distinction is the whole design.** `sway/config` ends with `exec swayidle -w before-sleep 'swaylock -f'`, which has **no `timeout` clause**, so it structurally cannot blank or lock during work. It exists to close one measured hole: logind's default `HandleLidSwitch=suspend` applies, so closing the lid suspends, and before this change reopening returned straight to an **unlocked** desktop (verified by closing the lid and reopening it). Screen blanking and idle timers remain declined — see "Deliberate omissions".

- **`-w` (swayidle) with `-f` (swaylock) is the pairing the swayidle man page prescribes**, and both halves are load-bearing: `-f` detaches only once the screen is actually locked, and `-w` makes swayidle hold logind's inhibitor until that returns — so the machine cannot suspend with the desktop still on screen. logind caps that wait at `InhibitDelayMaxSec` (5 s here, read from `InhibitDelayMaxUSec` on the bus); swaylock comes up well inside it.
- **`exec`, not `exec_always`** — a reload must not spawn a second swayidle. The consequence to remember: `swaymsg reload` does **not** start it, so after editing you must either re-login or run it by hand for the current session.
- **Lock on demand is `$mod+Ctrl+l`**, not `$mod+l` — `l` is `$right`. This is the same collision that moved the exit binding off `$mod+Shift+l` on 2025-11-10.
- **The `swaylock` package exists so the two call sites stay in sync.** swaylock is invoked from both the keybinding and the before-sleep hook; inline colour flags would drift, so both are a bare `swaylock -f` and everything cosmetic lives in `swaylock/config`.
- **An unrecognised key makes swaylock exit**, which means *no lock at all* rather than a visibly broken one — a fail-open direction that is easy to miss. Every key in `swaylock/config` was checked against `man 1 swaylock` (54 documented long options) for that reason; re-check after a swaylock upgrade.
- PAM is already correct on Fedora (`/etc/pam.d/swaylock` is `auth include login`, and non-setuid swaylock authenticates via the setuid `unix_chkpwd` helper). Verified live: password unlock works.

### Notifications: mako (added 2026-08-13)

**mako's `default-timeout` defaults to `0`, which means notifications never expire.** That is why the NetworkManager "Connection Established" popup used to sit on screen until clicked. `mako/config` sets `default-timeout=5000`.

`ignore-timeout=1` is set alongside it and is **not redundant**: `default-timeout` only applies when the sender expresses no preference, so an application that asks to persist forever (`expire_timeout=0`) would still persist. `ignore-timeout` makes our policy win. The one case where persisting is correct is given back by a `[urgency=critical]` criteria section setting `default-timeout=0`.

mako is **not** launched from `sway/config` — it is D-Bus activated via `/usr/share/dbus-1/services/fr.emersion.mako.service`, so it starts on the first notification and needs no `exec` line. It does **not** watch its config: apply changes with `makoctl reload` (exit 0 means accepted).

### The launcher: wofi (styled 2026-08-13)

`$mod+a` runs `wofi --show drun`. It went unstyled until 2026-08-13, which is the whole reason it looked like a stray GTK dialog rather than part of the desktop — there was no config at all, so it ran on bare defaults.

wofi is GTK3, the same toolkit as Waybar, so **the same narrow CSS dialect applies** (no `ch` units, no `font-variant-numeric`, `"tnum" 1` rejected) and the same parse-check is the way to verify a change before trusting it:

```bash
python3 -c 'import gi;gi.require_version("Gtk","3.0");from gi.repository import Gtk;Gtk.CssProvider().load_from_data(open("wofi/style.css","rb").read())'
```

Palette and typeface deliberately match `waybar/style.css` — black, Waybar's forest-green `@accent` (not sway's blue), Source Code Pro, and a 3px border echoing sway's `default_border pixel 3`.

Three behavioural settings matter more than the styling, and each fixes a real annoyance in bare wofi:

- **`matching=fuzzy` + `insensitive=true`.** The default is a literal, case-*sensitive* substring match, which is most of why stock wofi feels obstinate — `gimp` will not find "GNU Image Manipulation Program" without this.
- **`no_actions=true`** suppresses per-app `.desktop` actions ("New Window", "Private Browsing"), which roughly triple the list length.
- **`hide_scroll=true`** removes a gutter that otherwise shifts the text; keyboard scrolling is unaffected.

Deliberately no icons (`allow_images=false`), matching the text-only Waybar — no icon font is installed. `image_size` is set anyway so enabling them is a one-word change. Every key was validated against wofi(5)'s 63 documented options; the CSS node names (`#window`, `#input`, `#entry`, `#text`, …) come from its CSS SELECTORS section.

wofi reads its config at launch, so there is nothing to reload — just run it again.

### Verifying a sway config (2026-08-13)

**`sway --validate` does not check the command body of a `bindsym`** — measured, and the reason a config can validate clean and still be broken. `bindsym $mod+Escape totallynotacommand` exits 0; the same bogus word as a top-level directive exits 1 with `Unknown/invalid command`. Sway defers binding commands to execution time, so a typo there fails **silently at runtime**, with no error anywhere. Validate does cover everything else, including stat-ing the `output bg` path (a bad wallpaper path is a hard load error, not a silent fallback).

Two checks that close the gap:

- **One command:** `swaymsg -- '<the command>'`. Distinguish the two failure classes in the reply — `Unknown/invalid command` is a real config bug; `Can't move an empty workspace`, `Cannot resize nothing`, `Scratchpad is empty` are *state* complaints that prove the command parsed and reached semantic evaluation.

  **Automating that discrimination is trickier than it looks, and both obvious approaches are wrong** (found by mutation-testing `tests/desktop/run.sh`, 2026-08-13). Grepping the raw reply for `Unknown/invalid command` **never matches**: sway's IPC JSON escapes the slash, so the bytes actually read `Unknown\/invalid command` — a check written that way passes vacuously forever. And the `parse_error` field is **not** a discriminator either: sway sets `parse_error: true` for pure state failures too (`Scratchpad is empty` arrives with it set), so keying on it flags every valid command as broken. What works is decoding the JSON first and matching the decoded string:

  ```bash
  swaymsg -- '<cmd>' | jq -r 'any(.[]?; (.error // "") | test("Unknown/invalid command"))'
  ```
- **The whole file:** load it in a headless nested sway, which works fine from a GNOME session:
  ```bash
  WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 SWAYSOCK=/tmp/sway-test.sock \
    sway -c /path/to/test.conf &
  SWAYSOCK=/tmp/sway-test.sock swaymsg -t get_tree     # then swaymsg exit
  ```
  **Strip `include /etc/sway/config.d/*` from the copy you test first.** That include runs `/usr/libexec/sway-systemd/session.sh`, which sets `XDG_CURRENT_DESKTOP=sway` and `XDG_SESSION_TYPE=wayland` in the **live** systemd user and D-Bus environment — i.e. a test run would reach out and reconfigure the GNOME session you are sitting in. Strip startup `exec` lines too. All 83 bindings were verified this way on 2026-08-13: zero parse errors.

**swaynag button flags are not interchangeable, and the difference is silent.** Only `-z` / `-Z` dismiss the nag; `-b` / `-B` run their action and **leave the bar on screen**. A "Cancel" button built with `-b ... 'true'` therefore does nothing visible — which is what `$mod+Shift+Escape` did until 2026-08-13. There is always a built-in dismiss button; `-s <text>` only renames it, so `-s 'Cancel'` is the correct way to get a working Cancel. Prefer `-B` over `-b`: `-b` routes its action through `$TERMINAL` when that variable is set (it is unset on both machines, so `-b` happened to work).

**Waybar is launched as sway's bar (`bar { swaybar_command waybar }`), deliberately.** Sway respawns it if it dies and there is no duplicate-process problem on reload — the failure mode `exec_always waybar` has. The price: sway's own bar settings (`position`, `mode`, `hidden_state`, colors, font) are **dead config**, because Waybar ignores sway's bar protocol and reads `~/.config/waybar/config` instead. Sway currently believes that bar is `position: bottom, mode: dock` while Waybar renders at top. Nothing is wrong, but anything added to that `bar {}` block will silently do nothing — change Waybar's own config. This is also why `$mod+w` toggles visibility via `killall -SIGUSR1 waybar` rather than sway's `mode hide`. Sway appends `-b bar-0` to the command; Waybar ignores an unmatched bar id (verified — byte-identical startup with and without).

**Regression suite:** `tests/desktop/run.sh` (24 checks, ~10 s) covers all five desktop configs — sway, waybar, swaylock, mako, wofi. It exists because this subsystem's failure modes are *silent and catastrophic*: a CSS typo removes the whole bar, an unknown swaylock key means no lock at all, and `sway --validate` ignores binding commands entirely. So the suite validates the sway config, rejects duplicate chords, checks every binary a binding names, **executes every non-exec binding command against a headless nested sway** (the gap validate leaves), parses both GTK3 stylesheets and the waybar JSON, validates every swaylock/mako/wofi key against that machine's own man pages (so it tracks the installed version rather than a snapshot), and holds the cross-config wiring in place: the `#d08770` urgent colour across all four languages, the two identical `swaylock -f` call sites, the absence of a `timeout` clause in the swayidle line, and agreement between the two `60-stow.sh` arrays.

Two self-guards worth knowing: the CSS checker is proved non-vacuous by feeding it known-bad CSS, and the whole suite was mutation-verified — eleven single breaks, each caught by exactly its own check. Run it after editing any of the five configs.

**The nested-sway config copy must have three things stripped, and the third one caused a real outage.** `include /etc/sway/config.d/*` (rewrites the live systemd/D-Bus environment) and startup `exec` lines are the obvious two. The third is the **`bar { swaybar_command waybar }` block**: a nested sway spawns its own Waybar, and attached to a headless compositor it cannot draw on, one was measured growing to **9.2 GB RSS / 34 GB virtual** and tripping the kernel OOM killer (2026-08-13, during a 12-iteration mutation run). The damage was not confined to the bar, because `assign-cgroups.py` had placed that Waybar in the **terminal's** systemd scope — so the OOM kill took down the whole WezTerm scope and closed every window in it (`app-org.wezfurlong.wezterm-….scope: Failed with result 'oom-kill'`). The suite now strips the bar block, asserts the stripped copy contains no `swaybar_command`, and asserts it leaks no processes; re-verified afterwards across 12 runs with a peak Waybar RSS of 57 MB. **General lesson: a test that starts a compositor starts everything that compositor's config starts.**

### Deliberate omissions in `sway/config`

Recorded in the config's own "Deliberate omissions" section so they aren't "fixed" later, and repeated here because they read as gaps:

- **No idle timers and no screen blanking.** The screen stays on until dimmed by hand, because sway sessions here are long stretches of focused work — the same posture as leaving Caffeine on under GNOME. This is a standing decision, not an oversight, and the swayidle line in `sway/config` does **not** contradict it: that line has no `timeout` clause at all, only `before-sleep`, so it structurally cannot blank or lock mid-work. See "Locking: swaylock + swayidle" above for what it does do — and note the lid hole it closed is no longer open.
- **No tabbed or stacking container layouts.** Unbound since 2025-11-10 — the bindings were clunky and the feature goes unused, since every app that needs tabs brings its own (WezTerm, browsers, Okular). Independent of `workspace_layout default`, which only governs how *new workspaces* start.
- **No clock on the lock screen.** Mainline swaylock has none: `--clock` / `--timestr` / `--datestr` belong to `swaylock-effects`, a separate fork, so a real clock would mean replacing the packaged binary. Instead `indicator-idle-visible` keeps the ring on screen, which answers the actual question ("is the lock up, or is the machine off?") without a fork. Username and session detail are deliberately not displayed.

## Visual Consistency

TokyoNight "night" theme across Neovim, WezTerm, and Waybar. Source Code Pro 12pt font in both terminals (WezTerm, Alacritty). Alacritty carries font settings only — no colorscheme — so it falls back to its own default palette rather than TokyoNight.

## Pitfalls

- **`stow-all` does not auto-adopt.** It restows (`stow -R`); a pre-existing untracked file at a target makes it error out, not overwrite. Resolve with `stow --adopt` or by removing the file (README §8), then rerun.
- **Never edit a stowed file in place *through the live path*.** `sed -i`, and any tool that saves by write-temp-then-rename, **replaces the symlink with a regular file** — silently un-stowing it, after which repo and live copy drift apart with no error. This bit `~/.config/okularpartrc` on 2026-07-26. Edit the file under `~/Desktop/configs/` instead (a real file there, so in-place tools are safe), or pass `sed --follow-symlinks`. Note this is the *opposite* of how KConfig behaves — Okular resolves the symlink first and rewrites the repo copy, which is why `okularpartrc` survives Okular's own writes but not a careless `sed -i`. To check: `[ "$(stat -Lc%i ~/.config/okularpartrc)" = "$(stat -c%i ~/Desktop/configs/okular/okularpartrc)" ]`.
- **Public repo + `gpushall` runs `git add -A`.** Anything no ignore rule refuses is committed and pushed to a public remote. `.gitignore` grew from three path-specific rules to hygiene groups (editor/OS scratch, secret-shaped filenames, LaTeX/Python build artifacts) on 2026-08-17, out of the public-exposure audit behind TODO.md item 7 — its own comments record the reasoning. It still matches whole files by name: a secret pasted into a tracked file, or private data under an innocent name, ships regardless. Don't park secrets, private data, or large binaries here expecting them to be skipped. Note also that stow's default ignore list covers only `README.*`, `LICENSE.*`, `COPYING`, VCS dirs and `*~` — **not** `*.bak` or `*.save` — so an ad-hoc backup left in a package is still symlinked into the live config tree; `.gitignore` keeps it off the remote, stow does not keep it out of `~/.config`.

- **`latex/mod-cv/` shadows TeX Live's moderncv.** The 36 vendored `moderncv*.sty` files (plus `tweaklist.sty`) are pinned v2.3.1 and are load-bearing for the `mod-cv.cls` fork (it loads them by their upstream names) — they can't be deleted. But because `~/texmf` outranks `texmf-dist`, they also override TeX Live's copies for anything using `\documentclass{moderncv}`, which on TL2026 means a v2.6.1 class over v2.3.1 sub-packages. See `latex/mod-cv/README.md`.
- **`french-logic.sty` is a shared, snippet-coupled dependency** — editing it affects the dissertation/teaching repos. The generated snippet file no longer desyncs silently (auto-regenerated on next Neovim start), but the vimtex highlight registrations are still maintained by hand. See the LaTeX Packages section before touching it.
- **Adding files to a package needs a restow** (`stow -R <pkg>`) to create the new symlinks; editing already-linked files does not.
