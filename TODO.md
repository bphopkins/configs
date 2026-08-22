# TODO List

Planned pieces of work, each big enough to want its own session. Written up in
enough detail to brief a fresh chat without re-deriving the findings — the notes under
each item come from a full repo survey on 2026-07-26. (Items 1 and 2 — the git-sync
overhaul and the french-logic ↔ Neovim optimization — were completed 2026-07-26; see
Done. Items keep their original numbers because other docs reference them.)

Priority for the next working day: **(3)**.

---

## 3. Overhaul the `~/.bashrc.d` cluster

- [ ] Review the whole modular bash setup for robustness.

The last remaining survey item (1 and 2 are done). The structure is sound — `.bashrc` sources
`~/.bashrc.d/*.sh` in numbered order, and everything parses. Things a review might look
at: whether `00-shell-opts.sh` should finally get real `shopt`/`set` options (history
handling, `globstar`, `checkwinsize`); whether `30-prompt.sh` should define a prompt
rather than inherit `/etc/bashrc`'s; and whether the aliases in `40-aliases.sh` still
match how the machines are actually used.

**Deliberate, not oversights:** `00-shell-opts.sh` and `30-prompt.sh` are *reserved
empty slots*, not dead files. `90-nix.sh` is **load-bearing on bigfed**, where nix has
been installed since 2025-03-05 and this file is the only thing putting it on PATH —
bigfed is the machine that builds Carnap, and the Stage 3 build ran through it.
`.bashrc.min` / `.bash_profile.min` are rescue configs.
A `~/.config/environment.d` PATH drop-in was considered and **declined** — it would
give PATH a second source of truth that wouldn't reproduce `20-path.sh`'s
TeX-Live-first ordering.

*Corrected 2026-08-17.* The `90-nix.sh` sentence above previously read "kept ready for
Carnap development even though nix isn't installed" — false when written (2026-07-26),
since nix had been on bigfed for seventeen months by then. It was written from fedxps,
where nix genuinely is absent, and generalised without checking the other machine. The
same claim appeared in `90-nix.sh` and `CLAUDE.md` and was corrected there on
2026-08-17; **this third restatement was missed by that sweep and caught a day later**,
which is the argument for the `grep -rn` step whenever a restated fact changes. Note the
failure mode is not staleness but *unverified generalisation across machines*: a
two-machine setup makes "on either machine" the easiest sentence to write and the
hardest to check.

---

## 5. Sway config: the deferred tiers — COMPLETE 2026-08-13

- [x] All four tiers done, verified from inside a live Sway session. @done(2026-08-13)

Kept rather than folded into Done because the per-tier notes below record *why* things
were done the way they were, and the declined list at the foot is the part most likely to
be re-proposed by a future session. From a full inspection on 2026-08-13.

**Tier 1 — lid/lock. DONE 2026-08-13**, see the Done entry. Screen blanking and idle
timers remain **declined**. One follow-up if a timer is ever added after all: pair it
with `for_window [app_id=".*"] inhibit_idle fullscreen`, or a fullscreen talk will lock
mid-presentation.

**Tier 2 — `focus parent`. DONE 2026-08-13.** `$mod+p` walks up the tree, `$mod+Shift+p`
(`focus child`) comes back down; the pair is bound because parent alone leaves you
steering back with direction keys. `$mod+v` remains deliberately free.

**Tier 3 — screenshots. DONE 2026-08-13.** `Print` full-screen->file, `Shift+Print`
region->clipboard, `$mod+Print` region->file.

Two findings baked in. **The cancel guard is load-bearing:** written the obvious way as
`grim -g "$(slurp)" - | wl-copy`, pressing Esc leaves an empty geometry, grim fails, and
wl-copy still runs with empty stdin — silently **wiping the clipboard**. Testing both
slurp's exit status and the resulting string means a cancelled screenshot changes nothing;
verified with stub slurps for both the cancel and success paths.

**The destination is not redirectable from bash.** grim honours `GRIM_DEFAULT_DIR`, but
the `XDG_PICTURES_DIR` *environment variable* is ignored — setting it to a scratch dir
still wrote to `~/Pictures`, so grim reads `~/.config/user-dirs.dirs` instead and the man
page's "falls back first to `$XDG_PICTURES_DIR`" names the value, not the variable. And
exporting `GRIM_DEFAULT_DIR` from `bash/.bashrc.d` would not reach the keybinding anyway:
sway's children inherit the *session* environment, not an interactive shell's — the same
trap documented for `okular-inverse`. Redirecting it would mean naming a path in
`sway/config`. Left at `~/Pictures`.

