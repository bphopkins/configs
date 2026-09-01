# CLAUDE.md — nvim package

Charter for the `nvim` stow package (LazyVim-based), stowed to
`~/.config/nvim`. Entry point `init.lua` bootstraps lazy.nvim via
`lua/config/lazy.lua`. `README.md` here is the directory's viewport document —
a plugin tour in Brandon's voice; not a charter. The engineering records
behind the rules below: `docs/insert-latency-2026-08.md`,
`docs/nvim-audit-2026-08-22.md`, and `DECISIONS.md` (items 2, 9, Done ledger).

## Layout

- `lua/config/` — core settings (options, keymaps, autocmds, markdown_tasks,
  pandoc)
- `lua/plugins/` — plugin specs; `lua/plugins/inactive/` — disabled, kept
  deliberately (parked experiments)
- `lua/snippets/` — LuaSnip libraries plus the `sty-lua-snippets.py` generator
- `after/ftplugin/` — filetype overrides (tex.lua: custom highlight colours)
- `after/syntax/` — syntax layered on VimTeX (tex.lua: env-name families)

## LaTeX toolchain

VimTeX with latexmk and Okular (forward/inverse sync via neovim-remote). The
`/tmp/nvimsocket` serverstart in `vimtex.lua` is `pcall`-wrapped — a second
Neovim instance would otherwise abort the entire `init()`, silently dropping
every vimtex setting (this actually happened). The socket path is shared with
`bin/okular-inverse` — change one, change the other. Treesitter highlighting
is disabled for LaTeX: VimTeX's syntax engine is the sole highlighter.

Custom syntax in `vimtex.lua`: 219 literal command names + 33 regex patterns
registered into the register-taxonomy groups, coloured in
`after/ftplugin/tex.lua`; `after/syntax/tex.lua` colours environment *names*
by family. The scheme's semantics — the tower, the channel contract, the
species table, the geometric law, the closure rule — are the living contract
`docs/latex-register-taxonomy.md`. Redesigned 2026-08-28, adopted and held:
he rates it an improvement and a crude approximation of a scheme he cannot
yet articulate; change it only from instances he brings, exhibited on the
bench (the doc's Status section) before touching the config. 504 of the
`.sty`'s 509 commands are covered; the 5 exclusions are deliberate and listed
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

blink.cmp (UI) → blink.compat (adapter) → cmp-vimtex (source) → VimTeX
(scanner); TeX buffers use snippets + VimTeX completions only, no LSP
(`completions.lua`). Two rules from the latency work still bind:

- The `snippets` and `vimtex` providers are gated on `in_latex_context()` —
  part-way through a `\command`, or inside the braces that follow one — so
  the menu doesn't fire over running prose. ⚠ The gate's look-behind window
  is **300 chars**; 60 was a real bug (completion died mid-`\cite{` once a
  key list ran long).
- VimTeX's matchparen is switched off during insert (via its own
  `vimtex#matchparen#{disable,enable}`), ⚠ guarded on
  `g:vimtex_matchparen_enabled` — calling `disable()` with the feature off
  raises `E216` on every `InsertEnter`. Guard + `pcall` backstop are pinned
  by the latency suite.

bib/bibtex filetypes don't list the vimtex source (nothing to offer while
authoring entries; snippets and path remain). Confining the vimtex source to
brace contexts was considered and **declined** (2026-08-22 — the harvest is
how half-remembered commands get found; revisit only on felt annoyance; the
remedy for a repeatedly-accepted harvest item is curating it into a snippet).

## The cold-cache stall (standing rule)

VimTeX resolves `\usepackage`s by spawning `kpsewhich` per package (~190 ms
each here), cached on disk per machine — so the **first backslash of a
session** on an unwarmed machine can stall ~20 s, once. Remedy:
`bin/vimtex-warm`. Both machines are warm; re-warm only after
`:VimtexClearCache`, deleting an old TeX tree, or a genuinely new package
set. A TeX Live release upgrade does **not** invalidate the cache (the risk
there is staleness, not slowness). Full mechanism:
`docs/insert-latency-2026-08.md`.

