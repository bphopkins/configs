# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What This Repo Is

A GNU Stow-based dotfiles repository for Fedora Linux, synced across multiple
machines (fedxps, bigfed) via git. **This is a public GitHub repo**
(`github.com/bphopkins/configs`) — anything committed is published (see
Pitfalls). Configs are stored here at `~/Desktop/configs` and symlinked to
their live locations. The user is an academic working in logic/philosophy —
the LaTeX and Neovim configs are heavily tailored to dissertation writing.

Documentation follows the five-kinds doctrine
(`org/claude-config/rules/where-things-go.md`); decomposed 2026-08-26:

- **Per-package `CLAUDE.md`s** are the charters — operative detail lives with
  its package and loads lazily when the directory is touched. The package
  index below routes.
- **`TODO.md`** is the planned-work tracker (open items + a `## Closed`
  ledger). Read it before starting a work session here or proposing
  structural changes.
- **`DECISIONS.md`** is the rolling dated record of closed work; completed
  TODO items keep their original item numbers there.
- **`docs/`** holds dated investigation records (measurements, declined
  options, incident write-ups); charters carry one-clause verdicts and
  pointers into them.
- **`README.md`** is the from-scratch setup walkthrough for a new machine
  (import live dotfiles → seed commit → dry-run stow → link → verify →
  reload); its §8 covers conflict resolution and unlinking.

## Package index

Each package is a top-level directory; targets come from the associative
array in `bash/.bashrc.d/60-stow.sh` (the source of truth). `wallpapers/`,
`tests/`, and `docs/` are not packages.

| Package | Stow target | Charter covers |
|---|---|---|
| bash | `~` | module detail, git-sync guardrails + suite, reboot verdict, disk pair, the stow guard |
| wezterm | `~` | *(no charter — the config file carries its own: pinned font faces, and the two measured latency/throughput settings)* |
| ghostty | `~/.config/ghostty` | *(no charter — the config file carries its own: the WezTerm transcription, the chrome removal, the faint-text gap, the dual config-file trap)* |
| alacritty | `~/.config/alacritty` | *(no charter — font settings only, deliberately unthemed)* |
| nvim | `~/.config/nvim` | LaTeX toolchain + VimTeX traps, completion gates, snippets, persistence, auto-save, lockfile, suites |
| sway | `~/.config/sway` | desktop-suite charter: binding grammar, locking, verification method, cross-config wiring |
| swaylock | `~/.config/swaylock` | the fail-open unknown-key hazard |
| waybar | `~/.config/waybar` | GTK3 CSS dialect + parse-check, format-width conventions |
| mako | `~/.config/mako` | timeout semantics, reload |
| wofi | `~/.config/wofi` | launcher keys, same GTK3 dialect |
| latex | `~/texmf/tex/latex` | french-logic coupling, mod-cv shadow |
| bin | `~/bin` | tool inventory, tl-newyear, the Okular bridge, claude-link (the Claude configuration itself lives in `org/claude-config/`, private — this repo carries only the mechanism) |
| okular | `~/.config` | the one app-rewritten stowed file, exclusions |

## Stow Deployment

Key commands (defined in `bash/.bashrc.d/60-stow.sh`):

- `stow-all` — `git pull --ff-only`, then restow every package (`stow -R`).
  On a conflict (an untracked real file already sitting at a target) it
  **errors out** rather than resolving it — adopt or remove the file manually
  (README §8), then rerun.
- `stow-all-dry` — preview what stow-all would do (no changes)
- `unstow-all` — remove all managed symlinks (`stow -D`)

Editing already-linked files requires no restow; adding or removing files in
a package does (`stow -R <pkg>`). When adding a new package, update both the
target map and the ordering array in `60-stow.sh` — and see the re-source
trap below. `bash/.stow-global-ignore` (stowed to `~`) keeps the per-package
charters out of the live config tree; ⚠ it **replaces** stow's built-in
defaults, so its reproduced default patterns must stay (`bash/CLAUDE.md`).

## Daily Sync Workflow

Start of session: `gpullall` → `source ~/.bashrc` (if bash files changed) →
`stow-all` (if files added/deleted). End of session: `gpushall`.

**The re-source is not optional when a pull adds a stow package.**
`60-stow.sh` is itself a bash file, so a pull that adds a package updates it
on disk but not the arrays in the running shell — and `stow-all` iterates the
in-memory arrays, so it skips the new package **silently**, with no error.
When in doubt, re-source.

