# The register taxonomy — semantics of the LaTeX highlight scheme

Living contract for the colour scheme implemented in
`lua/plugins/vimtex.lua` (registrations), `after/ftplugin/tex.lua`
(colours), and `after/syntax/tex.lua` (environment-name families).
Present-tense truth: edit in place when the scheme changes. The
regression suite is `tests/nvim-syntax/`; the registration/`.sty`
coverage check is `sty-lua-snippets.py --coverage`.

The scheme's brief: colours encode the philosophy-of-logic structure of
the writing surface — what kind of thing each token is, on which level
of language it operates, and which side of the correspondence divide it
serves — so that reading the source keeps the document's conceptual
geography in view.

## Status

Adopted 2026-08-28 and held. His standing verdict, recorded at his
request: the scheme is a real improvement *and* a very crude
approximation — the true scheme is one he cannot yet articulate, and
this document describes the best current approximation of it, not a
finished object. Refinement is successive approximation with his eye
as the oracle: he brings instances from living in the scheme (glance,
then gaze, then wayfinding); a proposed change is exhibited on the
bench (the artifact "The Two Slopes") before it touches the config;
the geometric law and the closure rule bound what any change may do.
Between instances, the scheme holds still.

## Thesis 1 — the tower

Every content token sits at a depth in the tower of languages. The
**object language** (the logics under study: their operators,
connectives, formulas) is the deepest level — everything else is about
it. **Proof theory** works *at* the level of syntax: derivations, proof
sets, axiom systems are syntactic objects, so proof theory sits with
the object language. **Semantics** stands one level of aboutness above:
it assigns the syntax its values (models, ⟦·⟧, ⊨). **Metasemantics**
stands above that: the metalanguage studied as a language of its own
(the underlined FO connectives, frame conditions, correspondence
theory — which is precisely the discipline that relates the two levels
below it). **Prose** is the top of the tower: English as the ambient
metalanguage in which the whole document is conducted.

Formality runs inverse to aboutness: the deeper the level, the more
formal the material. The two axes earlier versions treated separately —
a formality gradient and a syntax/semantics polarity — are one
structure: the warm/cool division *is* a depth division, because the
⊢-side lives at syntax level and the ⊨-side one level up. Satisfaction
statements (`\M,w\trues\ought A`) are level-crossing claims and render
as cool machinery evaluating warm material; correspondence pairs
(CMr↔cmr) are level-crossing equations and render warm↔cool. This
mirrors the dissertation's own subject: congruentiality is respect for
⊢-equivalence, non-hyperintensionality respect for ⊨-equivalence, and
the project lives in the gap between the temperatures.

Two constituents are deliberately level-*neutral*:

- **The medium** — the unformalized mathematical vernacular (set
  theory, orderings, definitional idiom) is used at every level, so it
  takes no level colour: gray. Grayness is a semantic assignment
  (level-neutrality), not an absence. This is where prose shades into
  the formal.
- **The material** — variables, atoms, and the math body itself
  (Greek, roman, `p₀`…): warm tan `#c6ab90`, italic. The material is
  level-neutral in principle but leans toward what it mostly composes —
  the object language — per the formula-unity verdict of 2026-08-28
  ("exactly in between" neutral letters and fully warm object-letters):
  formulas cohere as warm wholes, and the cool machinery visibly
  crosses into them. Known tension, accepted: worlds and formula-sets
  (w, ω, Γ) share the tan; the escalation is the β sort convention
  (sentence letters full warm, semantic variables cool), ledgered and
  deliberately not built while the tan holds.

