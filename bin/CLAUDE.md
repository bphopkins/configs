# CLAUDE.md — bin package

Charter for `bin/`, stowed to `~/bin` (on PATH via `20-path.sh`, except in
a sway session started without `sway/wayland-session.desktop` installed—
`TODO.md` item 29). This is the
home for homegrown executables, and since 2026-09-07 `~/bin` holds nothing
else: **pip/npm-installed console scripts stay in `~/.local/bin`** — their
package managers rewrite them on upgrade — and launchers for locally installed
tools (Isabelle, the provers) are symlinks in `~/.local/bin` as well, pointing
into `~/opt/<Tool>` or `~/src/<tool>` (the tool-homes convention; inventory in
`org/machines/bigfed/provers-2026-06/`). Never point `isabelle install` at
`~/bin`: it does `rm -f` on its targets, so a same-named *tracked* file would
have its stow symlink silently replaced, and the next `stow -R bin` would fail
with a conflict.

## Inventory

- `tl-newyear` + `tl-{roots,check,compare,visdiff}.sh` — TeX Live release
  migration; see below.
- `okular-forward` / `okular-inverse` — the SyncTeX bridge; see below.
- `context-check` — read-only gauge for the Claude configuration tree, in the
  `disk-check` shape: nineteen verdict lines, exit 1 on a fault, 2 on
  could-not-determine, every FAIL naming its repair. The half of that tree's
  integrity a script can decide; `/restore-order` judges the prose and calls this
  first. Since 2026-10-12 its last ten lines watch the ground the routines
  stand on: premises about Claude Code, read from the installed binary (a
  literal anchor, then the value beside it; the binary is never started), from
  the server switches cached in `~/.claude.json`, and from the last 14 days of
  transcripts (`CONTEXT_CHECK_DAYS`). A FAIL there has no command: it names
  the texts that rest on the premise and its row in the inventory,
  `org/claude-config/context-order-2026-10/battery/dev-4-rented-ground.md`,
  and `/restore-order` files it as `moved-premise`. The version the gauge last
  ran against is his to record in `org/claude-config/claude-version-checked`;
  the gauge prints the line, and offers none where the record is newer than
  the install, since that machine catches up at its next update. When the
  installed version differs from the record, the SessionStart hook runs
  `context-check --binary` (checks 11 to 15 alone, 0.33 s) and tells him only
  when one fails or cannot be read (2026-10-18). The anchors are the vendor's
  strings; nothing of the configuration is in this file. Suite:
  `tests/context-check/run.sh` (150 checks, caged since 2026-10-12: a stub
  binary that would mark itself if started, a stub flag cache and stub
  transcripts, each premise mutated).
