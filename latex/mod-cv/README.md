# `mod-cv`

A private fork of [moderncv](https://ctan.org/pkg/moderncv) **v2.3.1** (2022-02-21),
renamed to `mod-cv` so it does not collide with the copy TeX Live ships. It is what
`bphopkins.net/cv/HopkinsCV.tex` actually builds against.

## Why the `moderncv*.sty` files are here

`mod-cv.cls` is only the class. It still loads the v2.3.1 sub-packages by their
upstream names — `moderncvcollection`, `moderncvcompatibility`, and, via
`\moderncvstyle` / `\moderncvcolor` / `\moderncvhead` / `\moderncvbody` /
`\moderncvicons`, the matching `moderncvstyle*`, `moderncvcolor*`, `moderncvhead*`,
`moderncvbody*`, and `moderncvicons*` files. They are load-bearing for the fork and
must stay pinned at v2.3.1 alongside it. Do not delete them.

## Known side effect: these shadow TeX Live's moderncv

This directory is stowed into `~/texmf`, which outranks `texmf-dist` in `kpsewhich`.
So on this machine:

```
kpsewhich moderncv.cls             -> TeX Live's           (v2.6.1, 2026-06-24)
kpsewhich moderncvstyleclassic.sty -> ~/texmf/.../mod-cv/  (v2.3.1, 2022-02-21)
```

Anything using `\documentclass{moderncv}` therefore gets a current class over
four-year-old sub-packages, which is not a combination upstream ever tested. This does
**not** affect `HopkinsCV.tex`, which uses `mod-cv` and so gets a self-consistent
v2.3.1 stack throughout.

If you ever do want stock moderncv, build it somewhere `TEXMFHOME` is out of the way
(`TEXMFHOME=/nonexistent pdflatex …`) rather than deleting anything here.

## The old diff

A 3,500-line diff against TeX Live 2025 used to sit beside this file. It was dropped in
July 2026: it compared against a release no longer active and against a source path
(`~/Desktop/texmf`) that no longer exists. Regenerate on demand:

```bash
diff -ru /usr/local/texlive/2026/texmf-dist/tex/latex/moderncv \
         ~/Desktop/configs/latex/mod-cv
```
