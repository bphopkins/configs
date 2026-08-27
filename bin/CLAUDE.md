# CLAUDE.md — bin package

Charter for `bin/`, stowed to `~/bin` (on PATH via `20-path.sh`). This is the
home for homegrown executables; **pip/npm-installed console scripts stay in
`~/.local/bin`** — their package managers rewrite them on upgrade. `~/bin`
also holds untracked files that belong to no repo: `isabelle` /
`isabelle_java` are written by `isabelle install ~/bin`, hardcode the release
path, and are correctly machine-local — leave them untracked. The trap runs
the other way too: `isabelle install` does `rm -f` on its targets, so a
same-named *tracked* file would have its stow symlink silently replaced, and
the next `stow -R bin` would fail with a conflict.

## Inventory

- `tl-newyear` + `tl-{roots,check,compare,visdiff}.sh` — TeX Live release
  migration; see below.
- `okular-forward` / `okular-inverse` — the SyncTeX bridge; see below.
- `claude-link` / `claude-prune` / `claude-collect.sh` — Claude Code
  configuration linkage; see below.
- `vimtex-warm` — pays VimTeX's per-package resolution cost on purpose
  instead of mid-sentence (`-d` warms the dissertation chapters; `-a` warms a
  covering set for every package used under `~/Desktop`, ~90 s; bare
  arguments warm named files). Read-only with respect to documents: disarms
  `bph_autosave`, sets `nomodifiable`, parks the cursor on a `\command`
  already in the text. Why the cost exists: `nvim/CLAUDE.md` → the
  cold-cache stall.
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
   up the new year automatically. Keep the old tree until confident.

State, fingerprints, and ~130MB of build artifacts live in
`~/.cache/tl-newyear` — machine-local, deliberately unsynced. Builds always
go there via `-output-directory`, never in-place: `teach-logic/` and
`opuscula/` track their build artifacts, and an in-place recompile would
dirty tracked PDFs.

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
- `okular-inverse` resolves only for a VimTeX-launched Okular. A
  desktop-launched one inherits the session PATH (no `~/bin`), and inverse
  search silently does nothing. A `~/.config/environment.d` PATH drop-in was
  considered and **declined** — it would give PATH a second source of truth
  that doesn't reproduce `20-path.sh`'s TeX-Live-first ordering. Only add it
  against a concrete failure.

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

- A repo's linked `settings.local.json` **cannot be written** by Claude Code
  ("don't ask again" silently fails to persist — the settings writer opens
  `O_NOFOLLOW`). Add entries in `org/claude-config`, or put global ones in
  `settings.json`, which is writable through its link.
- `settings.json` denies `git commit` / `git push` as a hard block, not a
  prompt; matching is prefix-based, so `git -C <path> commit` slips the
  matcher — the global `CLAUDE.md` remains the backstop for intent.
- The transcript-based measurement of which permission entries earn their
  place — and the built-in read-only command list, documented once — is
  `org/claude-config/permission-measurement.md`.
- Two machine-local gitignore rules carry weight (`~/.config/git/ignore`,
  kept in step by hand, not in any repo): `**/.claude/settings.local.json`
  (the linked permission cache must never be committed to the repo it sits
  in) and `**/.claude/projects/` (a superseded memory location Claude wrote
  to in early 2026 — nothing stops it recurring, and in a public repo
  `git add -A` would publish it).