**Tier 4 — DONE 2026-08-13.** `$mod+Tab` -> `workspace back_and_forth` (the third motion
the `$alt` prev/next pair left missing). `client.urgent` now uses `$urgent` `#d08770`, so
sway finally matches Waybar, mako and swaylock — one urgent colour desktop-wide. Waybar's
battery gained `states` (warning 20 / critical 10) with CSS classes, plus **notifications
via waybar's own `events` mechanism** — no daemon, no timer, because the module already
polls; critical fires at `urgency=critical`, which mako keeps on screen until dismissed.
Two incidental fixes found while there: the battery format used `{icon}` with no
`format-icons` array, so it rendered nothing (dropped — this bar is deliberately all
plain text); and the clock's `interval` defaulted to **60**, polling on the minute, which
is why `%T` showed `00` seconds forever under Sway while GNOME ticked. `interval: 1`
fixes it — verified by diffing two `grim` captures of the clock region 1.6 s apart.

A follow-on from that: with seconds now visible, the centred clock **jittered** once a
second, because the default proportional font renders different digits at different
widths (measured 145 <-> 146 px) and `modules-center` turns a width change into
horizontal movement. Fixed with `font-feature-settings: "tnum"` on `#clock` — tabular
figures, so every digit has one advance width; re-measured as a constant 155 px at a
constant offset across 8 consecutive seconds. Two things learned doing it, both now in
`CLAUDE.md`: GTK3 **rejects** the CSS-spec form `"tnum" 1` and knows nothing of
`font-variant-numeric`; and **a CSS parse error makes waybar exit silently**, leaving
sway with no bar and nothing in the journal but `Using CSS file …`. Parse-check
`style.css` before every reload.

**Not a gap, checked 2026-08-13:** `xdg-desktop-portal-wlr` *is* installed (it is a
libexec binary, so `command -v` misses it) and Fedora ships
`/usr/share/xdg-desktop-portal/sway-portals.conf` routing ScreenCast/Screenshot to wlr —
screen sharing will work. mako is installed and D-Bus-activated
(`fr.emersion.mako.service`), so notifications need no `exec` line.

**`seat * xcursor_theme`: investigated and struck, 2026-08-13.** It was on Tier 4 on the
theory that XWayland clients fall back to an unthemed X cursor. Tested live by running
the *same* binary on both backends (`alacritty` vs `env -u WAYLAND_DISPLAY alacritty`,
which is the way to force XWayland here) — **the cursors are identical**. The reason is
structural, so it is stable: Adwaita is the only cursor theme installed, and
`/usr/share/icons/default/index.theme` has `Inherits=Adwaita`, so the unnamed `default`
theme that both paths resolve lands on the same theme either way; `XCURSOR_SIZE=24` is
set session-wide. Nothing to fix unless a second cursor theme is ever installed. (Unrelated
observation from the same test, deliberately not pursued: the XWayland Alacritty renders
its font larger. `Xft.dpi` is unset and output scale is 1.0, so the likely cause is X11
clients deriving DPI from the panel's EDID physical size rather than assuming 96 —
unverified, and moot while every app in use is native Wayland.)

**Regression suite added 2026-08-13:** `tests/desktop/run.sh`, 24 checks, mutation-verified.
It guards the four silent-catastrophic failure modes this work uncovered (waybar CSS typo
kills the bar; unknown swaylock key means no lock; `sway --validate` skips binding command
bodies; mako/wofi unknown keys), plus the cross-config wiring that nothing else holds in
place. Run it after touching sway, waybar, swaylock, mako or wofi.

**Considered and DECLINED 2026-08-13** (asked and answered, do not re-propose):

- *Clipboard persistence* (`wl-clip-persist` / `cliphist`) — has never actually been a
  problem in practice, and is not worth running a daemon for.
- *Multi-monitor bindings* — sway has never been used with multiple monitors; the one
  attempt was on `bigfed`, which has been abandoned as a sway machine.
- *`for_window` floating rules* — no misbehaving dialog was ever demonstrated, so there is
  nothing to fix yet. The `inhibit_idle fullscreen` half only applies if idle timers are
  ever adopted, which they are not.
- *A clock on the lock screen* — wanted, but mainline swaylock cannot do it (see the
  swaylock note in `CLAUDE.md`); `indicator-idle-visible` was taken instead.

---

## 6. Impose an explicit logic on the sway keybindings

