
# `configs/nvim` 

A lean Neovim setup optimized for writing (LaTeX/Markdown), web editing (HTML/CSS/JS), and general coding. Uses lazy-loading to stay fast.

### When adding or removing files (not merely editing)

```bash
cd ~/Desktop/configs
stow -Rv -t ~/.config/nvim nvim
```


## Key features

* **Plugin manager:** `lazy.nvim` with per-topic specs and conservative defaults.
* **LSP & tools:** `mason.nvim` + `lspconfig` + formatters/linters via `conform`/`null-ls` (where useful).
* **Sessions:** `persistence.nvim` for restoring work state.
* **LaTeX:** `vimtex` + `latexmk`; viewer integration via Okular with `nvr` for sync.
* **Web preview:** a minimal live-preview plugin for HTML/CSS.
* **Markdown preview:** a minimal live-preview plugin for markdown.
* **Autosave:** safe, event-based writes for long documents (tuned to avoid churn).

