
# TeX → LuaSnip/VSCode Snippets

This folder contains:
- `generate_tex_snippets.py` — parses a LaTeX macro file and emits `tex.json` snippets.
- `tex.json` — VSCode-style snippet file (loadable by LuaSnip).

The generator supports:
- `\newcommand`, `\renewcommand`, `\providecommand`
- `\NewDocumentCommand{…}{…}` (xparse subset: `m, o, O{…}, s, t<…>, d(..)`)
- `\DeclareMathOperator`, `\DeclarePairedDelimiter`
- `\newenvironment`, `\renewenvironment`, `\NewDocumentEnvironment`

## Running the script

```bash
cd ~/Desktop/configs/nvim/snippets
python3 generate_tex_snippets.py \
  /home/bph/Desktop/configs/latex/french-logic/french-logic.sty \
  --out tex.json \
  --prefix both
```

I haven't had occasion to test whether this regeneration of the file conflicts with Stow, i.e., in the sense that replacing the file requires the creation of new symlinks. Off hand it seems likely, since the file is not being rewritten but recreated:
```bash
cd ~/Desktop/configs
stow -nRv -t ~/.config/nvim nvim
stow -Rv -t ~/.config/nvim nvim
```

## One-time setup (Neovim)

See my `configs/nvim/lua/plugins/snippets.lua` block for VS Code-style snippets.