- [ ] Investigate the implicit logic already present in the bindings, propose an explicit
  one to follow going forward, and rewrite the grammar header in `sway/config` to state
  it. Optimise for *conceptualising the action-space cleanly* and remembering bindings —
  not for tidiness. Explicit exceptions for workflow are expected and fine.

Raised 2026-08-13 after the config work of that day. The complaint, in the user's words:
there is no visible logic to the difference between `$mod+Shift` and `$mod+Ctrl`, which
makes it hard to keep in his head where a binding lives.

**Measurements already taken — do not re-derive.** Counts as of 2026-08-13: plain `$mod`
32 bindings, `$mod+Shift` 24, `$mod+Ctrl` 3, `$mod+$alt` 8.

- **A logic is already ~79% present.** 19 of the 24 `$mod+Shift` bindings are one idea:
  *take the focused window with you* — move directionally (8), send to workspace (10),
  stash in scratchpad (1). The `$mod+$alt+Shift` pair (carry window across workspaces)
  reinforces it.
- **Two of the five exceptions probably are not exceptions.** `Shift+f` (fullscreen) and
  `Shift+space` (floating toggle) fit if the rule is widened from "move the window" to
  "act on the focused window" — state counts as much as position.
- **Three are genuine.** `Shift+c` (reload) and `Shift+Escape` (poweroff) act on the
  session, not a window. `Shift+p` (focus child) is focus navigation — and was added on
  2026-08-13 *by an assistant who did not notice it broke the pattern*, because there was
  no stated rule to check against. That is the ongoing cost, and the best argument for
  doing this at all.
- **`$mod+Ctrl` is the real problem, and it is definitional.** Only 3 bindings, spanning
  two unrelated concepts: `Ctrl+h`/`Ctrl+v` (container structure) and `Ctrl+l` (lock,
  session). The lock landed there in 2026-08-13 purely because `$mod+l` was taken by
  `focus right` — key availability driving semantics, which is how drift starts. Decide
  **what Ctrl means** first; placements follow.

**Starting hypothesis, not a conclusion:** *Shift acts on the focused window; Ctrl acts on
the environment around it.* Splits shape the container, lock/reload/power act on the
session — all "not the window". Under that rule the required changes are **two bindings**
(`reload` -> `$mod+Ctrl+c`, `poweroff` -> `$mod+Ctrl+Escape`), both rarely pressed, plus
rehoming or explicitly excusing `focus child`. Test the hypothesis; do not assume it.

**Constraints, from the user directly:**

- He is *happy with the bindings* and does not want to deviate much — the value is the
  stated rule, not the moves. If the rule ever demands relocating something pressed daily,
  the rule bends, not the binding.
- Deliberate upstream divergences to preserve: `$mod+q` kill (not `$mod+Shift+q`),
  `$mod+Escape` exit (moved off `$mod+Shift+l` on 2025-11-10 because `l` is `$right`),
  splits on `$mod+Ctrl+h`/`v` (because `$mod+b`/`$mod+v` are launchers). `$mod+v` is
  deliberately free. Every motion is bound for **both** vim keys and arrows — keep that.
- Tabbed/stacking layouts are declined (see item 5), so the layout tier stays small.

**Also fix as part of this:** the "Binding grammar" header at the top of `sway/config` is
self-contradictory — it asserts both `$mod+Shift+hjkl = move the window` *and*
`$mod+Shift+<key> = the heavier variant of the unshifted action`. Two rules for one
modifier, the second vague enough to justify anything. It documents the mess rather than
resolving it, and is part of why the scheme still reads murky.

---

## 7. A dedicated secret scan across the repos

- [ ] Build a content-based secret scan. Decide first whether it belongs inside
  `gpushall` or — the stated preference — as a separate command run across all of
  `REPOS_DESKTOP` on its own schedule.

Raised 2026-08-17 out of a full public-exposure audit of this repo (all 138 tracked files,
the working tree, and all 89 commits / 376 blobs of history). **The audit found nothing to
remove**: no key, token, JWT, IP, MAC, phone, address, student data, or third-party PII has
ever been committed, in HEAD or in history. This item is about the *mechanism*, not a spill.

**The gap, precisely.** `_gsync_vet_new_files` lists staged paths with

```
git -C "$repo" -c diff.renames=false diff --cached --name-only --diff-filter=AT -z
```

`AT` is **Added + Typechanged**. Modifications (`M`) to already-tracked files are never
vetted — no size check, no glob check, no prompt. So a secret pasted into `CLAUDE.md`
(78 KB of constantly-churning prose), `TODO.md`, or any `bash/.bashrc.d/*.sh` commits and
pushes to a public remote in silence. Given this repo's file mix, that is the most
realistic remaining leak path.

