# tests/live-server

Hermetic regression suite for the live-server root wrapper
(`nvim/lua/plugins/live-server.lua`). 27 checks, ~10 s.

```bash
~/Desktop/configs/tests/live-server/run.sh
```

Exit 0 all green, 1 a check failed, 2 cannot run (plugin checkout or spec
missing). Last line follows the `tests/gsync` convention
(`passed: N  failed: M`). Run it after editing the wrapper **or after a
live-server.nvim update** — the wrapper's design notes exist because the
v0.1.7 → v0.3.0 rewrite (2026-06-03) broke the config silently, surfacing
months later.

## What it needs, what it touches

Needs the plugin checkout lazy.nvim keeps at
`~/.local/share/nvim/lazy/live-server.nvim` (present after any interactive
Neovim start) and `nvim` itself; nothing else. Everything runs in one
`nvim --clean --headless` process: fixture repos and XDG state live in a
`mktemp -d` sandbox removed on exit, the HTTP traffic is loopback-only on a
port picked free at runtime, `browser = false` keeps `vim.ui.open` shut, and
no real repo is read or written. The servers are in-process (`vim.uv`), so
nothing can outlive the run.

## The three check families

- **W1–W13** pin the wrapper's contract: start from a body file serves the
  project root with zero buffer churn; stop works from the same project, from
  a *different* project, and after `:bwipeout` of every buffer of the served
  project; start/stop/start cycles; the index-less-root fallback serves the
  *buffer's* directory (keeping live-reload alive beside the buffer) without
  touching cwd; both commands work from a `winfixbuf` window; a stop with
  nothing running stays silent.
- **U1–U3** are **upstream canaries**: they pin the plugin behaviors the
  wrapper's design *rests on* — bare start serves the buffer's directory,
  bare stop misses an explicitly-started instance (the trailing-slash key
  vs. the upward walk), and the Linux watch is non-recursive on the served
  root. **A U failure after a plugin update is not necessarily a breakage**:
  it means the ground moved (perhaps upstream fixed its bug), so re-read the
  wrapper's header comment and `DECISIONS.md` item 9 before changing either.
- **D0–D3** pin the directory semantics *outside* git repos (added
  2026-08-22, off the planned `nousowl.net` → `nousowl/` move): with no
  `.git` anywhere above the buffer, `project_root()` lands on the cwd, so a
  git-less cwd with `index.html` acts as the served root even from a subdir
  buffer (D1), one without an index serves the buffer's directory (D2), and
  an unnamed buffer degrades to serving the cwd — `expand('%:p:h')` on an
  unnamed buffer is the cwd, measured, not `''` (D3). D0 is the precondition:
  the mktemp sandbox must not itself sit under a git repo, or these legs
  never fire — it fails with the remedy named (point `TMPDIR` at a non-repo
  path). The in-repo counterpart of this family — a site subdirectory inside
  an ops-style repo whose root has no `index.html`, the exact nousowl-move
  shape — is already pinned by W10–W12 (fixture `projC`).

## Harness conventions (learned by mutation, keep them)

Every wrapper invocation goes through a `pcall`'d `cmd()` — the first
mutation run proved a spec that throws mid-check otherwise aborts the script
before the final `passed:` line. And each section `force_stop()`s whatever it
may have leaked, probing candidate directories *explicitly* (the plugin's
upward walk cannot find a root-keyed instance from below — the same
trailing-slash bug the wrapper works around); without this, one leaked server
holds the port and cascades failures into unrelated later checks.

## Mutation fingerprints (verified 2026-08-22)

`LIVE_SERVER_SPEC=<file> run.sh` substitutes the spec under test. Three
mutants, each failing exactly its own checks and nothing else:

| mutant | fails exactly |
|---|---|
| the pre-2026-08-22 buffer-juggling wrapper (`git show` of the old file) | W3, W8, W11, W13, W13b, W13c |
| `stop(last_root or project_root())` → `stop(project_root())` | W7, W8, W12b |
| fallback branch removed (always serve the root) | W10, W12, D2 |

The healthy suite is deterministic: two consecutive runs, 27/27 both.
