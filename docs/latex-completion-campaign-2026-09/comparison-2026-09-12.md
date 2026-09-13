# TeXstudio against the Neovim LaTeX layer: the comparison

Dated record, 2026-09-12, fedxps. The evidence base for `PLAN.md` beside it.
Every number was measured that day, by the method named with it; annotate,
never rewrite. Companion: Brandon's own study of the TeXstudio side,
`texstudio-summary.md` beside this file (copied 2026-09-13 from `~/Desktop/texstudio-summary.md`) (the clone `~/Desktop/texstudio`, upstream
master `0362907c2`; the installed rpm `texstudio-4.9.7-1.fc44`, whose
definition files are byte-identical to master).

The questions asked: what the number of colours and categories teaches
(0); whether the two highlight schemes converge (1); whether VimTeX's native
completion comes near TeXstudio's, and whether the snippet approach is the
better one (2); whether to regenerate the generic snippets from TeXstudio's
source instead of LaTeX Workshop's copy (3); whether one big file or one per
package (4).

## 1. Highlighting

### 1.1 Counts

| | TeXstudio, LaTeX source | VimTeX defaults | the scheme here |
|---|---|---|---|
| named categories | 19 formats fire (of 99 ids in 13 dialog groups) | 176 `hi def link` lines onto 14 standard groups | 64 groups set in `after/ftplugin/tex.lua`; 587 tex* groups defined in a buffer |
| distinct foregrounds | 15 | 6 under TokyoNight | 22 chosen; 27 in effect |
| bold / italic / underline | 3 / 0 / 1 | the theme's | 9 / 16 / 1 |

Method: the qxf and the dialog list for TeXstudio (his summary, sections
1.1 to 1.3); `grep` of the link lines in VimTeX's `syntax/core.vim`; a
headless probe (`probe.lua`, described in section 4) that resolved every
tex* group's foreground after the ftplugin ran.

Reading: both general editors land near 15 to 19 visual categories and
spend them on the same things: zones (math, verbatim, picture, comment),
argument roles (title, reference key, file, option), and in TeXstudio's case
document state. The scheme here spends its 22 colours on a dimension neither
has, the species of the author's own vocabulary. The cwl classification
letters carry validity (`m`, `/env`) and argument role, never meaning, so
TeXstudio could not express the register taxonomy even in principle. The
taxonomy's own answer to "how many hues" (one per genus) is untouched; what
the counts teach is where a budget goes, not how large it should be.

### 1.2 Convergences

- Section titles bold: TeXstudio `structure`; here `texPartArgTitle`.
- Environment names distinct: `environment` (navy); here the env-name family
  (teal bold, thm green bold, loaded mint).
- Math body as a zone colour: `numbers` (green); here tan italic.
- `$` and `\left(` singled out: `math-delimiter`, `math-keyword`; here
  magenta (`texMathDelim`, `texMathDelimMod` measured).
- `\text{}` inside math returns to prose colour: `math-text`; here VimTeX's
  `texMathTextArg` is unlinked and renders in Normal (measured in the probe
  and at completeness.tex line 172, neighborhoods.tex line 340).
- Comments gray, links underlined.

### 1.3 Divergences

- TeXstudio paints every command one maroon (`keyword`), olive inside math,
  orange inside pictures, and lets the *argument* carry the role. Here the
  command is coloured by species (12 custom groups over 218 name and 32
  pattern registrations).
- TeXstudio bolds `\begin`/`\end` with sectioning (`extra-keyword`); here
  they sit on the scaffold rung at regular weight, by the document-spectrum
  verdict of 2026-08-28.
- The rest of TeXstudio's budget is checks: reference present, missing or
  duplicated, citation and package present or missing, syntax mistake, brace
  mismatch, spelling. These encode document state; a syntax engine cannot
  know them. Out of scope for this campaign; a checker's job (texlab's
  diagnostics with its completion left off) if ever wanted.
- Rainbow brace levels (added upstream 2025-10): not adopted.

