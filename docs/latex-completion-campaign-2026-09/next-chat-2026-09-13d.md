Annotation, 2026-09-13: build chat 5 opened from this brief, landed stage 5 and closed the campaign; its successor is `next-chat-2026-09-13e.md` beside this file, whose queue is the bigfed half. Section 5 here still binds.

Prompt — the opening brief for the fifth build chat of the LaTeX completion
campaign. Dated record, written 2026-09-13 at the close of build chat 4, on
fedxps (the letter: four chats closed on one date). The next chat writes its
own successor beside this file at its close (`next-chat-YYYY-MM-DD.md`),
adds one annotation line at the head of this one, and otherwise leaves it
as it is. Its predecessors stay as written; sections 1 (how the work is
done), 6 (pitfalls) and 8 (where to look) of `next-chat.md`, section 5 of
`next-chat-2026-09-13.md`, section 5 of `next-chat-2026-09-13b.md` and
section 5 of `next-chat-2026-09-13c.md` still bind and are not repeated
here.

# Read this whole file, then PLAN.md, before touching anything

You are opening the fifth build chat of the campaign that rebuilds the
LaTeX completion layer of `configs/nvim` on TeXstudio's model. Stages 1 to 4
have landed; the menu he types into is the new layer, measured and tuned.
This chat does stage 5, records then close, and, if it is the first chat to
open on bigfed, the twin and the bigfed measurements first. The aim, the
decisions, the rules as built, the stages and the record trail are in
`PLAN.md` beside this file (section 0 says what "done" means; section 3 now
carries every stage-4 number; section 7 is what stage 5 owes). Read
`next-chat.md` sections 1, 6 and 8 as instructions.

## 0. The queue, and what closes each item

1. **Stage 5, records, then close.** Closes by `PLAN.md` section 7, each
   document edited only after he approves a draft: the `DECISIONS.md`
   section (the verdicts of section 1, the numbers of section 3); `TODO.md`
   (items 8 and 15 to the Closed ledger; new items from section 6, and from
   section 8 the `∗`-first marker and the harness's hygiene); the full
   rewrite of the charter's Completion and Snippets sections (the prose
   below the interim notes is still the pre-stage-3 record and names the
   retired files as history), the cold-cache rule, the suites list;
   `configs/CLAUDE.md` naming `tests/snipgen`; the memory note shrunk once
   `DECISIONS.md` carries the outcome, `nvim-snippet-gradual-perfection`
   superseded when item 8 closes. Then annotate `PLAN.md` closed with the
   date and the `DECISIONS.md` pointer.
2. **The bigfed twin and the bigfed measurements.** In whichever chat first
   opens on bigfed: clone `~/Desktop/texstudio` there, copy the clone's
   untracked root `CLAUDE.md` to it, `git pull --ff-only`, record both
   HEADs, check bigfed's `~/Desktop/CLAUDE.md` carries the `texstudio/`
   line; then the stage-4 bench there and the numbers into `PLAN.md`
   section 3: `spikes/stage4_keys.py` (the pre-campaign tree is `git -C
   ~/Desktop/configs archive 1bb69b1 nvim latex` extracted into a scratch
   directory named by `STAGE4_BEFORE`), `spikes/stage4_first.py 3 live
   wait`, `spikes/loadprobe.lua` and `spikes/coldchap.lua` headless on a
   chapter. Both suites run there as here; the startup check regenerates
   nothing unless a `.sty` differs.
3. **Optional, fedxps only.** Section 9's balanced-mode before figures (146
   and 92 ms) are unreproduced against the same tree's 53 and 19 in
   performance mode; if he switches the profile, `spikes/stage4_keys.py`
   re-measures both trees like for like.

Anything not needed for these goes to `TODO.md` as its own item at stage 5
(`PLAN.md` section 6), never into this queue.

## 1. What stage 4 landed (all uncommitted when this was written)

