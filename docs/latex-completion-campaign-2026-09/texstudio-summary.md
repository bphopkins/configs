# TeXstudio: syntax highlighting and completion, a study summary

Dated record. Findings from reading the read-only clone `~/Desktop/texstudio`
(upstream master at `0362907c2`, 2026-09-12) against the installed
`texstudio-4.9.7-1.fc44` rpm on fedxps. Every number is as measured on that
date. Annotate rather than rewrite.

Purpose: reference for configuring completion and highlighting in
Neovim/VimTeX (`configs/nvim/`).

Release anchors: 4.9.6 tagged 2026-07-24, 4.9.7 tagged 2026-08-14, 4.9.8
tagged 2026-09-07. Master is the 4.9.9 development line.

---

## 1. Syntax highlighting

### 1.1 What a "colour" is

- TeXstudio has no fixed palette. It has a **format scheme**: 99 named
  formats in `utilities/qxs/defaultFormats.qxf`. The file
  `utilities/qxs/defaultFormatsDark.qxf` is the dark twin and carries the
  same 99 ids.
- A format is a bundle, not a colour: foreground, background, bold, italic,
  underline, wave underline, strikeout, and a priority that settles overlaps
  (a higher number wins).
- The manual's only text on the subject is the short paragraph "Configuring
  Highlight Colors" in `utilities/manual/source/configuration.md`, which says
  colour, font, family and size can be set and that priority decides
  overlaps. The grouping and the wiring exist only in code.
- The base format `normal` is created in code
  (`src/qcodeedit/lib/qformatscheme.cpp`), not in the file.

Distinct colours across the whole scheme:

| | count |
|---|---|
| format ids | 99 |
| foreground colours | 34 |
| background colours | 18 |
| margin/underline colours (`linescolor`) | 5 |
| distinct colours overall | 52 |

### 1.2 The 13 groups

The Options dialog sorts the formats into categories at
`src/configdialog.cpp:506`–518:

| category | formats | covers |
|---|---|---|
| Basic highlighting | 21 | syntax colouring proper |
| LaTeX checking | 11 | braceMatch, braceMismatch, latexSyntaxMistake, referencePresent/Missing/Multiple, citationPresent/Missing, packagePresent/Missing, temporaryCodeCompletion |
| Language checking | 9 | spellingMistake, wordRepetition, wordRepetitionLongRange, badWord, grammarMistake, grammarMistakeSpecial1–4 |
| Line highlighting | 15 | line:error, line:warning, line:badbox, line:bookmark plus bookmark0–9 (11 bookmark slots), current line |
| Delimiter highlighting | 8 | braceLevel0–7, the rainbow brace levels |
| Search | 3 | search, replacement, selection |
| Diff | 3 | diffDelete, diffAdd, diffReplace |
| Preview | 1 | previewSelection |
| DTX files | 5 | dtx:guard, dtx:macro, dtx:verbatim, dtx:specialchar, dtx:commands |
| Sweave / Pweave | 4 | sweave-delimiter, sweave-block, pweave-delimiter, pweave-block |
| Asymptote | 6 | asymptote:block, keyword, type, numbers, string, comment |
| Lua | 2 | lua:keyword, lua:comment |
| QtScript | 6 | qtscript:comment, string, number, keyword, txs-variable, txs-function |

The dialog lists 94 names including `normal`; 93 of them come from the qxf.
The six qxf ids not in the dialog are the `txs-test-*` formats for the
test-results tab (93 + 6 = 99).

### 1.3 The 21 "Basic highlighting" formats and what produces each

Three production layers. Only layer A is the regex-style automaton.
Layers B and C are code reading the cwl-driven two-pass parse, which is how
TeXstudio tells math from text, picture from prose, and a section title from
an ordinary argument.

**Layer A: the automaton `utilities/qxs/tex.qnfa`.**