Sync commands (`bash/.bashrc.d/50-git-sync.sh`; the guardrails — vetting,
in-progress guards, offline handling, hints — and their scope live in
`bash/CLAUDE.md`):

- `gpullall` — ff-only pull of every repo in `REPOS_DESKTOP` (which spans
  *all* the Desktop repos, not just this one), with follow-up hints when a
  `configs` pull needs a re-source, restow, or lockfile restore — but the
  restow hint is blind to a *newly added* package (`TODO.md` item 10), so a
  pull that brings one still needs `stow-all` by hand
- `gpushall [-m MSG]` — stages everything (`git add -A`, vetting newly added
  paths), commits as `{hostname}: {YYYY-MM-DD HH:MM:SS}`, rebases, pushes
- `gpull <name>...` / `gpush [-m MSG] <name>...` — the same for named repos
- `gstatall [-f]` — read-only per-repo dashboard; the safe first move
  whenever the machines may be out of step

**Run `tests/gsync/run-all.sh` after any edit to `50-git-sync.sh`.**

`tests/term-bench/` holds the terminal-comparison harnesses (throughput,
keystroke-path latency, SGR-density sweep) and a README naming the seven
ways an apparently-fine terminal benchmark can measure nothing at all.
Findings: `docs/ghostty-vs-wezterm-2026-09-03.md`.

## Bash Configuration

Modular: `.bashrc` sources all `~/.bashrc.d/*.sh` in numbered order — `00`
shell-opts (reserved-empty), `10` env, `20` path (TeX-Live-first ordering,
auto-detected year), `30` prompt (reserved-empty), `40` aliases
(`sysupgrade`/`reboot-check`, `tl-upgrade`, `reload`, `cc`/`ccf`,
navigation), `50` git-sync, `60` stow, `70` `ls-tasks`, `80` `clam`, `85`
`disk-check`/`disk-fix`, `90` nix (load-bearing on bigfed). The empty modules
are reserved slots, not dead code. Everything else — module hazards, the
reboot-verdict contract, the disk pair, the suites — is in `bash/CLAUDE.md`.

## Visual Consistency

TokyoNight "night" theme across Neovim, WezTerm, Ghostty, and Waybar. Source
Code Pro 12pt font in three of the four terminals (WezTerm, Ghostty,
Alacritty). Alacritty carries font settings only — no colorscheme, so it falls
back to its own default palette. Ghostty is a deliberate transcription of the
WezTerm config, added 2026-09-03 to make the two comparable like for like; its
own comments carry the places where they cannot be made to agree.
The desktop's single urgent colour (`#d08770`) spans four configs in four
languages — see `sway/CLAUDE.md` before changing it.

## Pitfalls

- **`stow-all` does not auto-adopt.** It restows (`stow -R`); a pre-existing
  untracked file at a target makes it error out, not overwrite. Resolve with
  `stow --adopt` or by removing the file (README §8), then rerun.
- **Never edit a stowed file in place *through the live path*.** `sed -i`,
  and any tool that saves by write-temp-then-rename, **replaces the symlink
  with a regular file** — silently un-stowing it, after which repo and live
  copy drift apart with no error. Edit the file under `~/Desktop/configs/`
  instead, or pass `sed --follow-symlinks`. (KConfig/Okular is the one
  exception that resolves the link and rewrites the repo copy —
  `okular/CLAUDE.md`.)
- **Public repo + `gpushall` runs `git add -A`.** Anything no ignore rule
  refuses is committed and pushed to a public remote. `.gitignore` carries
  hygiene groups (its comments record the reasoning) but matches whole files
  by name: a secret pasted into a tracked file, or private data under an
  innocent name, ships regardless — the content scan is `TODO.md` item 7.
  Don't park secrets, private data, or large binaries here. Note also that
  stow's ignore list (the reproduced defaults + `CLAUDE\.md`) does **not**
  cover `*.bak`/`*.save` — `.gitignore` keeps such backups off the remote;
  stow does not keep them out of `~/.config`.
- **`latex/mod-cv/` shadows TeX Live's moderncv** — see `latex/CLAUDE.md`.
- **`french-logic.sty` is a shared, snippet-coupled dependency** — editing it
  affects the dissertation/teaching repos; see `latex/CLAUDE.md` before
  touching it.
