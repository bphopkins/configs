Annotation, 2026-09-13: build chat 3 opened from this brief and landed stage 3; its successor is `next-chat-2026-09-13c.md` beside this file. Sections 1, 6 and 8 of `next-chat.md` and section 5 of `next-chat-2026-09-13.md` still bind.

Prompt — the opening brief for the third build chat of the LaTeX completion
campaign. Dated record, written 2026-09-13 at the close of build chat 2, on
fedxps (the letter: two chats closed on one date). The next chat writes its
own successor beside this file at its close (`next-chat-YYYY-MM-DD.md`),
adds one annotation line at the head of this one, and otherwise leaves it
as it is. Its predecessors stay as written; sections 1 (how the work is
done), 6 (pitfalls) and 8 (where to look) of `next-chat.md` still bind and
are not repeated here, nor is section 5 of `next-chat-2026-09-13.md`.

# Read this whole file, then PLAN.md, before touching anything

You are opening the third build chat of the campaign that rebuilds the
LaTeX completion layer of `configs/nvim` on TeXstudio's model. Stages 1 and
2 have landed; this chat does stage 3, the loader, the gates and the
provider, and retires the old files. It is the first chat that changes a
configuration file, so it probably opens with a planning round. The aim,
the decisions, the rules as built, the stages and the record trail are in
`PLAN.md` beside this file (section 0 says what "done" means); the evidence
is `comparison-2026-09-12.md`. Read `next-chat.md` sections 1, 6 and 8 as
instructions.

## 0. The queue, and what closes each item

1. **Stage 3, loader, gates, provider; retire the old files.** Closes by
   `PLAN.md` section 3, stage 3: both Neovim suites green with the latency
   suite's flipped and added checks, `:SnippetsReport` on
   `completeness.tex` listing about 100 packages, and the old
   `french-logic.lua`, `latex-workshop.lua`, `sty-lua-snippets.py` and the
   blob-stamp startup check gone. Section 4 below lists what stage 2
   settled for it. This chat, probably after a planning round.
2. **Stage 4, measure, then tune.** Closes when the numbers are in
   `PLAN.md` section 3 on both machines and the sink constant is set.
3. **Stage 5, records, then close.** Closes when the record trail of
   `PLAN.md` section 7 is landed with his approval and the plan is
   annotated closed.
4. **The bigfed twin.** Folded into whichever stage first opens on bigfed:
   clone `~/Desktop/texstudio` there, copy the clone's untracked root
   `CLAUDE.md` to it, `git pull --ff-only`, record both HEADs, check that
   bigfed's `~/Desktop/CLAUDE.md` carries the `texstudio/` line. The
   committed `pkg/` and `sty/` files never need the clone; `--all --check`
   and cwl regeneration do; `--sty` never does.

Anything not needed for these goes to `TODO.md` as its own item at stage 5
(`PLAN.md` section 6), never into this queue.

## 1. What stage 2 landed (all uncommitted when this was written)

- `nvim/lua/snippets/snipgen.py`: `--sty FILE...` (one argument, the hub;
  every required package whose `.sty` sits beside it follows, recursively)
  and `--coverage [--vimtex FILE]`, the `.sty` rules in the docstring and
  in `PLAN.md` section 2; the emitter refactored into `cwl_header` plus a
  `render` that takes the header and the fields, byte-identical on all
  4,419 cwl files (`--all --check` 0/0/0). `sty-lua-snippets.py` is
  untouched and still run by the startup check.
- `nvim/lua/snippets/sty/`: 15 generated files, 544 rows over 540 names,
  the old 537 plus `\Yright`, `\shortminus`, `\strictif`; no `~`; each
  file's header carries its source path, its `\ProvidesPackage`
  description and its own `sty-sha256`. Never hand-edit; `snipgen.py --sty
  latex/french-logic/french-logic.sty --check` from the `configs` root is
  the drift test, no clone needed. `nvim/.styluaignore` gained the line.
- `tests/snipgen/`: `fixture/sty/` (a hub and its unit), `golden/sty/`
  (hand-written, met on the first run), the `sty` and `styhub` profiles in
  `verify.lua`, checks 8 to 15 in `run.sh`, `--update` covering the new
  goldens, the README's mutation record. 22 checks. `tests/stylua.toml`, a
  copy of `nvim/stylua.toml`, was added at the close so that an in-editor
  save of a test file no longer reflows it to stylua's defaults;
  `verify.lua` was reformatted once under it (the suite README says how
  stylua 2.x finds the file).
- `PLAN.md`: section 1 (stage-2 smalls), 2 (the `sty/` row, the `.sty`
  rules, the loader reading both directories), 3 (stage 2 landed), 5, 6
  (`\poscite`, the 77 keyvals-only files), 8 (open items), 10. This brief;
  the annotation on its predecessor; the memory note.
- Nothing in any configuration file changed but the stylua ignore line
  and, with his approval at the close, three passages of `nvim/CLAUDE.md`:
  the interim paragraph now covers `sty/`, the Formatter sentence names it
  among the excluded paths, and the `tests/snipgen` bullet says 22 checks.
  `lua/plugins/snippets.lua` still lazy-loads the whole of `lua/snippets`,
  so `sty/` is registered as a filetype named `sty`, never triggered, like
  `pkg/`. The live menu is exactly what it was.

## 2. The state of the trees you inherit

- `git status` in `configs`, at the close of this chat, showed everything
  build chat 1 left plus this chat's paths (section 1); in `org`, the two
  memory files. He may have committed all of it by the time you read this.
  Never sweep, revert or "clean up" what you did not make; when you report
  the tree, say which changes are yours.
