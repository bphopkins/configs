
# `configs/nvim`

This is the Neovim config I use for dissertation work, lecture prep, and logic projects. LazyVim stays under the hood so the modern tooling is there, while the part I see stays calm and text-first.

### When adding or removing files (not merely editing)

```bash
cd ~/Desktop/configs
stow -Rv -t ~/.config/nvim nvim
```

## Plugins

* **LazyVim/LazyVim:** Provides the base “distro”.
* **folke/tokyonight.nvim:** Locks the UI to the Tokyonight “night” palette.
* **saghen/blink.compat:** Lets the completion engine speak the same language as third-party sources such as VimTeX, so the menu can include relevant autofills rather than just buffer text constantly.
* **micangl/cmp-vimtex:** Exposes VimTeX’s knowledge of labels, citations, commands, and BibLaTeX entries to the completion system.
* **saghen/blink.cmp:** Supplies the completion UI itself; configured to prioritize snippets and VimTeX data so the menu stays relevant in TeX buffers while still supporting other languages.
* **L3MON4D3/LuaSnip:** Handles snippet expansion and loads my large auto-generated libraries (e.g., `latex-workshop.lua`, `french-logic.lua`). (Maybe see the python script `lua/snippets/sty-lua-snippets.py` that turns `.sty` files into new snippet sets on demand.)
* **lervag/vimtex:** Runs the LaTeX toolchain (latexmk + Okular), keeps source/PDF sync working, and scans projects for macros, figures, and bibliographies.
* **barrett-ruth/live-server.nvim:** Gives me a live server of my homepage while I edit.
* **iamcco/markdown-preview.nvim:** Provides a Markdown preview.
* **nvim-orgmode/orgmode:** So far just tinkering with this.
* **folke/persistence.nvim:** Remembers and restores sessions (buffers, terminals, tabs) for the main projects I work on, making it easy to pick up where I left off after a reboot.
* **folke/snacks.nvim:** Tweaks LazyVim’s picker so file browsing shows dotfiles by default, mirroring how I look at projects in the shell.