**Do not "fix" it by adding `M` to the diff-filter.** The vet matches *filenames* against
`GSYNC_SECRET_GLOBS`, and a modified file's name has not changed — it was already vetted
when it was added. Re-globbing it every run buys nothing and would prompt on ordinary
edits. Closing this needs a different instrument: a scan of the *content* of the staged
diff.

**Shape of the remedy, when it is built.** Scan added lines only (`diff --cached -U0`,
`^+` minus `+++`) for high-signal patterns, and keep the list tight so it stays
false-positive-free enough to be trusted: `BEGIN [A-Z ]*PRIVATE KEY`, `BEGIN CERTIFICATE`,
provider prefixes (`ghp_`, `gho_`, `github_pat_`, `sk-ant-`, `sk-`+20, `AKIA`, `AIza`,
`xox[abprs]-`, `glpat-`), JWTs (`eyJ` + two more dot-separated b64 segments), and
`Authorization:\s*(Bearer|Basic)`. Prompt with the same `[[ -t 0 ]]`-gated y/N flow as the
existing vet, and fail the same way it does — **closed**, refusing the commit if the
listing itself errors. Extend `tests/gsync/` in step; note that a naive fixture will trip
the scanner on the test file itself, which is exactly the false-positive shape to design
against.

**Two things already decided (2026-08-17), so they need no re-litigating:**

- **`.gitignore` is the cheap second layer, and it was taken.** It had only the three
  path-specific rules and now carries generic hygiene groups. That was not speculative:
  `init.el~` (2025-10-30), `sway/config.save` (2025-11-09) and two nvim `*.bak` files
  (2026-03-19) had *already* been committed and published by `git add -A`, and are still
  in history. Ignore rules refuse where the vet only prompts, and they cover the
  modified-file gap the vet structurally cannot see — but only for whole files, never for
  a secret inside a legitimate one. Hence this item.
- **The preference is a dedicated scan over `REPOS_DESKTOP`, not a `gpushall` bolt-on.**
  `gpushall` is already the most safety-critical function here, guarded by 153 checks;
  growing it has a cost. A separate command can also be run on demand and against repos
  that are not being pushed.

**Worth folding in while there:** `GSYNC_MAX_MB` is env-overridable, so a stray value in
the environment silently relaxes the size guard (a non-numeric one already warns and falls
back to 25; a numeric one does not). And the audit's other standing note — `~/.bashrc.d`,
`~/.config/nvim/{lua,after}`, and each `~/texmf/tex/latex/<pkg>` are whole-**directory**
symlinks into this repo, so anything a tool writes under those paths lands in the working
tree with no further step. All are clean today.

---

## Notes