### 1.4 Measured gaps in the scheme here

Five theme colours leak in, none assigned by the ftplugin (probe, section 4):

- `&` and `\\` in align and tabular resolve through `texTabularChar` to
  TokyoNight's Special `#2ac3de`, in the probe file and at completeness.tex
  line 145 and neighborhoods.tex line 40. TeXstudio gives alignment points a
  deliberate bold blue (`align-ampersand`).
- `\begin{align}`'s name resolves through `texMathEnvArgName` to the same
  Special, so math environment names are cyan while `proof` is mint and
  `tabular` teal; the family matches in `after/syntax/tex.lua` never see them.
- Special reaches 19 groups in all, among them `#1` parameters
  (`texNewcmdParm`), `\&`-type special characters, `texSymbol`.
- `texLength` resolves to Constant `#ff9e64`; `texCmdTodo`/`texCommentTodo`
  to Todo; the error and warning groups to red and amber (arguably right).

All are retunes within existing species (alignment furniture is pure
structure; math env names belong to the env-name family), no new genus. Per
the taxonomy's process they go to the bench first; nothing was changed.

## 2. Completion

### 2.1 VimTeX's native completion, from its source (commit 45a5a56)

- The 202 per-package lists in `autoload/vimtex/complete/` are made by
  `complete/tools/convert-cwl`, which keeps only the command name from each
  cwl line (`\w+\*?`), drops every argument, placeholder and classification,
  drops names of three letters or fewer and names already in `default` (820
  names), and attaches a Unicode glyph from a symbols table as menu text.
- A candidate is `{word = name, mode = '.', kind = '[cmd: pkg]', menu =
  glyph}`; no arity, no placeholders. `s:close_braces` applies only to the
  brace-argument completers. The math filter (`mode` m/n) exists but every
  package entry is mode-any, so it never filters.
- Commands scanned from a document's `\newcommand`s are names only.
- Package detection: `s:parse_packages` over the preamble (with options),
  then `update_packages` from the `.fls`, re-run after every successful
  compile (`compiler.vim`). On completeness.tex VimTeX chose the article
  wrapper as main and found 111 packages including every french-logic unit;
  the root `dissertation.fls` (2026-08-09) predates the unit split and lists
  no unit, so the root document's table is stale until its next full build.
  The latency fixture, with no `.fls` and everything loaded through
  french-logic, yields one package.
- Argument completers, called through `vimtex#complete#complete()` on the
  completeness chapter (warm timings): bib matches key, author, title and
  year by regex (`lewis` 4 rows, `Counterfactuals` 2 rows, 4 to 5 ms); ref
  from the aux file with number and page (`def:` 4 rows, "Definition 4.1
  [p. 12]", 22 ms); env 16 to 36 ms warm, 2.9 s the first time a machine's
  package cache is cold; pck 761 ms once per session then 11 ms.

### 2.2 TeXstudio's completer, from its source

- A row is the cwl line itself with named placeholders (`\parbox[position]
  {width}{text}`); `%<…%>` marks a partial placeholder, `%|` the final
  cursor, `%\` a newline.
- Four tabs (`latexcompleter.cpp:1504`): typical hides `#*` rows until one
  has been used once (`usageCount` −1 → 0 on first use); most-used pins the
  favourite; fuzzy; all. Rows restricted to an environment (`/env`) are hidden
  outside it in typical and most-used; length-typed rows only where a length
  is expected.
- Math-only rows (`m`) completed outside math get `$…$` around them
  (`Completion Auto Insert Math`, on in his ini).
- `\begin{env}` rows expand to a begin/end template (`\item` for lists).
- Key-value completion inside `[…]` from `#keyvals` blocks; tooltips from the
  LaTeX reference; case-insensitive prefix (his ini: 0).
- Citation completion filters keys by prefix only (`filterList`, the
  `citeStart` branch); label completion needs no compile.
- Loading per document: three always-on lists (tex, latex-document,
  latex-dev), the class file plus `cwlAliases.dat`, each `\usepackage` with
  its options (`#ifOption` blocks), the `#include` closure, and for a package
  with no cwl a bare list autogenerated from the `.sty` through kpsewhich,
  carrying `#include` lines for the style's own `\RequirePackage`s (the
  `mod-cv.cwl` on this machine has 19). Re-scanned on every preamble edit.