- The clone `~/Desktop/texstudio` was at `0362907c2` (2026-09-12), already
  up to date on 2026-09-13.
- Plugin commits unchanged since the spikes: blink.cmp `78336bc`, LuaSnip
  `0abc8f3`, vimtex `45a5a56`, live and in the lockfile.
- stylua `--check` from the repo root flags two files that predate this
  chat and are not the campaign's: `nvim/lua/plugins/colorscheme.lua`
  (untouched in the tree) and `tests/nvim-latency/stallwatch.lua`. Leave
  both to him.

## 3. Verify before you build

In this order, and record the results in your successor:

1. `tests/nvim-syntax/run.sh` (56), `tests/nvim-latency/run.sh` (42),
   `tests/snipgen/run.sh` (22). Any red: stop and tell him.
2. `git -C ~/Desktop/texstudio pull --ff-only`; record the HEAD. If it
   moved, `python3 nvim/lua/snippets/snipgen.py --all --check` from the
   `configs` root reports the drift; regenerate with `--all` and rerun the
   snipgen suite; if it did not move, `--all --check` must report 0 stale,
   0 missing, 0 extra.
3. `python3 nvim/lua/snippets/snipgen.py --sty latex/french-logic/french-logic.sty --check`
   must report 15 files, 0 stale, 0 missing, 0 extra, and the old
   generator's `--check` (the 15 `-i` inputs of the previous brief's
   section 3, step 3) "up to date". If he edited the package, both drift:
   regenerate both (the old file through nvim's startup check or by hand)
   and say so.
4. The three plugin commits against section 2; if one moved, the affected
   spikes of `comparison-2026-09-12.md` section 6 are re-run before
   trusting the plan.
5. Read `PLAN.md` section 8 and add anything your reading turns up.

## 4. Stage 3: what stage 2 settled for it, and where to start

Read, in this order: `PLAN.md` section 2 (the loader behaviour and the gates
and providers paragraphs), section 1 (every decision that names blink,
LuaSnip or VimTeX), section 8 (the open items), section 9 (the spikes) and
`spikes/README.md`; then `lua/plugins/snippets.lua`, `completions.lua`, the
latency suite's `README.md` and `harness.py`. Stage 2 fixed these for the
loader and the startup check:

- Two directories: `pkg/<name>.lua` then `sty/<name>.lua`, same shape; a
  missing file is skipped silently and named by `:SnippetsReport`
  (fontenc, lmodern, three of the five tikz libraries).
- The startup check compares fifteen `-- sty-sha256:` stamps in `sty/`
  against the fifteen files' own sha256 (the hub and every unit its
  `\RequirePackage{french-logic-…}` lines name, as the old loop reads them),
  regenerates with `snipgen.py --sty latex/french-logic/french-logic.sty`
  on any mismatch, and runs `--coverage` with the same argument; no blob,
  no clone, no order to agree on. Then `french-logic.lua`,
  `sty-lua-snippets.py`, the blob stamp and `latex-workshop.lua` retire (the
  32 bib entry templates move to `hand/bibtex.lua` first).
- The four `sty/` rows that coincide with the core three are dropped by
  the request-time transform; put the core three before the document's
  packages in the filetype order so the core row's math wrap wins.
- `lists` is per file; the `\begin{` transform unions it over the loaded
  files (the lists unit carries french-logic's ten).
- `helpers.lua`'s `mathwrap` is needed by three `sty/` rows now, not only
  by cwl rows.

Then plan the stage in a batched round with stakes, as section 1 of
`next-chat.md` says, before touching `completions.lua`.

Clean stopping points if the chat runs long: after the planning round is
recorded in `PLAN.md`; after the loader and startup check land with both
suites green and before the gates change; say which one you reached.

## 5. Pitfalls met in build chat 2, so you do not

- A hand-written golden was right and a shape check was wrong: the third
  insert node of a template with two mandatory groups is the sixth node.
  Count the nodes in the golden before asserting an index.
- A generator's stdout summary line leaks into the suite's output unless
  every run in `run.sh` sends stdout to `/dev/null`, except where the
  output is asserted.
- TeXstudio's own `.sty` parser (`src/latexstyleparser.cpp`) reads an empty
  optional default as no optional argument, misses a `\RequirePackage[`
  whose bracket closes on the next line, and marks every row `#S`; it is a
  reference for the includes, not the specification for the rows.
- `python3 -W error` around a one-line `ast.parse` raises a
  `ResourceWarning` about the one-liner's own unclosed file; not the
  generator.
- `stow-all-dry` is a function in `bash/.bashrc.d/60-stow.sh`; source it in
  a subshell. With nothing to do it prints only stow's simulation warnings.
- The `.sty` mode names sources relative to the configs root derived from
  the script's own location (`parents[3]`); moving the script breaks both
  the header path and the sourceless-file rule.
- `git status` in `configs` lists `nvim/lua/snippets/pkg/` and `sty/` as
  two untracked directories, one line each; `--short` hides nothing.

## 6. At the close of your chat

As `next-chat.md` section 7: land what is approved and green, record what
is not, update `PLAN.md` (stage status, section 8, the log), run the three
suites, review `git status` in `configs` and `org` and say which changes
are yours, update the memory note `latex-completion-redesign-2026-09` in
one or two lines, leave every tree uncommitted, and write your successor
beside this file, dated, with the queue as a numbered list, without
rewriting this one.
