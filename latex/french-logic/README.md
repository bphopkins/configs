# french-logic

`french-logic` is a semantic markup language for writing logic in LaTeX. A
document says *what* a symbol is — `\ought`, `\proves`, `\truthset{A}`,
`\CMr`, `\cmr` — and the package decides how it looks. It covers the modal and
deontic operators, the conditional connectives, consequence and satisfaction
relations, models and frames and their canonical constructions, the named
axioms, rules, and systems of the field, the I/O-logic and STIT vocabularies,
the underlined first-order metalanguage of neighbourhood semantics, and the
document structure a logic dissertation needs. Developed since 2021 under
Rohan French's supervision, hence the name. The homepage's phrase for the
ambition: "a useful semantic markup macro for students and logicians of a
certain kind."

This file is the map of the package: what it is for, how it is organised,
what its conventions are, and what is open. It is a living contract — edit it
in place; staleness is a bug. The member-by-member inventory is `AUDIT.md`,
generated. The stow-package charter is `../CLAUDE.md`. The API summary the
dissertation reads is in `dissertation/CLAUDE.md`. Written 2026-09-07 at the
start of the reorganisation; the *Status* line under each heading says how
far that heading is from the truth on the ground.

## Principles

Settled 2026-09-07, in Brandon's words where quoted.

1. **A language, not a toolkit.** Membership is decided by coherence with the
   language, not by use. "Nothing should be deleted unless a strong specific
   case can be made directly to me, which I accept." A member unused for years,
   or ever, is still vocabulary; the inventory's zero-use column is not a
   deletion list. What is being built is "a sprawling, but extremely coherent
   and well-tested semantic markup language."
2. **Coherent and well-tested.** Every member has a home (a unit), a form
   consistent with its family, and a rendering test. A broken member is a bug
   to fix; an inconsistent one is a form to normalise.
3. **Dependencies ride with the code.** Each unit loads what it needs, at its
   head, and nowhere else. This map records who needs what, so that the units
   can be separated without archaeology.
4. **One package, many units.** `french-logic` stays the sole user-facing
   package. It is a hub that loads unit files `french-logic-<unit>.sty`, each
   a small package with its own `\ProvidesPackage` and `\RequirePackage`
   lines. Users write `\usepackage{french-logic}`; a unit can also be loaded on
   its own, by a template or a colleague, without restructuring.
5. **A preamble by default, separable on demand.** The document furniture —
   fonts, encodings, babel, the convenience packages — is a unit the hub loads
   by default, so one `\usepackage` still replaces a hundred-line preamble.
   Options omit it, and the document-structure units, for host classes that
   own those things themselves (beamer, conference classes).
6. **Nothing changes output unnoticed.** Two nets. `tests/french-logic`
   renders every member on its own page and hashes it against a golden. A
   consumer harness (private; see *Tooling*) rebuilds the dissertation, its
   article wrappers, the decks, and the teaching and opuscula documents against
   any candidate package and compares them page by page.

## Architecture

*Status 2026-09-08: split done, every unit ordered, v1.0 released 2026-09-08.
`french-logic.sty` is the hub; the unit files below hold the language;
`french-logic-quarry.sty` is never loaded.
Every line of the single file moved verbatim into exactly one unit (checked
by multiset), and both nets were clean: no differences across the 27
consumers, no changed page among the 834 fixture pages. The dependency data
is measured — each external command was attributed by loading every package
alone and probing — and the reference data is the closure of the package's
own macro-to-macro uses. Each unit loads every package it needs and requires
the units it refers into, so that it works on its own; `tests/french-logic/units.sh`
proves it by loading each unit alone and typesetting all its members. Every
unit was reordered on 2026-09-08 — core by the tower, the others by their own
levels — with every definition byte-identical, the old headers gone, one
comment grammar throughout, and both nets clean at each step.*

The layering has two levels. **Core** is ordered by the tower of languages
that the Neovim register taxonomy also uses (`nvim/docs/latex-register-taxonomy.md`):
symbols, then sets and functions, syntax, relations, modal structures,
semantics, and the metalanguage. **Subject units** sit above core and use it.
**Document units** sit beside, and the **preamble** unit beneath. Every
reference in the file points downward through this order; there are no cycles.
A pure tower split was rejected because it would separate correspondence
pairs — `\CMr` on the syntax side from `\cmr` on the semantics side — which
belong together.