### 2.3 Verdict on question 2

For commands, the snippet approach is TeXstudio's approach; VimTeX's command
completer is a name dictionary and no setting changes that. Keeping it out
of the menu (2026-09-12) is right. VimTeX's argument completers are the
other half of TeXstudio's model, TeXstudio-grade or better, and were
reachable only by `<C-x><C-o>`. blink's built-in `complete_func` source (the
preconfigured `omni` provider) wraps `'omnifunc'`; enabled at runtime in the
harness, `\begin{enum` produced `enumerate <omni>` as the first row and
`\usepackage{amsm` the package rows. blink's frecency (on by default) plays
TeXstudio's most-used role.

### 2.4 The LaTeX Workshop file, measured against the cwl corpus

`latex-workshop.lua`: 517 snippets, of which 485 command-shaped (58 of them
environment templates) and 32 bib entry templates. Provenance: the
pseudo-commands and `\chaptername{name}` appear verbatim in LaTeX Workshop's
hand-curated `data/commands.json`; its converter `dev/parse-cwl.ts` reads
only `*` and `S` from a cwl classification; its manifest `dev/cwl.list`
covers 462 of TeXstudio's 4,524 files and lacks stmaryrd, enumitem, ebproof
and tikzsymbols. The file entered the repo 2025-11-13 (commit 84703a6)
already carrying the `~` trigger suffix; no rationale was recorded, and he
confirmed 2026-09-12 that it was a mistake.

| of the 485 command-shaped snippets | count |
|---|---|
| not in any of the 4,524 cwl files (`\bigl(`, `\emph{}`, `\{`, …) | 21 |
| from packages the dissertation never loads (beamer, fancyhdr, dsfont) | 24 |
| marked unusual by TeXstudio | 58 |
| arity disagrees with the cwl (`\kern{}`, `\hskip{}`, `\mathbin{}`, `\chaptername{}`, `\def`, …) | 13 |
| argument-taking snippets carrying placeholder names | 48 of 182 |
| TeXstudio would not offer for this document at all | 113 |

`french-logic.lua`: 537 snippets, 100 with arguments, 1 with named
placeholders.

### 2.5 Coverage for the dissertation's packages

The closure TeXstudio would load for the dissertation (class memoir, the 37
packages french-logic and the preamble require, `#include` followed,
`#ifOption` blocks evaluated against the options actually given): 96 files,
15,211 lines; 8,237 visible after `#*` and `S`; 4,931 of those restricted to
an environment (81 distinct commands); 2,196 distinct commands offered on a
bare backslash; 783 math-only; 465 commands with two or more signatures
(`\parbox` four, `\textcite` three, `\section` three once memoir's is
counted); 246 environment rows (111 with arguments); 4,486 key-value lines
for 178 targets. The two libraries here cover 333 of the 2,196. Missing:
amssymb 192, stmaryrd 105, mathtools 89, amsmath 66, biblatex 117, memoir
36, cleveref about 20, tex and latex-document 448, and noise (etoolbox 160,
tikzsymbols 102, babel 49). Option blocks matter for three packages only:
babel (3,658 lines inside blocks), biblatex (5,562), fontenc (2,108);
hyperref 76, the rest under a dozen. expl3-commands (4,731 lines) is entirely
restricted to expl syntax.

### 2.6 What he actually types

All `\command` tokens in the dissertation's 33 `.tex` files, classified
against the whole cwl corpus:

