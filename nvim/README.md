
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
* **saghen/blink.cmp:** Supplies the completion UI itself; in TeX buffers it runs three sources, my snippets while I type a command name, VimTeX's citation, label, environment, package and file completers inside a command's braces, and paths, while other languages keep the stock sources. VimTeX's command rows stay out of the menu, because they were bare names that duplicated the snippets (2026-09-12); inside `\begin{` the environment names become full templates (2026-09-13).
* **L3MON4D3/LuaSnip:** Handles snippet expansion. The libraries are generated, one file per package: `lua/snippets/pkg/` from TeXstudio's completion word lists (4,419 files) and `lua/snippets/sty/` from my french-logic package, and `lua/snippets/loader.lua` registers for each document exactly the packages it uses, from VimTeX's package table; `hand/` holds the two files I keep by hand (bib entry templates, and my own). The french-logic set keeps itself current: `lua/snippets/snipgen.py` stamps each `.sty`’s sha256 into its output, and on a mismatch at startup the generator re-runs, so snippets can’t silently drift from the package (rebuilt on TeXstudio’s model 2026-09-13).
* **lervag/vimtex:** Runs the LaTeX toolchain (latexmk + Okular), keeps source/PDF sync working, and scans projects for macros, figures, and bibliographies.
* **barrett-ruth/live-server.nvim:** Gives me a live server of my homepage while I edit.
* **iamcco/markdown-preview.nvim:** Provides a Markdown preview.
* **nvim-treesitter/nvim-treesitter:** Disables Treesitter highlighting for LaTeX so that VimTeX's syntax engine is the sole highlighter.
* **markdown_tasks:** Custom plugin for toggling markdown checkboxes and marking tasks done/started from within Neovim.
* **folke/persistence.nvim:** Remembers and restores sessions (buffers, terminals, tabs). A session is saved for every directory I work in; a bare `nvim` anywhere under `~/Desktop` autoloads that directory's session, and `<leader>qs` restores one manually anywhere else.
* **folke/snacks.nvim:** Tweaks LazyVim’s picker so file browsing shows dotfiles by default, mirroring how I look at projects in the shell. Also resizes the notification bubbles (its notifier renders every `vim.notify`, via noice): 10 s instead of 3, wider, and wrapping long lines instead of clipping them.

Three invisible pieces worth knowing about. LazyVim formats on save, which for Lua means Mason’s stylua with the rules in `stylua.toml` — that’s why this config’s Lua always looks uniform without my doing anything (the auto-generated snippet files are excluded via `.styluaignore`, so the generator’s output is never reflowed). An aggressive auto-save writes on leaving insert mode *and* on every normal-mode change — whenever I am in normal mode, the work is saved — and a save that *fails* announces itself once rather than failing silently. And the fragile parts are pinned by regression suites at the repo root: `tests/nvim-syntax/` for the french-logic highlight layer, `tests/nvim-latency/` for typing latency, completion gating, auto-save behaviour, and the markdown `<CR>` — worth a run after a VimTeX or blink.cmp update. The full engineering record (measurements, decisions, declined options) lives in `nvim/CLAUDE.md`, the dated records under the repo’s `docs/`, and `DECISIONS.md`.