| format | default | triggers |
|---|---|---|
| keyword | #800000 | any `\command`, `\{ \}`, and `\% \& \$ \_ \# \^ \~` |
| extra-keyword | #0095ff bold | `\begin{…}`, `\end{…}`, and the sectioning commands, which are injected into the automaton's `keywords/structure` list at runtime from the cwl `L0`–`L5` classes |
| magicComment | #555580 | `% !TeX …`, `% !BIB`, `%&`, `%BEGIN_FOLD` and `%END_FOLD` |
| math-keyword | #808000 | paired delimiters: `\left(`…`\right)`, `\left[`, `\left\{`, `\left<`, `\left|`, `\left\|`, `\lceil`/`\rceil`, `\lfloor`/`\rfloor`, `\langle`/`\rangle` |

Also in the automaton: embedded contexts for `\directlua{}` and `\latelua{}`
(Lua), `\begin{asy}` (Asymptote, `asymptote:block`), and `\Sexpr{}`
(`sweave-block`). The `comment/single` rule is commented out; see layer B.

**Layer B: the syntax-check worker thread (`SyntaxCheck`), keyed on cwl
environment classes.** The class-to-format table is
`LatexDocument::updateSettings` at `src/latexdocument.cpp:3572`; the painting
is in `src/syntaxcheck.cpp` (`mFormatList`).

| format | default | cwl class | triggers |
|---|---|---|---|
| numbers | #008000 | `math` | content of `$…$`, `\[…\]`, and any environment aliased `#\math` (59 bundled cwl files do this, e.g. `\begin{align}#\math,array`) |
| math-keyword | #808000 | `#math` | commands inside math |
| math-delimiter | #509600 | `&math` | the `$`, `\(`, `\[`, `\begin{equation}` boundaries themselves |
| math-text | #202000 | `#mathText` | `\text{…}` inside math (no bundled cwl uses the alias) |
| verbatim | #008080 | `verbatim` | verbatim-like environments, from the cwl `V` letter (`src/latexpackage.cpp:399`) or a `#\verbatim` alias (1 file) |
| picture | #804000 | `pictureHighlight` | content of `tikzpicture`, `picture`, and the 58 files aliasing `#\pictureHighlight` |
| picture-keyword | #c06000 | `#pictureHighlight` | commands inside picture environments |
| align-ampersand | #0055FF bold | | `&` in tabular and align (`src/syntaxcheck.cpp:1231`, `:1295`) |
| comment | #808080 | | `%` to end of line. The automaton's comment rule is commented out; the thread does it from lexer tokens so that `\%` is handled (`src/syntaxcheck.cpp:181`) |

**Layer C: the editor view, using context-aware tokens.**
`LatexEditorView::documentContentChanged`, `src/latexeditorview.cpp:2275`–2477.

| format | default | triggers |
|---|---|---|
| environment | #000080 | the name inside `\begin{}` and `\end{}` (`Token::env`, `Token::beginEnv`) |
| structure | #000000 bold | the title argument of sectioning commands (`Token::title`, `Token::shorttitle`) |
| commentTodo | bg #a8cf83 | `%TODO` comments and todo-note arguments |
| link | #0000FF underline | a clickable target under Ctrl-hover (applied at `src/latexeditorview.cpp:3613`) |

**Base and residue.**

| format | default | note |
|---|---|---|
| normal | none | base text |
| background | linescolor #c0c0c0 | the margin-line colour |
| preedit | bg #FFFF7F | input-method composition text |
| text | #ff0000 | listed under Basic but never fires for LaTeX; used by `bibtex.qnfa`, `xml.qnfa`, `binary.qnfa` |
| escapeseq | #ff0088 | likewise; used by `txsmacro.qnfa`, `qtscript.qnfa` |

Counts:

| | formats | foreground colours | background tints |
|---|---|---|---|
| Basic highlighting category | 21 | 17 | 2 |
| of which fire for LaTeX source | 19 | 15 | 2 |

The 17 Basic foregrounds: #000000, #000080, #0000ff, #0055ff, #008000,
#008080, #0095ff, #202000, #509600, #555580, #800000, #804000, #808000,
#808080, #c06000, #ff0000, #ff0088. The two backgrounds: #a8cf83, #ffff7f.
Dropping `text` and `escapeseq` leaves the 15 for LaTeX.

