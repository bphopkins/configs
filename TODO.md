# TODO List

Three planned pieces of work, each big enough to want its own session. Written up in
enough detail to brief a fresh chat without re-deriving the findings — the notes under
each item come from a full repo survey on 2026-07-26.

Priorities for the next working day: **(1)** and **(2)**.

---

## 1. Optimize the git-sync commands — *priority*

- [ ] Collapse the duplication in `bash/.bashrc.d/50-git-sync.sh` and decide what else the sync helpers should do.

**The core problem.** The file is 343 lines and roughly 200 of them are the same logic
written twice. `gpull` (lines 18–66) duplicates the body of `gpullall`'s loop (156–216);
`gpush` (68–150) duplicates `gpushall`'s (230–340). The `*all` variants add only
`ok`/`skipped`/`failed` counters and `continue` statements. The obvious shape is a
per-repo helper that both the single-repo and the all-repos entry points call, with the
loop owning the counters.

**Why it matters beyond tidiness.** Two copies can drift. A fix applied to `gpushall`
and not `gpush` would be invisible until the day it bites.

**Worth deciding at the same time:**
- `gpushall` runs `git add -A` across *all* 13 repos with no size or content check. A
  guard — warn before committing a file over some threshold, or anything matching a
  secrets-ish pattern — would be cheap. `configs` is public and `teach-logic` holds
  exam keys, so the blast radius is real.
- Behavior on partial failure: currently a failed repo is counted and skipped, and the
  summary line is easy to miss when 13 repos scroll past.
- Whether `gpull`/`gpush` should accept more than one repo name.

**Already settled — don't re-litigate:** the timestamped commit-message convention
(`{hostname}: {YYYY-MM-DD HH:MM:SS}`), the `--rebase=merges` strategy, and the contents
of `REPOS_DESKTOP` (13 entries, all verified to exist).

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
