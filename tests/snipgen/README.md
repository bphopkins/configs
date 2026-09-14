# tests/snipgen: the generator's suite

Regression suite for `nvim/lua/snippets/snipgen.py`, the cwl and `.sty` front
ends of the LaTeX completion layer. The rules it pins are section 2 of
`docs/latex-completion-campaign-2026-09/PLAN.md`; the stage-1 and stage-2
acceptance rows are section 3 there. Hermetic on the word lists and the `.sty`
package in `fixture/`, about a second; the amsmath spot checks run only where
the TeXstudio clone exists (`~/Desktop/texstudio`, or `$SNIPGEN_CLONE`) and
print `skip` otherwise. Run it after any edit to the generator, and after a
clone pull before a regeneration.

    ./run.sh            every check; exit 0 = ALL PASS
    ./run.sh --update   regenerate golden/ and golden/sty/ from the current generator, then run

## Files

- `fixture/fixture.cwl` — one row per rule, 96 lines, two of them CRLF. Every
  classification letter of the format, `#include` (twice the same, and the
  file itself), `#ifOption` blocks enabled and not, a typo directive
  (`#ifOpton`), a hash line without a colon (a comment, no warning), `#repl`,
  a `#keyvals` block with a comment and a blank line inside and one left open
  at end of file, `%<…%>` whole-group and embedded in literal text,
  `%:translatable`, `%|`, `%\`, the `%suffix` names, `\begin` rows with and
  without `\item` (both forms of one environment, only the `\item` form of
  another, a bare third, and one whose `\item` is known only from the core
  lists), a multi-line `\begin` template, an environment with
  a backslash inside an argument, an unparsable environment row, starred
  forms of a command and an environment, `(x,y)`, `<x>` and `[<x>]` groups, an
  empty group, control symbols (`\,`, `\\`, `\%`), a non-ASCII name, the two
  bare-backslash forms, duplicates within the file (one an unusual twin after
  its typical row, one before it), a subscripted command (`\sum_{min}^{max}`),
  an expl3 variable name with underscores, two rows that duplicate the core fixtures, a row
  without a backslash, an unknown classification letter, and TeXstudio's
  generic environment template.
- `fixture/core/{tex,latex-document,latex-dev}.cwl` — three-row stand-ins for
  TeXstudio's always-loaded lists, for the core deduplication and its order.
- `golden/fixture.lua`, `golden/latex-dev.lua` — the expected outputs, written
  by hand from the rules before the parser existed: they are the
  specification, and the parser was built to meet them.
  `golden/fixture.warnings` is the exact stderr, in file order.
- `fixture/sty/fixhub.sty`, `fixture/sty/fixhub-unit.sty` — the `.sty` front
  end's package: a hub that requires its sibling unit three times (once gated
  by a `\newif`, as the real hub gates every unit), real packages with a
  bracket, with a bracket spanning two lines, in a comma list and through
  `\RequirePackageWithOptions`, a `\usetikzlibrary` list, a multi-line
  `\ProvidesPackage` description, one command of its own, a commented-out
  definition and an `@` name; and a unit with every definition form:
  `\newcommand` bare, with two arguments, with a text default, an empty
  default and a macro default, `\renewcommand`, `\providecommand`,
  `\newcommand*`, a name defined twice, a definition split over two lines, a
  definition after a mid-line `%`, the hub's name redefined, an `@` helper,
  `\DeclareMathOperator` plain and starred, `\DeclareMathSymbol` plain and
  with an `@` name, `\newenvironment` bare, among the commands, with a text
  default, a macro default and two mandatory arguments, one wrapping itemize,
  one wrapping that wrapper but defined before it, one writing its own
  `\item[]` over a `list`, `\renewenvironment`, `\newtheorem` plain and
  starred, and a `\newtheoremstyle` that must not match.
- `golden/sty/fixhub.lua`, `golden/sty/fixhub-unit.lua` — the expected
  outputs, written by hand from the rules before the `.sty` mode existed; the
  generator met them byte for byte on its first run.
- `verify.lua` — loads a generated file under stub `luasnip`,
  `luasnip.extras` and `snippets.helpers` modules (`nvim --clean -l`) and
  checks the shape the loader relies on; with `fixture` as its second argument
  it checks the cwl fixture's expected contents too, with `sty` the unit
  golden's and with `styhub` the hub golden's.
- `.styluaignore` — keeps LazyVim's format-on-save off the goldens. Measured
  2026-09-13: without it an in-editor save reflows a `.lua` under `tests/`,
  because `nvim/.styluaignore` does not reach here.
- `../stylua.toml` — `tests/stylua.toml`, a copy of `nvim/stylua.toml` (two
  spaces, 100 columns), so that an in-editor save of `verify.lua` and the
  CLI agree; without it the in-editor path found no config above `tests/`
  and used stylua's defaults (tabs, 120 columns), reflowing the whole file on
  the next save. Placed at `tests/` because the other suites' Lua files
  already follow the same style. How it is found, measured 2026-09-13 with
  stylua 2.3.1: conform sets its working directory to the directory holding
  the nearest `stylua.toml` above the buffer's file and passes
  `--search-parent-directories`, so every in-editor save under `tests/`
  sees it; the CLI finds it from the repo root
  (`~/.local/share/nvim/mason/bin/stylua --check tests/`), walking up from
  each file's directory to the working directory, and does not find it
  from inside this directory, where a bare `stylua --check .` falls back to
  the defaults. Added in build chat 2 with the one reformat of `verify.lua`
  it implied.

## Checks, and what each pins

1. **fixture → golden, byte for byte.** Every rule of section 2 at once. A
   diff here names the row; decide which side is wrong before touching either
   (the golden is the specification, but it was typed by hand).
2. **warnings exactly as recorded.** The parser's tolerance: unknown
   directive, unknown letter, unparsable environment row, bare backslash, row
   without a backslash, unterminated keyvals block — one line each, in file
   order, nothing else.
3. **`--check` green twice.** Idempotence: regenerating changes nothing, so
   `--check` is a usable drift test.
4. **`--check` red on a changed copy, and writes nothing.**
5. **core order.** `latex-dev` drops a row `tex` already carries, so the three
   always-loaded lists deduplicate in order.
6. **the golden loads.** Under stub modules the file returns its five fields,
   every snippet has a string trigger and description, the math row is
   wrapped, the restricted row hides and sinks, the generic template mirrors
   its name, the hidden, core and disabled-option rows are absent, the typical
   row beats its unusual twin.
7. **amsmath spot checks** (clone only): the acceptance rows of PLAN.md
   section 3 (`\binom`, `\cfrac`, `\dotsb`, `align`, `\Hat`, `\AmSfont`), the
   includes header, and the commit stamp.
8. **`.sty` fixture → golden, byte for byte, from the hub alone, nothing on
   stderr.** Every `.sty` rule at once: the sibling recursion, the includes
   and their order, the tikz-library mapping, the multi-line bracket, source
   order, the two rows of an optional argument and their placeholder text,
   the opens-a-list rule with its fixpoint, the math wrap by construction,
   the hub-order dedupe, the skipped forms.
9. **the stamp is the source file's own sha256.** The stage-3 startup check
   compares per file, so the stamp must be the file's, not a blob's.
10. **`--sty --check` green twice.** Idempotence, as check 3.
11. **`--sty --check` red on drift and on a sourceless file, writes
    nothing.** A changed copy counts as stale; a file whose `-- source:`
    header names a `.sty` that no longer exists counts as extra; a file with
    another header (the cwl golden copied in) is never touched.
12. **a write run restores the drifted file and removes only the sourceless
    one.** The cwl file copied beside them survives.
13. **the unit golden loads**, and under the `sty` profile: 29 snippets, one
    include, the two wrapper lists, source order, both signatures of the
    three optional-argument commands with the right placeholder text, the
    last definition's shape in the first definition's place, the hub's name
    absent, the skipped forms absent, the three math rows wrapped with `cls`
    `m`, a plain row with neither `cls` nor `priority`, the environment rows'
    bodies.
14. **the hub golden loads**: nine includes in source order, no lists, one
    row, the `@` name absent.
15. **`--coverage` on the fixture against the real `vimtex.lua`**: exit 1
    naming `\plain` and `\shared`, not `\sym` (a `\DeclareMathSymbol` name
    stays outside the set, as the old generator had it).

## Mutation record

- 2026-09-13, build chat 1: the `%<…%>` rule was broken (the tokenizer no
  longer recognised the placeholder marker). Checks 1 and 3 went red, check 1
  showing the four marker rows (`\includegraphics`, `\cfrac`, `\magstep`,
  `\matrix`) and the multi-line template with a literal `%<` in them; every
  other check stayed green, as it should. Restored: ALL PASS (14 checks).
- The same day, before that: the first run against the hand-written golden
  failed on one row, the multi-line pgfplots template, where the parser had
  filled the inner `\begin{axis}` and `\end{…}` groups. The golden was right;
  the bracket rule gained its marker-row variant (only the groups attached to
  the row's own command are filled). Recorded in PLAN.md section 2.

- 2026-09-13, build chat 2: the optional-argument rule was broken (an empty
  default `[2][]` no longer counted as an optional argument, which is what
  TeXstudio's own `.sty` parser does). Checks 8, 10 and 12 went red, check 8
  showing the one missing row, `\optempty` `[]{}`; the other 19 stayed green.
  Restored: ALL PASS (22 checks).
- The same day, before that: the first run of the `.sty` mode met both
  hand-written goldens byte for byte; the one red check was an index in
  `verify.lua`'s `sty` profile (the third insert node of `argenv` is the
  sixth node, not the fifth). The golden was right.

## Updating the golden

`./run.sh --update` rewrites the goldens from the current generator. Read the
diff before accepting it: a change to a golden is a change to the rules and
belongs in PLAN.md section 2 as well.