- `sync-check` — read-only gauge for the Syncthing cluster and the git roles,
  in the `disk-check` shape (2026-10-10, step 3b of
  `org/machines/transport-2026-10/PLAN.md`, record `pilot/build-gauge.md`;
  completed 2026-10-26 at step 5a, record `cutover/tools.md`; the rules it
  reads are that directory's `rules.md` → ws-1, ws-2, ws-8, fedxps-3,
  bigfed-1, bigfed-2, hub-1, hub-4, him-2). Seven lines: `sync` (every folder
  this machine shares is up to date — a blocking scan, then the local status,
  this machine's view of the hub, and over batch-mode ssh the hub's view of
  both workstations and, when the hub shows the other workstation owing or
  needing something, that workstation's own view, since the hub holds
  ciphertext and names what it needs opaquely; a need that outlives a 15 s
  settle with every folder idle is stranded, named with him-2's repair —
  where both workstations list one path towards the hub, the vector of the
  path names the losing machine, the one whose counter the current version
  lacks, its repair an edit there, or a `touch` for a path under a
  repository's `.git`, never an edit (2026-10-27, settled 79; the two fixes
  for needs that do not arrive split their paths the same way), and a path
  under a repository's `.git` names him-2's split repair
  when it is stranded on the writer (the touch on the reader — and for a
  path that is a directory here, which a touch does not move, its
  permissions changed and set back there, the second sanctioned reader
  write, his word of the same day; the push line's fix says the same — then the
  phantom on the writer, `sync-check push <repo>` naming each step; for a
  path absent here, a deletion the hub refused while it held the reader's
  copy first, the reader's touch and then the deletion here again, its own
  line) and the
  reader's own `guard` line when it is stranded on the reader, never an
  edit, the two machines read from this one's role (2026-10-27, settled 80),
  and with no reading of the role a text naming no machine and no delete,
  `sync-check push <repo>` on the writer naming the repair
  — while a transfer still running is `WAIT`; a known stuck item is
  carried by name in `KNOWN`, and `DUE` says when it no longer shows, or when
  a folder's watcher is dead), `conflicts` (one `find` over `~/Desktop` and
  every folder path: copies under a `.git` and stale locks there FAIL, copies
  in a directory that loads FAIL, the rest DUE), `guard` (on a reader: the
  host link, every key of the host file resolving through it, the refusing
  hook present and executable where the host file names a `core.hooksPath`
  (the restow is its fix),
  `GIT_OPTIONAL_LOCKS` as the role requires, no write seen under a `.git`
  this machine reads in Syncthing's disk events — kept from the daemon's
  start, the last 1,000 — and, since 2026-10-26, every file and directory
  under each such `.git` read from the database with its version vector,
  which FAILs on this machine's counter, a write the disk events forget at
  the next daemon start (a repository nested deeper than one level below
  `~/Desktop` or a folder's top lies outside it, a named gap: fifteen in
  `ModalLogic/.lake` on 2026-10-27, settled 77); `KNOWN_WRITES` carries an explained write by
  machine and counter on any path, `path` optional and narrowing, since a
  counter never leaves a vector and returns on a path git deletes and
  writes again, and each vector FAIL prints the entries to paste, one per
  counter, as Python literals; a counter-keyed entry no path shows is a
  `DUE` only once its counter is older than the 10,920 h a workstation
  keeps a deleted record (2026-10-27, settled 79); on a writer, no
  `maintenance.lock` under any Desktop repository and no running `git
  maintenance`, the subcommand read past `-C`, `-c`, `--git-dir` and their
  kin, since `git -C <repo> maintenance run` is the fix line's own shape),
  `push REPO…` (bigfed-2: the folder up to date, nothing under
  the repository's `.git` needed in any view, no phantom ref or conflict copy
  under `.git` (either beside needed `.git` paths makes the fix the touch
  that clears the hub's loser, then the phantom repair: settled 79; refs git
  cannot list make it say a phantom could not be ruled out; a needed path
  absent here gets the refused deletion's text, as on the sync line), the
  other workstation's HEAD equal when it answers, and the
  age of what GitHub lacks; a repository in no Syncthing folder passes,
  silently under `-q`, unless a `.stfolder` marker sits at or above it, which
  is `WARN`; a workstation the hub shows asleep blocks nothing, what the hub
  lists for it being what it lacks; and, from 2026-10-26's adversarial read,
  every file and directory under the repository's `.git` read live from
  this machine's database, a FAIL when any carries another workstation's
  counter beyond `KNOWN_WRITES` — the discard half of a refused `checkout`
  or `reset` on the reader, which the hook cannot stop and Syncthing
  carries here), which `gpush` and `gpushall` run before
  `add -A`: exit 1 skips the repository, exit 2 pushes with the warning
  shown, exit 3 pushes with the DUE shown and hinted, and each reading is
  logged (`bash/CLAUDE.md` → Git sync); `hub` (2026-10-26, hub-4 and hub-1:
  over one ssh running this file's `--remote-hub` mode on the hub, btrfs's
  Free (estimated) of the sync volume with the growth commands below 10 GB,
  every hub folder's pull and folder errors, the index's size as a DUE past
  2 GB (settled 83, 2026-10-27), and the retention drop-in both in the unit's
  `DropInPaths` and in the running daemon's environment); and `config`
  (2026-10-26, ws-8: every stow package's entries linked at their target
  with no dangling link into `configs`, by stow's own ignore list — a
  dangling link under a target three levels deep included — the fix a
  `stow -R`; the installed plugins'
  HEADs against the shared lock on both roles, since a reader's own copy is
  rewritten by lazy's install pass and would read OK behind an arrival (the
  code review's H1); the `claude-link` dry run exiting 0 with no `[WARN]` or `[FAIL]` line,
  since it exits 0 over unlinked configuration too; `bash -n` on every
  module), and `session` (the session hook's since 2026-10-27, settled 76
  and 77: `org/claude-config/hooks/session-start.sh` runs it under `timeout
  4`, all clear to the model alone as `2 folders up to date by the newest
  full reading, byebye 9 h ago`, anything else to both channels, a cut
  naming the lines printed before it; each folder's newest full reading
  reprinted from the reading file below, ` (the newest full reading, by
  byebye 9 h ago, before this boot)` after the message on each tagged
  line, so an OK line still begins
  `<label>: up to date`, and `WARN <label>: no full reading on record` for a
  folder with none or with one another device took (a reading file carried
  to the other machine), a record dated more than 60 s ahead of the clock a
  `WARN` of its own, and one older than seven days (`READING_MAX_AGE_DAYS`,
  his word at the pause of 5c-b, 2026-10-27: on fedxps after the cutover the
  readings come from `byebye`, `bye` and hand runs alone, and a week-old all
  clear is no reading) `WARN <label>: the newest full reading is <age> old
  (by <caller>): too old to stand as a reading`, the stored verdict under
  `-v` alone; then `conflicts`, `guard` without the version vectors,
  `config` without the claude-link dry run, and `hub` last, read live; no
  scan, no `--remote-views`, no `db/browse` or `db/file`, and of this
  machine's daemon one `system/status` first, so a daemon dead since the
  reading is a WARN above the reprinted lines, on a writer too, where the
  live lines ask it nothing. At Desktop scale
  `sync` costs 44 s on bigfed and 66 s on fedxps, the blocking scan 39.5 and
  60.4 s of it, and the hook's bare run was cut at 4.1 s on both machines
  having read nothing (`cutover/rehearsal/r5.md`, t7, 2026-10-27); the
  stored lines print in milliseconds, so a cut at the hook's 4 s away from
  home, where the hub's first door costs 2 s, loses the hub's line alone).
  The bare run is `sync`, `conflicts`, `guard` with the version vectors,
  `hub` — the hub's readings riding on the sync line's ssh — and `config`
  without the claude-link dry run, which alone costs 1.8 s on bigfed; on
  the nine folders before the cutover it took 1.6 to 1.9 s on bigfed at home
  and 1.3 s on fedxps, on the Desktop folder 47 and 58 s on bigfed and 95 s on
  fedxps, its first after a restart (`cutover/day.md`, 2026-10-28), and it is
  no longer the hook's. Exit 0 all clear, 1 something wrong or not
  yet (FAIL, WAIT), 2 could not determine, 3 up to date with attention due:
  DUE lines and nothing worse, which `bye`, `byebye` and the push gauge pass
  (2026-10-14; `org/machines/transport-2026-10/PLAN.md` → settled 37). Every
  ssh tries `<host>` with a 2 s connect timeout and then `<host>-vpn`, his
  ssh configuration's tailnet alias for every machine, so the gauge reads
  the hub away from home where it was blind through the pilot (settled 39);
  a door that failed is not tried again in the run, and one wall budget per
  host — the connect budget plus `SYNC_CHECK_SSH_GRACE`, 30 s — bounds a
  door that connects and then hangs, the second door getting what remains. The API key is read from
  `config.xml` into a variable and sent as a header, never printed and never
  on a command line; the file is parsed for the fields needed, and a folder's
  `encryptionPassword` only as set or unset; `/rest/config` is never read. The
  hub and the other workstation run this same file in its `--remote-views`
  and `--remote-hub` modes from stdin, so the reads have one implementation,
  and every round of the settle reads them afresh. The gauge writes one
  file of its own, the reading file (settled 76): every live read of the
  sync line's folders — the bare run, `sync`, `push` — keeps each folder's
  verdict lines there, tags, messages and fix texts (a fix can name a
  stranded path; no key is ever in it), with the time, the caller,
  `SYNC_CHECK_CALLER` as `bye`, `byebye`, `gpush` and `gpushall` set it to
  their own names, else `sync-check <line>` (`sync-check` alone for the bare
  run), and the first seven characters of the daemon's device ID; the file is
  `SYNC_CHECK_READINGS` when set (set empty, none), else
  `$XDG_STATE_HOME/sync-check/readings.json`, else
  `~/.local/state/sync-check/readings.json`, machine-local, replaced whole at
  0600 in a 0700 directory, never written by the `--remote-*` modes nor for
  a folder read from the snapshot, and a write that fails is silent, the next
  `session` then reading no reading on record. And when
  `SYNC_CHECK_SNAPSHOT` names a file, `gpushall`'s thirteen calls
  read the cluster once and the rest read that file while it is under
  `SYNC_CHECK_SNAPSHOT_TTL` (300 s) old, the per-repository checks still
  live. Suite: `tests/sync-check/run.sh` (caged, about 140 s on bigfed; three
  fixture Syncthing instances on loopback, stubs for ssh with its two doors,
  uname, btrfs, df, systemctl and ps, a sandbox configs checkout stowed by the
  real `stow`, which must be installed; 741 checks, reviewed twice and
  mutation-tested the day it was written, `pilot/build-gauge.md`, its exit-3
  cases mutation-tested on 2026-10-14, 22 mutants of the 5a code killed on
  2026-10-26, 14 of step 5c-b's repairs on 2026-10-27, and 18 of its
  `session` line, reading file and `.git` touch the same day, a nineteenth,
  the remote modes' guard on the reading file, equivalent while no remote
  mode reads a folder through `check_folders`; after the review that
  evening, six of its surviving mutants and five of the fixes' own killed,
  each by its case).
- `syncthing-addfolder` — creates one encrypted Syncthing folder across the
  cluster, run on bigfed alone (2026-10-26, step 5a of
  `org/machines/transport-2026-10/PLAN.md`, `rules.md` → mig-4 there, record
  `cutover/tools.md`; the successor of the 2026-09 bash script in
  `org/machines/syncthing-2026-09/bin/`, every lesson of which it keeps). It
  reaches the hub and fedxps as `sync-check` does — its own source over
  `ssh -o BatchMode=yes` in a `--remote` mode, the `<host>-vpn` door for reads
  and never for a write — and composes each machine's folder entry on that
  machine from its own `config.xml`, so the cluster password is never printed
  and crosses the wire only when the reader holds no encrypted folder yet, a
  rebuilt machine, and then inside the program text on ssh's own stdin, as
  the 2026-09 script sent it; the two workstations' passwords are compared
  by HMAC in memory before anything is written. Two shapes, detected
  from the reader's path: **fresh** (absent or empty: bigfed's folder, the
  hub's `receiveencrypted` one with its staggered year set in the POST and in
  a new, empty directory, fedxps's once the hub holds bigfed's set, the hub
  device bounced on both workstations and the bounce observed, convergence
  read on all three) and **join** (a copy already there: the pilot's
  receive-only join with an outside trashcan, the gate before the revert on
  the hub's own sequence and equal counts, every local change listed and the
  run stopped on a path outside `.git`, the revert, the manifests and
  `git fsck` under the guard, the switch watched for a minute, the versioning
  back to none, the direct link added after). A preflight refuses before any
  write: the phone-home settings, a marker above or below either path, an
  existing hub directory, the hub path off the dedicated volume, a role that
  is not writer here or is writer there, an overlapping folder, a trashcan
  inside a folder. Every gate waits for Enter or `--yes`; `--dry-run` writes
  nothing; `--log` keeps the readings; `--undo ID LABEL` removes the folder
  from the hub, then bigfed, then fedxps, refusing when a label disagrees.
  The reader must read a present role other than writer, or a `readerRepo`
  naming the reader's path (the pilot's shape): an absent role refuses,
  since it is the net for a host file that has not travelled, and a git
  that cannot read either machine's configuration stops the run with exit
  2 (the adversarial read's finding, the same day). Suite:
  `tests/sync/run.sh addfolder` (156 checks on the real-instance rig, about
  eight minutes, the race guards and the gates' failing directions driven
  through the case's own ssh stub; twenty mutants caught after the
  reviews). Run live at the cutover rehearsal of 2026-10-26
  (`org/machines/transport-2026-10/cutover/rehearsal/REPORT.md`): the fresh
  shape on seven stand-in folders, the join end to end on a 336-thousand-file
  scratch Desktop. Since 2026-10-27 (step 5c-b; `PLAN.md` there
  → settled 67, 69) all three bodies carry `blockIndexing` false, which the
  dry run's plan names and the read-back after each POST and every re-run
  verify, a folder held with the index on stopping the run: a POST without
  the key inherits the index from the defaults template, and with it the
  rehearsal's hub fell from 81 files a second to 10–12 as its folder grew,
  against 80–94 flat without. Seven of the suite's checks are this
  change's, each shown failing against the tool before it.
- `claude-link` / `claude-prune` / `claude-collect.sh` — Claude Code
  configuration linkage; see below.
- `vimtex-warm` — pays VimTeX's per-package resolution cost on purpose
  instead of mid-sentence (`-d` warms the dissertation chapters; `-a` warms a
  covering set for every package used under `~/Desktop`, ~90 s; bare
  arguments warm named files). Read-only with respect to documents: disarms
  `bph_autosave`, sets `nomodifiable`, parks the cursor on a `\command`
  already in the text. Why the cost exists: `nvim/CLAUDE.md` → the
  cold-cache stall.
- `screens-off` — locks the session and powers the displays down, on the way
  out of the chair, under GNOME or sway; the first key or mouse movement
  brings them back to the lock screen, nothing else interrupted. Bound to
  `<Super><Ctrl>b` on bigfed: dconf under GNOME (`custom6`, outside this
  repo, as adelotype's `<Super>x` is), `$mod+Ctrl+b` in
  `sway/hosts/bigfed.conf` under sway (2026-10-03) — a session op on the
  Ctrl tier beside `l` for lock, by `sway/config`'s law. It exists because
  bigfed never suspends: it must answer SSH over the LAN and the tailnet
  whenever it is left alone, so the displays are the only thing that may
  turn off. One rule holds on both desktops: the component that powers the
  displays down is the one waiting to power them back on, and it waits for
  the seat to fall quiet first, so the chord's own release, which counts as
  input, cannot revert the blank; the script never writes a display's power
  state behind that component's back. Under GNOME it waits on
  `IdleMonitor.GetIdletime`, then only locks — gnome-settings-daemon blanks
  ~0.3 s later and wakes at the next input; forcing Mutter's `PowerSaveMode`
  around gsd hard-wedged KMS on 2026-09-06 (memory `bigfed-mutter-kms-wedge`),
  which is why that restraint is the design. Under sway it has sway spawn a
  bare `swaylock -f`, then itself as `screens-off --watch`, which notes its
  pid in `$XDG_RUNTIME_DIR/screens-off.watcher` and execs a one-shot
  `swayidle -w timeout 1 '…power off' resume '…power on; kill $PPID'`: dark
  a second after the seat falls quiet, relit and gone at the first input.
  The lock comes first because sway honours a browser's wake lock only
  while unlocked. The pid on file keeps a second invocation from arming a
  second watcher, and lets a re-run re-arm the wake if one ever died. It
  then waits up to 5 s for every output to read power off and exits 1 with
  a line on stderr if not. It finds the live compositor itself — a sway IPC
  socket that answers, else Mutter on the session bus — so it works over SSH
  from fedxps too. Verified live 2026-09-06 under GNOME (typed, chord, SSH;
  that branch is unchanged since, and the suite pins it) and 2026-10-03 under
  sway, by the chord after a reload. Suite:
  `tests/screens-off/run.sh` (43 checks, caged, stub-based; mutation-tested
  against seventeen breaks). Record: `DECISIONS.md`, 2026-10-03.
- `sway-split` — `$mod+Shift+v` and `$mod+Shift+b` as toggles, and Waybar's
  marker for them: `below` and `beside` set the focused window so the next
  opens there, cancel on a second press of the same key and flip on the
  other; `toggle`, the original single key, sets below or cancels either;
  `status` and `watch` print the marker. A floating window is left alone
  (state `off`; until 2026-09-30 the keys wrapped it invisibly, with no
  marker and no cancel). Called by path from `sway/config` and
  `waybar/config`, since a sway session's PATH lacks `~/bin`. Suite:
  `tests/sway-split/run.sh` (45 checks, caged; mutation-tested).
- `sway-pointer` — `$mod+m`: every pointing device off, and back on, and
  Waybar's `pointer off` marker meanwhile. `toggle` reads sway's device
  list, takes each pointer or touchpad facet on which sway exposes
  acceleration, skips an identifier any facet of which lacks it (a
  keyboard's wheel; a keyboard whose mouse-keys interface shares its name),
  and sets `events` by identifier, never by type, on what is present and on
  everything learned at earlier presses (`~/.local/state/sway-pointer/learned`,
  never pruned by the script), so a mouse asleep at the press wakes off.
  `status` and `watch` print the marker; `watch` carries sway-split's stop
  trap, so a Waybar restart leaves no subscriber behind. Called by path from
  `sway/config` and `waybar/config`. Suite: `tests/sway-pointer/run.sh` (43
  checks, caged, stub-based; mutation-tested against nine breaks,
  2026-10-03). Record: `DECISIONS.md`, 2026-10-03.
- `sway-equalize` — `$mod+Ctrl+e`: every row and column on the focused
  workspace back to the sizes sway gives windows opened fresh, level by
  level, by moving the edges between siblings with directional resizes. The
  plan simulates sway's floor, 100 px wide and 60 px high, so a window sway
  has left under it is reached from whichever side sway accepts; a lock on
  the script makes a second press wait for the first. Floating windows, the
  members of a fold, and a row or column holding a fullscreen window are
  left alone; exit 1 if sway refused a step, which only a crowded row or
  column can cause. Called by path from `sway/config`. Suite:
  `tests/sway-equalize/run.sh` (55 checks, caged, a nested sway at
  5120x1440; mutation-tested against nine breaks). Record: `DECISIONS.md`,
  2026-10-06.
- `sysinfo.sh` — root-run hardware/OS summary (`sudo ~/bin/sysinfo.sh`);
  writes an HTML fragment to `/home/bph/Desktop/sysinfo.html` and
  deliberately omits security-sensitive identifiers (serials, MAC
  addresses) — keep that property when editing.
- `battlog` / `battreport` / `battcal-restore` — battery instrumentation from
  the 2026-08-11 fedxps pack swap; effectively fedxps-only (all three
  hardcode `BAT0`, bigfed has no battery). Worth knowing from the header:
  stock `CriticalPowerAction=Auto` resolves to **Sleep** on fedxps, where
  zram-only swap means no hibernation — `battcal-restore --keep-poweroff`
  keeps the kinder `PowerOff`, and the daemon's actual intent is read with
  `GetCriticalAction`, never the config file alone.

## TeX Live release upgrades (`tl-newyear`)

TeX Live is installed from CTAN (not RPM) under `/usr/local/texlive/YYYY`.
**`tlmgr` cannot cross a release boundary** — within a release `tl-upgrade`
serves (the tlnet repo refreshes daily); crossing a year is a **parallel
install**, verified against a baseline, then a PATH switch. Stages are
separate subcommands because there is a human go/no-go decision in the
middle:

```bash
tl-newyear status              # installed releases, which is active, baseline on file
tl-newyear preflight           # disk + btrfs headroom check
tl-newyear baseline            # fingerprint every document on the CURRENT release
tl-newyear install 2027        # parallel install; does NOT touch PATH
tl-newyear compare 2027        # recompile, diff against baseline
tl-newyear visdiff <doc.tex>   # pixel-compare one document across releases
tl-newyear switch 2027         # migrate symlinks, only after a clean compare
```

The procedure, in order — each step earned its place:

1. **Baseline first.** Without it you cannot tell "the new release broke it"
   from "it was already broken."
2. **Check btrfs headroom** (`preflight`; `disk-check` covers the same
   class). A scheme-full install writes ~180k files and dies with
   `No space left on device` even when `df` reports plenty — this bit the
   2025→2026 upgrade.
3. **Install with `instopt_adjustpath 0`** so the `/usr/local/bin` symlinks
   keep pointing at the old release and the old toolchain stays active.
4. **Re-compile and diff.** Expect many `pdftotext` hash changes that are
   *not* regressions (glyph-to-Unicode fixes); confirm with `visdiff`'s
   pixel compare, never the text hash alone.
5. **Switch** (`tlmgr path remove` old, `path add` new). `20-path.sh` picks
   up the new year automatically; `fontconfig/` cannot, so `switch` checks
   its pinned year and prints the `sed` to bump it. Keep the old tree until
   confident.

State, fingerprints, and ~130MB of build artifacts live in
`~/.cache/tl-newyear` — machine-local, deliberately unsynced. Builds always
go there via `-output-directory`, never in-place. Every tree in `~/Desktop`
is **Syncthing** content since 2026-10-28, so an in-place recompile anywhere
there rewrites the artifacts of every document it builds, on three machines,
and leaves a year of `.stversions` entries for them on nousowl; in
`teach-logic/`, which tracks its build artifacts, it also dirties tracked PDFs.

**Known casualty: the *forall x* textbook.** `tabu` v2.9 (unmaintained)
patches `array.sty` internals, and TL2026's rewritten `array` breaks all
`forallxyyc*` builds in `teach-logic/` (`TeX capacity exceeded`). `tabu` is
used nowhere else. Until upstream migrates to `tabularray`, build the
textbook pinned: `TEXLIVE_YEAR=2025 make` in any `forallx-yyc-build/`. A pin
naming a release that isn't installed warns (interactive shells only) and is
otherwise ignored — commands fall through to whichever release is active.

**Rolling a release out to the second machine** (the scripts travel in the
Desktop folder; the ~13GB tree does not):

```bash
# on the machine that upgraded first: nothing to send; the Desktop's Syncthing folder carries the scripts since 2026-10-28
# on the other machine, once sync-check sync reads up to date:
reload                      # the arrived bash files; stow-all re-reads its own arrays since 2026-10-26
stow-all
tl-newyear status && tl-newyear preflight
tl-newyear install <year> && tl-newyear switch <year>
reload
```

Re-verifying on the second machine is optional — TeX Live is deterministic
given the same inputs; if you do, `baseline` must run *before* `install`.
Revision drift between machines is harmless in general, but run `tl-upgrade`
on both before generating a final dissertation PDF.

## The Okular SyncTeX bridge

Two halves, and both must agree on the Neovim socket path:

- **Forward** (tex → PDF): VimTeX calls `okular-forward <pdf> <line> <tex>`
  (`vimtex_view_general_viewer` in `nvim/lua/plugins/vimtex.lua`). Two jobs:
  **path rebasing** — Okular resolves a SyncTeX source path *relative to the
  PDF's directory*, so the absolute path VimTeX supplies must be rebased or
  the jump silently does nothing — and **routing** — a D-Bus already-open
  check finds the tab that already holds the PDF and jumps *inside* it
  (Okular's own `--unique` and plain invocations are both wrong for a loop
  spanning documents); only genuinely-unopened documents fall through to the
  CLI.
- **Inverse** (PDF → tex): Okular calls `okular-inverse <file> <line>`
  (`ExternalEditorCommand` in `~/.config/okularpartrc` — the `okular`
  package), which percent-decodes the path and hands it to `nvr` (pip:
  `neovim-remote`) at `/tmp/nvimsocket`, the same socket `vimtex.lua` opens.
  **Change one, change the other.**

Standing verdicts (2026-07/08; the full investigation is
`docs/okular-multidoc-2026-07.md`):

- A forward search into a *background tab* lands on the right page but does
  not raise or switch tabs — **deliberately not fixed** (it does not arise in
  the side-by-side layout; every working fix costs more than the defect; if
  it ever grates, the cheap answer is `notify-send` feedback, not focus).
- Tabs vs. separate windows is Okular's own preference; toggle it through
  the GUI, never by editing `okularpartrc` (see `okular/CLAUDE.md`).
- `okular-inverse` resolves for a desktop-launched Okular as well as a
  VimTeX-launched one from the first login after 2026-09-23: `.bash_profile`
  sources `20-path.sh` in the login shell GDM starts, so the session PATH
  carries `~/bin` and `~/.local/bin` (`nvr`). Before that the desktop-launched
  case silently did nothing — and PDFs are opened both ways (confirmed
  2026-09-21), which is the concrete failure the old decline was waiting for.
  A `~/.config/environment.d` PATH drop-in stays **declined**: PATH keeps one
  author, `20-path.sh` (`DECISIONS.md`, 2026-09-23; the chain:
  `org/machines/environment.md`). `tests/env/run.sh` pins the login shell's
  output; the live proof is an inverse search from an Okular opened in Files.
  A sway session misses all of this until `sway/wayland-session.desktop` is
  installed: there the desktop-launched case fails as before (measured
  2026-09-28; `TODO.md` item 29).

## Claude Code configuration linkage

**The configuration is not in this repo — only the mechanism is.** It lives
in `~/Desktop/org/claude-config/` (private); this repo carries the linker,
the same split as `tl-newyear` and its 13GB TeX tree. Publicity is a
property of location: this repo is public, and putting the whole
configuration somewhere private removes the per-fact judgment that would
eventually be got wrong.

```bash
claude-link              # dry run — says what would change
claude-link --apply      # create the links
claude-link --adopt      # first run on a machine that already has its own state
claude-link --unlink     # reverse it; keeps the merged content
claude-link --auto       # SessionEnd's: silent, confined (below)
claude-prune [--apply]   # drop mechanically dead permission entries
```

Since 2026-10-26 (`org/machines/transport-2026-10/rules.md` → ws-12 to
ws-14, his settled 15): every run that may write holds
`~/.claude/.claude-link.lock` — a second run exits 2 with one line, or 0 in
silence under `--auto`, and a lock that cannot be taken is said with its
reason, exit 2 by hand or one log line under `--auto` — because two
unlocked runs at once corrupted the shared tree in 13 of 30 trials (a nested
`memory/memory`, a self-link). `--auto` runs alone: beside `--apply`,
`--adopt` or `--unlink` it is refused with exit 2.
`--auto` writes nothing into the shared tree and removes nothing in
`~/Desktop`: it links a memory scope or a skill that has arrived, replaces an
empty real `memory/` with its link, repairs `~/.claude`'s own dangling links
and keeps the orphan list, and makes a missing link into `~/Desktop` (a
private layer or permission file that arrived by git) only while no
`.stfolder` marker sits at `~/Desktop` or above it — since the Desktop became
a Syncthing folder on 2026-10-28 those links arrive inside it, and `--auto`
makes none (reviewer 1's M2, the same day); harvesting a new scope or
permission file and sweeping `~/Desktop` are `--apply`'s and `--adopt`'s, run
by him on one machine.
And `~/.claude/skills` is a real directory of one link per authored skill
into `org/claude-config/skills/`, so Anthropic's skill sync writes its
`synced/`, `.trash/` and `.staging/` on each machine alone (they were
landing in the shared tree through the old directory link); `--apply` makes
the migration once per machine and moves the vendor's state out of the
shared tree in the same run, a new authored skill is linked by the next
`--apply` or `--auto`, and a skill written straight into `~/.claude/skills`
is reported as on this machine alone.
And since the same day the deliberate runs link `~/CLAUDE.md`, the
machine's own charter, to `org/claude-config/hosts/$(hostname -s).md` when
that file exists, treating it as any linked file (the dry run names it
missing, `--adopt` backs up a differing copy, `--unlink` leaves a real one),
while `--auto` never makes it, since it lies outside `~/.claude`, and a
dangling link into `hosts/` is named by every run (decision 12 of the
transport campaign; its `PLAN.md` → settled 59).

**`claude-prune` must follow the first `--adopt` on each machine — not
optional.** Adoption is deliberately lossless and re-admits every previously
dropped entry, including any secret. It maintains itself through two hooks in
`settings.json` (SessionEnd runs `claude-link --auto`; SessionStart
health-checks the links and warns the *user*, not just the model — and since
2026-10-26 names, in both channels, every memory topic file its scope's
`MEMORY.md` does not index, every conflict copy in a scope, and a
`~/CLAUDE.md` link that dangles or resolves to a conflict copy's name,
`rules.md` → ws-15) plus
`_gsync_pull_hints`, which runs `--auto` when a pull on bigfed changes
`claude-config/` (what arrives by the Desktop folder fires no hint; SessionEnd's
`--auto` links it). `claude-collect.sh` is the one-shot read-only inventory of
what a machine holds that is *not* synced.

Layout, deployment, curation history, and the conditional-rules syntax:
`org/claude-config/README.md`. Verified behaviors and their experiments
(frozen linked lists, the deny block's reach, hook verification, the
ephemeral-scope exclusion): `docs/claude-config-behaviors-2026-08.md`. Facts
worth keeping in view here:

- A repo's linked `settings.local.json` **cannot be written** by Claude Code,
  whether the file or its `.claude/` directory is the link: the settings writer
  lstats the file and opens the parent `O_NOFOLLOW`, either check throws
  `SymlinkWriteRefusedError`, and "don't ask again" logs it and moves on — the
  grant holds for the session and nothing on screen says it did not persist.
  Tested on 2.1.238 (2026-08-20) and 2.1.269 (2026-09-11); accepted as designed,
  not worked around (`docs/claude-config-behaviors-2026-08.md`). Add entries in
  `org/claude-config`, or put global ones in `settings.json`, which the same
  writer does follow through its link.
- **Both halves of the health check reach inside `~/.claude`.** The user-level
  link pass skips a shared directory that has disappeared —
  `[ -e "$CFG/$e" ] || continue` — so only the sweep sees the dangling link left
  behind, and the sweep walks `~/.claude` as well as `~/Desktop` for exactly
  that reason (the `~/Desktop` half under `--apply` and `--adopt` alone since
  2026-10-26). SessionStart counts dangling links into the config and says so in
  both channels; SessionEnd's `--auto` repairs them. An empty shared directory
  was the cause while git carried the tree, since git cannot carry one (the
  Desktop folder does since 2026-10-28; a clone from GitHub still cannot):
  `claude-link --apply` drops a
  `.gitkeep` into an empty memory scope, and `--auto` deliberately does not, so
  a directory visited once does not become a permanent entry. Fixed 2026-09-18.
- **`claude-link` reports orphan charters, and SessionStart counts them.** An
  orphan is a `CLAUDE.md` or `CLAUDE.local.md` in a git work tree that git
  ignores and does not track. The global exclude that keeps agent context out
  of every repository hides any charter written straight into a tree, so
  git never carries it, `git status` never lists it, and a merge or checkout that
  brings its path replaces it without a word; `/init` writes one at a
  repository's root. Every run lists them under `== orphans ==` and moves none,
  since the cure is a choice per file: into `org/claude-config/repos/<path>/`
  as `CLAUDE.local.md`, or tracked with `git add -f`. Every run that may write
  keeps the list in `~/.claude/claude-link-orphans`, which SessionStart counts
  into both channels. Added 2026-10-06; suite `tests/claude/run.sh`, caged
  since the same day.
- `settings.json` denies `git commit` / `git push` as a hard block, not a
  prompt; matching is prefix-based, so `git -C <path> commit` slips the
  matcher — the global `CLAUDE.md` remains the backstop for intent.
- The transcript-based measurement of which permission entries earn their
  place — and the built-in read-only command list, documented once — is
  `org/claude-config/permission-measurement.md`.
- The rules that keep agent context out of every repository live in the
  private global exclude, `org/claude-config/git/ignore`, which the identity
  include sets as `core.excludesFile` (2026-10-04): both charter names,
  `**/.claude/settings.local.json` (the linked permission cache must never be
  committed to the repo it sits in) and `**/.claude/projects/` (a superseded
  memory location Claude wrote to in early 2026 — nothing stops it recurring,
  and in a public repo `git add -A` would publish it). This repo's
  `git/ignore`, still stowed to `~/.config/git/ignore`, is shadowed: git no
  longer reads it.