- `nvim/lua/plugins/completions.lua`: the `snippets.active` override (the
  block after `opts.snippets.preset`, answering blink from LuaSnip's session
  and keeping the expandable check for `<Tab>`/`<S-Tab>`); the description
  column at 45 cells (`opts.completion.menu.draw.components
  .label_description.width.max`); the sink unchanged at 5.
- `nvim/lua/snippets/loader.lua`: the idle pre-warm (`M.prewarm`,
  `M.prewarm_buffer`, `prewarm_step`, `roots_of`, the `User
  VimtexEventInitPost` autocmd in `setup()`, group `SnippetsPrewarm`, one
  file per 10 ms tick, deferred 100 ms after the event); `tex_state(bufnr)`,
  `document(st, lists, bufnr)` and `build` reading `vim.b[bufnr].vimtex_id`,
  so a step that runs while another buffer is current still names the right
  document; the pre-warm line of `:SnippetsReport`; `M.reload` forgetting
  the pre-warm state.
- `tests/nvim-latency/verify.py` at 71 checks (four added: the pre-warm
  registers before any keystroke with no request made; the column is 45;
  prose keystrokes never reach the loader's `ft_func`; a fully typed
  trigger with the menu closed still expands on `<Tab>`), its README with
  the two mutations of stage 4 (the override removed: exactly the `ft_func`
  pin; the autocmd removed: exactly the pre-warm pin).
- `PLAN.md`: sections 1 (the stage-4 smalls: the `active` fix as objective,
  the round's three answers and what was declined), 2 (the table rows, the
  loader paragraph, the gates paragraph), 3 (stage 4 measured and tuned,
  every number), 5 (four hazards), 7 (the charter's `snippets.active` and
  the 71), 8 (closed items, three open), 9 (build chat 4), 10. Sixteen files
  in `spikes/` with README rows (`stage4lib.py` and the fifteen probes).
- With his approval at the close, three interim passages of
  `nvim/CLAUDE.md`: the latency suite bullet (71 checks, the four stage-4
  pins, five mutations), a stage-4 sentence after the Completion head note,
  and the cold-cache sentence corrected (13 s on the chapter for `\begin{`,
  `\usepackage{` 0.9 s per session unprimed). The Completion and Snippets
  prose below the interim notes is still the pre-stage-3 record, rewritten
  at stage 5.
- This brief; the annotation on its predecessor; the memory note
  `latex-completion-redesign-2026-09` and its index line; the cold-cache
  memory's addendum corrected the same way.

## 2. The state of the trees you inherit

- `git status` in `configs`, at the close of this chat, showed everything
  the earlier chats left plus this chat's paths (section 1); in `org`, the
  campaign's memory files and changes of his own (`CLAUDE.md`,
  `licensing/`, a `licensing-has-a-home` memory) that are not the
  campaign's. He may have committed all of it by the time you read this.
  Never sweep, revert or "clean up" what you did not make; when you report
  the tree, say which changes are yours.
- The clone `~/Desktop/texstudio` at `0362907c2` (2026-09-12), unmoved on
  2026-09-13.
- Plugin commits unchanged: blink.cmp `78336bc`, LuaSnip `0abc8f3`, vimtex
  `45a5a56`, LazyVim `99970099`, live and in the lockfile.
- stylua `--check` from the repo root flags the same two files as before,
  `nvim/lua/plugins/colorscheme.lua` and `tests/nvim-latency/stallwatch.lua`;
  leave both to him.
- fedxps was in performance mode (`/sys/firmware/acpi/platform_profile`)
  for every stage-4 number.

## 3. Verify before you build

In this order, and record the results in your successor:

1. `tests/nvim-syntax/run.sh` (56), `tests/nvim-latency/run.sh` (71, about
   150 s), `tests/snipgen/run.sh` (22). Any red: stop and tell him.
2. `git -C ~/Desktop/texstudio pull --ff-only`; record the HEAD; `python3
   nvim/lua/snippets/snipgen.py --all --check` from the `configs` root
   must report 0 stale, 0 missing, 0 extra if it did not move, and the
   drift if it did (regenerate with `--all`, rerun the snipgen suite).