| unit | file | holds | needs beyond the kernel | refers into |
|---|---|---|---|---|
| preamble | `french-logic-preamble.sty` | fontenc T1, inputenc utf8, lmodern, babel english; ragged2e, setspace, multicol, xcolor, soul, tabularx, mdframed, calc, trimclip, adjustbox, booktabs, bm, centernot; graphicx and `\graphicspath` | those | nothing |
| core | `french-logic-core.sty` | in tower order since 2026-09-08: the label helper; symbols (`\Yright`, `\shortminus`, `\strictif`, `\dvbar`); sets and the definitional idiom; syntax (languages and logics, connectives with `\nec` and `\poss`, consequence and closure, proof sets and classes); relations (`\proves`, `\models`, `\trues`, sequent arrows); structures (`\M`, `\F`, `\C`, `\A`, indexed and Σ forms, the canonical model, the closure arrows); the `f` functions; semantics (valuations, satisfaction in a model, truth sets, operations on propositions); the underlined metalanguage | amsmath, amssymb, mathtools, stmaryrd, mathrsfs, xspace, soul (`\st` is a renewal of soul's), graphicx, trimclip, the txfonts `txsyc` glyph | nothing |
| applied | `french-logic-applied.sty` | temporal (`\hitherto`, `\henceforth`, `\was`, `\willbe`), epistemic (`\knows`, `\believes`, …), credence (`\cprob`, `\cred`) | nothing | nothing |
| deontic | `french-logic-deontic.sty` | `\ought`, `\may`, `\forbidden`, … ; dyadic operators `\cobs`, `\cperms`, `\cnecs`, `\cposs` and their solo forms; `\sphere`, `\cfact` | amssymb, graphicx | core (`\nec`, `\poss`) |
| modal | `french-logic-modal.sty` | axiom names (`\Kax` …, parenthesised, converse), rule names, system names (`\K` … `\CEMC`), deontic systems (`\SDL`, `\KDought`) | xspace | deontic (`\ought`), core (`\poss`) |
| conditional | `french-logic-conditional.sty` | the CM/CC families with their lowercase frame conditions, CN, CP, CT, C-Dual, the order conditions `\rup` … | xspace, core's `\strictif` | core |
| io | `french-logic-io.sty` | `\IO` and the IO systems, in/out/deriv, the rule names `\TOP` … `\CT` and their starred forms | amsmath (`\text` in `\IO`), xspace | core (`\fl@lbl`) |
| stit | `french-logic-stit.sty` | `\cstit`, `\dstit`, the structure names via `\versal` | microtype, loaded bare with `tracking=smallcaps` set after it (D16) | nothing |
| proof | `french-logic-proof.sty` | the Set-Set … framework names, the subscripted `\proves` variants, the `//` consequence separator `\infer` | amssymb, microtype; amsthm is detected, never loaded here | core (`\proves`) |
| gentzen | `french-logic-gentzen.sty` | the `gentzen` proof-tree environment over ebproof, rule labels, the signed-formula `\af`/`\de` family | ebproof, relsize (loaded since D4) | nothing |
| diagrams | `french-logic-diagrams.sty` | the TikZ styles for possible-worlds diagrams (`modal`, `world`, `point`, the `reflexive` loops) | tikz, tikzsymbols | nothing |
| lists | `french-logic-lists.sty` | the list environments (with the beamer enumitem shim), `block`, `\by` | enumitem | nothing |
| structure | `french-logic-structure.sty` | hyperref, cleveref, footmisc; theorem styles and the eleven theorem environments, `proof`, `proofsketch`, the sketch and remark marks | amsthm, amssymb, cleveref, hyperref, footmisc; LaTeX 2026-06-01 or later | proof (`\qed`) |
| cite | `french-logic-cite.sty` | `\tcite`, `\pcite`, `\poscite`, the unbreakable name–label delimiter | biblatex (+ csquotes) | nothing |
| quarry | `french-logic-quarry.sty` | retired explorations, every entry commented out, each headed by the unit it came from: the conditional-obligation glyph trials, the B/4/5 axiom names, `\prob`, Ax/Th, page references, the question/answer environments from an old homework template, the `$`-form IO names | never loaded | nothing |

Hub: `french-logic.sty` keeps the options and loads the units in the order
above, with one exception: `proof` loads last, after `structure`, because its
house end-of-proof mark applies only when amsthm is visible, whether loaded by
`structure` or by the document itself before the package under `deon`. The
lists unit is not gated: the decks use `hilbertlist` under `deon`. Options
(settled 2026-09-07): one switch per unit through the kernel's keyval package
options, default on — `[structure=false,cite=false]` for a host class that
owns theorems, hyperlinks, and the bibliography driver, `[preamble=false]` for
one that owns fonts and layout — with two bundles, `deon` (structure and cite
off; the DEON template, beamer) and `slim` (`deon` plus preamble off). Keys
apply in the order given, an unknown option is an error, and loading under
beamer with `structure` still on raises a french-logic error that names the
fix, rather than letting hyperref's option clash speak. The history behind
`deon` (Brandon): it began as "everything that broke the DEON template",
offloaded into one block and switched off, and it happened to make beamer work
because beamer owns the same things; the per-unit switches are that idea made
general. The rendering suite compiles the fixture under both bundles.

## Conventions

*Status 2026-09-08: settled as listed, each with its date; nothing open. The
last forms were decided on 2026-09-08, on the board's fifth and sixth sittings
and in one batched ask, and the campaign closed with the v1.0 release; one kern
value is a deferred fine-tune (item 14).*

- **Mode.** Names — systems, axiom schemata, frame conditions, rules, I/O
  rules — are `\ensuremath{…}\xspace`, so they work in text and in math with
  no manual spacing. Objects — structures, relations, operators, truth sets —
  are math-only. The mode table (`tests/french-logic/modes.tsv`) records the
  fact: 295 members work in both modes, 202 in math only, 14 in text only,
  4 only inside a proof tree (census of 2026-09-08). `\Lc` gained the wrapper
  its `\lang` siblings have on 2026-09-07; the table caught up with it on
  2026-09-08 (D15).
- **Face.** Bold upright for axiom schemata and systems, inside italic text
  too — Humberstone's convention, settled 2026-09-07; every name now carries
  `\ensuremath{\textup{\textbf{…}}}\xspace`. Roman for rules, frame
  conditions, and generic names. Rule β, settled 2026-09-07: names built from
  schema letters (K, KD45, CE, CM<sub>R</sub>, KD<sub>O</sub>) are bold roman;
  proper-name terms of art (SDL, CO for conditional obligation, vF for van
  Fraassen, I/O, and the IO systems built on that name) are roman — chosen
  over small capitals and sans serif on the board, sans serif because it
  already means syntactic objects and frame classes here. The IO systems left
  bold under this rule on 2026-09-07. The face system is then: bold roman
  schema-built names, roman proper names, sans syntactic objects and frame
  classes, fraktur structures, calligraphic logics, script languages.
- **Indices on structures.** The letter under a frame or function — the R of
  F<sub>R</sub>, the D of f<sub>D</sub> — is an italic math letter, unlike the
  upright label on a name, and the two never look alike. Settled 2026-09-07
  from the definitions: F<sub>R</sub> is ⟨W, R⟩, so R is the relation itself;
  the strict typographic rule (descriptive subscripts upright) would split the
  family at f<sub>D</sub> and f<sub>M</sub>, and the uniform italic is kept.
- **Parentheses.** Lowercase frame-condition names and the `…par` variants
  carry their own parentheses; write `\cmr`, never `(\cmr)`.
- **Names.** Uppercase family names are axioms, lowercase their frame
  conditions (`\CMr` / `\cmr`). Suffix grammar: `s` star, `d` dual, `a`
  additive, capital `S` a superscript *s*, `conj`/`disj`, `conjd`/`disjd`,
  `up`/`down` the fishhook superscript named by the family's order direction,
  `par` parenthesised, `c` converse, `solo` the bare glyph for mention rather
  than use. Single letters: fraktur `\A \C \F \M` are structures, bold `\B \D \E \K \T` are
  systems, `\Slog`, `\four`, `\five` the forced exceptions. `\mathsf{{O}}` keeps
  double braces as the placeholder for a future bold switch. The `solo` rule,
  settled 2026-09-08 in Brandon's words: a connective named as a verb —
  `\cnecs` for "conditionally necessitates", like `\proves` and
  `\necessitates` — is for use between sentences, with its connective
  spacing; `solo` names the same glyph for mention, standalone and unspaced,
  and replaces the verb's *s* (`\cnecsolo`, `\cobsolo`); the metalanguage
  connectives are named by their symbols, so `solo` appends (`\mltosolo`).
  Whether one command could serve both, spacing itself by context, is a
  tracker item (`configs/TODO.md`, item 14), not a drift.
- **The grammar of the names — settled 2026-09-08: strict, substituted, no
  aliases.** A name is the letters as printed, CamelCase, digits spelled out. Kind is carried by case and one suffix: an initial capital for a schema
  or a system (`\CMr`, `\K`), with `ax` added only where the same letters also
  name a system (`\Kax` beside `\K`); lowercase for a frame condition (`\cmr`,
  and so `\rup` for the order conditions); lowercase with `rule` for a rule.
  Decorations are suffixes: `s` star, `plus`, `par` parenthesised, `c`
  converse, `solo` for mention, `ought` for the deontic reading; numbers are
  spelled and count as printed (`\FRtwo`, `\FNone`); a suffix letter is the
  letter printed (`\topa`, `\MR`, `\langc`). Landed in two rounds on 2026-09-08, each proved on
  both nets (renamed fixture pages hash-identical to their old golden pages;
  every consumer page-identical): round one the eighteen outliers (`\rmposs`
  → `\rmpossrule` and kin, `\Ts` → `\TOPs`, `\FRo` → `\FRtwo` and the frame
  numbering as printed, `\topt` → `\topa`, `\bott` → `\bota`, `\MRel` → `\MR`,
  `\Lc` → `\langc`, now beside its siblings, `\SDLt` → `\SDLT`); round two
  the thirty-seven classical schemata with their initial capital (`\kax` →
  `\Kax`, `\maxi` → `\Max`, `\duax` → `\Dualax`, `\cduax` → `\CDualax`, the
  `par` and `c` forms alike) and the four order conditions lowercase (`\Rup`
  → `\rup`). The old names are gone; every rename with its live-use counts is
  on the type board, section 7, and the consumers were substituted in
  the same landing. Three opuscula documents that had defined `\Lc` or `\SDLt`
  themselves stopped clashing with the package; the DEON fork keeps its own
  frozen copy and was not touched. Tool consequences landed with it: the
  highlight patterns (`axfam` on capitals, `orderfam` lowercase, `rpossfam`
  absorbed by `rulefam`, `langfam` with `c`), the snippets, the register
  taxonomy's mention of `\langc`, and the syntax suite's fixture.
- **Small labels.** The small letter on a name — the R of CM<sub>R</sub>, the
  H of IO<sup>H</sup> — is set by one internal helper, `\fl@lbl`, in core:
  upright, at `\scriptscriptstyle`, so it scales with the mathematics around
  it, smaller in a footnote and larger in a heading. Settled 2026-09-07 by eye
  against the four fixed-size idioms the file had grown; the 121 labels were
  converted in one pass, pixel-identical in 12 pt running text, visibly better
  in headings. Hyperref bookmarks receive the bare letter. The symbol
  decorations on truth sets and classes (`\truthsetm`, `\proofsetl`,
  `\eclassl`) scale the same way since 2026-09-07, judged on the board.
  Their old tuck — `\mkern-2mu` at text size inside the fixed box — went
  missing in that conversion and came back on the sixth sitting (2026-09-08)
  as `\mkern-3mu` inside the script on the ten decorated members, the old
  gap at every size within a pixel; Brandon suspects −2 mu is the optimum,
  a fine-tune on the tracker (item 14).
- **Decorations** (board, fifth sitting, 2026-09-08). A decoration letter on
  a name is an italic math letter at script size — the *c* of the converse
  family, the *d*, *a*, *s* on the conditional schemata — so `\Wocax` sets
  its converse *c* that way beside its sans O, where it had a text c; a
  system's superscript decoration is a math superscript at script size, as
  the + of `\SDLplus` and the * of `\CEMPs`, so `\SDLT` sets its T that
  way, where it had a `\textsuperscript`. The family label stays `\fl@lbl`.
  The kern under a subscripted letter is per-letter tuning and stays as it
  is: `\Woax`, `\Wocax` and `\Waxc` kern before the underscore (text-size
  mu, the deeper tuck under the W's arm), `\Poax` and `\Posax` inside the
  subscript (script-size mu); measured on the board, not the same, and not
  unified. The same idea gives the L its tuck (sixth sitting, 2026-09-08):
  `\SDLT` and `\SDLplus` pull their superscript by `\mkern-4.5mu` into the
  void above the L's foot, the 2 pt the old `\SDLt` had; the other superscript
  decorations stay untucked.
- **Kerns and forms** (2026-09-08, the batched ask). A kern is part of a
  glyph's tuning and stays (`\unpossed`'s leading `\!`) until the eye says
  otherwise: `\emptytruthset`'s `\!\cdot\!` was kept on the ask and dropped
  on the confirmation pass later that day, the open dot reading better; a
  run of kerns summing to zero is a no-op and goes, as D11's `\!\,` did — `\unneced`'s `\!\:\!\:\!\:\!` went on 2026-09-08,
  0 pixels changed. No member ends in forced space: `\mcslog` lost its
  trailing `\ ` the same day (no live use; a document can add space and
  cannot remove it). Every member is `\newcommand`: the five `\newcommand*`
  forms (`\IO`, `\hyphantom`, `\close`, `\incomp`, `\hk`) were unstarred,
  output-identical.
- **Spacing.** `/` is on the `\xspace` exception list, so `\ccr/\ccl` sets
  correctly.
- **Comment grammar** (settled with the core pass, applied to every unit,
  2026-09-08). Inside a unit a `%%%` line opens a level (the tower's in core,
  the unit's own elsewhere), a short `%` line names a group within it — the
  inventory's headings, so a group line stands apart from prose by a blank
  line — and `%%` lines are prose, never headings. A group heading reads
  "Level: group" where a level has more than one group. Each unit's head
  comment says what it holds, what it refers into, and the date of its pass.
- **Dates** (settled 2026-09-08). A file's `\ProvidesPackage` date is the date
  of its last change, so a landing bumps the unit it touches; the hub's date
  moves only when the hub itself changes. The hub carries the version, v1.0
  since 2026-09-08 (the release D12 promised); a release moves the hub's date
  and version together.
- **Provenance.** `\Yright` as the sequent separator (`\seq`, `\tseq`) is
  Humberstone's convention; its declaration stays in the package as the
  record even though stmaryrd supplies the glyph. Renewals that restate a
  kernel or amsthm definition (`\to`, `proof`) are membership pins, not
  redundancy.
- **Duplicates.** Fourteen groups of byte-identical definitions (measured
  2026-09-08) are deliberate vocabulary until decided otherwise — principle 1:
  ten within one unit (`\then`, `\onlyif`, `\to`; `\gives`, `\asserts`,
  `\proves`; `\oset`, `\tuple`; …) and four across units: the three where
  the applied and deontic operators share a sans letter (`\was`, `\may`,
  `\permissible`; `\willbe`, `\forbidden`; `\henceforth`, `\gratuitous`)
  and the four names for `\Rightarrow` (`\derives`, `\necessitates`,
  `\triggers`, `\ecu`), which span core, deontic and gentzen.

## Tooling

- **Snippets.** `nvim/lua/snippets/sty-lua-snippets.py` generates the LuaSnip
  module from braced `\newcommand` forms, comments stripped, reading the hub
  and every unit it loads (`-i` repeated, hub first); the module carries one
  hash over all of them and regenerates on the next Neovim start. It cannot
  see `\DeclareMathSymbol`, `\NewDocumentCommand`, or `\DeclareCiteCommand`
  members, and it keys list-shaped snippets on the substring `list` in an
  environment's name.
- **Highlighting.** `nvim/lua/plugins/vimtex.lua` registers members into the
  register taxonomy by name shape (`C[CM][rl]\w*`, `[CKDTUPWN]ax\w*`, `\w*rule\w*`, `[rl]%(up|down)`, …); renames must keep to those shapes or update them. The
  coverage check is `sty-lua-snippets.py --coverage`.
- **Rendering suite.** `tests/french-logic/run.sh`; golden re-accepted after
  each landed change, last on 2026-09-08 after the confirmation pass (the
  ten decorated members and both SDL names tucked, `\emptytruthset` open;
  836 pages); the split changed no page. `extras.tex` adds fixture pages for what has no
  member, today the diagram styles, after a scratch-directory mishap showed
  that nothing else would notice them breaking.
  `\qed` and `\qedsymbol` are members of the fixture since D7 wrote them with
  braces. `tests/french-logic/inventory.py` regenerates `AUDIT.md` from the
  unit files (its group headings are the units' own: a `%%%` line, or the
  first line of a run of `%` lines); `tests/french-logic/units.sh` is the standalone-load test.
- **Consumer harness.** `org/claude-config/repos/configs/french-logic-harness/`
  (private): `sync.sh` copies the dissertation, its wrappers, the decks, and
  the teaching and opuscula documents into a scratch tree, `run-suite.sh`
  builds them against a candidate package, `compare.py` diffs page by page.
- **The type board.** A private page of photographed samples for decisions
  taken by eye (labels, faces, decorations, the folds' code, the grammar
  draft); its link is in memory, and it is redeployed sitting by sitting.

## Consumers

Thirty-three documents load the stowed package (counted 2026-09-08 by the
directory each compiles in: the 27 harness targets, four in `opuscula/old`,
and two `old/old.tex` files whose parent directory's frozen copy does not
reach them, since TeX searches only the compile directory); twenty-seven
more carry a frozen copy of an old version beside them, twenty-five in
opuscula and two in the DEON fork, and are untouched by edits here. The
dissertation and its seven article wrappers use 253 members. The three
teaching documents use twenty macro uses in total, all from core, and
otherwise use the package as a preamble. The `deon` option is passed by the
three beamer decks and the two LvFsystems documents; the two IO-logic decks
passed the `conflicts` option that `deon` replaced on 2025-11-15 until D9
was closed. Three opuscula documents fail against the current package because they
define macros the package has since acquired (`\IO`, `\lang`, `\suchthat`) or
use the retired `defn` environment; that is consumer drift, not a package
defect, and is on the ledger. A fourth, on-indices, built again on 2026-09-08
when `\SDLt` became `\SDLT` and its own definition no longer clashed; the two
others lost one error each the same way. The DEON fork
(`IO-logic/DEON/IO-DEON-fork/`) is a frozen tree with its own copy of the old
package; its `final/` copies name the stowed package only because no copy
sits beside them, and they were left as submitted. The usage census the
inventory reads (`usage.tsv`, in the harness) is hand-kept; its `\SDLT` row
carried two opuscula documents' own `\SDLt` under the renamed key until
2026-09-08, when it was corrected to zero — the package's `\SDLT` has no
live site.

## Ledger

Defects are numbered D, form drift F. Every item below is closed; each is one
line here and stands in full, as it read when it moved on 2026-09-08, in
`configs/DECISIONS.md`, item 13.

- **D1** orphan `\makeatother` and the comment that blamed `\ExplSyntaxOn` —
  fixed 2026-09-07.
- **D2** U+2019 in the `modal` arrow tip — fixed 2026-09-07; `stealth'` kept.
- **D3** `\usepackage` for microtype inside the package — fixed 2026-09-07.
- **D4** relsize for the signed-formula family, unloaded — fixed 2026-09-07.
- **D5** stmaryrd's symbol font re-declared — resolved 2026-09-07; the
  `\Yright` declaration kept as Humberstone's record.
- **D6** `\IOfn`'s bare `\tiny` — fixed 2026-09-07; the label at the scaling
  size.
- **D7** the `\qed` renewal that broke `\qedhere` — fixed 2026-09-07 on
  amsthm's mechanism; two dissertation pages changed, as intended.
- **D8** aliascnt on the 2026-06-01 kernel — fixed 2026-09-07; older formats
  refused.
- **D9** the IO decks' removed `conflicts` option and the enumitem recursion
  — fixed 2026-09-07; both decks build.
- **D10** `block` inside the amsthm guard — fixed 2026-09-07.
- **D11** apparent no-ops — resolved 2026-09-07; four kerns removed, the two
  pins kept.
- **D12** prose where the `\ProvidesPackage` date belongs — fixed 2026-09-07.
- **D13** the absolute `!TEX root` path — resolved 2026-09-07, relative.
- **D14** the inventory's prose-fragment headings — fixed 2026-09-08.
- **D15** the mode table behind `\Lc`'s wrapper — fixed 2026-09-08; golden
  836 pages.
- **D16** microtype's option clash from the stit unit — fixed 2026-09-08;
  bare load, `\microtypesetup` after.
- **F1** mode, face and naming drift — settled 2026-09-07 and 2026-09-08; the
  ordering passes landed 2026-09-08.
- **F2** the four hand-copied dyadic bodies, two theorem styles, two loops —
  folded 2026-09-07.
- **F3** header hierarchy, blank-line runs, whitespace, long lines — resolved
  by the split and the passes, 2026-09-08.

Decisions closed 2026-09-07: the option design (above); hyperref keeps its
defaults, a document that wants otherwise sets `\hypersetup` itself;
`geometry` stays with the documents, where every consumer already sets it.
The opuscula drift was recorded in that repo's inventory (finding 10) on
2026-09-07 and left as it is. The ordering passes and the dissertation
charter's package section both closed on 2026-09-08. Closed 2026-09-08, at
the campaign's end: the preamble's eight furniture loads no consumer uses
(multicol, tabularx, xcolor, ragged2e, bm, centernot, calc; tikzsymbols in
diagrams) stay, under principle 5 — the unit is a preamble, and the six
documents outside the harness were never censused for them;
`\graphicspath{{./images/}}` stays, harmless, for a document that has such a
directory; `slim` stays, part of the option design and proved by the suite;
`dissertation-template/philogic.sty`, which could one day be derived from the
units, is out of the campaign's scope and on the tracker (item 14). Nothing is
open but the decorations' kern fine-tune (item 14). The campaign concluded 2026-09-08; its four briefs are the dated
record in `configs/docs/french-logic-campaign-2026-09/`, and its post-mortem
is `configs/DECISIONS.md`, item 13.

## History

Imported into `configs` on 2025-11-10 from the texmf tree, where it had grown
since 2021. 2025-11-15: the `deon` option replaced the `kvoptions`
`conflicts` mechanism and its `conflicts.def`. March–June 2026: cleveref,
the aliascnt idiom, the `\ensuremath`/`\xspace` form for names, the order
conditions and metalanguage quantifiers, `hilbertlist`'s right margin,
`axiomproof`, `\by`, `\textup` inside the family names, `\metalogic` and the
solo forms. 2026-09-05: the biblatex options and the citation forms.
2026-09-07: the audit, the harness, the map, the rendering suite, and the
first three fixes. 2026-09-08: the second chat verified all of it on fedxps
against the pre-split package (the differences were exactly the deliberate
list), and fixed the inventory headings and the mode table; the naming grammar,
decided strict, landed in two rounds the same day. Later on 2026-09-08 the
third chat, on bigfed, verified the second's work, landed the core ordering
pass, the microtype fix (D16), the dates rule and the dissertation charter's
package section, recounted the duplicates and the consumers, and then, on
his "let us proceed", landed the ordering passes for the thirteen other units
and moved the closed ledger to `configs/DECISIONS.md`. The fourth chat, on
bigfed later that day, verified the third's work, put the last three forms on
the board (the converse *c*, the T on SDL, the kern under W against P), took
the rest in one batched ask, landed four forms and recorded four policies,
wrote the `solo` rule down in Brandon's words, released v1.0, and closed the
campaign; the four briefs moved together to
`configs/docs/french-logic-campaign-2026-09/`. That evening's confirmation
pass, every choice re-photographed from v1.0 on the type board, returned three
notes: `\emptytruthset` reversed to the open dot; the decorations' lost tuck
restored (K3) and the SDL names tucked (Bk on both), the sixth sitting; the
decorations' kern value is the one fine-tune left, on the tracker.
