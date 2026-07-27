# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A GNU Stow-based dotfiles repository for Fedora Linux, synced across multiple machines (fedxps, bigfed) via git. **This is a public GitHub repo** (`github.com/bphopkins/configs`) — anything committed is published (see Pitfalls). Configs are stored here at `~/Desktop/configs` and symlinked to their live locations. The user is an academic working in logic/philosophy — the LaTeX and Neovim configs are heavily tailored to dissertation writing.

## Stow Deployment

Each top-level directory (except `wallpapers/` and `tests/`) is a stow "package" with a specific target. The source of truth for targets is the associative array in `bash/.bashrc.d/60-stow.sh`:

| Package    | Stow Target                  |
|------------|------------------------------|
| bash       | `~`                          |
| wezterm    | `~`                          |
| alacritty  | `~/.config/alacritty`        |
| nvim       | `~/.config/nvim`             |
| sway       | `~/.config/sway`             |
| waybar     | `~/.config/waybar`           |
| latex      | `~/texmf/tex/latex`          |
| bin        | `~/bin`                      |
| okular     | `~/.config`                  |

Key commands (defined in `bash/.bashrc.d/60-stow.sh`):
- `stow-all` — `git pull --ff-only`, then restow every package (`stow -R`). On a conflict (an untracked real file already sitting at a target) it **errors out** rather than resolving it — adopt or remove the file manually (README §8 covers `stow --adopt`), then rerun.
- `stow-all-dry` — preview what stow-all would do (no changes)
- `unstow-all` — remove all managed symlinks (`stow -D`)

When adding a new stow package, update both the target map and the ordering array in `60-stow.sh`. Editing existing symlinked files requires no restow; adding new files to a package does.

`README.md` is the authoritative from-scratch walkthrough for standing this up on a new machine (import live dotfiles → seed commit → dry-run stow → link → verify → reload); its §8 covers conflict resolution (`stow --adopt`), per-package restow, and unlinking.

## Daily Sync Workflow

Start of session: `gpullall` → `source ~/.bashrc` (if bash files changed) → `stow-all` (if files added/deleted). End of session: `gpushall`.

**The re-source is not optional when a pull adds a stow package.** `60-stow.sh` is itself a bash file, so a pull that adds a package updates it on disk but not the arrays in the running shell — and `stow-all` iterates the in-memory arrays, so it skips the new package **silently**, with no error. This bit the `bin` package and applies again to `okular`. When in doubt, re-source.

## Git Sync Workflow

