# CLAUDE.md — latex package

Charter for `latex/`, stowed to `~/texmf/tex/latex` (the standard TEXMFHOME
tree). Editing an already-linked file takes effect on the next compile with
no restow; adding a package directory needs `stow -R latex`. `README.md` here
is the directory's GitHub-viewport document — a public how-to in Brandon's
own voice, written a decade ago and deliberately preserved as a historical
artifact (prune declined 2026-08-26); not a charter — leave it alone.

- **french-logic** — 511 commands and 25 environments for modal/deontic
  logic; a single `\usepackage{french-logic}` replaces a 100+ line preamble;
  `deon` option for DEON conference submissions. ⚠ **Shared, snippet-coupled
  dependency**: `dissertation/`, `teaching/live-lecture/`, and parts of
  `teach-logic/` load the stowed copy, so edits here ripple into all of them.
  The Neovim snippet library regenerates automatically on the next Neovim
  start (sha-stamp check), but the vimtex highlight registrations are
  maintained **by hand** — see `nvim/CLAUDE.md` (snippets, custom syntax).
  The API is documented in `dissertation/CLAUDE.md`;
  `dissertation-template/` deliberately bundles its own trimmed
  `philogic.sty` instead.
- **bph-paper** — article class with BibLaTeX Chicago style and custom
  quotation environments.
- **logic-hw**, **tufte-compact** — homework and handout classes.
- **mod-cv** — CV class fork, and ⚠ **a shadow over TeX Live's moderncv**:
  its 36 vendored `moderncv*.sty` files (pinned v2.3.1) are load-bearing for
  the fork and can't be deleted, but because `~/texmf` outranks `texmf-dist`
  they also override TeX Live's copies for anything using
  `\documentclass{moderncv}`. See `latex/mod-cv/README.md`.

Don't add `.sty`/`.cls` files to `dissertation/` or `dissertation-template/`
— canonical sources live here (the template's tracked `philogic.sty` is the
one deliberate exception).
