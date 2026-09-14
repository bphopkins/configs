# CLAUDE.md — nvim package

Charter for the `nvim` stow package (LazyVim-based), stowed to
`~/.config/nvim`. Entry point `init.lua` bootstraps lazy.nvim via
`lua/config/lazy.lua`. `README.md` here is the directory's viewport document —
a plugin tour in Brandon's voice; not a charter. The engineering records behind
the rules below: `docs/insert-latency-2026-08.md`,
`docs/nvim-audit-2026-08-22.md`, `docs/latex-completion-campaign-2026-09/` (the
completion layer) and `DECISIONS.md` (items 2, 9, the Done ledger, the
2026-09-12 and 2026-09-13 sections).

## Layout

- `lua/config/` — core settings (options, keymaps, autocmds, markdown_tasks,
  pandoc)
- `lua/plugins/` — plugin specs; `lua/plugins/inactive/` — disabled, kept
  deliberately (parked experiments)
- `lua/snippets/` — the generated libraries (`pkg/`, `sty/`), the `snipgen.py`
  generator, `loader.lua`, `helpers.lua`, and `hand/` (the two hand-kept files)
- `after/ftplugin/` — filetype overrides (tex.lua: custom highlight colours)
- `after/syntax/` — syntax layered on VimTeX (tex.lua: env-name families)

## LaTeX toolchain

VimTeX with latexmk and Okular (forward/inverse sync via neovim-remote). The
`/tmp/nvimsocket` serverstart in `vimtex.lua` is `pcall`-wrapped — a second
Neovim instance would otherwise abort the entire `init()`, silently dropping
every vimtex setting (this actually happened). The socket path is shared with
`bin/okular-inverse` — change one, change the other. Treesitter highlighting
is disabled for LaTeX: VimTeX's syntax engine is the sole highlighter, under
two locks — no latex parser is installed, and `treesitter-tex.lua` disables
the highlighter should one arrive (its header says what else would change).
A treesitter port of the colour layer was measured and **declined
2026-09-12**: the pinned grammar rejects `\item[(\Kax)]` labels, 313 of them
in the dissertation (DECISIONS.md). The latency suite pins the invariant.

