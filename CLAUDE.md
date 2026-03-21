# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A GNU Stow-based dotfiles repository for Fedora Linux, synced across multiple machines (fedxps, bigfed) via git. Configs are stored here at `~/Desktop/configs` and symlinked to their live locations.

## Stow Deployment

Each top-level directory is a stow "package" with a specific target:

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
- `stow-all` — git pull then restow all packages
- `stow-all-dry` — preview what stow-all would do
- `unstow-all` — remove all managed symlinks

When adding new files to an existing package, restow is needed. Editing existing symlinked files requires no action.

## Git Sync Workflow

Defined in `bash/.bashrc.d/50-git-sync.sh`:
- `gpullall` — pulls all tracked repos on Desktop
- `gpushall` — auto-stages, commits (hostname + timestamp), and pushes all repos

Commit messages follow the pattern: `{hostname}: {YYYY-MM-DD HH:MM:SS}`

## Bash Configuration

Modular design: `.bashrc` sources all `~/.bashrc.d/*.sh` files. The numbered prefix controls load order:
- `00-shell-opts.sh` — shopt/set options
- `10-env.sh` — environment variables
- `20-path.sh` — PATH additions
- `30-prompt.sh` — prompt config
- `40-aliases.sh` — aliases
- `50-git-sync.sh` — git sync functions
- `60-stow.sh` — stow functions
- `70-task-list.sh` — markdown task utilities
- `90-nix.sh` — nix profile loader

## Neovim Configuration

LazyVim-based setup. Entry point: `nvim/init.lua` bootstraps lazy.nvim.

- `lua/config/` — core settings (options, keymaps, autocmds, markdown_tasks, pandoc)
- `lua/plugins/` — plugin specs (each file returns a lazy.nvim plugin spec table)
- `lua/plugins/inactive/` — disabled plugins (not loaded)
- `lua/snippets/` — LuaSnip snippet libraries; `sty-lua-snippets.py` auto-generates snippets from `.sty` files

LaTeX toolchain: vimtex with latexmk compiler and Okular PDF viewer (with source/PDF sync). Formatter: stylua (config in `nvim/stylua.toml`).

## LaTeX Packages

Custom `.sty` and `.cls` files in `latex/` are stowed into `~/texmf/tex/latex` so they're globally available to TeX Live. Packages: french-logic, logic-hw, bph-paper, mod-cv, tufte-compact.

## Sway/Waybar

Sway uses vim-style navigation (hjkl). Mod4 (Super) is the primary modifier. Waybar config is a JSON file with a companion `style.css`.