| class | tokens | distinct names |
|---|---|---|
| typical stock commands | 10,131 | 210 |
| french-logic macros | 7,721 | 237 |
| marked unusual (`#*`) | 91 | 25 |
| in no cwl (document-local macros) | 53 | 12 |

The 25 unusual names are preamble plumbing (`\clearfield` ×40 inside
`\AtEveryBibitem`, `\ifentrytype`, spacing and length settings) and
`\makebox` ×4. Among everyday commands, `#*` falls on `\par`, `\medskip`,
`\raisebox`, `\hrulefill`, `\kern`, `\displaystyle`, none of which he types.
TeXstudio's prior fits his writing; nothing should be hidden.

### 2.7 The broken brace branch

In the latency harness (throwaway fixture copy): typing `\begin{ali` opens
the menu with `\align*~` first; accepting it writes
`Scratch. \begin{\begin{align*}` / `  ` / `\end{align*}}`, because the
snippet replaces only the letters after the brace and the auto-pair's closing
brace survives. From a bare `\alig` the same row expands correctly. Inside
`\cite{che` the menu offers 175 snippet rows beginning `\check~`. TODO item
15 described the branch as noisy; at `\begin{` it is harmful.

## 3. Structure (question 4)

TeXstudio: one cwl per package (4,524), loaded per document. VimTeX: one
list per package (202) plus `default`, loaded per document from preamble and
`.fls`. LaTeX Workshop: one JSON per package (462) plus `commands.json`,
loaded per `\usepackage`. Here: two monoliths loaded into every TeX buffer.
The mechanism for the TeXstudio shape exists: LuaSnip's `ft_func` and
`load_ft_func` are config keys (`default_config.lua`), blink's LuaSnip source
asks `get_snippet_filetypes()` per request and caches converted items per
filetype, `require("luasnip.loaders").load_lazy_loaded(bufnr)` re-evaluates a
buffer's filetypes, VimTeX fires `User VimtexEventInitPost` after
`b:vimtex` exists and refreshes the package table on `VimtexEventCompileSuccess`.
blink honours a per-item `score_offset` (`fuzzy/init.lua:46`);
`vimtex#syntax#in_mathzone()` and `vimtex#env#get_inner()` exist.

## 4. Method

- Headless, read-only probes on real chapters (`nvim --headless <file>
  +'lua dofile(probe)' +qa!`, `NVIM_NOSESSION=1`, the persistence guard
  disarms headless saves): syntax groups at named positions; VimTeX's
  completers via `vimtex#complete#complete()`; timings via `vim.uv.hrtime`.
- The latency harness (`tests/nvim-latency/harness.py`, a fixture copy under
  `$TMPDIR`) for anything that types: the brace-branch breakage, the omni
  provider enabled at runtime through `require('blink.cmp.config')`.
- Python over the clone's `completion/` for every cwl count; `#ifOption`
  evaluated against options parsed from the french-logic units and
  `dissertation.tex`.
- `git log`/`git show` on `configs` for the snippet files' history; WebFetch
  of LaTeX Workshop's `data/packages/amsmath.json`, `data/commands.json`,
  `dev/parse-cwl.ts`, `dev/cwl.list` and its wiki for provenance.
- Side effect: the headless probes on real chapters may have written VimTeX's
  on-disk package cache (`pkgcomplete`) under the live cache root, which is
  why the env completer's first call fell from 2.9 s to 36 ms between runs.
  No buffer or file of his was modified.

## 5. Decisions taken the same day

Annotation, 2026-09-13: two of these changed the next day, by his call:
every cwl is converted (no per-document selection), and `pkg/` is committed
with attribution. `PLAN.md` section 1 is current; this section stays as the
record of the 12th.

See `PLAN.md`, section 1, which carries them with their rationale. In one
line each: regenerate the generic library from the cwl corpus in its
entirety; one file per package loaded from VimTeX's package table with
includes headers and a hub-implies-units fallback; unusual rows generated
with a small tie-breaking sink and the flag kept; one row per signature with
the compact shape inline and the expansion on highlight; math-only rows
wrapped in `$…$` outside math and environment-restricted rows hidden outside
their environment; VimTeX's argument completers in the menu through blink's
omni provider, gated to brace contexts; no trailing `~`; keyvals, named
placeholders for french-logic, corpus-frequency ranking and the five stray
colours deferred.