- From the 2026-08-09 git-sync audit (item 4's gpushall question), two observations,
  deliberately not acted on absent a concrete failure: the five network git calls in
  `50-git-sync.sh` have no timeout beyond the 4s TCP probe of `github.com:22`, so a
  connection black-holed *after* the probe hangs — silently at the `>/dev/null 2>&1`
  sites; and `git commit -m` in `_gsync_push_repo` is the one place a future
  pre-commit hook could recreate the dnf-style invisible prompt (captured stdout +
  live terminal stdin) — `</dev/null` there is free insurance if hooks ever appear.
- `markdown-preview.nvim` is pinned to commit `a923f5f` (2023-10-17). That is not a
  stale pin — it is the newest commit upstream has ever had; the project was abandoned
  in October 2023. Nothing to update. It works today; if a future Neovim release breaks
  it, the replacements to look at are `render-markdown.nvim` or `peek.nvim`.
- Desktop typography under Sway, surveyed 2026-08-13. The bar and the launcher were
  brought in line; the rest was **deliberately left alone**. There is no XSettings daemon under sway, so GTK3 apps read gsettings
  directly (`Adwaita Sans 11`) and agree with each other — but anything shipping its own
  stylesheet does not participate. `wofi` ($mod+a) *was* the worst outlier — no config at
  all, running on compiled-in defaults — and got its own stow package the same day
  (palette + Source Code Pro matching Waybar; see `CLAUDE.md`). mako and swaylock still
  fall back to their own defaults for fonts, which has not mattered in practice. Judged too big to
  fold into a config pass; it is a design question, not a config sweep. Waybar was
  monospaced (Source Code Pro, matching the terminals) on its own merits — see `CLAUDE.md`.
  Note the Wi-Fi tray icon can never join in: it is an SNI *icon* painted by `nm-applet`
  from the Adwaita icon theme, not text, so no font setting reaches it. Replacing it with
  waybar's text `network` module is possible but `nm-applet` must keep running regardless
  — it is the 802.1x secret agent — so that would add a text indicator without removing
  the icon.
- Alacritty carries font settings only, no colourscheme, so it is the one terminal not
  on TokyoNight. Deliberate or not, it's a one-block fix whenever wanted.
- `wallpapers/monarch1080.png` (2.0 MB) and the five solid-colour PNGs are referenced
  nowhere; only `monarch1080dark.png` is used (by `sway/config` and the GNOME
  background). ~3.6 MB of the repo's 9.2 MB is this directory, which is not a stow
  package.

---

## Done

- [x] **Diagnosed and fixed Neovim's LaTeX editing latency on `fedxps`.** Two separate
  faults, which is why no single explanation fitted both symptoms. (1) A per-keystroke
  tax of **212 ms** at the end of an 1860-char paragraph line, against a `nvim -u NONE`
  floor of 3.6 ms on the same line — attributed by ablation to VimTeX's own matchparen
  (62 ms), blink's `snippets` (33) and `vimtex` (26) sources, the custom syntax cmds
  (29) and base VimTeX syntax (20). Fixed by switching VimTeX's matchparen off *during
  insert only* (its public API, so normal-mode `$…$`/`\begin`/`\left` matching survives)
  and gating blink's two heavy sources on being part-way through a `\command` or inside
  its braces → **13/23/84/54 ms** at 585/1001/1417/1860 chars, a 3–4× improvement.
  (2) A one-shot **22.8-second stall on the first backslash of a session**, reproduced
  live: VimTeX spawns `kpsewhich` once per `\usepackage`'d package (97 of them) and one
  spawn costs ~190 ms here — which is process *startup*, not the lookup. Remedied with
  `bin/vimtex-warm`, which pays it deliberately (`-a`: 38 documents covering all 109
  packages under `~/Desktop`, 90 s, once per machine).
  **Corrections to prior beliefs, all measured:** syntax complexity was *not* the cost
  driver (~14% of the bill, not the bulk); Neovim's built-in matchparen costs ~0 here;
  a TeX Live upgrade does *not* invalidate the kpsewhich cache (risk there is staleness,
  not slowness); and latexmk continuous does not multiply write cost (`$sleep_time` is 2 s,
  so writes coalesce). **Declined:** trimming the custom syntax rules (smallest lever,
  costs semantic colour); changing the `tuned` `powersave` profile, which is deliberate
  despite a measured 2.4× cold-clock penalty on post-pause keystrokes; and any change to
  the auto-save, whose two events turn out to be the *minimum* pair yielding "in normal
  mode ⟹ saved" — `TextChanged` does not fire on Esc, `InsertLeavePre` does not fire on
  normal-mode edits, so neither is redundant (`write`→`update` and debouncing were both
  measured/considered and rejected). New suite `tests/nvim-latency/run.sh` (26 checks,
  hermetic, mutation-verified); one bug in the first version of the fix — `E216` on every
  `InsertEnter` when `vimtex_matchparen_enabled=0` — was found by testing the off case and
  is now pinned by its own check. @done(2026-08-22)

- [x] **Tier 1 of item 5: lock before suspend** (`swaylock` + `swayidle`), plus a `mako`
  notification config — both new stow packages, both verified in a live Sway session.
  **The lock is `before-sleep` only**, with no `timeout` clause, so the no-idle-timers
  posture is structurally preserved; it exists solely to close the measured hole that
  lid-close → suspend → reopen landed on an unlocked desktop. `$mod+Ctrl+l` locks on
  demand. Verified: PAM authentication works (password unlock succeeded under a
  watchdog harness that made lockout impossible), and the lid path now locks.
  **mako:** its `default-timeout` defaults to `0` — never expire — which is why the
  NetworkManager "Connection Established" popup persisted until clicked; now 5 s, with
  `ignore-timeout=1` so a sender asking to persist forever cannot override that, and a
  `[urgency=critical]` section giving persistence back where it belongs. Both configs
  had every key validated against their man pages first, because an unrecognised key
  makes swaylock **exit** — i.e. no lock at all, a fail-open direction. Also learned and
  recorded: **sway is `fedxps`-only**; `bigfed` never boots it, which moots the
  cross-machine caveats in these packages. @done(2026-08-13)
- [x] Inspected `sway/config` end to end and restructured it for readability, plus two
  defect fixes (opened item 5 for the deferred tiers). **Verification:** `sway --validate`
  clean, and — because validate provably does *not* check `bindsym` command bodies — all
  83 bindings were additionally executed against a headless nested sway, giving zero
  parse errors; the restructure was diffed as a normalized *set* of active directives to
  prove nothing was lost (115 before, 115 after, only the intended changes).
  **Fixed:** the `$mod+Shift+Escape` poweroff nag's Cancel button did nothing — per
  `man 1 swaynag` only `-z`/`-Z` dismiss, so `-b 'Cancel' 'true'` ran `true` and left the
  bar on screen; now `-s 'Cancel'` renames the built-in dismiss button, and `-b` became
  `-B` on both nags so neither action can be routed through `$TERMINAL`. Also replaced
  the two hardcoded `/home/bph/` paths with `~` (verified sway expands it — validate
  stats the background path, so a bogus one fails rc=1 while the `~` form passes).
  **Readability:** the live touchpad block was sitting under an `# Example configuration:`
  header with more commented example below it; app launchers lived under `### Variables`;
  the trackpad toggle was orphaned flush-left in no section; a stray `# ~/.config/sway/config`
  comment pointed at exactly the file the header warns against editing. Bindings are now
  grouped by function with the binding grammar stated once at the top, every parked
  decision carries its reason inline, and a "Deliberate omissions" section records the
  declined items. @done(2026-08-13)
- [x] Decided how `reboot-check` depends on repo metadata (was item 4): adopted the
  **hybrid fallback**. Full check first (advisories are a documented input, so repos
  stay enabled); on any unparseable verdict a retry with `--disable-repo='*'` — no
  metadata, no keyring, works with zero cache — reports the core-package verdict
  visibly flagged as degraded. Exit codes stay verdict-matched (rc 2 remains "no
  verdict at all"); the degraded message shrinks its claim to its evidence ("no core
  updates or stale services since boot") and carries the failing call's stderr
  excerpt plus a paste-ready remedy (`dnf needs-restarting`). The service scan runs
  `--disable-repo='*'` unconditionally — dnf5-needs-restarting(8) defines `-s` by
  rpmdb facts alone, no advisory input; measured byte-identical and ~1.2s faster
  (the scan was empty that day, so the man-page definition carries the semantic
  claim). Both calls surface stderr's first line in degraded/[WARN] messages.
  **Live findings that correct this item's original account** (same dnf5 5.4.2.1
  as the incident): with a tty on stdin dnf asks and blocks — reproduced via a pty,
  and the question never even flushes through a captured stdout, so the hang is
  signless; with stdin closed the question lands on *stderr*, EOF declines it, and
  dnf **skips the unverifiable repo and succeeds** — so a declined key no longer
  fails the check (the "declined key → [WARN]" model was wrong), and the hybrid's
  real triggers are hard failures. Degraded path live-verified with a cold cache
  behind a dead proxy: flagged core verdict with the true cause in-line, 2.9s.
  Suite grown to 75 checks, mutation-verified five ways (fallback disabled → exactly
  the 15 fallback checks fail; `-s` repos re-enabled → exactly 1; degraded note
  silenced → exactly 5; each `</dev/null` guard → exactly its own stdin probe).
  Declined: always `--disable-repo='*'` for the main check (silently narrows the
  verdict); rc 2 for a degraded no; prompt-text sniffing (dnf's human text is not a
  contract — and its stream choice proved variable within one day); upstream dnf5
  report (user decision 2026-08-09: local workflow only); any gpushall change — an
  independent audit found the dnf bug class absent from `50-git-sync.sh` (git, ssh,
  and gpg all prompt via `/dev/tty`, so nothing blocks invisibly under capture; the
  vet prompt is `[[ -t 0 ]]`-gated), with two adjacent observations recorded under
  Notes. @done(2026-08-09)

- [x] Retired the `scripts` repo (survey + fold-in). Verdict of the survey: 14 of its
  16 items were regenerable one-offs (OCR/PDF/plot/file-management scripts, a stale
  third-party tweet-deleter) — deleted. Adopted the two keepers: the 153-check
  git-sync regression battery as `tests/gsync/` (suites re-rooted via `CFG_ROOT` so
  they test the checkout they live in, not a hardcoded `~/Desktop` path; verified
  153/153 post-move) and `sysinfo.sh` into `bin/` (stowed). Dropped `scripts` from
  `REPOS_DESKTOP`; local repo moved to `~/Desktop/archive/scripts` with full history
  — the **sole** history copy once the GitHub remote is deleted (planned). Docs
  updated here (CLAUDE.md) and in the Desktop-level CLAUDE.md. @done(2026-08-04)

- [x] Post-sweep self-audit (prompted by "did anything break?"): discovered that every
  headless `nvim` run — the day's test probes and `tests/nvim-syntax/run.sh` alike —
  had been saving a session for its CWD on exit, and the smoke tests had overwritten
  the real `configs` session with a scratch-file buffer (unrecoverable, low-value; the
  next interactive exit in `configs` re-creates it). Deleted the five junk/synthetic
  session files (kept `dissertation.vim` — 7 real buffers, genuine). Added a headless
  guard to `persistence.lua`: an init()-registered VimLeavePre autocmd calling
  `stop()` when no UI is attached. First attempt used VimEnter and **failed** —
  `nvim --headless +qa!` exits before VimEnter fires; the VimLeavePre placement is
  load-bearing. Verified: neither headless exit pattern saves; the syntax suite leaves
  no session; a pynvim `ui_attach` instance (interactive-equivalent) still saves
  normally. @done(2026-07-26)

- [x] Staleness sweep of `nvim/` (full-directory audit). Removed the 8 dead
  `vimtex_*` settings from `vimtex.lua` — 7 (`root_markers`, `texmf_home`,
  `includegraphics_search_paths`, `complete_{recursive_bib,input_paths,scan_files_depth}`,
  `include_search_paths`) were never VimTeX options at all, and `compiler_progname` was
  deprecated upstream in 2021. Verified inert three ways: grepped every installed plugin,
  the whole config, and `~/Desktop` scripts for readers (none); confirmed absent from
  VimTeX code *and* docs; diffed VimTeX's resolved runtime state on a dissertation
  chapter before/after (identical — root/main-file detection was always VimTeX's own
  heuristics). Widened persistence autoload from the six-root allowlist to any CWD under
  `~/Desktop` — sessions were already saved for every CWD (80 on file, incl. Carnap,
  LogiKEy, org subdirs) and `<leader>qs` already restored anywhere; the list gated only
  empty-start autoload. Verified end-to-end in a scratch dir (save → autoload-restore →
  negative control outside Desktop). Everything else checked healthy: syntax regression
  suite 24/24 before and after; snippet `--check`/`--coverage` clean; treesitter
  `highlight.disable` still honored by LazyVim's `main`-branch shim (and no latex parser
  installed — double protection); headless startup clean; new `after/syntax/` live via
  the existing `after` symlink (no restow needed); `nvr`/`pandoc`/`live-server`/`latexmk`
  all resolve; lockfile matches installed plugins. `lua/plugins/inactive/` kept
  deliberately (parked experiments, per session decision). Same-day follow-up resolved
  the stylua question: it is *load-bearing* — LazyVim format-on-save (conform → Mason's
  stylua) formats Lua on every in-editor save, which is why the tree was mostly clean;
  the 4 drifted files had last been written outside Neovim. (Headless probes first made
  it look inactive: LazyVim registers format-on-save in its VeryLazy callback, which
  never fires under `--headless` — firing it manually proved the chain.) Formatted the
  4 files via CLI (verified byte-identical to what an in-editor save produces), added
  `nvim/.styluaignore` for the 2 generated snippet files (verified honored by both CLI
  walk and editor path), restowed, corrected CLAUDE.md's formatter docs; `--check` now
  clean. @done(2026-07-26)

