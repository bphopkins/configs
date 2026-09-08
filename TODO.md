# TODO List

Planned pieces of work, each big enough to want its own session. Written up in
enough detail to brief a fresh chat without re-deriving the findings — the
notes under each item come from a full repo survey on 2026-07-26. Items keep
their original numbers because other docs reference them; completed items and
their full post-mortems live in `DECISIONS.md` under those same numbers
(tracker/record split 2026-08-26 — the ## Closed ledger below is the index).

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

## 8. Gradually perfect the generated snippet libraries

- [ ] Fix bulk-generation oddities in the two snippet libraries as they surface
  in real use — no sweep, just capture-and-correct when noticed.

Raised 2026-08-22. The libraries were generated in bulk and small mistakes got
internalized; they function well, but as the permanent snippet source they are
worth perfecting over time ("if these end up being my source for the rest of
time, then it's worth gradually perfecting them from here").

**The one rule that makes fix-as-noticed work — the two files are opposites:**

- `latex-workshop.lua` is a one-time conversion with no generator behind it:
  **hand-edit it freely**; edits are durable (`.styluaignore`d too, so nothing
  reflows them).
- `french-logic.lua` is **regenerated wholesale** whenever `french-logic.sty`
  changes (sha-stamp check at every Neovim start) — **a hand edit there is
  silently obliterated by the next `.sty` change.** Durable fixes go into the
  generator (`sty-lua-snippets.py`) when the oddity is systematic, or into the
  `.sty` itself when the snippet faithfully mirrors a package quirk. Precedent
  for the generator route: the 2026-07-26 env-optional-default refinement
  (`\proof~` dropped its redundant `[\proofname]`) — exactly the shape of
  change this item expects more of.

If a one-off divergence from generator output is ever genuinely needed (not
systematic, not a `.sty` matter), there is **no override mechanism yet** —
designing one is part of this item. Candidates: an exceptions table in the
generator (precedent: `KNOWN_UNREGISTERED` for `--coverage`), or a third
hand-curated library file in `lua/snippets/` plus one name in `snippets.lua`'s
`filetype_extend` (the growth path already noted in
`docs/nvim-audit-2026-08-22.md`). Note that duplicate triggers across libraries do **not** shadow each
other — both appear in the menu — so a shadowing scheme needs actual design,
not just a second file.

## 10. `gpullall`'s restow hint cannot see a *new* stow package

- [ ] Build the package list for the post-pull hint from the repo's directories
  on disk rather than from the in-memory `STOW_ORDER`, and add a regression test
  that adds a new package directory and asserts the `stow-all` hint fires.

Found 2026-09-03 by exercising the workflow end to end: a `configs` pull on
bigfed that added the new `ghostty` package printed only
`[HINT] configs: bash files changed — run: source ~/.bashrc`, and never
mentioned `stow-all`.

**The gap, precisely.** In the post-pull hint classification loop
(`50-git-sync.sh`, around line 311):

```
local -A is_pkg=() pkg_hit=()
if declare -p STOW_ORDER >/dev/null 2>&1; then
  for p in "${STOW_ORDER[@]}"; do is_pkg[$p]=1; done
fi
...
[[ -n "${is_pkg[${p%%/*}]:-}" ]] && pkg_hit[${p%%/*}]=1
```

`is_pkg` comes from `STOW_ORDER` **as loaded in the running shell**. A brand-new
package is by definition absent from that array, because the pull that added it
has only just updated `60-stow.sh` on disk. So `ghostty/config` classified as
"not in a stow package", `pkg_hit` stayed empty, and the hint could not fire.

This is the same in-memory-versus-disk trap `stow-all` itself has — documented
in the root charter — reappearing one layer up, in the tool built to warn about
it. And it misses **exactly** the case that matters: the hint is reliable for
changes to *existing* packages and structurally blind to a *new* one, which is
the only case where forgetting to restow fails silently.

**Why it did not bite.** Adding a package requires editing `60-stow.sh`, which
lives in `bash/`, so `bash_hit` fired and produced the re-source hint. That
coupling is luck, not design, and the hint says `source ~/.bashrc` and stops —
followed literally, the new package is never linked.

**Why the suite did not catch it.** `test-gsync.sh:129` and `test-audit.sh:10`
both `source` the current `60-stow.sh`, so `STOW_ORDER` is always fully
populated, and every stow-hint assertion adds files to an *existing* package
(`bash/.bashrc.d/95-added.sh`, `test-audit.sh:249`). No test has ever introduced
a new package directory.

**Proposed fix.** Populate `is_pkg` from the repo's top-level directories after
the pull — every entry except the known non-packages (`docs`, `tests`,
`wallpapers`, `.git`) — optionally unioned with `STOW_ORDER`. It degrades in the
right direction: an unrecognised directory yields a spurious hint at worst,
never a missing one. Run `tests/gsync/run-all.sh` after.


## 12. The fontconfig duplicate-rejection over-rejects

Found 2026-09-07 in the home-directory audit, after `dejavu-sans-fonts` left
fedxps as a Thunderbird dependency and took the only visible DejaVu Sans with
it. `fontconfig/conf.d/09-texlive-fonts.conf` block (1) rejects whole TeX Live
directories on the premise that Fedora packages the same families. Measured at
the family level on both machines (`fc-scan` of each rejected directory, then
`fc-list ":family=…"` for every family it yields), the premise fails for part
of several directories:

- **Invisible on both machines:** DejaVu Sans Mono and DejaVu Serif (Fedora
  splits DejaVu into three packages and only `dejavu-sans-fonts` is installed),
  Montserrat Alternates, Open Sans Condensed and Condensed Light, STIX Math
  (the `stix` directory is STIX 1; Fedora's `stix-fonts` is STIX Two), and
  fifteen RIT Malayalam families (Fedora has only Meera New and Rachana).
- **Invisible on fedxps only:** Latin Modern Math and MnSymbol (bigfed has the
  `texlive-lm-math` and `texlive-mnsymbol` rpms; fedxps has Latin Modern
  *text* from a user font dir, `~/.local/share/fonts/latinmodern`, and nothing
  for math), Courier 10 Pitch, and FontAwesome 4 (bigfed has
  `fontawesome4-fonts`).

Three ways out, not decided:

1. **Narrow the globs to the files whose families Fedora provides** — reject
   `DejaVuSans*.ttf` but not Mono/Serif, `Montserrat-*` but not the Alternates,
   and drop `stix`, `courierten` and `rit-fonts` from the list. Keeps the
   package machine-independent; the snapshot needs re-measuring after each TeX
   Live release.
2. **Install the Fedora packages the premise assumes, on both machines** —
   `dejavu-sans-mono-fonts`, `dejavu-serif-fonts`, `texlive-lm-math`,
   `texlive-mnsymbol`, each `dnf mark user`. Makes the premise true and settles
   the Latin Modern two-mechanisms question in the rpm direction (the user font
   dir on fedxps then goes). STIX 1, Open Sans Condensed, Montserrat Alternates
   and the RIT set have no Fedora package, so those globs still need option 1.
3. **Accept** the missing families as unused. DejaVu Sans Mono argues against
   this: it is a common monospace fallback.

The measurement is one loop; rerun it on both machines before and after any
change, and after each TeX Live release. Cross-listed in
`org/machines/machines.md` under the Latin Modern item.

## 13. french-logic: the map, the unit split, the rendering suite

- [x] Audit the single-file package end to end; build the consumer harness
  (scratch copy of the dissertation and its siblings, page-by-page diffs) and
  the rendering suite `tests/french-logic/`. @done(2026-09-07)
- [x] Write the map (`latex/french-logic/README.md`) and the inventory
  (`latex/french-logic/AUDIT.md`). @done(2026-09-07)
- [ ] Work the open ledger in the map, one item at a time, each verified by
  both nets before it lands. All thirteen D items closed 2026-09-07; the F
  items (form drift) are worked per unit after the split.
- [x] Split the package into the hub and the unit files the map plans, output-
  identical under both nets; extend the snippet generator to read the units.
  @done(2026-09-07) — fourteen units plus the quarry; no differences across
  27 consumers, no changed fixture page.
- [x] The F items decided by eye on the type board and landed: mode, face
  (rule β), small labels (idiom A), decorations, structure indices, the three
  folds. @done(2026-09-07)
- [ ] The naming grammar: proposal recorded in the map (Conventions, "A grammar
  for the names") and on the board; strict, lenient, or record-only is the
  first decision of the next chat.
- [ ] Per-unit ordering passes: within each unit the blocks still sit in the
  old file's order; reorder by the tower with the suite watching.
- [ ] `dissertation/CLAUDE.md`, the package paragraph: still describes aliascnt,
  the old `deon` semantics, and an absolute path — Brandon's document, update on
  his say-so.
- [x] Decide the option design, the two IO-logic beamer decks, `\hypersetup`
  and `geometry`. @done(2026-09-07) — one keyval switch per unit with `deon`
  and `slim` bundles; the decks pass `deon` and build; hyperref defaults kept;
  geometry stays with the documents.
- [x] The opuscula drift: recorded as finding 10 in opuscula's AUDIT.md and
  left as it is; no version of the package builds them. @done(2026-09-07)

Opened 2026-09-07. The next session opens with `latex/french-logic/next-chat.md`,
the dated brief that says what exists, how to verify it, and what comes next.
The package is a semantic markup language for logic; the
governing principles (nothing deleted without an accepted case, dependencies
ride with the code, one package with unit files, a preamble by default) are
recorded in the map, which is the living contract — read it before touching
`latex/french-logic/`. Run `tests/french-logic/run.sh` after any edit there.

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
  (palette + Source Code Pro matching Waybar; see `wofi/CLAUDE.md`). mako and swaylock still
  fall back to their own defaults for fonts, which has not mattered in practice. Judged too big to
  fold into a config pass; it is a design question, not a config sweep. Waybar was
  monospaced (Source Code Pro, matching the terminals) on its own merits — see `waybar/CLAUDE.md`.
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

## Closed

One line per closed item — verdict, date, pointer. Full notes and post-mortems
are in `DECISIONS.md` under the same item numbers.

- **1. Git-sync overhaul** — collapsed into shared per-repo helpers with vetting and
  guards; 153-check suite. Closed 2026-07-26 → `DECISIONS.md`, Done ledger.
- **2. french-logic ↔ Neovim optimization** — 504/509 coverage, three latent VimTeX
  bugs fixed, self-regenerating snippets. Closed 2026-07-26 → `DECISIONS.md`, Done
  ledger (with same-day follow-ups).
- **4. reboot-check's repo-metadata dependence** — hybrid fallback adopted; degraded
  verdicts flagged in-line. Closed 2026-08-09 → `DECISIONS.md`, Done ledger.
- **5. Sway deferred tiers** — all four tiers done; idle timers and screen blanking
  stay declined. Closed 2026-08-13 → `DECISIONS.md` item 5.
- **6. Sway binding grammar** — the modifier-names-the-target law adopted; container
  tier dropped. Closed 2026-08-22 → `DECISIONS.md` item 6.
- **9. live-server root wrapper** — explicit directories at both ends plus
  `last_root`; simpler shapes measured lossy. Closed 2026-08-22 → `DECISIONS.md`
  item 9.
- **11. Per-window cgroup scopes after the Ghostty launcher change** — confirmed:
  one process per window means the window *is* the cgroup, so `linux-cgroup =
  always` stays declined. The item's *reasoning* needed correcting — `systemd-oomd`
  is inactive here, so the cgroup-level reaper it assumed is not running; the
  verdict survives on other grounds. Closed 2026-09-05 → `DECISIONS.md` item 11.
- Unnumbered closed work (the 2026-08-22 latency fix, lock/notifications, the sway
  restructure, the `scripts` repo retirement, the 2026-07-26 staleness sweeps,
  earlier setup) → `DECISIONS.md`, Done ledger.