Defined in `bash/.bashrc.d/50-git-sync.sh`. The single-repo and all-repo commands share the same per-repo helpers (`_gsync_pull_repo` / `_gsync_push_repo`), so their behavior cannot drift apart:
- `gpullall` — pulls every repo in the `REPOS_DESKTOP` array (ff-only, prune, submodules on demand; tags on fetched history auto-follow — deliberately no `--tags`, so a force-moved remote tag can't wedge every future pull)
- `gpushall [-m MSG]` — stages (`git add -A`), vets new paths, commits, `pull --rebase=merges`, pushes every repo. Remote commits integrated by the rebase are reported (`[PULL] integrated changes from origin`) and fire the configs hints — the push path is never silently ahead of what you saw. A legacy positional message is accepted and joins all words (`gpushall fixed the thing`); unknown flags are rejected so `gpushall -f` can't commit 13 repos with the message `-f`
- `gpull <name>...` / `gpush [-m MSG] <name>...` — same flows for one or more repos under `~/Desktop`; names tab-complete from `REPOS_DESKTOP`
- `gstatall [-f]` — read-only dashboard: branch, dirty count, behind/ahead, and a STATE verdict in words that composes every applicable flag (`needs push` / `needs pull` / `DIVERGED` / `uncommitted` / an in-progress op — e.g. `uncommitted; needs pull`), so dirty work is never elided by a sync verdict. Plain runs read the last fetch; `-f` fetches first so verdicts are current vs origin while still pushing and pulling **nothing**. The safe first move whenever the machines may be out of step

Guardrails, shared by the single- and all-repo variants:
- **New-path vetting**: newly added paths — including rename targets and typechanges (the listing runs with rename detection off), matched per path component so a directory named `.env/` or `credentials/` is caught — larger than `GSYNC_MAX_MB` (default 25; a non-numeric override falls back to 25 with a warning) or matching `GSYNC_SECRET_GLOBS`, plus embedded git repositories (which would push as empty gitlinks), get a y/N prompt before being committed. Declined files are unstaged via `:(literal)` pathspecs (hostile filenames can't dodge or collateral-match the unstage) and verified gone before the commit proceeds; when stdin is not a tty they are left uncommitted with a warning, and they are flagged again next run. The vet **fails closed**: if the staged-file listing itself errors, the repo's commit is refused rather than performed unvetted.
- **Committed new files are listed** in the output (up to 12, then `+N more`), so nothing enters a repo invisibly. This matters because the repo is public and `.gitignore` is minimal.
- **In-progress rebase/merge/cherry-pick/revert/bisect is detected** and reported as such — previously an unresolved merge or revert could have conflict markers committed by `add -A` + `commit`. A brand-new repo with no commits yet is skipped (`no commits yet`), never auto-committed.
- **A rebase conflict is auto-aborted**: the repo is returned to a clean state with the local commit intact, and the summary names the repo for manual resolution. A batch command never leaves a repo mid-rebase.
- **Offline-aware**: one TCP probe of `github.com:22` (all remotes are GitHub-over-SSH); when offline, `gpushall` still commits locally and reports pushes as `[PEND]`, `gpullall` reports offline once and stops.
- **Non-main branches are synced but flagged** with a warning.
- **Unpushed work is surfaced**: after pulling, `gpullall`/`gpull` warn when a repo is still ahead of origin, so "up to date" can never be mistaken for "in sync with the other machine".
- **A diverged repo names its remedy**: when `gpullall` can't fast-forward because the repo has local unpushed commits, it says so and points at `gpush <name>` (which rebases) instead of dumping a raw git error.
- **Post-pull hints**: a `configs` pull — via `gpullall` *or* a `gpushall` rebase that integrated remote changes — that changed `bash/` files or added/removed files in a stow package prints the required follow-up (`source ~/.bashrc`, `stow-all`) — the silent-skip trap from "Daily Sync Workflow" above. The change list is parsed NUL-delimited, so non-ASCII filenames (which git C-quotes in plain output) can't silently defeat it.

Summaries name the repos that skipped/failed/are pending, and tags are colorized on a tty. The explicit pre-pull fetch was removed (the pull's own fetch serves), halving network round-trips; the only remaining explicit fetch is on the rare set-upstream path. To add a new repo, append its path to the `REPOS_DESKTOP` array. Commit messages follow `{hostname}: {YYYY-MM-DD HH:MM:SS}`; override per-run with `-m`. Note that `REPOS_DESKTOP` spans *all* the user's Desktop repos (dissertation, teaching, etc.), not just this one.

## Bash Configuration

Modular design: `.bashrc` sources all `~/.bashrc.d/*.sh` files. The numbered prefix controls load order:
- `00-shell-opts.sh` — shopt/set options. **Deliberately empty**, reserved so there's an obvious home for such options when one is wanted; ditto `30-prompt.sh`. Much of the bash tree is scaffolding like this — an empty numbered module is not dead code to be removed.
- `10-env.sh` — environment variables (`EDITOR`/`VISUAL` = nvim)
- `20-path.sh` — PATH/MANPATH/INFOPATH additions (guards against duplicates via substring matching); prepends `~/bin`, `~/.local/bin`, `~/.local/npm-global/bin`, and `~/.bun/bin` if bun is installed (it currently isn't on either machine, so that block is guarded on the directory existing rather than prepending a nonexistent path). Each entry prepends, so the **effective priority is the reverse of the reading order** — TeX Live ends up first, `~/bin` last of the personal dirs. **TeX Live is auto-detected, not hardcoded**: it picks the newest `/usr/local/texlive/YYYY` that actually contains a working `tlmgr` (half-installed trees are skipped, so a parallel install in progress can't knock TeX Live out of PATH). Override with `TEXLIVE_YEAR=<year>` to pin an older release — see "TeX Live release upgrades" below
- `30-prompt.sh` — prompt config. Empty by design; inherits the system default from `/etc/bashrc`. See `00-shell-opts.sh` above.
- `40-aliases.sh` — aliases: `sysupgrade` (dnf + flatpak update), `tl-upgrade` (TeX Live `tlmgr` self+all update; resolves `tlmgr` through PATH so it survives year bumps — note this only updates *within* a release, see "TeX Live release upgrades" below), `reload` (typo-proof `source ~/.bashrc` — guards against tab-completing into `~/.bash_history`, which would replay every command in it), `cc` (`claude --model opus --effort max`), plus `cd`+`ls` navigation/edit shortcuts (`configs`, `dissertate`, `teach`, `logic`, …)
- `50-git-sync.sh` — git sync functions (`gpullall`, `gpushall`, `gpull`, `gpush`, `gstatall`) plus the `_gsync_*` per-repo helpers, new-file vet guards (`GSYNC_MAX_MB`, `GSYNC_SECRET_GLOBS`), and repo-name tab completion — see "Git Sync Workflow" above
- `60-stow.sh` — stow functions (`stow-all`, `unstow-all`)
- `70-task-list.sh` — `ls-tasks [PATH]`: recursively lists unchecked `- [ ]` items from markdown files
- `80-clamav.sh` — `clam {update,home,full}`: ClamAV signature refresh and scan helpers (logs to `~/clam-scan-{home,full}-<ts>.log`). Requires `clamav` + `clamav-update`.
- `90-nix.sh` — nix profile loader (conditional; only if nix is installed). Nix is **not** installed on either machine right now; the loader is kept ready for Carnap development, which builds via nix. It's a no-op until then — leave it in place.

Also in the `bash` package, stowed to `~/.bashrc.min` and `~/.bash_profile.min`: minimal known-good rescue configs, for recovering from an edit that breaks login. Not sourced by anything; see README §8.

## Neovim Configuration

LazyVim-based setup. Entry point: `nvim/init.lua` bootstraps lazy.nvim via `lua/config/lazy.lua`.

### Directory layout
- `lua/config/` — core settings (options, keymaps, autocmds, markdown_tasks, pandoc)
- `lua/plugins/` — plugin specs (each file returns a lazy.nvim plugin spec table)
- `lua/plugins/inactive/` — disabled plugins (not loaded by lazy.nvim)
- `lua/snippets/` — LuaSnip snippet libraries (plus the `sty-lua-snippets.py` generator)
- `after/ftplugin/` — filetype overrides (tex.lua is ~200 lines of custom highlight-group colours)
- `after/syntax/` — syntax additions layered on VimTeX (tex.lua: per-family environment-name matches)

### LaTeX toolchain
VimTeX with latexmk compiler and Okular PDF viewer (forward/reverse sync via neovim-remote). The `/tmp/nvimsocket` serverstart in `vimtex.lua` is wrapped in `pcall` — a second Neovim instance would otherwise throw ("address already in use") and abort the entire `init()`, silently dropping every vimtex setting in that instance (this actually happened; found 2026-07-26). Treesitter highlighting is disabled for LaTeX — VimTeX's syntax engine is the sole highlighter.

Custom syntax in `lua/plugins/vimtex.lua` registers 219 literal command names plus 31 regex patterns across 7 semantic highlight groups (axioms, frame conditions, logic systems, semantic notation, modal operators, proof rules, set notation), coloured in `after/ftplugin/tex.lua`; `after/syntax/tex.lua` additionally colours environment *names* by family (theorem-family orange, proof/derivation magenta, list/layout envs keep the default cyan). Measured 2026-07-26 after the coverage overhaul: 504 of the `.sty`'s 509 commands are covered; the 5 exclusions (`\versal`, `\sketchqed`, `\remarkqed`, `\inf`, `\infer`) are deliberate and listed in the `vimtex.lua` header comment.

Three VimTeX API traps, each of which had silently bitten this config:

- Every `vimtex_syntax_custom_cmds` entry **requires `name`** (it derives the syntax-group names); `cmdre` only overrides the match pattern. A nameless `cmdre` entry is **silently dropped** — until 2026-07-26 every pattern registration was dead for exactly this reason.
- `cmdre` patterns are embedded into a very-magic match with **no implicit trailing `>`** — add one whenever a pattern must not prefix-match longer command names (see the de-family entry vs `\defby`).
- `argstyle` accepts only `bold`/`ital`/... keywords, never highlight groups. Argument colouring by group goes through the `arglink()` helper instead, which records the generated arg-group → colour-group links in `vim.g.french_logic_arg_links`; `after/ftplugin/tex.lua` applies them (after the colorscheme, so they survive its `:hi clear`).

Note for testing: custom cmds are applied by VimTeX's `init_custom()`, which runs only once at least one package's syntax loads — a buffer whose project has no recognised packages shows none of the custom colours (headless tests need a `\usepackage{amsmath}`).

**Regression suite:** `tests/nvim-syntax/run.sh` (~5 s, headless, read-only) verifies all of the above — the env-name families, one representative command per registered family, the de-family/`\defby` anchoring, and the argument links. Run it after a VimTeX plugin update or whenever logic highlighting looks wrong; exit 0 means the syntax layer is intact.

### Completion stack (for TeX filetypes)
blink.cmp (UI) → blink.compat (adapter) → cmp-vimtex (source) → VimTeX (scanner). TeX filetypes only use snippets + VimTeX completions (no LSP). Configured in `lua/plugins/completions.lua`.

### Snippets
`lua/snippets/french-logic.lua` (auto-generated from `french-logic.sty` by `sty-lua-snippets.py`; covers commands, `\newenvironment`s incl. optional arguments, and `\newtheorem` environments) and `latex-workshop.lua` (BibTeX templates). Loaded via filetype extensions in `lua/plugins/snippets.lua`.

**Regeneration is automatic**: the generator stamps the `.sty`'s sha256 into the output header (`-- sty-sha256:`), and `snippets.lua` compares stamps when LuaSnip loads — on mismatch it re-runs the generator (with a notification) before snippets load, so completions cannot silently drift from the package. The write goes through the stow symlink into the repo, so the regenerated file is then committed by the next `gpushall` — expected. Manual regeneration still works, and `--check` diffs without writing (exit 1 on drift):

```bash
cd ~/Desktop/configs
python3 nvim/lua/snippets/sty-lua-snippets.py -i latex/french-logic/french-logic.sty -o nvim/lua/snippets/french-logic.lua [--check]
```

The generator also has `--coverage`: it cross-references the `.sty` against `vimtex.lua`'s highlight registrations and lists any command with no registration (exit 1; the 5 deliberate exclusions are allowlisted in `KNOWN_UNREGISTERED`, which mirrors the `vimtex.lua` header). The auto-regen hook runs it whenever the `.sty` has changed and raises a notification, so a newly added macro that lacks highlighting is flagged the next time Neovim starts — purely informational, the macro just renders in the default command colour until registered.

### Markdown tasks
Custom task system in `lua/config/markdown_tasks.lua` with keybindings in `lua/plugins/markdown_tasks.lua`:
- `<localleader>mt` — toggle `[ ]`/`[x]`
- `<localleader>md` — toggle `@done(timestamp)`
- `<localleader>ms` — toggle `@started(timestamp)`
- `<localleader>mD` — toggle checkbox + @done synced
- `<localleader>mc` — insert `- [ ] ` at the cursor
- `<CR>` in insert mode — smart newline (continues checkbox lists)

### Session persistence
`lua/plugins/persistence.lua` auto-loads a session on empty start (`nvim` with no args) for any CWD under `~/Desktop` (a six-repo allowlist until 2026-07-26). Sessions are *saved* per-CWD everywhere regardless — the gate controls only autoload — and `<leader>qs` restores manually anywhere. Bypass autoload with `NVIM_NOSESSION=1`.

**Headless runs neither autoload nor save.** Before 2026-07-26, *any* headless nvim run (test suite, agent probe, script) silently overwrote the session of whatever directory it ran in on exit — this actually clobbered a real session. The guard is an init()-registered `VimLeavePre` autocmd that calls `persistence.stop()` when `nvim_list_uis()` is empty; it must live on VimLeavePre and be registered *before* the plugin loads, because `nvim --headless +qa!` exits before VimEnter ever fires, so a VimEnter-only guard misses the most common scripted invocation. Verified against both headless exit patterns and, via a pynvim `ui_attach` instance, that UI-attached (interactive) saving is unaffected.

### Formatter
stylua (config in `nvim/stylua.toml`: 2-space indent, 100 columns). **It is load-bearing and invisible**: LazyVim's format-on-save runs it (through conform.nvim) on every in-editor save of a Lua file — which the auto-save autocmd makes near-continuous — using the Mason-installed binary (`~/.local/share/nvim/mason/bin/stylua`; **not on the shell PATH**). Hand-written Lua therefore stays formatted automatically; drift appears only in files last written outside Neovim (e.g. by tools/agents). Manual run from repo root: `~/.local/share/nvim/mason/bin/stylua nvim/` (`--check` to diff without writing). The two auto-generated snippet files are excluded via `nvim/.styluaignore`, honored by both the CLI walk and the in-editor path (conform passes `--respect-ignores`), so the generator's output is never reflowed.

Note for headless testing: format-on-save — and everything else LazyVim registers in its `User VeryLazy` callback — is inert under `nvim --headless`, because VeryLazy hangs off the UI attaching. A headless probe that needs those behaviors must fire it manually (`vim.api.nvim_exec_autocmds("User", {pattern="VeryLazy"})`); otherwise "works headless" and "works interactively" can genuinely differ.

## LaTeX Packages

Custom `.sty` and `.cls` files in `latex/` are stowed into `~/texmf/tex/latex`. Key package:

- **french-logic** — 509 commands and 25 environments (counted 2026-07-26; 14 `\newenvironment` + 11 `\newtheorem`) for modal/deontic logic (semantic notation, modal operators, axiom schemas, logic system labels). Single `\usepackage{french-logic}` replaces a 100+ line preamble. Has a `deon` option for DEON conference submissions. **Shared dependency:** sibling repos (`dissertation/`, `dissertation-template/`, `teaching/`, `teach-logic/`) load it from the stowed copy, so edits here ripple into all of them. It is also the source for the auto-generated Neovim snippets — these regenerate automatically on the next Neovim start after a macro change (see Snippets above).
- **bph-paper** — article class with BibLaTeX Chicago style and custom quotation environments
- **logic-hw**, **mod-cv**, **tufte-compact** — homework, CV, and handout classes

## The `bin` package

Everything in `bin/` is stowed to `~/bin` and is on PATH via `20-path.sh`. This is the home for homegrown executables; **pip/npm-installed console scripts stay in `~/.local/bin` and must not be moved here** — their package managers rewrite them on upgrade.

- `tl-newyear` + `tl-{roots,check,compare,visdiff}.sh` — TeX Live release migration. See "TeX Live release upgrades" below.
- `okular-forward` / `okular-inverse` — SyncTeX bridge between VimTeX and Okular. See below.

**`~/bin` also holds untracked files that do not belong in this repo.** `~/bin/isabelle` and `~/bin/isabelle_java` are generated by Isabelle's own installer — `isabelle install ~/bin` writes them (and `mkdir -p`s `~/bin`, which is how the directory first appeared). They hardcode the release path, are regenerated by re-running that one command, and are correctly machine-local, since `~/opt/Isabelle2025` isn't synced either. Leave them untracked. Note the trap in the other direction: `isabelle install` does `rm -f` on its targets, so if a same-named file were ever tracked here, re-running it after an Isabelle upgrade would silently replace the stow symlink with a real file and the next `stow -R bin` would fail with a conflict.

### The Okular SyncTeX bridge

Two halves, and both must agree on the Neovim socket path:

- **Forward** (tex → PDF): VimTeX calls `okular-forward <pdf> <line> <tex>`, configured in `nvim/lua/plugins/vimtex.lua` via `vimtex_view_general_viewer`. The wrapper does two jobs. **Path rebasing:** Okular resolves a SyncTeX source path *relative to the PDF's directory*, so the absolute path VimTeX supplies has to be rebased first or the jump silently does nothing. **Routing:** it finds the tab that already holds the PDF and jumps *into* it, instead of letting Okular replace or duplicate documents — see "Several documents open at once" below.
- **Inverse** (PDF → tex): Okular calls `okular-inverse <file> <line>`, set in `~/.config/okularpartrc` as `ExternalEditorCommand`. It percent-decodes the path and hands it to `nvr` (pip: `neovim-remote`) at `/tmp/nvimsocket` — the same socket `vimtex.lua` opens with `vim.fn.serverstart`. Change one, change the other.

### Several documents open at once — reworked 2026-07-26

The forward wrapper used to end in `exec okular --unique …`. That is why only one PDF was ever viewable: `--unique` makes the running instance **replace** its current document on every call, so compiling a second deck evicted the first. It also bypasses "Open new files in tabs" entirely, which is why toggling that preference appeared to do nothing.

Okular offers only two CLI behaviours and **both are wrong** for a VimTeX loop spanning more than one document:

| invocation | behaviour | failure |
|------------|-----------|---------|
| `okular --unique <pdf>` | reuses one window, replaces the document | deck B evicts deck A |
| `okular <pdf>` | honours the tabs preference, but has **no already-open check** | every forward search into the *same* doc appends *another* tab (measured 1 → 2 → 3) |

So the already-open check is done in the wrapper, over D-Bus. The enabling fact: **each open tab exports its own object** — `/okular`, `/okular2`, `/okular3`, … on service `org.kde.okular-<pid>` — and each answers `currentDocument()`. Calling `openDocument()` on the object that already holds the PDF performs the SyncTeX jump *inside that tab*, creating nothing; `tryRaise()` on `/okularshell` brings the window forward. Only genuinely-unopened documents fall through to the CLI.

Note the service name depends on launch flags: a `--unique` instance claims the well-known name `org.kde.okular`, a normal one registers `org.kde.okular-<pid>`. The wrapper matches both, so a stray `--unique` instance from an older session is still found. A per-document `flock` in `$XDG_RUNTIME_DIR` closes the startup race (two searches fired at a still-launching document would otherwise both decide it is absent). Detection costs ~70 ms.

**Tabs vs. separate windows is not hardcoded** — the wrapper is mode-agnostic and both were tested. Flip it in Okular: Settings → Configure Okular → General → "Open new files in tabs" (`okularpartrc`, `[General] ShellOpenFileInTabs`). Toggle it *through the GUI*, not by editing the file, since Okular rewrites `okularpartrc` on exit and would clobber a hand edit. It governs only where *newly opened* documents land; already-open ones do not rearrange, so close Okular and let the next forward search reopen them.

**Measured limitation, tabs mode:** a forward search into a *background* tab lands on the correct page but does **not** switch to that tab — you get no visible feedback until you switch, at which point it is already in the right place. Confirmed by triggering the exported `file_close` action over D-Bus and seeing which document vanished. There is no clean fix: Okular exports only 11 actions and none is tab-related (it *has* `activateNextTab` / `Switch to Tab %1` internally, just not on the bus); the one call that does activate a tab (`shell.openDocument`) always appends a new one, and `file_close` only closes the *active* tab, so the stale duplicate cannot be cleaned up. Key injection is out too — Okular here is a native Wayland client (`libqwayland.so`, not `libqxcb.so`), so `xdotool` cannot reach it, and `wtype` needs `zwp_virtual_keyboard_v1`, which GNOME does not implement. **Separate-windows mode is the likely fix if the silent jump ever grates, but it is unconfirmed.** There, each document gets its own process and so its own `/okularshell`, and `tryRaise()` was verified to succeed and to target the right window — but whether GNOME actually *raises* it was never tested. Doubt it: the wrapper passes an empty activation token (`tryRaise s ""`), and Wayland focus-stealing prevention will generally refuse to activate without a valid `xdg-activation-v1` token, marking the window as demanding attention instead. GNOME exposes no setting to relax this, and its `Introspect.ActivateWindow` D-Bus route is access-denied. Sway does have the knob — `focus_on_window_activation focus` — and its `layout tabbed` would supply the tab bar at the compositor level, so windows-mode-under-sway is the configuration most likely to give jump-and-show; untried, and both settings would need adding (`sway/config` has `layout tabbed` only as a commented-out binding). **Test before relying on any of this:** put both Okular windows behind the terminal, forward-search the one not on top, and see whether it comes forward or merely flashes in the dash.

### The `okular` package — and what is deliberately excluded

`~/.config/okularpartrc` **is** stowed (added 2026-07-26), so the `ExternalEditorCommand` above travels with the repo, along with the hand-built `QuickAnnotationTools` toolbar (highlighters on shortcuts 1/2/3, underline 4, insert-text 5, notes 6/7) — the part that would be tedious to rebuild through the GUI — and `ShellOpenFileInTabs=true`, which selects tabs over separate windows for the multi-document workflow above. Everything in that file is durable preference: no paths, no window geometry, no resolution-keyed values.

**Nothing else Okular writes belongs in this repo**, and `.gitignore` guards against it:

- `~/.config/okularrc` — window state plus a `[Recent Files]` list rewritten every session. Under `gpushall`'s `git add -A` that means a commit a day, and since both machines rewrite the same ten lines it would collide on every `pull --rebase=merges`. It also has resolution-keyed `[Print Preview]` sizes, and it names refereeing and teaching PDFs — into a public remote.
- `~/.local/share/okular/docdata/` — ~13MB across ~3,200 XML files of per-document bookmarks, annotations, and page positions. Constantly rewritten, and keyed by filename+size against `~/Desktop/readings/`, which isn't synced — so it would be inert on the other machine anyway.

**`okularpartrc` is the only stowed file that the *application itself* rewrites** — everything else here is written only by an editor. That was the open risk when the package was added, since KConfig saves by atomic replace, which could swap the symlink for a real file and silently un-stow it. **Tested over two write cycles on 2026-07-26 and it survives**, but be precise about the mechanism: KConfig *does* replace-and-rename — the target file's inode changes on each write — it just resolves the symlink first and replaces the file inside the repo rather than clobbering the link in `~/.config`. The link stayed intact, both paths kept reporting the same inode *as each other*, the changed key appeared in the repo file, and every other key was preserved. Toggling a setting back removed its key entirely rather than writing `=false`, so the file returned byte-identical to its prior state.

To re-verify at any time: `[ "$(stat -Lc%i ~/.config/okularpartrc)" = "$(stat -c%i ~/Desktop/configs/okular/okularpartrc)" ]` should hold, and `~/.config/okularpartrc` should still be a symlink.

The practical consequence of replace-and-rename: don't assume anything holding an open file descriptor on the repo copy will see updates, and don't be surprised that `git` reports a whole-file change.

Two consequences. First, changing an Okular preference now dirties the repo, and `gpushall` will commit it — expected, and it only happens on a deliberate change, since this file carries no session state. Second, if Okular settings ever *do* stop syncing after a KDE upgrade, check `ls -l ~/.config/okularpartrc` before anything else; if it is no longer a symlink, move the file back into `okular/` and restow.

**Pulling a change to this file while Okular is running is safe** — tested 2026-07-26 by writing a new key underneath a live Okular and quitting it. KConfig writes back only the keys it changed *that session*, so it merges rather than overwriting, and the pulled value survives. The one caveat is the running process, not the file: it keeps its old in-memory value until restarted, so a pulled preference does not take effect in an already-open Okular.

**Where `okular-inverse` resolves from — measured, 2026-07-26.** Okular finds it via the PATH of whatever launched it, and only one of the two cases works:

- **Launched by VimTeX** (the normal path): inherits the interactive shell's PATH, so `~/bin/okular-inverse` resolves and inverse search works.
- **Launched from the desktop** (app grid, Files, `xdg-open`): inherits the session PATH, which is `/usr/local/bin:/usr/bin` — `gnome-shell`'s actual environ, matching `systemctl --user show-environment`. `okular-inverse` is not found and inverse search silently does nothing.

Neither `~/bin` nor `~/.local/bin` is on that session PATH; both come only from `20-path.sh`, which runs for interactive shells only. So this is a property of how Okular is launched, not of where the script lives — verified by resolving the old `~/.local/bin` location against the same session PATH, which also fails. Moving these scripts into the repo changed nothing either way.

If inverse search from a desktop-launched Okular is ever wanted, the fix is a `~/.config/environment.d/*.conf` adding both directories (`PATH=$HOME/bin:$HOME/.local/bin:$PATH` — expansion confirmed working). Deliberately **not** done: it would give PATH a second source of truth that does not reproduce `20-path.sh`'s TeX-Live-first ordering, so a GUI process and a terminal process could disagree about which `pdflatex` wins mid-`tl-newyear`. Only add it against a concrete failure.

## TeX Live release upgrades

TeX Live is installed from the CTAN mirrors (not RPM), under `/usr/local/texlive/YYYY`.

**`tlmgr` cannot cross a release boundary.** It updates packages *within* a release — which it does continuously, since the tlnet repo refreshes daily — but refuses year-to-year upgrades by design. Crossing a year means a **parallel install**: the new release goes in alongside the old, both are verified to produce identical output, and only then does PATH move. Multiple releases coexist happily.

**`tl-newyear` (in the `bin` package) automates this.** Stages are separate subcommands because there is a human go/no-go decision in the middle:

```bash
tl-newyear status              # installed releases, which is active, baseline on file
tl-newyear preflight           # disk + btrfs headroom check
tl-newyear baseline            # fingerprint every document on the CURRENT release
tl-newyear install 2027        # parallel install; does NOT touch PATH
tl-newyear compare 2027        # recompile, diff against baseline
tl-newyear visdiff <doc.tex>   # pixel-compare one document across releases
tl-newyear switch 2027         # migrate symlinks, only after a clean compare
```

State (root lists, fingerprints, per-run logs and PDFs) lives in `~/.cache/tl-newyear`; the helper scripts are `tl-roots.sh`, `tl-check.sh`, `tl-compare.sh`, `tl-visdiff.sh`. Builds always go to that state tree via `-output-directory` — never in-place, because `teach-logic/` and `opuscula/` track their build artifacts and an in-place recompile would dirty tracked PDFs.

The procedure it implements, in order:

1. **Baseline first.** Compile every document on the *current* release and record page counts plus a `pdftotext | md5` fingerprint. Without this you cannot tell "the new release broke it" from "it was already broken."
2. **Check btrfs headroom.** The root filesystem is btrfs, and a `scheme-full` install writes ~180k files. If `btrfs filesystem usage /` shows little **Device unallocated**, the install dies with `No space left on device` *even though `df` reports plenty free* — free space inside already-allocated data chunks cannot be used for metadata. Fix with `sudo btrfs balance start -dusage=0 /` then `-dusage=50 /`. This bit the 2025→2026 upgrade.
3. **Install with `instopt_adjustpath 0`** so `/usr/local/bin` symlinks (~500 of them) keep pointing at the old release and the old toolchain stays active.
4. **Re-compile and diff** against the baseline. Expect many `pdftotext` hash changes that are *not* regressions — newer releases fix glyph-to-Unicode mappings, so logic symbols extract correctly where they previously came out as garbage. Confirm with a pixel comparison (`pdftoppm` + `compare -metric AE`) rather than trusting the text hash.
5. **Switch** with `tlmgr path remove` on the old release then `tlmgr path add` on the new. `20-path.sh` picks up the new year automatically. Keep the old tree until confident.

**Known casualty: the *forall x* textbook.** `tabu` v2.9 (unmaintained since 2019) patches `array.sty`'s internals, and `array` was rewritten in TL2026 (`1995/06/01` → `2026/06/01`). This breaks all `forallxyyc*` builds in `teach-logic/` with `TeX capacity exceeded [grouping levels]`, and shifts the solutions documents by one page. `tabu` is used nowhere else — the dissertation, `opuscula/`, `org/`, `teaching/`, and `n-cube/` are unaffected. Until upstream *forall x: Calgary* migrates to `tabularray`, build the textbook pinned to the old release:

```bash
TEXLIVE_YEAR=2025 make      # in any forallx-yyc-build/ directory
```

A pin naming a release that isn't installed **warns** (interactive shells only) and is otherwise ignored — PATH gets no TeX Live entry and commands fall through to the `/usr/local/bin` symlinks, which point at whichever release is active. So a pin only works on a machine that still has the pinned release.

### Rolling a release out to the second machine

The scripts and dotfiles travel in git; the ~13GB TeX Live tree does not. Order matters:

```bash
# on the machine that already upgraded
gpushall

# on the other machine
gpullall
source ~/.bashrc            # MUST precede stow-all -- see below
stow-all
tl-newyear status
tl-newyear preflight
tl-newyear install <year>
tl-newyear switch <year>
source ~/.bashrc
```

**Why the re-source must come first.** `stow-all` iterates `STOW_ORDER` / `STOW_TARGETS` as loaded in the *running shell*. A pull that adds a **new** stow package (as `bin` was) updates `60-stow.sh` on disk but not the arrays in memory, so `stow-all` skips the new package **silently** — no error, it simply isn't in the list being iterated. Applies to any newly added package, not just this one.

**Re-verifying on the second machine is optional.** TeX Live is deterministic given the same inputs, so a release verified on one machine behaves the same on the other. Run `baseline` + `compare` there only to catch machine-specific divergence — a different `~/texmf`, or repos sitting at a different commit. If you do, `baseline` must run *before* `install`, since it fingerprints whichever release is currently active.

**Revision drift between machines.** Two machines installing the same release on different days get different tlnet snapshots, so package versions differ slightly. Harmless in general, but run `tl-upgrade` on both before generating a final dissertation PDF so the output doesn't depend on which machine you happened to use.

**`~/.cache/tl-newyear` is machine-local** — per-machine fingerprints plus ~130MB of build artifacts. Deliberately not synced, and shouldn't be.

## Sway/Waybar

Sway uses vim-style navigation (hjkl). Mod4 (Super) is the primary modifier. Waybar config is JSON + `style.css`.

**Check which compositor is actually running before testing anything here.** As of 2026-07-26 the live session on `fedxps` is **GNOME** (`gnome-shell` running, `sway` not), even though sway and waybar are both installed and `sway --validate -c sway/config` passes. The config is stowed and ready, it just isn't what's booted. `pgrep -x gnome-shell` / `pgrep -x sway` settles it; `swaymsg` will fail confusingly under GNOME.

**The two bars do not share an accent, on purpose.** Sway's focused-window border is dodger blue (`$accent`, `#0088FF`); Waybar's active workspace is still forest green (`@accent`, `#228B22`). `sway/config` also defines `$forest #228B22`, unused, kept so the old accent can be swapped back in one word — don't "clean it up."

Note `$mod+b` and `$mod+v` are launchers here (Brave, VS Code), not upstream sway's horizontal/vertical splits; splits live on `$mod+Ctrl+h` / `$mod+Ctrl+v`.

`waybar/config` hardcodes `"device": "intel_backlight"` — laptop-specific. On `bigfed` the backlight and battery modules simply don't render.

## Visual Consistency

TokyoNight "night" theme across Neovim, WezTerm, and Waybar. Source Code Pro 12pt font in both terminals (WezTerm, Alacritty). Alacritty carries font settings only — no colorscheme — so it falls back to its own default palette rather than TokyoNight.

## Pitfalls

- **`stow-all` does not auto-adopt.** It restows (`stow -R`); a pre-existing untracked file at a target makes it error out, not overwrite. Resolve with `stow --adopt` or by removing the file (README §8), then rerun.
- **Never edit a stowed file in place *through the live path*.** `sed -i`, and any tool that saves by write-temp-then-rename, **replaces the symlink with a regular file** — silently un-stowing it, after which repo and live copy drift apart with no error. This bit `~/.config/okularpartrc` on 2026-07-26. Edit the file under `~/Desktop/configs/` instead (a real file there, so in-place tools are safe), or pass `sed --follow-symlinks`. Note this is the *opposite* of how KConfig behaves — Okular resolves the symlink first and rewrites the repo copy, which is why `okularpartrc` survives Okular's own writes but not a careless `sed -i`. To check: `[ "$(stat -Lc%i ~/.config/okularpartrc)" = "$(stat -c%i ~/Desktop/configs/okular/okularpartrc)" ]`.
- **Public repo + minimal `.gitignore` + `gpushall` runs `git add -A`.** As of 2026-07-26 `.gitignore` has exactly three entries — `.claude/settings.local.json`, `okular/okularrc`, `okular/docdata/` — and **everything else in the tree gets committed and pushed to a public remote**. Don't park secrets, private data, or large binaries here expecting them to be skipped. Note also that stow's default ignore list covers only `README.*`, `LICENSE.*`, `COPYING`, VCS dirs and `*~` — **not** `*.bak` or `*.save`, so ad-hoc backups left in a package get symlinked into the live config tree as well as published.

- **`latex/mod-cv/` shadows TeX Live's moderncv.** The 36 vendored `moderncv*.sty` files (plus `tweaklist.sty`) are pinned v2.3.1 and are load-bearing for the `mod-cv.cls` fork (it loads them by their upstream names) — they can't be deleted. But because `~/texmf` outranks `texmf-dist`, they also override TeX Live's copies for anything using `\documentclass{moderncv}`, which on TL2026 means a v2.6.1 class over v2.3.1 sub-packages. See `latex/mod-cv/README.md`.
- **`french-logic.sty` is a shared, snippet-coupled dependency** — editing it affects the dissertation/teaching repos. The generated snippet file no longer desyncs silently (auto-regenerated on next Neovim start), but the vimtex highlight registrations are still maintained by hand. See the LaTeX Packages section before touching it.
- **Adding files to a package needs a restow** (`stow -R <pkg>`) to create the new symlinks; editing already-linked files does not.
