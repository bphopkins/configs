# CLAUDE.md — bin package

Charter for `bin/`, stowed to `~/bin` (on PATH via `20-path.sh`). This is the
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
- `claude-link` / `claude-prune` / `claude-collect.sh` — Claude Code
  configuration linkage; see below.
- `vimtex-warm` — pays VimTeX's per-package resolution cost on purpose
  instead of mid-sentence (`-d` warms the dissertation chapters; `-a` warms a
  covering set for every package used under `~/Desktop`, ~90 s; bare
  arguments warm named files). Read-only with respect to documents: disarms
  `bph_autosave`, sets `nomodifiable`, parks the cursor on a `\command`
  already in the text. Why the cost exists: `nvim/CLAUDE.md` → the
  cold-cache stall.
- `tabula` — opens GNOME Text Editor in a randomly chosen monospace font,
  bound to `<Super>x` in place of `gnome-text-editor --new-window`. The point
  is exposure: the scratchpad is low-stakes enough to wear an unfamiliar face,
  which the terminal is not. Two things to know before editing it. The font is
  one GSettings key (`org.gnome.TextEditor custom-font`), which is
  application-global and so re-fonts every open window, not just the new one;
  and `use-system-font` must be false or the key is ignored in silence, which
  is why the script sets it defensively every run. The rotation is a plain
  table at the top — comment a line out to prune it, which is the intended way
  to converge. Sizes are a flat 12; two normalisations were tried and dropped,
  and the header records why. The *binding* is per-machine and outside this
  repo: a dconf shortcut on bigfed, `bindsym $mod+x` in `sway/config` on
  fedxps.

- `screens-off` — locks the session and lets GNOME power the displays down,
  bound to `<Super><Ctrl>b` on bigfed. It exists because bigfed never
  suspends: it must answer SSH over the LAN and the tailnet whenever it is
  left alone, so the displays are the only thing that may turn off, and this
  reaches that state on the way out of the chair instead of 15 minutes later.
  It **never writes** Mutter's `PowerSaveMode` itself, and that restraint is
  the whole design. Forcing the property straight to mutter, behind
  gnome-settings-daemon's back, hard-wedged KMS on 2026-09-06: the chord
  release reverted gsd's own blank, gsd went back to normal and unaware, and
  the forced-off monitors had nothing left watching to wake them — no input
  recovered it, only a VT round-trip from another machine did (memory
  `bigfed-mutter-kms-wedge`). So it just locks. Locking makes the screensaver
  active, and gnome-settings-daemon blanks the monitors ~0.3 s later (a real
  DPMS power-down) and wakes them at the next seat input — the same path GNOME
  uses for its own idle blank, where the component that blanks is the one
  waiting to wake. The lone subtlety is the `IdleMonitor.GetIdletime` wait: it
  lets the seat fall quiet *before* locking, so the launching keypress or the
  chord release cannot revert GNOME's blank. Two provisions make it work over
  SSH from fedxps as well as locally: it defaults `DBUS_SESSION_BUS_ADDRESS`,
  and it locks an explicitly looked-up graphical session, since bare `loginctl
  lock-session` would lock the SSH session instead. GNOME only. As with
  `tabula`, the *binding* is per-machine dconf and outside this repo; the
  placement follows `sway/config`'s law, a session op at `$mod+Ctrl+letter`,
  beside `$mod+Ctrl+l` for lock. Verified end to end 2026-09-06: typed, chord,
  and SSH-from-fedxps invocations all blanked, held dark, stayed locked, and
  woke to the lock screen on a Bluetooth key.
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

- A repo's linked `settings.local.json` **cannot be written** by Claude Code,
  whether the file or its `.claude/` directory is the link: the settings writer
  lstats the file and opens the parent `O_NOFOLLOW`, either check throws
  `SymlinkWriteRefusedError`, and "don't ask again" logs it and moves on — the
  grant holds for the session and nothing on screen says it did not persist.
  Tested on 2.1.238 (2026-08-20) and 2.1.269 (2026-09-11); accepted as designed,
  not worked around (`docs/claude-config-behaviors-2026-08.md`). Add entries in
  `org/claude-config`, or put global ones in `settings.json`, which the same
  writer does follow through its link.
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