Custom syntax in `vimtex.lua`: 218 literal command names + 32 regex patterns
registered into the register-taxonomy groups, coloured in
`after/ftplugin/tex.lua`; `after/syntax/tex.lua` colours environment *names*
by family. The scheme's semantics — the tower, the channel contract, the
species table, the geometric law, the closure rule — are the living contract
`docs/latex-register-taxonomy.md`. Redesigned 2026-08-28, adopted and held:
he rates it an improvement and a crude approximation of a scheme he cannot
yet articulate; change it only from instances he brings, exhibited on the
bench (the doc's Status section) before touching the config. 504 of the
`.sty`'s 512 commands are covered; the 8 exclusions are deliberate and listed
in the `vimtex.lua` header comment.

Five VimTeX/Vim API traps, each of which had silently bitten this config:

- Every `vimtex_syntax_custom_cmds` entry **requires `name`** (it derives the
  syntax-group names); `cmdre` only overrides the match pattern. A nameless
  `cmdre` entry is **silently dropped**.
- `cmdre` patterns are embedded into a very-magic match with **no implicit
  trailing `>`** — add one whenever a pattern must not prefix-match longer
  command names (see the de-family entry vs `\defby`).
- `argstyle` accepts only `bold`/`ital`/... keywords, never highlight groups.
  Argument colouring goes through the `arglink()` helper, whose recorded
  links `after/ftplugin/tex.lua` applies after the colorscheme (so they
  survive its `:hi clear`).
- Vim highlight-group names are **case-insensitive**: two registration slugs
  differing only by case merge into one group and the first `hi def link`
  wins — the cm/cc frame-condition families rendered as Axiom gold for
  months (found 2026-08-28; pinned by the `\cmr` suite check).
- VimTeX's default argument machinery emits a zero-width match after every
  command that **blocks a custom command directly after another**
  (`\M\nmodels` lost its colour on the second token). Symbol entries must
  declare `opt = false, arg = false`; only arg-taking entries keep the
  machinery (pinned by the adjacency checks).

Testing note: custom cmds are applied by VimTeX's `init_custom()`, which runs
only once at least one package's syntax loads — headless tests need a
`\usepackage{amsmath}`.

## Completion (TeX filetypes)

Rebuilt on TeXstudio's model 2026-09-13 (the campaign in
`docs/latex-completion-campaign-2026-09/`: `PLAN.md` section 2 is the contract
as built, `DECISIONS.md`'s 2026-09-13 section the verdicts). blink.cmp draws
the menu; in TeX buffers it runs three sources (`completions.lua`) and nothing
else: `snippets` (LuaSnip, the generated libraries of the Snippets section),
blink's built-in `omni` provider over VimTeX's omnifunc (citation keys, labels,
environment names, packages, files) and `path`. No LSP: texlab's command items
are bare names, so it cannot serve a snippet-first design, and label and
citation navigation is all it would add (declined 2026-09-12). bib/bibtex
buffers get snippets (the entry templates in `hand/bibtex.lua`) and path.

**The two gates** decide which source may fire, each in a 300-character
look-behind (⚠ 60 was a real bug: completion died mid-`\cite{` once a key list
ran long):

- `snippets` while a `\command` name is typed (a lone backslash too) and
  nowhere else, so the menu never fires over running prose;
- `omni` inside the braces that follow a command, unless a new command name is
  being typed there (`\textbf{\al` is a snippets context), and nowhere else.
  VimTeX's own completer patterns decide which braces yield rows; its *command*
  completer never fires (its rows are bare names; the 2026-09-12 drop stands,
  and `<C-x><C-o>` still reaches the omnifunc). cmp-vimtex and blink.compat
  stay parked as `enabled = false` fragments.

Non-TeX filetypes are untouched by both. blink opens the menu on keyword
characters, not on `{`, so a row inside `\cite{` appears once a letter is
typed.

**`\begin{`** writes TeXstudio's environment template: the omni transform
rewrites every environment row into `\begin{name}`, an indented body line
(`\item` for a list environment) and `\end{name}`, extended over the
auto-paired `}` so no stray brace survives (the 2026-09-12 breakage wrote
`\begin{\begin{align*}`), and appends the environment names the buffer's
snippet files define that VimTeX did not return – VimTeX knows an environment
only from its own data, the project's `\newenvironment` lines and the packages
a *fresh* `.fls` names, so without the union no french-logic environment
appeared until a compile. Pinned exact. ⚠ Both transforms must stay idempotent
(blink re-applies a provider's transform when it resolves an item), and a row a
transform appends must carry the fields blink stamps on a provider's own rows
(`source_id`, `source_name`, `cursor_column`, `score_offset`, `kind`), or
accepting it errors inside blink.

**The snippets transform** sinks TeXstudio's "unusual" rows (`∗` at the end of
the description) by a constant of 5 subtracted from the provider's offset of 10
– never an absolute offset, which replaces the provider's – and drops a
repeated (label, description) pair, keeping the first, which is how a hand row
shadows a generated one and a core row its package twin (the loader's order,
Snippets). Both are table lookups memoised per snippet id: blink shallow-copies
every cached row per request and runs the transform over the full result. The
description column is 45 cells (`label_description.width.max`; blink's 30 cut a
tenth of the chapter's rows, 45 cuts 2.3%; decided with the menu in front of
him). The sink is a static tie-break: blink's frecency never sees an accepted
LuaSnip row (`fuzzy.access` is never called for one), so usage cannot lift a
row (TODO 18).

**`snippets.active` is answered from LuaSnip's session** (stage 4, 2026-09-13).
blink's luasnip preset ran `ls.expandable()`, a match of every registered
trigger against the line, on every `InsertCharPre` and `TextChangedI` and
discarded the answer: 3.5 ms per prose keystroke with the closure's ~7,800
rows, and it was what first loaded the closure, on the first insert-mode
keystroke of a session. The override keeps the scan for `<Tab>`/`<S-Tab>` only,
where a fully typed trigger with the menu closed still expands. ⚠ A blink
update that adds another no-filter caller brings the cost back; the latency
suite's `ft_func` pin (prose keystrokes never reach the loader) is what says
so.

Two rules from the latency work still bind. VimTeX's matchparen is switched off
during insert (via its own `vimtex#matchparen#{disable,enable}`), ⚠ guarded on
`g:vimtex_matchparen_enabled` – calling `disable()` with the feature off raises
`E216` on every `InsertEnter`; guard and `pcall` backstop are pinned. And
`<Tab>` inside a snippet is named explicitly in `completions.lua` as blink's
own `snippet_forward` (2026-09-12): LazyVim's blink spec adds a `<Tab>` entry
of its own whenever the user's keymap has none, and that entry jumps native
`vim.snippet` sessions only, so under the luasnip preset `<Tab>` in an expanded
snippet inserted whitespace instead of jumping. The line duplicates blink's
preset entry on purpose – it is what keeps LazyVim's hook out; four
latency-suite checks pin the jumps, from insert and from select mode.

**Cost, settled 2026-09-13 – don't re-derive.** Against the pre-campaign tree
under one machine state (fedxps, performance mode): 53 ms per keystroke before
and 54 after inside a command name at the end of the fixture's longest line,
prose 19 and 19; the backslash that opens a command is a request in both trees
and costs about 30 ms more once (21 ms before, 50 after), the per-request copy
of ~7,800 rows. Cutting that means a completion source of our own rather than
LuaSnip's; declined. The numbers: `PLAN.md` section 3. Open, in `TODO.md`:
key-value completion inside `[…]` (16), the marker's position and corpus
ranking (18).

## The cold-cache stall (standing rule)

VimTeX resolves `\usepackage`s by spawning `kpsewhich` per package (about 190
ms each on fedxps in power-saver mode), cached on disk per machine under
`~/.cache/vimtex`, and pays the whole scan synchronously the first time a
completer needs it. Since the campaign that is the **first `\begin{` of a
session** (and `<C-x><C-o>`), never typing a command name: on a cold cache 13 s
measured on a chapter with 111 packages, 356 ms on the small latency fixture,
tens of ms once primed. Remedy: `bin/vimtex-warm`, which primes the kpsewhich
cache and `pkgcomplete.json`; both machines are warm. Re-warm only after
`:VimtexClearCache`, deleting an old TeX tree, or a genuinely new package set;
a TeX Live release upgrade does **not** invalidate the cache (the risk there is
staleness, not slowness). `\usepackage{` is a different cost that nothing
primes: about 0.9 s once per session whatever the cache, because VimTeX lists
`kpsewhich --all ls-R` per session and stores nothing; accepted. The snippet
closure is not this stall: it loads in idle time after VimTeX's init
(Snippets). Full mechanism: `docs/insert-latency-2026-08.md`; the measurements:
`docs/latex-completion-campaign-2026-09/PLAN.md` section 3.

## Keystroke cost (settled 2026-09-12)

There is no latency problem on either machine: 4 ms per keystroke on bigfed
and 7–8 ms on fedxps at the end of the longest dissertation line, in
balanced or performance mode. The August residual of 54 ms was fedxps's
power-saver mode (clocks pinned at 900 MHz), which still costs 17–21 ms;
write in balanced on battery. Don't propose engine work for speed: the
custom layer is ~60% of syntax time and merging its rules into families
measured no gain, VimTeX's Unicode classes are off (they coloured nothing),
and the three recorded exits stay declined. Record: DECISIONS.md and the
addendum to `docs/insert-latency-2026-08.md`.

## Snippets

The libraries are generated, one file per package, and loaded per document
(rebuilt on TeXstudio's model 2026-09-13; the rules as built are
`docs/latex-completion-campaign-2026-09/PLAN.md` section 2, the suite
`tests/snipgen`). Under `lua/snippets/`:

- `pkg/` – 4,419 files from TeXstudio's completion word lists (`snipgen.py
  --all` over the read-only clone `~/Desktop/texstudio`, at `0362907c2`).
  Derived GPL-3 data, committed to this public repo by his decision: each
  file's header names its cwl source, its sha256, the clone's commit and the
  list's own credits, and `pkg/NOTICE` with `pkg/COPYING` carries the
  attribution and the licence. 38 MB on disk; the sync's vet prompts only above
  25 MB per file.
- `sty/` – 15 files from the french-logic package (`snipgen.py --sty
  latex/french-logic/french-logic.sty`: the hub and its 14 units, 540 names).
  His own data, so a sibling of `pkg/` and outside the notice. The hub file's
  `includes` name the units and each unit's its own requires, so a document
  that loads french-logic reaches every unit and every package they require
  even with no fresh `.fls`.
- `hand/bibtex.lua` (the 32 bib entry templates) and `hand/local.lua` (yours,
  empty) – the two hand-kept files.
- `helpers.lua` (math wrap, environment restriction, the parser for a
  document's own definitions), `loader.lua` (below) and `snipgen.py`.

A row is trigger `\name` (no `~`), one placeholder per bracket group, named by
its content, and the shape in the description column; one row per distinct
signature, so an optional argument gives a bare row and a bracket row; a
math-only row expands wrapped in `$…$` in prose and bare inside math; an
environment-restricted row is hidden outside its environment; a `\begin{env}`
row is a template (body line, `\item` for a list environment, `\end`);
TeXstudio's "unusual" rows carry `∗` and a small sink (Completion).

**The loader** (`loader.lua`) is LuaSnip's filetype function. For a TeX buffer
it reads VimTeX's package table and document class on every request (0.09 ms),
adds the always-loaded core three (tex, latex-document, latex-dev), closes over
the files' `includes` headers, registers a file once per session under
`pkg-<name>`, and returns the pseudo-filetypes in the order that decides which
of two identical rows wins: `tex`, `hand-local`, the document's own definitions
(`doc-<id>`; the whole main file, re-read whenever its mtime changes), the core
three, the class, the closure. Since stage 4 the closure is registered in idle
time after `User VimtexEventInitPost`, one file per 10 ms tick (104 files in
3.6 s on the completeness chapter), so the first request finds it in place; a
request that comes first registers what is left. The closure costs about 0.7 s
of CPU and 120 MB of heap per session per document, accepted. A name with no
file (the expl3 and keyvals-only lists the generator skips by rule, a class
without a list) is skipped silently; `:SnippetsReport` names them and prints
what the buffer holds – main file, class, packages, files and rows, the
pre-warm's state, the document's rows, the environment names for `\begin{`, the
last dedupe count – and `:SnippetsReload` re-reads every registered file. A
package table refreshed by a compile is seen at the next request.

**Never hand-edit or format a file under `pkg/` or `sty/`** (both are in
`.styluaignore`); a regeneration overwrites them. A systematic oddity is a
generator change, proved by `tests/snipgen`, then a regeneration; a package
quirk is a `.sty` change; a one-off is a row in `hand/local.lua` with the
generated row's label and description, which shadows it (pinned). `sty/` keeps
itself current: at LuaSnip load `snippets.lua` compares each file's
`sty-sha256` stamp with its `.sty` (0.9 ms) and on a mismatch re-runs `--sty`
(about 0.1 s), then `--coverage`; the write goes through the stow symlink into
the repo, so the regenerated files are committed by the next `gpushall` –
expected, and byte-identical on both machines, because `--sty` reads nothing
but `.sty` files. `pkg/` regenerates only by hand, where the clone is, from the
repo root:

```bash
git -C ~/Desktop/texstudio pull --ff-only
python3 nvim/lua/snippets/snipgen.py --all --check   # 0 stale, 0 missing, 0 extra, or the drift
python3 nvim/lua/snippets/snipgen.py --all           # regenerate, then tests/snipgen/run.sh
python3 nvim/lua/snippets/snipgen.py --sty latex/french-logic/french-logic.sty [--check|--coverage]
```

A regeneration changes what upstream changed (about 11% of files a year); read
the generator's stderr after it, the warnings are upstream data errors and few.
`--coverage` cross-references the `.sty` against `vimtex.lua`'s registrations
(the 8 deliberate exclusions allowlisted in `KNOWN_UNREGISTERED`, mirroring the
`vimtex.lua` header; `\tcite`/`\pcite` are there because citation commands are
coloured by VimTeX's own `texCmdRef` machinery in `after/syntax/tex.lua`, not
by a custom-cmd registration); the startup check runs it whenever a `.sty`
changed and raises a notification – informational, a newly added macro just
renders in the default colour until registered by hand. Open, in `TODO.md`: a
comment convention in the `.sty` for named placeholders, math marks and
`\poscite` (17), bare lists for packages with no cwl (19).

## Markdown tasks

`lua/config/markdown_tasks.lua`, keybindings in
`lua/plugins/markdown_tasks.lua`: `<localleader>mt` toggle `[ ]`/`[x]`, `md`
toggle `@done(ts)`, `ms` toggle `@started(ts)`, `mD` checkbox+@done synced,
`mc` insert `- [ ] `, and `<CR>` in insert mode continues checkbox lists. The
`<CR>` mapping does **not** fight blink's enter-accept — blink snapshots ours
as its fallback (verified live; rests on undocumented blink behaviour, pinned
by four latency-suite checks). Don't "fix" it.

## Session persistence

`persistence.lua` auto-loads a session on empty start when CWD is a directory
**strictly below** `~/Desktop` (the repos and their subdirs); the `~/Desktop`
root is excluded — it is where a raw nvim and the LazyVim dashboard are
wanted, not a project (2026-09-12). `<leader>qs` restores manually anywhere;
bypass autoload with `NVIM_NOSESSION=1`.

**Two cases disarm the quit-time save**, through an init()-registered
`VimLeavePre` autocmd (group `PersistenceSaveGuard`) that calls
`persistence.stop()` before the plugin's own save fires: `nvim_list_uis()`
empty (**headless** — test suites once clobbered a real session this way, and
the VimLeavePre placement is load-bearing since `nvim --headless +qa!` exits
before VimEnter fires) and CWD being the `~/Desktop` root. The root exclusion
matters because persistence writes a session per CWD on *every* quit, so a
file opened from a `~/Desktop` shell was landing in the root session's
**argument list** (`$argadd`) and returning on every bare launch — and
`:bd`/`:%bd` never clear an arglist entry, only `:argdelete`/`:%argdelete` do
(found 2026-09-12).

Buffer-tab order is **not** persisted, by choice. bufferline keeps its moved
order in `vim.g.BufferlinePositions`, and it can be made to survive a restart
(add `globals` to `sessionoptions`, then re-apply the order once bufferline has
loaded). That was built and then **dropped 2026-09-12**: the restore leaned on
bufferline's undocumented internals and on cross-plugin load order (persistence
on `VimEnter`, bufferline on `VeryLazy`), too fragile to carry, and an early
attempt to force bufferline to load first broke the tabline render. To set a
specific order instead, hand-edit the `badd` sequence in the session file with
nvim closed — the default order follows it.

## Auto-save — both events are load-bearing

`lua/config/autocmds.lua` saves on **both** `InsertLeavePre` and
`TextChanged` (augroup `bph_autosave`, so a re-source can't register a second
copy). That pair is the *minimum* yielding the invariant "whenever I am in
normal mode, the work is saved": `TextChanged` does not fire on Esc,
`InsertLeavePre` does not fire on normal-mode edits — and note it is not
insert-only: `x`, `dd`, `p`, `u` each write too. Neither event may be
"cleaned up". Measured cost ~7% of an editing loop; latexmk `-pvc` does not
multiply it (`$sleep_time` is 2 s, so writes coalesce). Declined:
`write`→`update` (no measurable change — with a save on every change the
buffer is genuinely modified whenever `TextChanged` fires) and debouncing
(breaks the invariant during the window).

**Failures are loud, once per episode (2026-08-22).** The write runs under
`pcall` with `'confirm'` dropped for the duration — LazyVim sets `'confirm'`,
under which a failing `:write` does not error but pops a **modal dialog**,
which the old `silent!` suppressed along with everything else (so a full disk
broke the invariant silently, indefinitely). First failure per buffer → one
WARN with the E-code; repeats stay quiet; a save succeeding again notes once
at INFO; readonly/nomodifiable buffers are skipped outright. `:wqa` remains
the quit-time backstop. Pinned by five latency-suite checks,
mutation-verified.

## Formatter

stylua (config `nvim/stylua.toml`: 2-space indent, 100 columns).
**Load-bearing and invisible**: LazyVim format-on-save runs the
Mason-installed binary (`~/.local/share/nvim/mason/bin/stylua` — **not on the
shell PATH**) on every in-editor Lua save, so drift appears only in files
last written outside Neovim. Manual run from the repo root:
`~/.local/share/nvim/mason/bin/stylua nvim/` (`--check` to diff). The two
generated snippet files, `lua/snippets/pkg/` and `lua/snippets/sty/` are
excluded via `nvim/.styluaignore`, honored by both the CLI walk and the
in-editor path. Headless note: format-on-save — and
everything else in LazyVim's `User VeryLazy` callback — is inert under
`--headless`; fire it manually
(`vim.api.nvim_exec_autocmds("User", {pattern="VeryLazy"})`) or "works
headless" and "works interactively" can genuinely differ.

## Live-server wrapper

`lua/plugins/live-server.lua` starts/stops live-server.nvim
(`<localleader>hh` / `<localleader>hk`) with the directory passed explicitly
at both ends plus one remembered string (`last_root`), so the stop works from
any buffer in any project; a root without `index.html` gets the *buffer's*
directory served instead (the Linux watch is non-recursive on the served
root, so serving an ops-repo root would kill live-reload below it). Bare
start/stop resolve from the current buffer and silently miss
explicitly-started instances — an upstream bug, recorded and deliberately not
filed. A page that hangs after about five loads in one tab is the
plugin's SSE stream meeting Chromium's six-connection cap, released after
about a minute; not the site (2026-09-04 addendum to item 9). Full record, measured losses of simpler shapes, and declined
alternatives: `DECISIONS.md` item 9. Suite: `tests/live-server/run.sh` — W
checks pin the wrapper contract, D the directory semantics, U the upstream
behaviours *as canaries* (a U failure after a plugin update means the ground
moved, not that something broke; read its README before "fixing" either
side). Run it after editing the wrapper or after any live-server.nvim update.

## Plugin lockfile

`lazy-lock.json` is tracked **on purpose**: it is the rollback record
(`git log nvim/lazy-lock.json` + `:Lazy restore` is the one-move return to
last-known-good) and the only convergence target. Updates stay ad hoc on
either machine; a pulled lock changes nothing until
`nvim --headless "+Lazy! restore" +qa` — the gsync hint prints exactly that.
On a lock conflict during `gpushall`'s rebase: take either side, restore, and
run the two nvim suites if VimTeX or blink moved. Untracking the lock, and
auto-running restore inside the pull, were considered and **declined**
(2026-08-22; `docs/nvim-audit-2026-08-22.md`).

## Standing verdicts (don't re-derive)

- **The LazyVim UI layer is not a latency lever** — measured by ablation,
  everything under 1 ms (`docs/nvim-audit-2026-08-22.md`). Don't re-propose
  statuscolumn/cursorline/snacks/clipboard changes as latency fixes.
- Notification bubbles are sized in `snacks.lua` (10 s / 0.55 width /
  wrapped; compact style kept after live comparison).
- The two disabled plugins (friendly-snippets, catppuccin) are
  `enabled = false` fragments; ⚠ the `name = "catppuccin"` on that fragment
  is load-bearing — without it lazy.nvim files the fragment under a new
  plugin named "nvim" and disables nothing. Reverting either is deleting its
  line.

## Regression suites

- `tests/nvim-syntax/run.sh` (~5 s, headless, read-only) — 56 checks:
  env-name families, one command per registered family, pattern anchoring,
  argument links, the case-collision and adjacency pins, and that every
  pinned group carries a defined colour (a registration/ftplugin desync
  passes name pins invisibly without that). Run after a VimTeX update or
  whenever logic highlighting looks wrong; exit 0 means the syntax layer is
  intact. `perf.sh <file.tex>` beside it prices the whole custom layer
  (read-only; bigfed 2026-08-28: 0.47 ms/line on completeness.tex; under
  ~2 ms/line is imperceptible per keystroke).
- `tests/nvim-latency/run.sh` (71 checks, ~150 s, hermetic, needs `pynvim`)
  — the 42 of 2026-08-22, the stage-3 pins of 2026-09-13 (the two gates,
  the rows, the `\begin{` template, the document's own commands) and the
  four stage-4 pins of the same day (the idle pre-warm, the 45-cell
  description column, blink's per-keystroke snippet check kept off
  LuaSnip's trigger scan, a typed trigger still expanding on `<Tab>`);
  asserts the *structure* the latency fixes rest on and the behaviour they
  must not have broken; no millisecond assertions (timings move with the
  machine). Mutation-verified, five mutations recorded 2026-09-13 in its
  README. `bench.py` beside it is the measurement tool;
  `stallwatch.lua` catches stalls in a live session. Read its README before
  changing any of it — it records which checks were once vacuous and why.
- `tests/snipgen/run.sh` (22 checks, ~1 s, hermetic; the amsmath spot checks
  run only where `~/Desktop/texstudio` exists) — the snippet generator's cwl
  and `.sty` front ends. Run after any edit to `snipgen.py`, after a clone
  pull, or after an edit to the french-logic package; its README records
  what each check pins and the two mutations.
