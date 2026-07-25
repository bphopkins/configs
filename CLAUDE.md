# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A GNU Stow-based dotfiles repository for Fedora Linux, synced across multiple machines (fedxps, bigfed) via git. **This is a public GitHub repo** (`github.com/bphopkins/configs`) — anything committed is published (see Pitfalls). Configs are stored here at `~/Desktop/configs` and symlinked to their live locations. The user is an academic working in logic/philosophy — the LaTeX and Neovim configs are heavily tailored to dissertation writing.

## Stow Deployment

Each top-level directory (except `wallpapers/`) is a stow "package" with a specific target. The source of truth for targets is the associative array in `bash/.bashrc.d/60-stow.sh`:

| Package    | Stow Target                  |
|------------|------------------------------|
| bash       | `~`                          |
| wezterm    | `~`                          |
| alacritty  | `~/.config/alacritty`        |
| nvim       | `~/.config/nvim`             |
| sway       | `~/.config/sway`             |
| waybar     | `~/.config/waybar`           |
| latex      | `~/texmf/tex/latex`          |
| bin        | `~/bin`                      |

Key commands (defined in `bash/.bashrc.d/60-stow.sh`):
- `stow-all` — `git pull --ff-only`, then restow every package (`stow -R`). On a conflict (an untracked real file already sitting at a target) it **errors out** rather than resolving it — adopt or remove the file manually (README §8 covers `stow --adopt`), then rerun.
- `stow-all-dry` — preview what stow-all would do (no changes)
- `unstow-all` — remove all managed symlinks (`stow -D`)

When adding a new stow package, update both the target map and the ordering array in `60-stow.sh`. Editing existing symlinked files requires no restow; adding new files to a package does.

`README.md` is the authoritative from-scratch walkthrough for standing this up on a new machine (import live dotfiles → seed commit → dry-run stow → link → verify → reload); its §8 covers conflict resolution (`stow --adopt`), per-package restow, and unlinking.

## Daily Sync Workflow

Start of session: `gpullall` → `source ~/.bashrc` (if bash files changed) → `stow-all` (if files added/deleted). End of session: `gpushall`.

## Git Sync Workflow

Defined in `bash/.bashrc.d/50-git-sync.sh`:
- `gpullall` — pulls every repo in the `REPOS_DESKTOP` array (ff-only, with submodule handling)
- `gpushall` — auto-stages (`git add -A`), commits (hostname + timestamp), rebases, and pushes every repo
- `gpull <name>` / `gpush <name>` — single-repo variants operating on `~/Desktop/<name>`

To add a new repo, append its path to the `REPOS_DESKTOP` array. Commit messages follow: `{hostname}: {YYYY-MM-DD HH:MM:SS}`. Note that `REPOS_DESKTOP` spans *all* the user's Desktop repos (dissertation, teaching, etc.), not just this one.

## Bash Configuration