3. `python3 nvim/lua/snippets/snipgen.py --sty latex/french-logic/french-logic.sty --check`
   must report 15 files, 0 stale, 0 missing, 0 extra.
4. The four plugin commits against section 2; if one moved, the affected
   spikes and the latency suite are re-run before trusting the plan.
5. `:SnippetsReport` headless on `completeness.tex`, waiting for the
   pre-warm (one instance, `NVIM_NOSESSION=1`, `+'lua vim.wait(20000,
   function() return vim.b.vimtex ~= nil end, 100) vim.wait(20000,
   function() local p = require("snippets.loader").prewarm[vim.api
   .nvim_get_current_buf()] return p and p.done end, 20)
   print(vim.fn.execute("SnippetsReport"))'`) must list 104 files, "pre-warm:
   done, 104 files in about 3,600 ms of idle ticks", and no message in
   `:messages`.
6. Read `PLAN.md` section 8 and add anything your reading turns up.

## 4. Stage 5: where to start

Read `PLAN.md` sections 1, 3 and 7. Draft `DECISIONS.md` first (the biggest
document; the verdicts are section 1's bullets in order, the numbers
section 3's stage-4 paragraph), then `TODO.md`, then the charter rewrite
(the Completion and Snippets sections whole, keeping what the four interim
notes of 2026-09-13 say and dropping the pre-stage-3 prose and the retired
files), and put each to him as a draft before writing. The two READMEs
(`nvim/README.md`, `latex/french-logic/README.md`) were rewritten at the
close of build chat 3 and need nothing from stage 4.

## 5. Pitfalls met in build chat 4, so you do not

- The harness's `silent! undo` after typed text does not revert it (blink's
  auto-insert previews break the undo block); the line grew by exactly the
  typed characters in spike4 too. Save the line and restore it with
  `nvim_buf_set_lines`.
- blink copies a provider's `transform_items` into its provider object at
  creation; a runtime hook must wrap
  `require('blink.cmp.sources.lib').get_provider_by_id(id).config.transform_items`,
  not the config table.
- blink's luasnip preset ran LuaSnip's `expandable()` on every
  `InsertCharPre` and `TextChangedI`, so anything `ft_func` does ran per
  keystroke; the override in `completions.lua` ends that, and the `ft_func`
  pin notices if a blink update adds another caller.
- A LuaSnip session lingers after its text is deleted (no
  `delete_check_events` set), so a `<Tab>` test after an expansion is
  contaminated: fresh instances per condition, or `unlink_current` and
  `require('luasnip.session').current_nodes[buf] = nil` between sub-tests.
- The auto-mode classifier can time out on a Bash call, and that call does
  not run while the others in the batch do; a patch script's own "patched"
  line is the only proof a patch landed.
- A Python docstring with `\u` (`\usepackage`) is a unicode escape; every
  docstring that names a TeX command is a raw string.
- `XDG_STATE_HOME` isolates blink's frecency store and Neovim's shada and
  undo for a harness instance, `cache_root` VimTeX's cache; the default
  harness uses the live ones and writes into both.
- `vimtex-warm` primes `\begin{` across sessions; nothing primes
  `\usepackage{`.
- The fixture's package table holds one package (french-logic); its 100
  files come from the includes walk. "111 packages" is the chapter.
- blink never records an accepted LuaSnip row in its frecency store (the
  source's own `execute` bypasses the accept path), so a rank that should
  rise with use cannot; the sink experiment shows nothing by design.
- Entering insert mode costs about 100 ms the first time in a session in
  either tree, and a lone backslash is a completion request in either
  tree; neither is the campaign's, both are in section 3 and 9.

## 6. At the close of your chat

As `next-chat.md` section 7: land what is approved and green, record what
is not, update `PLAN.md` (stage status, section 8, the log), run the three
suites, review `git status` in `configs` and `org` and say which changes
are yours, update the memory note `latex-completion-redesign-2026-09` in
one or two lines, leave every tree uncommitted, and write your successor
beside this file, dated, with the queue as a numbered list, without
rewriting this one.
