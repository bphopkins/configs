# CLAUDE.md — bash package

Charter for the `bash` stow package: the modular shell configuration stowed to
`~`. `.bashrc` sources every `~/.bashrc.d/*.sh` in numbered order, and
`~/.bashrc.d` is a whole-directory symlink into this package — so `gpullall` +
`source ~/.bashrc` deploys edits on the other machine with no restow. A restow
(`stow -R bash`) is needed only when files are added or removed at the package
top.

`.bash_profile` sources the two environment modules, `10-env.sh` and
`20-path.sh`, before `.bashrc` (2026-09-23). A login shell reads it, and the one
GDM starts for a **GNOME** session is a login shell whose environment the whole
graphical session inherits — so that is how desktop-launched apps get the
personal PATH and `EDITOR` there, and how bigfed's session sheds Lmod's
`BASH_ENV` (once: that manager lingers, and the upload never removes a
variable it already holds, so the first deployment needs
`systemctl --user unset-environment BASH_ENV` or a reboot). A **sway** session
gets no login shell from GDM and none of this (measured on both machines,
2026-09-28 and 29; the gap is `TODO.md` item 29). `.bashrc`'s early return still keeps `ssh host cmd` and scripts cheap. Both modules are
idempotent, so the interactive pass re-sourcing them is a no-op. Takes effect
at a login. **Run `tests/env/run.sh` after any edit to `.bash_profile`,
`10-env.sh`, `20-path.sh` or `environment.d/`**: it pins the login shell's
output and the `environment.d` generator's, caged in its own systemd scope.
**And `tests/shell-opts/run.sh` after any edit to `00-shell-opts.sh`**: the
same cage, interactive shells against the real system layer, a sandboxed
history file. **And `tests/prompt/run.sh` after any edit to `30-prompt.sh`**:
the rendered prompt in every shape a shell here takes, through both terminal
integrations. The cage the three share is `tests/cage.sh` (2026-09-23).

## Module map (sourced in numbered order)

- `00-shell-opts.sh` — the history contract and four shell options
  (2026-09-23; a reserved empty slot until then). History: 20,000 entries in
  memory and on disk — `HISTFILESIZE=40000`, because assigned at startup the
  file limit counts lines, two per dated entry — `%F %T` timestamps, `exit`
  and `clear` ignored, `ignoredups`, and a `history -a` after every command
  as a `PROMPT_COMMAND` *array element*, the form that survives bash-preexec
  (it rewrites element 0 at the first prompt). The file is trimmed at every
  shell start and never at exit, which has nothing left to save. Options:
  `globstar`, `checkjobs`, `no_empty_cmd_completion`, `histverify`. The
  file's comments carry the measurements and the declined options
  (`erasedups`, `ignorespace` — dead under bash-preexec — `lithist`,
  `autocd`, `cdspell`, `history -n`). ⚠ `~/.bash_history` now carries a
  `#<epoch>` line per entry: count commands by skipping `#` lines. Suite:
  `tests/shell-opts/run.sh`.