On top come the LaTeX-checking overlays most people read as colours: green
(#008000) for a resolved `\ref`, `\cite` or `\usepackage`; the same green with
a wave underline for a missing one; purple (#800080) with a wave underline for
a duplicated label (`referenceMultiple`).

Quirk: the colour of math content is the format named "numbers". Changing
"numbers" in the dialog changes the equations.

The format-id lookup table that binds names to the `*Format` integers is
`LatexEditorView::updateFormatSettings`, `src/latexeditorview.cpp:1972`.

### 1.4 The installed instance

- rpm: `texstudio-4.9.7-1.fc44.x86_64`.
- `~/.config/texstudio/texstudio.ini` has empty `[formats]` and
  `[formatsDark]` sections, so the running instance uses the defaults above
  unchanged.
- The two scheme files, `tex.qnfa`, and the category list in
  `src/configdialog.cpp` are byte-identical between tag 4.9.7 and master.

### 1.5 VimTeX comparison

VimTeX reaches the same distinctions with regex regions in its core syntax
file plus per-package files; it has no separate lexicon. `:syntax list` in a
tex buffer prints the VimTeX side.

---

## 2. Completions

### 2.1 Where the library lives

- The flat directory `completion/` at the repo root, one `.cwl` file per
  package or class. No subdirectories.
- Beside them: `completion/cwlAliases.dat` (1,627 lines, mapping document
  classes to the packages they imply, imported at startup by
  `LatexParser::importCwlAliases`) and `completion/updateCompletionQRC.sh`.
- `completion.qrc` at the repo root is what gets compiled into the binary:
  4,525 entries, one per cwl plus the aliases file. A cwl not listed there is
  not in the binary.

### 2.2 How many

By version:

| tag | cwl files |
|---|---|
| 4.9.7 (the installed rpm) | 4,473 |
| 4.9.8 | 4,506 |
| master, 2026-09-12 | 4,524 |

Content of the master set:

| | count |
|---|---|
| non-comment, non-blank lines, all files | 416,422 |
| lines beginning with `\` (command and environment declarations) | 278,830 |
| unique such lines | 208,261 |
| unique command names | 156,103 |
| `\begin{…}` lines | 9,388 |
| distinct environment names | 3,950 |
| key=value lines inside `#keyvals` blocks | 109,547, across 2,899 files |
| `#include:` dependency lines | 17,041 |

### 2.3 What loads

Only three lists load unconditionally. The default is hard-coded at
`src/configmanager.cpp:998` and the installed instance still has it
(`Editor\Completion Files=latex-dev.cwl, latex-document.cwl, tex.cwl`):

| file | entries |
|---|---|
| tex.cwl | 946 |
| latex-document.cwl | 783 |
| latex-dev.cwl | 803 |

Everything else loads per document from its `\documentclass` and
`\usepackage` lines. On fedxps, `~/.config/texstudio/completion/autogenerated/`
holds 10 bare lists autogenerated for packages with no bundled cwl (`eptcs`
and `mod-cv` among them); `~/.config/texstudio/completion/user/` exists and
is empty.

### 2.4 The same files drive highlighting

The `#` classification suffix on each cwl line is what tells the checker
that `align` is math, `tikzpicture` is a picture, `\section` is level 2, and
the argument of `\ref` is a reference. That is the structural difference
from VimTeX.

---

## 3. Churn, measured 2026-09-12

### 3.1 Method and baseline

Windows are measured back from 2026-09-12 by committer date; "authors" are
distinct author names. Repo-wide line counts are useless as a baseline
because dictionaries (`utilities/dictionaries`), `utilities/packageDatabase.json`
and `translation/*.ts` dominate them, so components are compared by commits.

| baseline, whole repo | 3 months | 6 months | 12 months |
|---|---|---|---|
| commits | 254 | 514 | 879 |
| distinct authors | 11 | 16 | 19 |

The maintainer commits under two names, Jan Sundermeyer and sunderme; together
they account for 709 of the 879 commits.

### 3.2 Highlighting definitions: effectively frozen

| component | commits, 12 mo | lines, 12 mo | last substantive change |
|---|---|---|---|
| `defaultFormats.qxf` and dark twin | 2 | +48, plus whitespace | 2025-10-26 (`41bb95777`, "Rainbow delimiter (#4224)") added the eight `braceLevel` formats, 24 lines per file. 2026-06-12 (`8ea4cf8a1`, "fix #4508") gave `math-keyword` an explicit `<priority>0</priority>` and stripped trailing whitespace. |
| `tex.qnfa` | 2 | +2 rules | both 2026-05-31: `2c9f93914` ("fix #4465") extended the single-character keyword class from `\\ \% \& \$` to add `\_ \# \^ \~`; `abbc6f4ff` gave `\{` and `\}` the keyword colour. |
| qnfa engine and format-scheme code in `src/qcodeedit/` | 2 | +8 | trivial |
| config-dialog category list (`src/configdialog.cpp:506`–518) | 0 | 0 | 2025-10-26, rainbow category added |
| format-id table `updateFormatSettings` (`src/latexeditorview.cpp:1972`) | 0 | 0 | 2021-10-17 (`b7bbfa653`) |
| cwl-class to format map (`src/latexdocument.cpp:3572`) | 0 | 0 | 2023-09-06 (`8a0da06b7`) |
| manual, cwl format section (`background.md` lines 109–354) | 5 | small | two new specifiers (3.5) plus typo fixes |

Nothing in the last 3 months touched the three definition files. The other
`utilities/qxs` commits in the year were typo fixes in `doc/QNFA.html`.
None of the above differ between the installed 4.9.7 and master.

### 3.3 Highlighting and parsing code: churn is in the same files, about other things

Ranking is among the 73 source files changed in 12 months; `src/texstudio.cpp`
leads with 126 commits.

| file | commits, 12 mo | rank | what the commits were |
|---|---|---|---|
| `src/latexdocument.cpp` | 51 | 2nd | labels, document cache, TOC updates, an April 2026 load-time speed campaign, crash fixes |
| `src/latexeditorview.cpp` | 26 | 5th | same campaign; the token-painting routine (`documentContentChanged`) was touched twice, 2026-04-15 (`f274e32f9`, "avoid double handling line") and 2026-04-24 (`85957c224`, "avoid unnecessary update") |
| `src/latexparser/` | 35 | 7th (`latexparsing.cpp` 22) | a Sept–Oct 2025 burst for multi-line keyval values and `%specialMultiArg`, then bug fixes |
| `src/syntaxcheck.cpp` | 14 | 11th | the only behaviour changes to what gets painted (3.4) |
| `src/latexcompleter.cpp` | 8 | 19th | |
| `src/configdialog.cpp` | 8 | 20th | |
| `src/latexpackage.cpp` (cwl loader) | 6 | 23rd | |
| `src/latexstyleparser.cpp` | 2 | | |

Per-window figures for the same paths:

| path | 3 mo commits | 6 mo commits | 12 mo commits | 12 mo lines |
|---|---|---|---|---|
| `src/latexparser/` | 6 | 13 | 35 | +350 / −128 |
| `src/syntaxcheck.cpp`, `.h` | 2 | 3 | 14 | +198 / −45 |
| `src/latexeditorview.cpp`, `.h` | 3 | 16 | 26 | +180 / −57 |
| `src/latexdocument.cpp`, `.h` | 8 | 44 | 51 | +384 / −108 |
| `src/latexpackage.cpp`, `.h` | 1 | 3 | 6 | +32 / −8 |
| `src/latexcompleter.cpp`, `.h` | 4 | 6 | 9 | +34 / −12 |
| `src/tests/` | 14 | 17 | 45 | +662 / −78 |

### 3.4 Painting behaviour that changed in the year (all in the checker thread)

- **Rainbow delimiters**, 2025-10-26: a new optional overlay with its own
  eight colours (`braceLevel0`–`7`).
- **Math colouring of `\end…`**, fixed 2025-10-26.
- **siunitx square brackets** ignored, 2026-05-06.
- **Tikz semicolon check**, 2026-08-14 (`5ef42edec`, "Tikz semicolon
  (#4589)"): a new error overlay, "semicolon in previous tikz command
  missing". It keys off a new derived cwl class `%semicolonEnd`: any cwl
  line ending in `;` (`src/latexpackage.cpp:239`). The bundled tikz lists have
  carried such lines since 2022 (276 lines in 31 files), so the check lit up
  without touching them. The manual does not document it.

### 3.5 cwl format specification changes in the year

- `%specialMultiArg`, 2025-09-23: like `%special`, but the argument may
  contain more than one element, each checked individually.
- `=%<text%>` on a keyval key, 2025-10-22: the value is treated as text,
  i.e. spell-checked.
- Plus the undocumented `;`-suffix class above.

### 3.6 Completion library: weekly, additive churn

| `completion/` | 3 months | 6 months | 12 months |
|---|---|---|---|
| commits | 16 | 31 | 82 |
| cwl files added | 84 | 129 | 168 |
| cwl files modified | 124 | 210 | 344 |
| cwl files deleted | 0 | 0 | 0 |
| lines | +9,219 / −777 | +13,941 / −1,675 | +28,860 / −7,105 |

About 11 percent of the 4,524 files were touched in a year; nothing removed.
The cadence is a near-weekly "Cwls (#NNNN)" pull request from one
contributor, mbertucci47, who made 61 of the 82 commits; the maintainer made
17, others 4. `completion.qrc` grows in lockstep: 32 commits, +168 lines, all
additions.

Monthly commit volume: 22 in 2025-09, 17 in 2025-10, then 1 to 5 a month
through 2026-04, 8 in 2026-05, 9 in 2026-06, and 3 to 5 a month since.

The three always-loaded lists barely move:

| file | commits, 12 mo | lines, 12 mo | last changed |
|---|---|---|---|
| `tex.cwl` | 3 | +3 / −3 | 2026-01-18 |
| `latex-document.cwl` | 4 | +8 / −5 | 2026-09-12 |
| `latex-dev.cwl` | 4 | +31 / −5 | 2026-06-02 |
| `cwlAliases.dat` | 1 | +16 | 2026-06-15 |

### 3.7 Since the installed 4.9.7 (tagged 2026-08-14)

- `completion/`: 51 cwl files added, 49 modified.
- Code paths of sections 3.2 and 3.3: two commits only. The tikz semicolon
  check (`src/syntaxcheck.cpp` +40/−4, `syntaxcheck.h` +1,
  `src/latexpackage.cpp` +3) and a one-line memory-reservation fix in
  `src/latexeditorview.cpp` (2026-08-28).
- Definitions: no change.

### 3.8 Implications for the port

- **Model the colour groups from 4.9.7 without worry.** The scheme, the
  automaton and the class-to-format wiring change on a multi-year timescale,
  and the two 2026 tweaks were single rules.
- **Treat the cwl library as an annual re-sync**, and diff only the packages
  you load. The long tail is where the churn is; the core three lists changed
  by a few lines.
- **Watch the format spec, not the files.** It grows by a specifier or two a
  year, and one derived class arrived undocumented. Anything that parses cwl
  lines should tolerate an unknown suffix.

---

## Appendix: where to look

| question | place |
|---|---|
| format definitions, light and dark | `utilities/qxs/defaultFormats.qxf`, `utilities/qxs/defaultFormatsDark.qxf` |
| the TeX automaton | `utilities/qxs/tex.qnfa` |
| the 13 dialog categories | `src/configdialog.cpp:506`–518 |
| cwl class to format map | `src/latexdocument.cpp:3572` (`LatexDocument::updateSettings`) |
| format-id lookup table | `src/latexeditorview.cpp:1972` (`updateFormatSettings`) |
| token-driven overlays | `src/latexeditorview.cpp:2275`–2477 (`documentContentChanged`) |
| checker-thread painting | `src/syntaxcheck.cpp` (`mFormatList`; comment at `:181`, ampersand at `:1231`) |
| cwl loader and classifications | `src/latexpackage.cpp` (`V` at `:399`, `;` suffix at `:239`) |
| default completion files | `src/configmanager.cpp:998` |
| cwl format reference | `utilities/manual/source/background.md`, "Description of the cwl format" |
| highlight-colour manual text | `utilities/manual/source/configuration.md`, "Configuring Highlight Colors" |
| installed settings | `~/.config/texstudio/texstudio.ini`, `~/.config/texstudio/completion/{user,autogenerated}/` |
