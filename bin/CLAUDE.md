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
  `disk-check` shape: nine verdict lines, exit 1 on a fault, 2 on
  could-not-determine, every FAIL naming its repair. The half of that tree's
  integrity a script can decide; `/restore-order` judges the prose and calls this
  first. Suite: `tests/context-check/run.sh`.
- `sync-check` — read-only gauge for the Syncthing cluster and the git roles,
  in the `disk-check` shape (2026-10-10, step 3b of
  `org/machines/transport-2026-10/PLAN.md`; the rules it reads are that
  directory's `rules.md` → ws-1, ws-2, fedxps-3, bigfed-2; record
  `pilot/build-gauge.md`). Four lines: `sync` (every folder this machine
  shares is up to date — a blocking scan, then the local status, this
  machine's view of the hub, and over batch-mode ssh the hub's view of both
  workstations and, when the hub shows the other workstation owing or
  needing something, that workstation's own view, since the hub holds
  ciphertext and names what it needs opaquely; a need that outlives a 15 s
  settle with every folder idle is stranded, named with him-2's repair,
  while a transfer still running is `WAIT`; one known stuck item is carried
  by name in `KNOWN`, and `DUE` says when it no longer shows, or when a
  folder's watcher is dead), `conflicts` (one `find`
  over `~/Desktop` and every folder path: copies under a `.git` and stale
  locks there FAIL, copies in a directory that loads FAIL, the rest DUE),
  `guard` (the host link, every key of the host file resolving through it,
  `GIT_OPTIONAL_LOCKS` as the role requires, and no write seen under a `.git`
  this machine reads in Syncthing's disk events, which are kept from the
  daemon's start, the last 1,000), and `push REPO…` (bigfed-2: the folder up
  to date, nothing under the repository's `.git` needed in any view, no
  phantom ref or conflict copy under `.git`, the other workstation's HEAD
  equal when it answers, and the age of what GitHub lacks; a repository in
  no Syncthing folder passes, silently under `-q`, unless a `.stfolder`
  marker sits at or above it, which is `WARN`; a workstation the hub shows
  asleep blocks nothing, what the hub lists for it being what it lacks),
  which `gpush` and `gpushall` run before `add -A`: exit 1 skips the
  repository, exit 2 pushes with the warning shown (`bash/CLAUDE.md` → Git
  sync). Exit 0 all
  clear, 1 attention (FAIL, WAIT, DUE), 2 could not determine. The API key is
  read from `config.xml` into a variable and sent as a header, never printed
  and never on a command line; the file is parsed for the fields needed and a
  folder's `encryptionPassword` is never extracted; `/rest/config` is never
  read. The hub and the other workstation run this same file in its
  `--remote-views` mode from stdin, so the reads have one implementation,
  and every round of the settle reads them afresh. Suite:
  `tests/sync-check/run.sh` (caged, three fixture Syncthing instances on
  loopback, a stub `ssh` and `uname`; 257 checks, reviewed twice and
  mutation-tested the day it was written, `pilot/build-gauge.md`).
- `claude-link` / `claude-prune` / `claude-collect.sh` — Claude Code
  configuration linkage; see below.
- `vimtex-warm` — pays VimTeX's per-package resolution cost on purpose
  instead of mid-sentence (`-d` warms the dissertation chapters; `-a` warms a
  covering set for every package used under `~/Desktop`, ~90 s; bare
  arguments warm named files). Read-only with respect to documents: disarms
  `bph_autosave`, sets `nomodifiable`, parks the cursor on a `\command`
  already in the text. Why the cost exists: `nvim/CLAUDE.md` → the
  cold-cache stall.
- `tabula` — **retired 2026-09-29** and deleted: the font trial it opened
  (2026-09-15) is `~/Desktop/adelotype`, which took its `<Super>x` on bigfed
  through its own `tools/launcher.sh bind` (record: adelotype's private `DECISIONS.md`,
  2026-09-29; tabula's arc and its three declined mechanisms stay in
  `DECISIONS.md`, 2026-09-15). Its binding was per-machine dconf and outside
  this repo, and fedxps's `<Super>x` kept `gnome-text-editor` throughout.
  Since 2026-09-29 `$mod+x` under sway runs adelotype on both machines too,
  from `sway/config`, with the plain editor on `$mod+Shift+x`; under GNOME
  the key is adelotype's own `tools/launcher.sh bind`, per machine.

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
go there via `-output-directory`, never in-place. `teach-logic/` tracks its
build artifacts, so an in-place recompile dirties tracked PDFs; `opuscula/`
carries 285 of them as **Syncthing** content since 2026-09-15
(`org/machines/syncthing.md`), so one in-place recompile there rewrites all
285 across three machines and leaves a year of `.stversions` entries on
nousowl.

**Known casualty: the *forall x* textbook.** `tabu` v2.9 (unmaintained)
patches `array.sty` internals, and TL2026's rewritten `array` breaks all
`forallxyyc*` builds in `teach-logic/` (`TeX capacity exceeded`). `tabu` is
used nowhere else. Until upstream migrates to `tabularray`, build the
textbook pinned: `TEXLIVE_YEAR=2025 make` in any `forallx-yyc-build/`. A pin
naming a release that isn't installed warns (interactive shells only) and is
otherwise ignored — commands fall through to whichever release is active.

**Rolling a release out to the second machine** (scripts travel in git; the
~13GB tree does not):

```bash
gpushall                    # on the machine that already upgraded
# on the other machine:
gpullall
source ~/.bashrc            # MUST precede stow-all — bash/CLAUDE.md, the re-source trap
stow-all
tl-newyear status && tl-newyear preflight
tl-newyear install <year> && tl-newyear switch <year>
source ~/.bashrc
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
  installed: GDM starts sway with no login shell, so there the
  desktop-launched case fails as before (measured 2026-09-28; the session
  file, which re-execs sway through a login shell, is drafted 2026-09-30 —
  `TODO.md` item 29).

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
claude-prune [--apply]   # drop mechanically dead permission entries
```

**`claude-prune` must follow the first `--adopt` on each machine — not
optional.** Adoption is deliberately lossless and re-admits every previously
dropped entry, including any secret. It maintains itself through two hooks in
`settings.json` (SessionEnd runs `claude-link --auto`; SessionStart
health-checks the links and warns the *user*, not just the model) plus
`_gsync_pull_hints`, which runs `--auto` when a pull changes
`claude-config/`. `claude-collect.sh` is the one-shot read-only inventory of
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
- **Both halves of the health check reach inside `~/.claude`, and that is new.**
  The user-level link pass skips a shared directory that has disappeared —
  `[ -e "$CFG/$e" ] || continue` — so only the sweep sees the dangling link left
  behind, and the sweep walks `~/.claude` as well as `~/Desktop` for exactly that
  reason. `~/.claude/plans` sat broken on both machines for 23 days because
  nothing did. SessionStart now counts dangling links into the config and says so
  in both channels; SessionEnd's `--auto` repairs them. An empty shared directory
  is the cause, since git cannot carry one: `claude-link --apply` drops a
  `.gitkeep` into an empty memory scope, and `--auto` deliberately does not, so a
  directory visited once does not become a permanent entry. Fixed 2026-09-18.
- **`claude-link` reports orphan charters, and SessionStart counts them.** An
  orphan is a `CLAUDE.md` or `CLAUDE.local.md` in a git work tree that git
  ignores and does not track. The global exclude that keeps agent context out
  of every repository hides any charter written straight into a tree, so
  nothing syncs it, `git status` never lists it, and a merge or checkout that
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