Markedness refines this within a level: a level's own unmarked
workhorses desaturate toward the medium — but toward *their bank* of
it. The saddle where the two slopes meet has two banks (2026-08-28,
after the steel's blue lean made booleans read semantics-side):
object-language connectives (`\to`, `\land`, `\neg`, `\top`…, stock or
`.sty`) take the warm bank — the material tan in roman, so formulas
cohere as warm wholes with style separating connective from variable —
while metalanguage and set-theoretic glue keeps the cool steel. What
carries a level's colour is its *distinctive* vocabulary.

**The closure rule (adopted 2026-08-28):** the taxonomy is closed.
Future changes retune or remove; adding a species requires exhibiting
a new *genus*, on the bench, first. This is the standing answer to
"reaching too far" — and note the cost model: runtime cost scales with
match rules, not colours. Measured 2026-08-28 on completeness.tex
(572 paragraph-lines, full synID sweep): 402 ms with the custom layer,
137 ms without — 0.46 ms/line total for the whole apparatus, no
pattern above 6 µs average in `syntime report`. Re-run any time with
`tests/nvim-syntax/perf.sh <file.tex>` — it prints the with/without
delta and a ms/line verdict; under ~2 ms/line is imperceptible.

**The geometric law (adopted 2026-08-28):** the palette's shape is a
constraint, not a preference. Tokens keep discrete, statable colours,
but the assignment as a whole must stay homomorphic to the tower:
saturation tracks depth on each slope, temperature tracks side, and
the two slopes meet at the gray medium. Any future colour change must
preserve this shape — "continuum in the large, discrete in the small."

## Thesis 2 — the channel contract

| channel | encodes |
|---|---|
| **hue** | genus, and side/depth within content: warm gold = syntax-level (proof theory + object language); cool blue = semantics + metasemantics; warm tan = material; gray = medium; green = the document dimension entire (a spectrum: landmarks > loaded structure > containers > scaffolding, deixis in-family); magenta = register boundaries; red = preamble machinery |
| **saturation** | markedness — unmarked workhorses shade toward gray |
| **lightness** | salience within a family: relations > objects > names |
| **bold** | name/anchor status — what the eye scans for |
| **italic** | material and argument content; prose emphasis |

## The species table

Background `#1a1b26`; contrast is WCAG vs that background.

| species | members (examples) | group | colour | weight | contrast |
|---|---|---|---|---|---|
| semantic relations | `\trues` `\models` + negations, `\bisim`, `\natent` | `texCmdTurnstileSem` | `#89ddff` | — | 11.3 |
| derivability relations | `\proves` family, `\gives`, `\seq`, signed forces via af/de | `texCmdTurnstileSyn` | `#eec584` | — | 10.5 |
| intensional operators | `\ought` `\may` `\cobs` `\cnecs` `\nec` `\sphere`, stit, epistemic, temporal | `texCmdIntension` | `#d9aa5e` | — | 8.0 |
| semantic objects | `\M` `\F` `\flog` fams, `\truthset` `\ctruthset`, `f`-functions, valuations, truth values, STIT structures, credence | `texCmdSemObj` (+`texArgSemObj` ital) | `#74acf5` | — | 7.3 |
| syntactic objects | `\proofsetl` `\eclassl`, languages `\lang*` `\Lc`, `\logic`, `\Fm` `\atoms` `\props`, mcs, `\cn` `\theory`, I/O out(·) | `texCmdSynObj` (+`texArgSynObj` ital) | `#bd9750` | — | 6.3 |
| names, syntax side | schemata (CMr…), systems (K, CE, IO…), rules (RE, MP…), frameworks | `texCmdNameSyn` | `#bd9750` | bold | 6.3 |
| names, semantics side | conditions (cmr, cth…), order conditions (R↑…) | `texCmdNameSem` | `#7396c2` | — | 5.6 |
| object connectives | `\to` `\iff` `\then` `\onlyif` `\hk`, typed variants, stock `\land` `\lor` `\neg` `\top` `\bot` `\equiv` (stockbool) | `texCmdConnective` | `#c6ab90` | roman | 7.8 |
| medium | `\in` `\subseteq` `\set` `\power` `\cap` `\emptyset` `\defby` `\ent`, ml-connectives, `\metalogic` (+ stock via `texMathCmd`) | `texCmdGround` | `#8f99c9` | — | 6.2 |
| material | Greek letters, `p₀`–`p₃`; math body; formula args | `texCmdVariable`, zones, `texArgFormula` | `#c6ab90` | italic | 7.8 |
| landmarks | `\chapter` `\section`, titles; theorem-family env names | sectioning groups, `texEnvArgNameThm` | `#9ece6a` | bold | 9.4 |
| loaded structure | env names: proof, proofsketch, gentzen, axiomproof, **hilbertlist** | `texEnvArgNameLoaded` | `#4fd6b0` | bold | 9.4 |
| pure structure | `\begin`/`\end`, `\item`, default env names, booktabs rules, proof-tree scaffolding (`\hypo` `\infr` `\by` `\close`) | `texCmdEnv/Item/Scaffold`, `texEnvArgName` | `#1abc9c` | names bold | 7.1 |
| deixis | `\cref` `\ref` `\label` `\cite` | ref groups | `#9ece6a` | — | 9.4 |
| prose inflection | `\emph` `\textit` `\textbf` tokens (content keeps body tone), `\footnote` | `texCmdStyle` etc. | `#9aa5ce` | italic | 7.0 |
| boundaries | `$` and math delimiters; `\qed` family | math delim groups, `texCmdQed` | `#bb9af7` | — | 7.4 |
| stage crew | preamble, packages, `\input`, `\newcommand` (defined name takes `#bd9750`) | package/def groups | `#f7768e` | def bold | 6.5 |

## The document genus

The document dimension is **one green spectrum**, per the spectrum
verdict of 2026-08-28: landmarks (`#9ece6a` bold — sectioning, titles,
theorem-family heads) > loaded structure (`#4fd6b0` bold — proof
environments, gentzen, axiomproof, hilbertlist: containers that confer
mathematical status) > plain containers (`#1abc9c` bold env names) >
scaffolding (`#1abc9c` regular — `\begin`/`\end`, `\item`, proof-tree
helpers, booktabs). Deixis (`\cref`, `\cite`, `#9ece6a` regular) is
the same family at the landmark hue: pointing shares colour with what
is pointed at. Prose inflections (`\emph`, `\textit`) are the voice
modulating itself: firmly prose-side, muted command tokens, body-toned
content.

*Retired 2026-08-28:* loaded structure borrowing the content side's
colour (hilbertlist in the warm name gold). It failed the glance test —
loaded env names impersonated system names, and the document dimension
fractured into unrelated hues when its nature is a single spectrum.

## The open questions, answered

**How many hues?** One per genus that has an identity: the count is
derived, not chosen — warm, cool, violet, gray, green, orange, magenta,
red. Adding a hue requires exhibiting a new *genus*, not a new species;
species within a genus are carried by lightness and weight.

**How much gradient within a hue?** At most three rungs. Measured
CIEDE2000 between the warm rungs is 6.5–7.2, which is near the floor of
reliable discrimination for 12pt text; a fourth rung would drop below
it. Rungs follow the salience rule (relations > objects > names).

**Adjacent hues to encode spectra?** No continuous ramps. A ramp
produces intermediate colours with no statable meaning, and the scheme
must stay *learnable*: every colour answers "what does this mean?" in
one sentence. Where a genuine spectrum exists (structure shading into
content), it is encoded by **discrete borrowing** at the loaded end —
hilbertlist wears the warm family — not by interpolation.

## Borderline ledger

Calls that could reasonably go the other way; each is a one-line move.

- `\metalogic` — the metalanguage named as its own object language;
  gray with its connectives. Could take the cool name tone.
- Canonical-model family (`\Mlog` `\flog` `\Wlog`…) — **resolved
  2026-08-28: semantic in kind (blue)**. His rationale: the canonical
  construction *extracts* semantics from proof theory, and that
  direction is already carried by the prose. Left open: whether
  canonical semantic objects someday take a sub-rung of their own
  (a deeper blue) as distinct-from-semantics-in-general.
- Languages, `\Fm`, `\props` — warm as syntactic objects, though they
  serve semantics as indices (`\proofsetl` subscripts).
- Object connectives gray — markedness overrides depth (850 tokens of
  warm skeleton would flood the field). Revisit if formulas feel
  underpainted.
- `\ent` (⊢/⊨ interface glyph) — gray, as the interface itself.

## Revisit dials

- Warm feels heavy in deontic-dense chapters → operator `#d9aa5e` →
  `#c9a05a`.
- Poles feel inverted in some formula → report the formula; a two-hex
  swap trades the anchors while keeping the geometry.
- Condition names too dim in appendix-B → `#7396c2` → `#7d9cc9`.
- Cursorline (in `lua/plugins/colorscheme.lua`): `#1f2132` (1.08:1);
  dials `#212439` / `#1d1e2c`.
- Semantic azure `#74acf5` still reads warm inside formulas →
  `#6ea6f2` (costs distance to the condition names).
- Formula unity resolved 2026-08-28 by the warm-tan material (γ, the
  in-between). Escalation if formulas still fragment after living with
  it: the β sort convention — sentence letters full warm `#bd9750`,
  worlds/sets cool — requires fragile bare-letter matches and a
  letter→sort table derived from the corpus and confirmed line by
  line. Deliberately not built.
- Math-body-vs-prose distance is now 28.7 dE00; the old violet dial
  (`#af9ef5`) is obsolete.
- Math body vs prose still too close → `#b3a8f2` → `#af9ef5` (costs
  body brightness and nears the `$` magenta).
