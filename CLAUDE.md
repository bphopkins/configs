# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A GNU Stow-based dotfiles repository for Fedora Linux, synced across multiple machines (fedxps, bigfed) via git. Configs are stored here at `~/Desktop/configs` and symlinked to their live locations. The user is an academic working in logic/philosophy — the LaTeX and Neovim configs are heavily tailored to dissertation writing.

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

Key commands (defined in `bash/.bashrc.d/60-stow.sh`):
- `stow-all` — git pull then restow all packages (uses `--adopt` to resolve conflicts)
- `stow-all-dry` — preview what stow-all would do
- `unstow-all` — remove all managed symlinks

When adding a new stow package, update both the target map and the ordering array in `60-stow.sh`. Editing existing symlinked files requires no restow; adding new files to a package does.

## Git Sync Workflow

Defined in `bash/.bashrc.d/50-git-sync.sh`:
- `gpullall` — pulls all repos in the `REPOS_DESKTOP` array (ff-only, with submodule handling)
- `gpushall` — auto-stages (`git add -A`), commits (hostname + timestamp), rebases, and pushes all repos

To add a new repo, append its path to the `REPOS_DESKTOP` array. Commit messages follow: `{hostname}: {YYYY-MM-DD HH:MM:SS}`

## Bash Configuration

Modular design: `.bashrc` sources all `~/.bashrc.d/*.sh` files. The numbered prefix controls load order:
- `00-shell-opts.sh` — shopt/set options
- `10-env.sh` — environment variables (`EDITOR`/`VISUAL` = nvim)
- `20-path.sh` — PATH additions (guards against duplicates via substring matching)
- `30-prompt.sh` — prompt config
- `40-aliases.sh` — aliases (`sysupgrade`, `cc` for claude, navigation shortcuts)
- `50-git-sync.sh` — git sync functions (`gpullall`, `gpushall`)
- `60-stow.sh` — stow functions (`stow-all`, `unstow-all`)
- `70-task-list.sh` — `ls-tasks [PATH]`: recursively lists unchecked `- [ ]` items from markdown files
- `90-nix.sh` — nix profile loader (conditional; only if nix is installed)

## Neovim Configuration

LazyVim-based setup. Entry point: `nvim/init.lua` bootstraps lazy.nvim via `lua/config/lazy.lua`.

### Directory layout
- `lua/config/` — core settings (options, keymaps, autocmds, markdown_tasks, pandoc)
- `lua/plugins/` — plugin specs (each file returns a lazy.nvim plugin spec table)
- `lua/plugins/inactive/` — disabled plugins (not loaded by lazy.nvim)
- `lua/snippets/` — LuaSnip snippet libraries
- `after/ftplugin/` — filetype overrides (tex.lua has 196 lines of custom highlight groups)

### LaTeX toolchain
VimTeX with latexmk compiler and Okular PDF viewer (forward/reverse sync via neovim-remote). Treesitter highlighting is disabled for LaTeX — VimTeX's syntax engine is the sole highlighter. Custom syntax in `lua/plugins/vimtex.lua` registers 350+ commands across 7 semantic highlight groups (axioms, frame conditions, logic systems, semantic notation, modal operators, proof rules, set notation), colored in `after/ftplugin/tex.lua`.

### Completion stack (for TeX filetypes)
blink.cmp (UI) → blink.compat (adapter) → cmp-vimtex (source) → VimTeX (scanner). TeX filetypes only use snippets + VimTeX completions (no LSP). Configured in `lua/plugins/completions.lua`.

### Snippets
`lua/snippets/french-logic.lua` (auto-generated from `french-logic.sty` by `sty-lua-snippets.py`) and `latex-workshop.lua` (BibTeX templates). Loaded via filetype extensions in `lua/plugins/snippets.lua`.

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
stylua (config in `nvim/stylua.toml`: 2-space indent, 100 columns).

## LaTeX Packages

Custom `.sty` and `.cls` files in `latex/` are stowed into `~/texmf/tex/latex`. Key package:

- **french-logic** — 350+ macros for modal/deontic logic (semantic notation, modal operators, axiom schemas, logic system labels). Single `\usepackage{french-logic}` replaces a 100+ line preamble. Has a `deon` option for DEON conference submissions. This is the source for auto-generated Neovim snippets.
- **bph-paper** — article class with BibLaTeX Chicago style and custom quotation environments
- **logic-hw**, **mod-cv**, **tufte-compact** — homework, CV, and handout classes

## Sway/Waybar

Sway uses vim-style navigation (hjkl). Mod4 (Super) is the primary modifier. Forest green (#228B22) accent color. Waybar config is JSON + `style.css`.

## Visual Consistency

TokyoNight "night" theme across Neovim, WezTerm, and Waybar. Source Code Pro 12pt font in both terminals (WezTerm, Alacritty). Forest green (#228B22) accent in Sway borders and Waybar active workspace.
