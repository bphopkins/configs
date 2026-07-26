# TODO List

Planned pieces of work, each big enough to want its own session. Written up in
enough detail to brief a fresh chat without re-deriving the findings — the notes under
each item come from a full repo survey on 2026-07-26. (Item 1, the git-sync overhaul,
was completed 2026-07-26 — see Done. Items keep their original numbers because other
docs reference them.)

Priority for the next working day: **(2)**.

---

## 2. Optimize the `french-logic.sty` ↔ Neovim interplay — *priority*

- [ ] Improve the snippet generator, close the syntax-highlighting coverage gaps, and revisit the colour scheme.

**The pieces involved.** `latex/french-logic/french-logic.sty` (513 commands,
24 environments) → `nvim/lua/snippets/sty-lua-snippets.py` (281 lines) generates
`nvim/lua/snippets/french-logic.lua` → snippets loaded via `lua/plugins/snippets.lua`.
Separately, `lua/plugins/vimtex.lua` registers 208 literal command names and 25 regex
patterns into 7 semantic highlight groups, which are coloured in
`after/ftplugin/tex.lua` (195 lines, TokyoNight night palette).

**Highlighting gap A — 63 commands unregistered.** Verified against the `.sty`: there
are *zero* dead registrations (every name and pattern matches something real), but 63
defined commands get no custom group. They fall into coherent families whose siblings
*are* highlighted, with real usage across `dissertation/`, `opuscula/`, `n-cube/`,
`teaching/`:

| family | members | uses |
|---|---|---|
| affirm/deny I/O | `af` `aff` `affirm` `afland` `aflor` `afneg` `afto` `de` `den` `deny` `deneg` `deland` `delor` `deto` `clor` `ilor` `cto` `ito` | ~370 (`\af` 100, `\de` 100) |
| metalanguage connectives | `mlnot` `mlforall` `mlexists` + the six `*solo` variants | ~20 (`mland`/`mlor`/`mlto` *are* registered — 3 of 12) |
| misc | `incomp` 28, `tuple` 25, `ecu` 25, `qed` 20, `precedes` 18 | ~116 |
| axioms | `cax` `caxc` `caxpar` | 11 |
| logic systems | `Kfour` `Kfive` `Kfourfive` `EN` `Rlog` | 5 |

Note `cax` is missed only because the pattern is `[kdtupwn]ax\w*` — k/d/t/u/p/w/n but
not `c`. One character.

**Highlighting gap B — all 24 environments, and this is the bigger win.**
`vim.g.vimtex_syntax_custom_envs` is **never set**, so no environment gets custom
highlighting at all. Usage counts: `gentzen` 157, `block` 150, `hilbertlist` 143,
`definition` 104, `theorem` 48, `romanlist` 35, `remark` 21, `arablist` 20,
`proofsketch` 16, `itemlist` 14, `lemma` 6, `note` 6, `proposition` 5, `convention` 4,
`digression` 3, `example` 1 — roughly 730 uses. This needs new highlight groups in
`after/ftplugin/tex.lua` as well as the vimtex registration, so it involves colour
choices.

**Snippet generator.** Regeneration is manual and there is no check that it has been
run, so `french-logic.lua` can silently fall out of step with the `.sty` — the failure
mode is stale completions, with no error. (Verified in sync as of 2026-07-26.) Worth
considering: a check that flags desync, or wiring regeneration into a git hook.

```bash
cd ~/Desktop/configs
python3 nvim/lua/snippets/sty-lua-snippets.py \
  -i latex/french-logic/french-logic.sty -o nvim/lua/snippets/french-logic.lua
```

**Careful:** `french-logic.sty` is a shared dependency — `dissertation/`,
`teaching/`, `teach-logic/`, and `opuscula/` all load the stowed copy, so edits ripple.
Its line-1 `% !TEX root` pointing at `dissertation.tex` is **intentional** until the
dissertation is finished (~2027); leave it.

---

## 3. Overhaul the `~/.bashrc.d` cluster

- [ ] Review the whole modular bash setup for robustness.

Lower priority than 1 and 2. The structure is sound — `.bashrc` sources
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