Modular design: `.bashrc` sources all `~/.bashrc.d/*.sh` files. The numbered prefix controls load order:
- `00-shell-opts.sh` — shopt/set options
- `10-env.sh` — environment variables (`EDITOR`/`VISUAL` = nvim)
- `20-path.sh` — PATH/MANPATH/INFOPATH additions (guards against duplicates via substring matching); also sets `BUN_INSTALL` and prepends `~/bin`, `~/.local/bin`, `~/.local/npm-global/bin`. **TeX Live is auto-detected, not hardcoded**: it picks the newest `/usr/local/texlive/YYYY` that actually contains a working `tlmgr` (half-installed trees are skipped, so a parallel install in progress can't knock TeX Live out of PATH). Override with `TEXLIVE_YEAR=<year>` to pin an older release — see "TeX Live release upgrades" below
- `30-prompt.sh` — prompt config
- `40-aliases.sh` — aliases: `sysupgrade` (dnf + flatpak update), `tl-upgrade` (TeX Live `tlmgr` self+all update; resolves `tlmgr` through PATH so it survives year bumps — note this only updates *within* a release, see "TeX Live release upgrades" below), `cc` (`claude --model opus --effort max`), plus `cd`+`ls` navigation/edit shortcuts (`configs`, `dissertate`, `teach`, `logic`, …)
- `50-git-sync.sh` — git sync functions (`gpullall`, `gpushall`)
- `60-stow.sh` — stow functions (`stow-all`, `unstow-all`)
- `70-task-list.sh` — `ls-tasks [PATH]`: recursively lists unchecked `- [ ]` items from markdown files
- `80-clamav.sh` — `clam {update,home,full}`: ClamAV signature refresh and scan helpers (logs to `~/clam-scan-{home,full}-<ts>.log`). Requires `clamav` + `clamav-update`.
- `90-nix.sh` — nix profile loader (conditional; only if nix is installed)

## Neovim Configuration

LazyVim-based setup. Entry point: `nvim/init.lua` bootstraps lazy.nvim via `lua/config/lazy.lua`.

### Directory layout
- `lua/config/` — core settings (options, keymaps, autocmds, markdown_tasks, pandoc)
- `lua/plugins/` — plugin specs (each file returns a lazy.nvim plugin spec table)
- `lua/plugins/inactive/` — disabled plugins (not loaded by lazy.nvim)
- `lua/snippets/` — LuaSnip snippet libraries
- `after/ftplugin/` — filetype overrides (tex.lua is ~195 lines of custom highlight-group colors)

### LaTeX toolchain
VimTeX with latexmk compiler and Okular PDF viewer (forward/reverse sync via neovim-remote). Treesitter highlighting is disabled for LaTeX — VimTeX's syntax engine is the sole highlighter. Custom syntax in `lua/plugins/vimtex.lua` registers 350+ commands across 7 semantic highlight groups (axioms, frame conditions, logic systems, semantic notation, modal operators, proof rules, set notation), colored in `after/ftplugin/tex.lua`.

### Completion stack (for TeX filetypes)
blink.cmp (UI) → blink.compat (adapter) → cmp-vimtex (source) → VimTeX (scanner). TeX filetypes only use snippets + VimTeX completions (no LSP). Configured in `lua/plugins/completions.lua`.

### Snippets
`lua/snippets/french-logic.lua` (auto-generated from `french-logic.sty` by `sty-lua-snippets.py`) and `latex-workshop.lua` (BibTeX templates). Loaded via filetype extensions in `lua/plugins/snippets.lua`.

Regenerate after editing `french-logic.sty`:
```bash
cd ~/Desktop/configs
python3 nvim/lua/snippets/sty-lua-snippets.py -i latex/french-logic/french-logic.sty -o nvim/lua/snippets/french-logic.lua
```

### Markdown tasks
Custom task system in `lua/config/markdown_tasks.lua` with keybindings in `lua/plugins/markdown_tasks.lua`:
- `<localleader>mt` — toggle `[ ]`/`[x]`
- `<localleader>md` — toggle `@done(timestamp)`
- `<localleader>ms` — toggle `@started(timestamp)`
- `<localleader>mD` — toggle checkbox + @done synced
- `<CR>` in insert mode — smart newline (continues checkbox lists)

### Session persistence
`lua/plugins/persistence.lua` auto-loads sessions for specific roots: `~/Desktop/{dissertation,bphopkins.net,nousowl.net,configs,teaching,org}`. Bypass with `NVIM_NOSESSION=1`.

### Formatter
stylua (config in `nvim/stylua.toml`: 2-space indent, 100 columns). Run from repo root: `stylua nvim/`

## LaTeX Packages

Custom `.sty` and `.cls` files in `latex/` are stowed into `~/texmf/tex/latex`. Key package:

- **french-logic** — 350+ macros for modal/deontic logic (semantic notation, modal operators, axiom schemas, logic system labels). Single `\usepackage{french-logic}` replaces a 100+ line preamble. Has a `deon` option for DEON conference submissions. **Shared dependency:** sibling repos (`dissertation/`, `dissertation-template/`, `teaching/`, `teach-logic/`) load it from the stowed copy, so edits here ripple into all of them. It is also the source for the auto-generated Neovim snippets — regenerate `french-logic.lua` after any macro change (see Snippets above) or completions go stale.
- **bph-paper** — article class with BibLaTeX Chicago style and custom quotation environments
- **logic-hw**, **mod-cv**, **tufte-compact** — homework, CV, and handout classes

## TeX Live release upgrades

TeX Live is installed from the CTAN mirrors (not RPM), under `/usr/local/texlive/YYYY`.

**`tlmgr` cannot cross a release boundary.** It updates packages *within* a release — which it does continuously, since the tlnet repo refreshes daily — but refuses year-to-year upgrades by design. Crossing a year means a **parallel install**: the new release goes in alongside the old, both are verified to produce identical output, and only then does PATH move. Multiple releases coexist happily.

**`tl-newyear` (in the `bin` package) automates this.** Stages are separate subcommands because there is a human go/no-go decision in the middle:

```bash
tl-newyear status              # installed releases, which is active, baseline on file
tl-newyear preflight           # disk + btrfs headroom check
tl-newyear baseline            # fingerprint every document on the CURRENT release
tl-newyear install 2027        # parallel install; does NOT touch PATH
tl-newyear compare 2027        # recompile, diff against baseline
tl-newyear visdiff <doc.tex>   # pixel-compare one document across releases
tl-newyear switch 2027         # migrate symlinks, only after a clean compare
```

State (root lists, fingerprints, per-run logs and PDFs) lives in `~/.cache/tl-newyear`; the helper scripts are `tl-roots.sh`, `tl-check.sh`, `tl-compare.sh`, `tl-visdiff.sh`. Builds always go to that state tree via `-output-directory` — never in-place, because `teach-logic/` and `opuscula/` track their build artifacts and an in-place recompile would dirty tracked PDFs.

The procedure it implements, in order:

1. **Baseline first.** Compile every document on the *current* release and record page counts plus a `pdftotext | md5` fingerprint. Without this you cannot tell "the new release broke it" from "it was already broken."
2. **Check btrfs headroom.** The root filesystem is btrfs, and a `scheme-full` install writes ~180k files. If `btrfs filesystem usage /` shows little **Device unallocated**, the install dies with `No space left on device` *even though `df` reports plenty free* — free space inside already-allocated data chunks cannot be used for metadata. Fix with `sudo btrfs balance start -dusage=0 /` then `-dusage=50 /`. This bit the 2025→2026 upgrade.
3. **Install with `instopt_adjustpath 0`** so `/usr/local/bin` symlinks (~500 of them) keep pointing at the old release and the old toolchain stays active.
4. **Re-compile and diff** against the baseline. Expect many `pdftotext` hash changes that are *not* regressions — newer releases fix glyph-to-Unicode mappings, so logic symbols extract correctly where they previously came out as garbage. Confirm with a pixel comparison (`pdftoppm` + `compare -metric AE`) rather than trusting the text hash.
5. **Switch** with `tlmgr path remove` on the old release then `tlmgr path add` on the new. `20-path.sh` picks up the new year automatically. Keep the old tree until confident.

**Known casualty: the *forall x* textbook.** `tabu` v2.9 (unmaintained since 2019) patches `array.sty`'s internals, and `array` was rewritten in TL2026 (`1995/06/01` → `2026/06/01`). This breaks all `forallxyyc*` builds in `teach-logic/` with `TeX capacity exceeded [grouping levels]`, and shifts the solutions documents by one page. `tabu` is used nowhere else — the dissertation, `opuscula/`, `org/`, `teaching/`, and `n-cube/` are unaffected. Until upstream *forall x: Calgary* migrates to `tabularray`, build the textbook pinned to the old release:

```bash
TEXLIVE_YEAR=2025 make      # in any forallx-yyc-build/ directory
```

A pin naming a release that isn't installed **warns** (interactive shells only) and is otherwise ignored — PATH gets no TeX Live entry and commands fall through to the `/usr/local/bin` symlinks, which point at whichever release is active. So a pin only works on a machine that still has the pinned release.

### Rolling a release out to the second machine

The scripts and dotfiles travel in git; the ~13GB TeX Live tree does not. Order matters:

```bash
# on the machine that already upgraded
gpushall

# on the other machine
gpullall
source ~/.bashrc            # MUST precede stow-all -- see below
stow-all
tl-newyear status
tl-newyear preflight
tl-newyear install <year>
tl-newyear switch <year>
source ~/.bashrc
```

**Why the re-source must come first.** `stow-all` iterates `STOW_ORDER` / `STOW_TARGETS` as loaded in the *running shell*. A pull that adds a **new** stow package (as `bin` was) updates `60-stow.sh` on disk but not the arrays in memory, so `stow-all` skips the new package **silently** — no error, it simply isn't in the list being iterated. Applies to any newly added package, not just this one.

**Re-verifying on the second machine is optional.** TeX Live is deterministic given the same inputs, so a release verified on one machine behaves the same on the other. Run `baseline` + `compare` there only to catch machine-specific divergence — a different `~/texmf`, or repos sitting at a different commit. If you do, `baseline` must run *before* `install`, since it fingerprints whichever release is currently active.

**Revision drift between machines.** Two machines installing the same release on different days get different tlnet snapshots, so package versions differ slightly. Harmless in general, but run `tl-upgrade` on both before generating a final dissertation PDF so the output doesn't depend on which machine you happened to use.

**`~/.cache/tl-newyear` is machine-local** — per-machine fingerprints plus ~130MB of build artifacts. Deliberately not synced, and shouldn't be.

## Sway/Waybar

Sway uses vim-style navigation (hjkl). Mod4 (Super) is the primary modifier. Forest green (#228B22) accent color. Waybar config is JSON + `style.css`.

## Visual Consistency

TokyoNight "night" theme across Neovim, WezTerm, and Waybar. Source Code Pro 12pt font in both terminals (WezTerm, Alacritty). Forest green (#228B22) accent in Sway borders and Waybar active workspace.

## Pitfalls

- **`stow-all` does not auto-adopt.** It restows (`stow -R`); a pre-existing untracked file at a target makes it error out, not overwrite. Resolve with `stow --adopt` or by removing the file (README §8), then rerun.
- **Public repo + minimal `.gitignore` + `gpushall` runs `git add -A`.** Only `.claude/settings.local.json` is ignored — everything else in the tree gets committed *and pushed to a public remote*, including the tracked `*.lua.bak` backups under `nvim/`. Don't park secrets, private data, or large binaries here expecting them to be skipped.
- **`french-logic.sty` is a shared, snippet-coupled dependency** — editing it affects the dissertation/teaching repos and silently desyncs the generated snippet file. See the LaTeX Packages section before touching it.
- **Adding files to a package needs a restow** (`stow -R <pkg>`) to create the new symlinks; editing already-linked files does not.