- [x] Follow-ups to item 2, same day: `--coverage` mode in the snippet generator
  (cross-references the `.sty` against `vimtex.lua`'s registrations; wired into the
  auto-regen notification, so a new macro without highlighting is flagged on next
  Neovim start); committed the 24-check headless syntax regression suite as
  `tests/nvim-syntax/run.sh` (verified both green and red paths); env snippets no
  longer emit macro-valued optional defaults (`\proof~` dropped its redundant
  `[\proofname]`). @done(2026-07-26)

- [x] Optimized the `french-logic.sty` ↔ Neovim interplay (was item 2). **Coverage:**
  registered the ~60 unhighlighted commands (affirm/deny family, metalanguage
  connectives, `\by`/`\close`/`\infr`/`\hyphantom`, `Rup`/`Rdown`/`Lup`/`Ldown` order
  conditions, `cax`/`Kfour`/`Kfive`/`Kfourfive`/`EN`/`Rlog`, `r[me]?poss` rules, `qed`,
  `tuple`, `precedes`, `metalogic`, `incomp`, I/O connectives) — now 504/509 covered,
  the 5 exclusions deliberate and documented. **Environment names** coloured by family
  via a new `after/syntax/tex.lua` (theorem-family orange, proof/derivation magenta,
  lists default cyan); gentzen math-region registration deliberately skipped (retired
  notation, per session decision). **Three latent bugs found and fixed:** (a) every
  `re()`/`mre()`/`mare()` pattern registration had been silently dead — VimTeX drops
  `cmdre` entries without `name`; all 31 patterns now have group-name slugs and were
  runtime-verified; (b) `argstyle` never accepted highlight groups, so all intended
  argument colouring was dead — replaced with `arglink()` + explicit links applied in
  the ftplugin; (c) an unguarded `serverstart("/tmp/nvimsocket")` aborted the whole
  vimtex `init()` in any second Neovim instance — now `pcall`ed. **Rebalance:**
  `texCmdRule` dark5 → TokyoNight purple (hue-tied to the magenta proof envs).
  **Snippets:** generator now parses `\newtheorem` (11 new env snippets incl.
  `definition`/`theorem`) and env optional args (`proofsketch[Proof sketch]`), stamps
  the `.sty` sha256 into the output, and gained `--check`; `snippets.lua`
  auto-regenerates on stamp mismatch at LuaSnip load (chosen over hook/manual
  options). Verified by a 24-check headless suite plus a live dissertation-chapter
  smoke test (`\CMr` → axiom gold). @done(2026-07-26)