## 6. Spikes, 2026-09-13

Run to test the parts of `PLAN.md` that had rested on reading source. Method
as in section 4: the latency harness on its fixture copy for anything that
types, with the loader pieces injected at runtime through
`require('blink.cmp.config')` and `require('luasnip.session').config`;
headless and read-only on the chapters for timings.

| claim | result |
|---|---|
| a runtime LuaSnip `ft_func` plus `add_snippets("pkg-x")` reaches blink's menu | yes; Lua buffers keep `{lua, all}` |
| `show_condition` false hides a row | yes |
| per-item `score_offset` reorders | yes; −50 in place of the provider's 10 buried the row below unrelated matches, so the sink must be relative |
| dedupe in `transform_items` | two identical rows collapsed; 0.19 ms per 200 rows |
| description column from `dscr` | drawn by blink's default columns `{ {kind_icon}, {label, label_description} }`; LazyVim sets only `draw.treesitter` |
| tilde-less trigger expands from full and partial typing | `\spikeone{a}{b}` both times |
| math wrap by function nodes at expansion | `$\alpha$` in prose, `\alpha` after `$x `; the docstring shows the wrapped form |
| `\begin{` through an omni transform to a snippet-format edit | `\begin{enumerate}` / `  ` / `\end{enumerate}`, auto-paired brace consumed |
| `regTrig` environment snippet | inserted the pattern text; declined |
| pre-expand callback editing the buffer | scrambled the line (blink fixes the clear region first); declined |
| `\end{` through omni | nothing shown until a letter is typed (blink opens on keyword characters); VimTeX's `]]` closes environments |
| reading `vim.b.vimtex.packages` per request | 0.09 ms; `keys()` through `eval` 0.02 ms |
| `vimtex#syntax#in_mathzone()` | 0.05 ms per call |
| keyed re-registration | old rows stay listed as invalidated until `clean_invalidated({ inv_limit = 0 })` |
| cross-file duplicate rows in the closure | 117 of 8,716; 74 involve a core file (tex, latex-document, latex-dev, amsopn) |
| environment-restricted typical rows in the closure | 6 (hyperref form fields); `\item`, `\draw`, `\node`, booktabs rules carry no restriction |
| option blocks selected by his options | biblatex 0 lines; only `natbib` would add 67 |
| `vimtex-warm` | writes `pkgcomplete.json` too, so it primes the omni provider's cold cost |
| blink `max_items` | 200 rows displayed; fuzzy ranks all |
| licence | TeXstudio `COPYING` is GPL-3; no statement in `completion/`; configs has no LICENSE; VimTeX and LaTeX Workshop (MIT) redistribute converted lists |
| his usage of environment-restricted commands | `\draw` and `\node` only inside `tikzpicture`; `\item` inside itemize, hilbertlist, romanlist, arablist, enumerate, itemlist |
| weight of the whole corpus | `completion/` is 24 MB, 493,816 lines, 4,524 files; largest expl3-commands 347 KB, biblatex 276 KB; generated Lua runs 69 bytes per bare snippet, about 190 per named one; the configs pack is 4.35 MiB |
| `gpushall` on thousands of new files | `_gsync_vet_new_files` prompts only for a file over `GSYNC_MAX_MB` (25) or matching a secret glob; other new files are listed, not questioned |
| math-only commands he uses in prose | none: 73 commands sampled up to three times per file over 41 files, 1,023 uses in math, 0 in text (100 apparent text hits were commented-out code) |
| probe method note | a headless sweep that `:edit`s file after file never reaches VimTeX's syntax post-init and idles in its wait; one headless instance per file, given on the command line, did all 41 in 140 s |
