Annotation, 2026-09-13: the sixth chat, the first on bigfed, opened from this brief and closed queue item 1 (the twin unmoved at `0362907c2`, the stale bytecode removed, the three suites and both drift checks green, `:SnippetsReport` on the chapter, the stage-4 numbers annotated into `PLAN.md` section 3, the two `~/Desktop/CLAUDE.md` items and the `DECISIONS.md` annotation from approved drafts), then item 2 at the close by his call, on the snippet checks alone (the comment reworded, the cite unit re-stamped, `--coverage` and the three suites green). Item 3 stays as written, optional; no successor was written. Section 4 here still binds.

Prompt — the opening brief for the sixth chat of the LaTeX completion
campaign, meant for the first chat that opens on bigfed. Dated record,
written 2026-09-13 at the close of build chat 5, on fedxps (the letter: five
chats closed on one date). The campaign is closed; this brief carries the
bigfed half of "done" and two small items. The chat that opens from it adds
one annotation line at the head of this file and writes a successor
(`next-chat-YYYY-MM-DD.md`) only if the queue is not emptied. Its
predecessors stay as written; sections 1 (how the work is done), 6
(pitfalls) and 8 (where to look) of `next-chat.md`, section 5 of
`next-chat-2026-09-13.md`, section 5 of `next-chat-2026-09-13b.md`, section
5 of `next-chat-2026-09-13c.md` and section 5 of `next-chat-2026-09-13d.md`
still bind and are not repeated here.

# Read this whole file, then PLAN.md, before touching anything