## Snippets

`lua/snippets/french-logic.lua` (auto-generated from `french-logic.sty` by
`sty-lua-snippets.py`; commands, `\newenvironment`s incl. optional args, and
`\newtheorem`s) and `latex-workshop.lua` (BibTeX templates), loaded via
filetype extensions in `snippets.lua`. **Regeneration is automatic**: the
generator stamps the `.sty`'s sha256 into the output, `snippets.lua` compares
at LuaSnip load and re-runs the generator on mismatch — completions cannot
silently drift from the package. The write goes through the stow symlink into
the repo, so the regenerated file is committed by the next `gpushall` —
expected. The two files are opposites (TODO.md item 8): `latex-workshop.lua`
may be hand-edited freely; **a hand edit to `french-logic.lua` is silently
obliterated** by the next `.sty` change — durable fixes go in the generator
or the `.sty`.

Manual regeneration and drift checks, from the repo root:

```bash
python3 nvim/lua/snippets/sty-lua-snippets.py -i latex/french-logic/french-logic.sty \
  -o nvim/lua/snippets/french-logic.lua [--check|--coverage]
```

`--coverage` cross-references the `.sty` against `vimtex.lua`'s registrations
(the 5 deliberate exclusions allowlisted in `KNOWN_UNREGISTERED`, mirroring
the `vimtex.lua` header); the auto-regen hook runs it whenever the `.sty`
changed and raises a notification — informational, a newly added macro just
renders in the default colour until registered by hand.

## Markdown tasks

`lua/config/markdown_tasks.lua`, keybindings in
`lua/plugins/markdown_tasks.lua`: `<localleader>mt` toggle `[ ]`/`[x]`, `md`
toggle `@done(ts)`, `ms` toggle `@started(ts)`, `mD` checkbox+@done synced,
`mc` insert `- [ ] `, and `<CR>` in insert mode continues checkbox lists. The
`<CR>` mapping does **not** fight blink's enter-accept — blink snapshots ours
as its fallback (verified live; rests on undocumented blink behaviour, pinned
by four latency-suite checks). Don't "fix" it.

## Session persistence

`persistence.lua` auto-loads a session on empty start for any CWD under
`~/Desktop`; sessions are *saved* per-CWD everywhere (the gate controls only
autoload); `<leader>qs` restores manually anywhere; bypass with
`NVIM_NOSESSION=1`. **Headless runs neither autoload nor save** — the guard
is an init()-registered `VimLeavePre` autocmd calling `persistence.stop()`
when `nvim_list_uis()` is empty, and the VimLeavePre placement is
load-bearing: `nvim --headless +qa!` exits before VimEnter ever fires. Before
the guard, headless test runs actually clobbered a real session.

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
generated snippet files are excluded via `nvim/.styluaignore`, honored by
both the CLI walk and the in-editor path. Headless note: format-on-save — and
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
filed. Full record, measured losses of simpler shapes, and declined
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

- `tests/nvim-syntax/run.sh` (~5 s, headless, read-only) — 45 checks:
  env-name families, one command per registered family, pattern anchoring,
  argument links, the case-collision and adjacency pins, and that every
  pinned group carries a defined colour (a registration/ftplugin desync
  passes name pins invisibly without that). Run after a VimTeX update or
  whenever logic highlighting looks wrong; exit 0 means the syntax layer is
  intact. `perf.sh <file.tex>` beside it prices the whole custom layer
  (read-only; bigfed 2026-08-28: 0.47 ms/line on completeness.tex; under
  ~2 ms/line is imperceptible per keystroke).
- `tests/nvim-latency/run.sh` (37 checks, ~40 s, hermetic, needs `pynvim`) —
  asserts the *structure* the latency fixes rest on and the behaviour they
  must not have broken; no millisecond assertions (timings move with the
  machine). Mutation-verified. `bench.py` beside it is the measurement tool;
  `stallwatch.lua` catches stalls in a live session. Read its README before
  changing any of it — it records which checks were once vacuous and why.
