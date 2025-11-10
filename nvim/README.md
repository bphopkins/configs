
# `configs/nvim` 

A lean Neovim setup optimized for writing (LaTeX/Markdown), web editing (HTML/CSS/JS), and general coding. Uses lazy-loading to stay fast.

## Key features (high level)

* **Plugin manager:** `lazy.nvim` with per-topic specs and conservative defaults.
* **LSP & tools:** `mason.nvim` + `lspconfig` + formatters/linters via `conform`/`null-ls` (where useful).
* **Sessions:** `persistence.nvim` for restoring work state.
* **LaTeX:** `vimtex` + `latexmk`; viewer integration via Okular with `nvr` for sync.
* **Web preview:** a minimal live-preview plugin for HTML/CSS.
* **Autosave:** safe, event-based writes for long documents (tuned to avoid churn).

## Setup

1. Put this directory at `~/.config/nvim` (or symlink `configs/nvim` → `~/.config/nvim`).
2. Start Neovim; plugins bootstrap automatically.
3. Recommended external tools (install as needed):

   * `ripgrep`, `fd` (fuzzy search); `git`
   * For LaTeX: `latexmk`, `okular`, `python3`, `nvr`
   * LSP/tooling managed by `mason` as per language


## Philosophy

Small, readable modules; minimal global state; defaults first, overrides local; fast startup; only dependable plugins.