The campaign closed on 2026-09-13 (`PLAN.md`, head annotation). The record
is `configs/DECISIONS.md`, the section "nvim/LaTeX: completion rebuilt on
TeXstudio's model — 2026-09-13"; the operative rules are `nvim/CLAUDE.md`,
sections Completion, The cold-cache stall and Snippets; the deferred work is
`TODO.md` items 16 to 21. Nothing in this brief is a design question. What
is left is the bigfed half of `PLAN.md` section 0 (criterion 1, both
machines green; the bigfed numbers under section 3's stage-4 paragraph), one
deferred comment fix, and one optional measurement. Read `next-chat.md`
sections 1, 6 and 8 as instructions: every number to him as it lands, his
documents only from an approved draft, nothing committed.

## 0. The queue, and what closes each item

1. **bigfed: the twin, the mirror, the suites, the measurements.** In the
   first chat that opens on bigfed, after `gpullall` has brought the
   campaign's commits (check `git -C ~/Desktop/configs log -1` is past
   `1bb69b1` and `nvim/lua/snippets/pkg/` holds 4,419 files):
   - The twin exists: he cloned it and copied the charter at the close of build
     chat 5 (2026-09-13, about 19:10), verified from fedxps over SSH:
     `~/Desktop/texstudio` on bigfed at `0362907c2` (2026-09-12, "New and
     updated cwls (#4652)"), the same HEAD as fedxps's clone, with the
     untracked root `CLAUDE.md` byte-identical to fedxps's (sha256 `370b23a3…`,
     10,347 bytes). That charter says the clone is twinned and every edit
     mirrored. Still to do there: `git -C ~/Desktop/texstudio pull --ff-only`
     and record the HEAD; if it moved, `--all --check` reports the drift.
   - bigfed's `~/Desktop/CLAUDE.md` is machine-local and **per-machine by
     design**: diffed over SSH at the close of build chat 5, it lists
     `LogiKEy/`, `finances/`, `lecture-recordings/` and `personal/` as its own
     local directories where fedxps's says personal administration lives on
     bigfed, and its clones paragraph says "twinned on fedxps where the clone
     exists there". Never copy the whole file. Carry over two items only, in
     that file's own phrasing: the `texstudio/` line in the read-only clones
     list (fedxps's wording, its "fedxps only" clause dropped), and the
     french-logic section's last sentence in its 2026-09-13 form, "Editing it
     desyncs the generated Neovim snippet files under
     `configs/nvim/lua/snippets/sty/`, which regenerate on the next start
     (`configs/nvim/CLAUDE.md`)." At 19:00 on 2026-09-13 bigfed's copy (8,244
     bytes, 2026-09-08) had neither.
   - The three suites and the two drift checks, as section 3 below. The
     startup check regenerates nothing unless a `.sty` differs; `--all
     --check` must report 0 stale, 0 missing, 0 extra if the clone did not
     move, and the drift if it did (regenerate with `--all`, rerun
     `tests/snipgen`, the regenerated files travel by his sync).
   - `:SnippetsReport` headless on a chapter, as section 3 below.
   - The stage-4 bench, the same probes as on fedxps: `spikes/stage4_keys.py`
     (the pre-campaign tree is `git -C ~/Desktop/configs archive 1bb69b1
     nvim latex` extracted into a scratch directory named by
     `STAGE4_BEFORE`, never inside a repo), `spikes/stage4_first.py 3 live
     wait`, `spikes/loadprobe.lua` and `spikes/coldchap.lua` headless on a
     chapter. Put every number to him as it lands; annotate them into
     `PLAN.md` section 3 under the stage-4 paragraph (the plan is closed:
     annotate, never rewrite), and into `DECISIONS.md` only as a dated
     annotation of the 2026-09-13 section, from a draft he approves.
   Closes when the three suites are green on bigfed, the numbers are in
   `PLAN.md`, and bigfed's `~/Desktop/CLAUDE.md` carries the two items.
2. **The stale comment in `latex/french-logic/french-logic-cite.sty`**
   (line 74 on 2026-09-13): "sty-lua-snippets.py picks them up and emits
   \tcite~ / \pcite~ snippets" names the retired generator and the dropped
   tildes. His call on 2026-09-13: leave it for his next french-logic
   session, because a `.sty` change re-stamps `sty/french-logic-cite.lua` at
   the next Neovim start and the working agreement wants both nets
   (`tests/french-logic/run.sh` and the private harness) before any `.sty`
   change lands. Closes with that session; the wording is
   "snipgen.py --sty picks them up and emits the \tcite and \pcite
   snippets".
3. **Optional, fedxps only.** `PLAN.md` section 9's balanced-mode before
   figures (146 and 92 ms) are unreproduced against the same tree's 53 and
   19 in performance mode; if he switches the profile,
   `spikes/stage4_keys.py` re-measures both trees like for like.

Anything else goes to `TODO.md` as its own item, never into this queue.

## 1. What build chat 5 landed (all uncommitted when this was written)

- `DECISIONS.md`: the section "nvim/LaTeX: completion rebuilt on
  TeXstudio's model — 2026-09-13", 327 lines at the end of the file: the
  verdicts of `PLAN.md` section 1 in order, the numbers of stage 4, items 8
  and 15 closed with their checklists moved verbatim, a post-mortem, the
  records line.
- `TODO.md`: items 8 and 15 removed from the open body, one line each in
  the Closed ledger in number order; items 16 to 21 opened before `##
  Notes` (key-value completion; the `.sty` comment convention; the `∗`
  position and corpus ranking; bare lists for packages with no cwl; the
  harness's hygiene; the bench sitting for the five stray colours).
- `nvim/CLAUDE.md`: the head's records sentence, and the Completion,
  cold-cache and Snippets sections rewritten whole; the pre-stage-3 record
  and every retired name are gone from it. The Keystroke-cost and
  Regression-suites sections were already current and were not touched.
- `CLAUDE.md` (configs root): a bold line after the `tests/gsync` one,
  naming `tests/snipgen/run.sh` and the generated, committed data.
- Three one-line fixes from a sweep for the retired names:
  `latex/CLAUDE.md` (the snippet files, per-file stamps),
  `nvim/docs/latex-register-taxonomy.md` (the coverage command), and
  fedxps's machine-local `~/Desktop/CLAUDE.md` (queue item 1 mirrors it).
- `PLAN.md`: the head annotation, section 3 (stage 5 landed, with the
  baseline), sections 7, 8 and 10.
- Memory (the org tree): `latex-completion-redesign-2026-09` shrunk to the
  closed state, `nvim-snippet-gradual-perfection` rewritten for item 8's
  closure, both index lines in `MEMORY.md`.
- At the close, two stale accounts of the cold-cache stall corrected for where
  it is paid now (`\begin{`, 13.3 s on 111 packages) and for the TeX Live
  claim (an upgrade does not empty the cache): the last section of
  `tests/nvim-latency/README.md`, and the header comment of `bin/vimtex-warm`
  (comment only; `bash -n` clean). The memory
  `fedxps-vimtex-cold-cache-stall`'s description line, the same way.
- This brief; the annotation on its predecessor.
- Not touched: any code (the comment above aside), any suite, `pkg/`, `sty/`,
  `nvim/README.md`, `latex/french-logic/README.md`.

## 2. The state of the trees you inherit

- `configs` HEAD was still `1bb69b1` (2026-09-13 01:05) at the close:
  nothing of the campaign was committed, and `git status` showed everything
  the five chats left. He may have committed all of it by the time you read
  this. Never sweep, revert or "clean up" what you did not make; when you
  report the tree, say which changes are yours.
- The clone `~/Desktop/texstudio` on fedxps at `0362907c2` (2026-09-12),
  unmoved on 2026-09-13 (pulled at the start of build chat 5).
- Plugin commits unchanged: blink.cmp `78336bc`, LuaSnip `0abc8f3`, vimtex
  `45a5a56`, LazyVim `99970099`, live and in the lockfile. If one has moved
  on bigfed after `:Lazy restore`, run the latency suite before trusting
  any number.
- stylua `--check nvim/` flags `nvim/lua/plugins/colorscheme.lua` (his);
  `tests/nvim-latency/stallwatch.lua` shows only when `tests/` is in the
  walk. Leave both to him.
- fedxps was in performance mode for every number. Record bigfed's
  profile with its numbers.
- bigfed was reachable at the close over `ssh bigfed` (the LAN alias;
  `bigfed-vpn` is the tailnet one); the twin clone and its charter were put
  there by him at the close (queue item 1), everything else in that item is
  still to do.
- bigfed, read over SSH at the close: `pynvim` 0.6.0 and Neovim 0.12.5
  installed, so the latency suite can run; `~/.cache/vimtex/pkgcomplete.json`
  present (529 KB, 2026-09-12), so VimTeX's cache is warm; no
  `/sys/firmware/acpi/platform_profile` (a desktop; record the numbers
  without a profile). Its `configs` was at `36e2c67`, one commit behind, so
  `gpullall` fast-forwards; the pull deletes the three retired files under
  `nvim/lua/snippets/` but leaves the gitignored `__pycache__/` there, which
  holds bytecode of the retired generator: remove it by literal path.

## 3. The baseline build chat 5 verified (fedxps, 2026-09-13)

In this order; on bigfed run the same list, and any red: stop and tell him.

1. `tests/nvim-syntax/run.sh`: ALL PASS (56 checks).
   `tests/nvim-latency/run.sh`: passed 71, failed 0 (about 150 s, needs
   `pynvim`). `tests/snipgen/run.sh`: ALL PASS (22 checks; the amsmath spot
   checks run once the clone exists).
2. `git -C ~/Desktop/texstudio pull --ff-only`: already up to date at
   `0362907c2`. `python3 nvim/lua/snippets/snipgen.py --all --check` from
   the `configs` root: 4,419 files would be generated, 0 stale, 0 missing,
   0 extra, 4.0 s, 42 warnings on stderr (upstream data errors, listed in
   `next-chat-2026-09-13.md`).
3. `python3 nvim/lua/snippets/snipgen.py --sty latex/french-logic/french-logic.sty --check`:
   15 files, 0 stale, 0 missing, 0 extra.
4. The four plugin commits as section 2, live equal to the lockfile.
5. `:SnippetsReport` headless on `completeness.tex`, one instance,
   `NVIM_NOSESSION=1`, waiting up to 20 s for `vim.b.vimtex` and then for
   `require("snippets.loader").prewarm[buf].done`: main the article wrapper,
   class article, 111 packages in VimTeX's table; loaded 104 files, 7,834
   rows; "pre-warm: done, 104 files in 3580 ms of idle ticks"; 31 names
   with no generated file; 6 document rows; 211 environment names for
   `\begin{`, 13 of them lists; dedupe 0; hand files bibtex 32 rows, local
   0; `:messages` held only the report itself.
6. After every record of stage 5 had landed, the three suites again:
   `tests/nvim-syntax` ALL PASS (56), `tests/nvim-latency` passed 71,
   failed 0, `tests/snipgen` ALL PASS (22). No code was touched by build
   chat 5, so this is the same layer measured at the baseline.

## 4. Pitfalls met in build chat 5, so you do not

- `~/Desktop/CLAUDE.md` is machine-local, unsynced, and different on each
  machine by design (the local-only directories, the clones paragraph); a
  fix there exists on one machine until carried over by hand, item by item,
  never by copying the file (queue item 1).
- `snipgen.py --sty` accepts several files (`nargs="+"`) while `PLAN.md`
  and the charter describe one argument, the hub; the startup check and the
  suite pass one, nothing depends on the difference. Recorded in `PLAN.md`
  section 8, left.
- A draft shown unwrapped in the chat and a file wrapped at the repo's 79
  columns are one text: write the draft once, wrap it at write time with
  `textwrap` (bullets with a two-space continuation; headings, fences and
  `---` untouched), then check the result for lines over 79 outside fences.
  `git diff` against `1bb69b1` shows every earlier chat's long lines as
  added too; check the file, not the diff.
- The Closed ledger of `TODO.md` is in item-number order, not date order;
  a new line goes in by number. The open items are contiguous before `##
  Notes` since this chat (item 15 had been appended after it).
- `DECISIONS.md` entries are never rewritten, so a count that a later step
  of the same chat changes (the number of briefs) is worth writing as a
  pointer rather than a number.

## 5. At the close of your chat

As `next-chat.md` section 7: land what is approved and green, record what
is not, annotate `PLAN.md` section 3 with bigfed's numbers, run the three
suites, review `git status` in `configs` and `org` and say which changes
are yours, update the memory note `latex-completion-redesign-2026-09` (drop
its pending paragraph once queue item 1 closes), leave every tree
uncommitted, and add one annotation line at the head of this file. A
successor is needed only if the queue is not emptied.