- `10-env.sh` — environment variables (`EDITOR`/`VISUAL` = nvim;
  `NPM_CONFIG_PREFIX`, which replaced the hand-made `~/.npmrc` on 2026-09-23),
  and the `unset BASH_ENV` that disarms Lmod (2026-09-21). Lmod arrives as a hard
  dependency of Singular, so the package cannot be removed; its
  `/etc/profile.d/modules.sh` points `BASH_ENV` at Lmod's init script, which
  bash then sources at the start of **every non-interactive shell that
  inherits it**: a terminal's `bash -c` and scripts, and the GNOME session's,
  which carries it from its own profile pass — but not `ssh host cmd`, which
  runs no profile (measured 2026-09-21). ~10 ms a spawn, ~7% on
  `tests/gsync/run-all.sh`. `modules.sh` sets it only when
  unset and `.bashrc` sources `/etc/bashrc` before this directory, so
  unsetting here is the whole fix. `module`/`ml` are unaffected: they are
  exported shell functions and survive into child shells on their own.
  Since 2026-10-10 it also exports `GIT_OPTIONAL_LOCKS=0` when either host
  file the sync commands read — `configs/git/hosts/<hostname>.inc`, the
  hostname short and lowercased, or the file `~/.config/git/host.inc` points
  at, which is what git reads — names this machine a reader (`gsync.role`
  anything but `writer`) or names a reader repository (`gsync.readerRepo`,
  the pilot's `nousowl`), or exists but cannot be read or parsed, or the
  link dangles: the environment half of fedxps's reader guard, which keeps
  `git status` from rewriting `.git/index` on a copy Syncthing delivered
  (`org/machines/transport-2026-10/rules.md` → fedxps-1; the config half is
  the link, see "Git sync"). Never on bigfed, where it would make
  `gpushall`'s `add -A` re-stamp pack files. Never unset here: a role change
  takes a new login, and reaches only shells and sessions started after it.
  About 1.3 ms a shell with a host file present. Suite: `tests/env/run.sh`.
- `20-path.sh` — PATH/MANPATH/INFOPATH additions, duplicate-guarded. Each
  entry prepends, so **effective priority is the reverse of reading order** —
  TeX Live ends up first, `~/bin` last of the personal dirs. **TeX Live is
  auto-detected, not hardcoded**: the newest `/usr/local/texlive/YYYY` that
  contains a working `tlmgr` (half-installed trees are skipped, so a parallel
  install in progress can't knock TeX Live off PATH). Pin an older release
  with `TEXLIVE_YEAR=<year>` — see `bin/CLAUDE.md`, TeX Live release
  upgrades. The bun block is a guarded shim, inert until bun exists. Sourced
  from `.bash_profile` too, so a GNOME session carries the same PATH in the
  same order (a sway session does not: item 29); this file is PATH's one author.
- `30-prompt.sh` — writes PS1 in full (2026-09-23): a reset, bold and the
  machine colour on `\u@\h`, a plain colon, bold and colour on `\w`, a reset,
  `\$ ` — the shape Fedora's bash-color-prompt package gave it, now stated
  here. Until that date the module only filled two of the package's
  `PROMPT_*` variables, and the prompt's shape depended on the package's
  activation test (PS1 still Fedora's, and `COLORTERM` or a colour `TERM`);
  the package still runs from `/etc/bashrc` and its template is overwritten,
  since its disable switch would have to be set before `/etc/bashrc` is read
  (`TODO.md` item 25). Bold is pinned because the package decided it by a
  string comparison against `DESKTOP_SESSION` — the reason bigfed and fedxps
  looked different off the same repo. The colours are, since 2026-09-20,
  **truecolor hexes off the terminal palette** rather than ANSI indices: the
  three are machine identities, and an index is by construction the same
  colour as everything else that asks for it. fedxps `#73daca` mint, bigfed
  `#ff5fd1` rose, nousowl `#ff9e64` orange — one per gap in the hue circle
  TokyoNight's sixteen leave open — with root on the package's magenta behind
  an EUID guard, an unregistered host on the package's green, and each host's
  old index as the `$COLORTERM` fallback, so a VT console still gets a
  colour. `NO_COLOR` gives bold alone. **The scheme spans two repos**:
  nousowl's half lives in that machine's own
  `configs/bash/.bashrc.d/30-prompt.sh`, deployed by `./configs/install.sh`
  over ssh rather than by stow, and the two halves are kept in step by hand.
  The file's comments carry the derivation, the measurements and the declined
  alternatives; the record is `DECISIONS.md`, 2026-09-23. Suite:
  `tests/prompt/run.sh`, after any edit here.
- `40-aliases.sh` — aliases plus functions: `bye` and `byebye` (see "Leaving
  a machine" below), `sysupgrade` and `reboot-check`
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
  requires `clamav` + `clamav-freshclam`). Its PUA detection flags benign
  browser/dev content — read hits skeptically.
- `85-disk.sh` — `disk-check` / `disk-fix`. See "Disk maintenance pair" below.
- `90-nix.sh` — nix profile loader, guarded twice: on nix being installed, and
  on `NIX_PROFILES` being unset. **Load-bearing on bigfed** (nix since
  2025-03-05; this file is the only thing putting it on PATH, and it exports
  `NIX_SSL_CERT_FILE`, without which substituter fetches fail TLS). An inert
  no-op elsewhere, so one file is correct on every machine — same guarded-shim
  pattern as the bun block. ⚠ The second guard is load-bearing in its own
  right (2026-09-21): upstream's `nix.sh` is **not idempotent**, so re-sourcing
  it in a nested shell grew PATH, MANPATH and `XDG_DATA_DIRS` without bound —
  measured at 2, 3 and 4 copies at nesting depths 1, 2 and 3. `20-path.sh`'s
  duplicate guards cannot reach it, because the growth happens inside a vendor
  file this module only sources; guarding the *source* fixes all three at once.

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
  `--tags`, so a force-moved remote tag can't wedge every future pull). On a
  writer; a reader refuses, see the first guardrail below
- `gpushall [-m MSG]` — stages (`git add -A`), vets new paths, commits,
  `pull --rebase=merges`, pushes every repo. Remote commits integrated by the
  rebase are reported (`[PULL] integrated changes from origin`) and fire the
  configs hints — the push path is never silently ahead of what you saw. A
  legacy positional message is accepted and joins all words; unknown flags are
  rejected so `gpushall -f` can't commit every repo in the rotation with the message `-f`
- `gpull <name>...` / `gpush [-m MSG] <name>...` — the same flows for one or
  more repos under `~/Desktop`; names tab-complete from `REPOS_DESKTOP`
- `gstatall [-f]` — read-only dashboard: branch, dirty count, behind/ahead,
  and a STATE verdict in words that composes every applicable flag
  (`needs push` / `needs pull` / `DIVERGED` / `uncommitted` / an in-progress
  op), so dirty work is never elided by a sync verdict. Plain runs read the
  last fetch; `-f` fetches first while still pushing and pulling **nothing**.
  The safe first move whenever the machines may be out of step

Guardrails, shared by the single- and all-repo variants:

- **The machine's role (2026-10-10)**: Syncthing carries each repository,
  `.git` included, between the machines, and bigfed alone commits and pushes
  (`org/machines/transport-2026-10/rules.md` → fedxps-2). The tracked host
  file `configs/git/hosts/<hostname>.inc` says which this machine is, read
  two ways and a reader if either says so: by hostname (short, lowercased),
  not through the link `~/.config/git/host.inc` that git itself reads, so a
  rebuilt fedxps refuses before its link exists; and through that link, so
  the sync commands never disagree with git when the hostname is not what
  the file is named for (an FQDN, a container; warned about). On a reader
  (`gsync.role` present and anything but `writer`, so a typo fails safe),
  `gpullall` and `gpushall` refuse with one line and touch nothing, `gpull`
  and `gpush` refuse each named repository, and `gstatall -f` fetches
  nothing while plain `gstatall` still runs, every row marked `reader`.
  `gsync.readerRepo = <name>` (repeatable) refuses that repository alone
  while the rest are still written — the pilot's `nousowl`, armed at the
  seeding's step 1: `gpushall` and `gpullall` skip it with one
  `[SKIP] … refused` line naming what carries it and the hub-outage route
  (him-5). No host file, or no role: a writer, which is what anyone else
  using this repo gets; a host file git cannot parse or read, or a dangling
  link, makes a reader, with a warning, and a `readerRepo` value naming no
  repository of `REPOS_DESKTOP` is warned about. The files are read once per
  command, from `/` (`git config -f` still discovers a repository from the
  working directory) and with their includes, and a repository is matched by
  its top level's canonical path, so `gpush nousowl/`, `./nousowl`,
  `nousowl/sub` and a symlink to it are refused like `gpush nousowl`. The
  refusal sits in the per-repo helpers, before any git
  command that could write runs there — it reads the remote URL, for the
  clone command it prints. `gstatall` passes `--no-optional-locks` for the
  rows this machine reads and never for the writer's, whose refresh is what
  keeps bigfed's `add -A` from re-stamping packs; the index half of the guard
  otherwise rides in fedxps's environment and git config (`10-env.sh`,
  `git/hosts/fedxps.inc`), not here.
- **A Syncthing conflict copy refuses the repository's push (2026-10-10)**:
  a path matching `*.sync-conflict-*` among the staged paths (new or
  modified; a staged deletion is the remedy) or among the tracked files
  anywhere in the tree (one committed by another route) makes the vet refuse
  that repository outright — `[FAIL]`, no prompt, no override — naming each
  copy and the remedy: keep the right text in the original, delete the copy,
  `git rm` a committed one (`rules.md` → ws-5, him-2). The staged copies and
  every file the vet would have declined (a secret, an oversize file) are
  unstaged, without a prompt, so a commit made by any other route afterwards
  carries none of them. The rest of the batch still pushes.
- **The push gauge runs before anything is staged (2026-10-10)**: `gpush`
  and `gpushall` run `sync-check push -q` on each repository before its
  `add -A` (`rules.md` → bigfed-2; the gauge is `bin/sync-check`,
  `bin/CLAUDE.md`). For a repository Syncthing carries that means the folder
  up to date on both machines and the hub, nothing under its `.git` needed
  in any view, no phantom ref or conflict copy under `.git`, and the other
  workstation at the same HEAD when it answers; a repository in no
  Syncthing folder passes at once and in silence, which today is all of
  them. A refusal (exit 1) skips the repository — `[SKIP] … the push gauge
  refused` with the gauge's own lines, which name the repair — and the rest
  of the batch still pushes; there is no override, since the repair is the
  way through. A cluster that cannot be read (exit 2: the hub, this
  machine's Syncthing or the other workstation unreadable) pushes this
  machine's own state under a `[WARN]` that shows the gauge's lines, his
  word of 2026-10-10 (the campaign's `PLAN.md` → settled 34): nothing from
  the other workstation can arrive meanwhile, it writes no `.git`, and a
  skip would only leave GitHub's copy ageing for the outage. A machine
  without the gauge on `PATH` pushes with one hint naming `stow-all`,
  because refusing every push for a missing tool would stop the backup —
  except a repository with a Syncthing marker (`.stfolder`) at its root or
  above it, the one case the gauge exists for, which is skipped. On a pass
  the gauge's one line for a carried repository prints unindented above
  the repository's own. Suite: `tests/gsync/test-role.sh`, section 5,
  against a stub gauge; every suite stubs it, since the real one reads this
  machine's Syncthing.
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
  `nvim --headless "+Lazy! restore" +qa`). The stow hint's package list is
  the repo's top-level directories on disk (minus `docs`, `tests`,
  `wallpapers`) unioned with `STOW_ORDER`, so a brand-new package — absent
  from the array this shell loaded, since the pull has only just rewritten
  `60-stow.sh` — is reported like any other (blind to it until 2026-09-23;
  found 2026-09-03 when `ghostty` arrived on bigfed; `DECISIONS.md` item 10).
  The change list is parsed
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

**Regression suite:** `tests/gsync/run-all.sh` (418 checks in five suites,
sandboxed under `$TMPDIR`, no network). Run it after **any** edit to
`50-git-sync.sh`, and after an edit to `git/hosts/`, whose files the role
suite reads. Each suite also runs standalone and tests the checkout it
lives in; `tests/gsync/README.md` has suite scope and the harness conventions
new suites must follow (`passed: N  failed: M` last line, registration in
`run-all.sh`, a `uname` stub so the machine's own host file never reaches a
suite, a `sync-check` stub so the real gauge never does).

## Leaving a machine (`40-aliases.sh`, added 2026-10-10)

`byebye` powers off and `bye` suspends, each only once the Syncthing gauge
reads every folder this machine shares up to date. `byebye` is his usual
leaving of either machine and is one function on both; `bye` is for the
laptop when he suspends it by command rather than closing the lid, which he
rarely does (`org/machines/transport-2026-10/rules.md` → bigfed-3, him-3;
built at the pilot's seeding, `pilot/seeding.md` there, kept on his word).
Both run `sync-check sync`, show its lines, and write one line — the reading
and the verb — into this machine's own file of the pilot's log,
`org/machines/transport-2026-10/pilot/log-<hostname>.md` (one file per
machine: two machines appending to one git-synced file would be a merge
conflict; `LEAVE_LOG_DIR` overrides the directory, and a machine without it
logs nothing and acts). `byebye` also refuses while `git maintenance` runs or
its lock stands under a rotation repository, since a power-off cuts a repack
short (bigfed-1); `bye` skips that, a suspend cutting nothing. The process is
matched by argv — `git` then `maintenance` — never by a command line carrying
the words: a Claude session's own wrapper did, and read as a repack
(2026-10-10). Flags: `-f` leaves whatever the gauge says, logged as forced;
`-i` is systemctl's `--ignore-inhibitors`. Without the gauge on PATH they act
as the plain commands did, with one hint. A reading of WARN (exit 2, the
cluster unreadable) refuses like a FAIL: away from the hub, `bye -f` is the
honest form. The old `byebye` alias was `systemctl poweroff` alone, and an
`unalias byebye` line stands before the definitions, as for `sysupgrade`: a
shell still holding that alias would otherwise alias-expand the name in the
definition at `reload` and die with a syntax error, losing every alias after
it in silence (reproduced and closed 2026-10-10; the suite's last case).

**Regression suite:** `tests/leave/run.sh` (53 checks; caged), with
`systemctl`, the gauge, `uname` and `ps` stubbed and the log in a sandbox:
the suspend and the power-off on OK, the log's header and lines, the refusal
on FAIL and on WARN with the gauge's line in the log, `-f` and `-i`, usage on
a bad flag, the maintenance process and the stale lock on a power-off and
their irrelevance to a suspend, no gauge on PATH, no log directory. Run it
after any edit to these two.

## Reboot verdict (`40-aliases.sh`, added 2026-08-08)

`sysupgrade` (dnf upgrade + autoremove + flatpak update/uninstall-unused —
mark keepers with `dnf mark user <pkg>`, autoremove runs `-y`) ends by
printing whether the upgrade earned a reboot; `reboot-check` runs the same
verdict standalone, unprivileged. It is the only updater: GNOME Software's
automatic download (`org.gnome.software download-updates`) is off on both
machines since 2026-09-23, after it had been staging and arming the same
updates in the background; the function's comment carries the story and the
warning line that means it is back on. The signal is `dnf needs-restarting` from
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