- [x] Configure markdown-tasks.lua(s) to handle all of the following:
    - mt - toggle `[ ]/[x]`
    - md - toggle marked done
    - ms - toggle marked started
    - mD - toggle both `[ ]/[x]` and done
- [x] Configure markdown_tasks.lua(s) to either (a) generate a TASKS.md file with all open tasks in a directory, or (b) write a bash script/function that accomplishes the same thing. @done(2025-11-25 09:16)
- [x] Initialize `~/.bashrc.d` directory and split up aliases and functions. @done(2025-11-24 21:28)
- [x] Update Neovim README when the dust settles @done(2026-03-20)
- [x] Full staleness survey of the repo; fixed the README's missing `bin` package, corrected the Sway accent colour in the docs, cleared stale `.bak`/`.save`/diff artifacts, guarded the dead bun PATH entry @done(2026-07-26)
- [x] Consolidate homegrown scripts into `bin/`: moved `okular-forward` / `okular-inverse` from `~/.local/bin`, verified resolution is unchanged. Left `~/bin/isabelle*` untracked — generated by `isabelle install ~/bin` @done(2026-07-26)
- [x] Add an `okular` stow package for `okularpartrc`, excluding `okularrc` and `docdata/`; confirmed over two write cycles that Okular does not break the symlink @done(2026-07-26)
- [x] Four-lens adversarial audit of the git-sync rewrite (independent reviewers: control flow, bash semantics, git semantics, test blind spots) after a return-status bug reached production. Fixed everything found: unborn-branch guard bypass (gpush could root-commit a fresh `git init`), fail-open vet listing (now fails closed), `:(literal)` unstaging with post-verify (leading-colon/glob filenames could dodge a decline), rename/typechange vet bypass (`git mv x .env` now vetted), embedded-git-repo detection, per-component secrets matching (`.env/` dirs), `REVERT_HEAD` in-progress guard, dropped `--tags` from pulls (force-moved tag wedged every sync), `gpushall` parser (`-f` no longer commits 13 repos with message `-f`; multi-word positional messages no longer truncate), offline no-upstream PEND, push-path integrated-changes reporting + hints (silent fast-forward fixed), rebase-abort verification, prompt context duplicated to stderr under capture, `GSYNC_MAX_MB` validation, exact-ref `ls-remote`. Regression suites grown to 153 checks in four files. @done(2026-07-26)
- [x] Overhauled the git-sync commands (was item 1): collapsed the gpull/gpullall and gpush/gpushall duplication into shared `_gsync_pull_repo`/`_gsync_push_repo` helpers; added new-file vetting (size via `GSYNC_MAX_MB`, secrets globs, y/N prompts), listing of first-time-committed files, an in-progress rebase/merge guard, auto-abort on rebase conflict, offline-aware pushes (commit locally, mark pending), non-main-branch warnings, compact colorized output with named-repo summaries, multi-name `gpull`/`gpush` with `-m` and tab completion, a `gstatall [-f]` dashboard with per-repo sync verdicts (needs push / needs pull / DIVERGED), a post-pull ahead-of-origin warning, post-pull re-source/restow hints, and removal of the redundant pre-pull fetch (~half the network round-trips). Verified by a 37-check sandbox suite plus a live `gstatall`/`gpullall` run. @done(2026-07-26)
