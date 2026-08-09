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
empty slots*, not dead files. `90-nix.sh` is kept ready for Carnap development even
though nix isn't installed. `.bashrc.min` / `.bash_profile.min` are rescue configs.
A `~/.config/environment.d` PATH drop-in was considered and **declined** — it would
give PATH a second source of truth that wouldn't reproduce `20-path.sh`'s
TeX-Live-first ordering.

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
- Alacritty carries font settings only, no colourscheme, so it is the one terminal not
  on TokyoNight. Deliberate or not, it's a one-block fix whenever wanted.
- `wallpapers/monarch1080.png` (2.0 MB) and the five solid-colour PNGs are referenced
  nowhere; only `monarch1080dark.png` is used (by `sway/config` and the GNOME
  background). ~3.6 MB of the repo's 9.2 MB is this directory, which is not a stow
  package.

---

## Done

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
