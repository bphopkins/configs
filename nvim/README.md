
# `configs/nvim`

This is the Neovim config I use for dissertation work, lecture prep, and logic projects. LazyVim stays under the hood so the modern tooling is there, while the part I see stays calm and text-first.

### When adding or removing files (not merely editing)

```bash
cd ~/Desktop/configs
stow -Rv -t ~/.config/nvim nvim
```

(`stow-all` does the same across every package; merely editing already-linked files needs nothing.)

## Plugins

* **LazyVim/LazyVim:** Provides the base “distro”.
* **folke/tokyonight.nvim:** Locks the UI to the Tokyonight “night” palette.
* **saghen/blink.compat:** Lets the completion engine speak the same language as third-party sources such as VimTeX, so the menu can include relevant autofills rather than just buffer text constantly.
* **micangl/cmp-vimtex:** Exposes VimTeX’s knowledge of labels, citations, commands, and BibLaTeX entries to the completion system.
* **saghen/blink.cmp:** Supplies the completion UI itself; configured to prioritize snippets and VimTeX data so the menu stays relevant in TeX buffers while still supporting other languages.
* **L3MON4D3/LuaSnip:** Handles snippet expansion and loads my two auto-generated libraries, `latex-workshop.lua` and `french-logic.lua` — together the complete snippet inventory; nothing else contributes snippets. The french-logic set keeps itself current: `lua/snippets/sty-lua-snippets.py` stamps the `.sty`’s sha256 into its output, and on a mismatch at startup the generator re-runs, so snippets can’t silently drift from the package.
* **lervag/vimtex:** Runs the LaTeX toolchain (latexmk + Okular), keeps source/PDF sync working, and scans projects for macros, figures, and bibliographies.
* **barrett-ruth/live-server.nvim:** Gives me a live server of my homepage while I edit.
* **iamcco/markdown-preview.nvim:** Provides a Markdown preview.
* **nvim-treesitter/nvim-treesitter:** Disables Treesitter highlighting for LaTeX so that VimTeX's syntax engine is the sole highlighter.
* **markdown_tasks:** Custom plugin for toggling markdown checkboxes and marking tasks done/started from within Neovim.
* **folke/persistence.nvim:** Remembers and restores sessions (buffers, terminals, tabs). A session is saved for every directory I work in; a bare `nvim` anywhere under `~/Desktop` autoloads that directory's session, and `<leader>qs` restores one manually anywhere else.
* **folke/snacks.nvim:** Tweaks LazyVim’s picker so file browsing shows dotfiles by default, mirroring how I look at projects in the shell. Also resizes the notification bubbles (its notifier renders every `vim.notify`, via noice): 10 s instead of 3, wider, and wrapping long lines instead of clipping them.

Three invisible pieces worth knowing about. LazyVim formats on save, which for Lua means Mason’s stylua with the rules in `stylua.toml` — that’s why this config’s Lua always looks uniform without my doing anything (the auto-generated snippet files are excluded via `.styluaignore`, so the generator’s output is never reflowed). An aggressive auto-save writes on leaving insert mode *and* on every normal-mode change — whenever I am in normal mode, the work is saved — and a save that *fails* announces itself once rather than failing silently. And the fragile parts are pinned by regression suites at the repo root: `tests/nvim-syntax/` for the french-logic highlight layer, `tests/nvim-latency/` for typing latency, completion gating, auto-save behaviour, and the markdown `<CR>` — worth a run after a VimTeX or blink.cmp update. The full engineering record (measurements, decisions, declined options) lives in the repo’s `CLAUDE.md`.
