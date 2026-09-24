# Decisions — configs

Dated record — the closed-work ledger for this repo, created 2026-08-26
(context-policy Stage 2) by moving `TODO.md`'s completed items here. Numbered
headings keep their original TODO.md item numbers, which code comments and
other docs cite — "item 6" means the same item in either file. Entries are
never rewritten, only annotated; new entries are appended at the end with
their date. References to `CLAUDE.md` sections inside the moved text predate
the 2026-08-26 decomposition of the root charter; that content now lives in
the per-package charters and `docs/`.

---

## 5. Sway config: the deferred tiers — COMPLETE 2026-08-13

- [x] All four tiers done, verified from inside a live Sway session. @done(2026-08-13)

Kept rather than folded into Done because the per-tier notes below record *why* things
were done the way they were, and the declined list at the foot is the part most likely to
be re-proposed by a future session. From a full inspection on 2026-08-13.

**Tier 1 — lid/lock. DONE 2026-08-13**, see the Done entry. Screen blanking and idle
timers remain **declined**. One follow-up if a timer is ever added after all: pair it
with `for_window [app_id=".*"] inhibit_idle fullscreen`, or a fullscreen talk will lock
mid-presentation.

**Tier 2 — `focus parent`. DONE 2026-08-13.** `$mod+p` walks up the tree, `$mod+Shift+p`
(`focus child`) comes back down; the pair is bound because parent alone leaves you
steering back with direction keys. `$mod+v` remains deliberately free. *(Superseded
2026-08-22: the pair — and the splits — were dropped with the whole container tier;
see item 6.)*

**Tier 3 — screenshots. DONE 2026-08-13.** `Print` full-screen->file, `Shift+Print`
region->clipboard, `$mod+Print` region->file.

Two findings baked in. **The cancel guard is load-bearing:** written the obvious way as
`grim -g "$(slurp)" - | wl-copy`, pressing Esc leaves an empty geometry, grim fails, and
wl-copy still runs with empty stdin — silently **wiping the clipboard**. Testing both
slurp's exit status and the resulting string means a cancelled screenshot changes nothing;
verified with stub slurps for both the cancel and success paths.

**The destination is not redirectable from bash.** grim honours `GRIM_DEFAULT_DIR`, but
the `XDG_PICTURES_DIR` *environment variable* is ignored — setting it to a scratch dir
still wrote to `~/Pictures`, so grim reads `~/.config/user-dirs.dirs` instead and the man
page's "falls back first to `$XDG_PICTURES_DIR`" names the value, not the variable. And
exporting `GRIM_DEFAULT_DIR` from `bash/.bashrc.d` would not reach the keybinding anyway:
sway's children inherit the *session* environment, not an interactive shell's — the same
trap documented for `okular-inverse`. Redirecting it would mean naming a path in
`sway/config`. Left at `~/Pictures`.

**Tier 4 — DONE 2026-08-13.** `$mod+Tab` -> `workspace back_and_forth` (the third motion
the `$alt` prev/next pair left missing). `client.urgent` now uses `$urgent` `#d08770`, so
sway finally matches Waybar, mako and swaylock — one urgent colour desktop-wide. Waybar's
battery gained `states` (warning 20 / critical 10) with CSS classes, plus **notifications
via waybar's own `events` mechanism** — no daemon, no timer, because the module already
polls; critical fires at `urgency=critical`, which mako keeps on screen until dismissed.
Two incidental fixes found while there: the battery format used `{icon}` with no
`format-icons` array, so it rendered nothing (dropped — this bar is deliberately all
plain text); and the clock's `interval` defaulted to **60**, polling on the minute, which
is why `%T` showed `00` seconds forever under Sway while GNOME ticked. `interval: 1`
fixes it — verified by diffing two `grim` captures of the clock region 1.6 s apart.

A follow-on from that: with seconds now visible, the centred clock **jittered** once a
second, because the default proportional font renders different digits at different
widths (measured 145 <-> 146 px) and `modules-center` turns a width change into
horizontal movement. Fixed with `font-feature-settings: "tnum"` on `#clock` — tabular
figures, so every digit has one advance width; re-measured as a constant 155 px at a
constant offset across 8 consecutive seconds. Two things learned doing it, both now in
`CLAUDE.md`: GTK3 **rejects** the CSS-spec form `"tnum" 1` and knows nothing of
`font-variant-numeric`; and **a CSS parse error makes waybar exit silently**, leaving
sway with no bar and nothing in the journal but `Using CSS file …`. Parse-check
`style.css` before every reload.

**Not a gap, checked 2026-08-13:** `xdg-desktop-portal-wlr` *is* installed (it is a
libexec binary, so `command -v` misses it) and Fedora ships
`/usr/share/xdg-desktop-portal/sway-portals.conf` routing ScreenCast/Screenshot to wlr —
screen sharing will work. mako is installed and D-Bus-activated
(`fr.emersion.mako.service`), so notifications need no `exec` line.

**`seat * xcursor_theme`: investigated and struck, 2026-08-13.** It was on Tier 4 on the
theory that XWayland clients fall back to an unthemed X cursor. Tested live by running
the *same* binary on both backends (`alacritty` vs `env -u WAYLAND_DISPLAY alacritty`,
which is the way to force XWayland here) — **the cursors are identical**. The reason is
structural, so it is stable: Adwaita is the only cursor theme installed, and
`/usr/share/icons/default/index.theme` has `Inherits=Adwaita`, so the unnamed `default`
theme that both paths resolve lands on the same theme either way; `XCURSOR_SIZE=24` is
set session-wide. Nothing to fix unless a second cursor theme is ever installed. (Unrelated
observation from the same test, deliberately not pursued: the XWayland Alacritty renders
its font larger. `Xft.dpi` is unset and output scale is 1.0, so the likely cause is X11
clients deriving DPI from the panel's EDID physical size rather than assuming 96 —
unverified, and moot while every app in use is native Wayland.)

**Regression suite added 2026-08-13:** `tests/desktop/run.sh`, 24 checks, mutation-verified.
It guards the four silent-catastrophic failure modes this work uncovered (waybar CSS typo
kills the bar; unknown swaylock key means no lock; `sway --validate` skips binding command
bodies; mako/wofi unknown keys), plus the cross-config wiring that nothing else holds in
place. Run it after touching sway, waybar, swaylock, mako or wofi.

**Considered and DECLINED 2026-08-13** (asked and answered, do not re-propose):

- *Clipboard persistence* (`wl-clip-persist` / `cliphist`) — has never actually been a
  problem in practice, and is not worth running a daemon for.
- *Multi-monitor bindings* — sway has never been used with multiple monitors; the one
  attempt was on `bigfed`, which has been abandoned as a sway machine.
- *`for_window` floating rules* — no misbehaving dialog was ever demonstrated, so there is
  nothing to fix yet. The `inhibit_idle fullscreen` half only applies if idle timers are
  ever adopted, which they are not.
- *A clock on the lock screen* — wanted, but mainline swaylock cannot do it (see the
  swaylock note in `CLAUDE.md`); `indicator-idle-visible` was taken instead.

---

## 6. Impose an explicit logic on the sway keybindings — COMPLETE 2026-08-22

- [x] Grammar adopted, header rewritten to state it, config brought into line, both
  gates green. @done(2026-08-22)

Kept with full notes because the reasoning is the deliverable here: the law, the one
move it cost, the tier it deleted, and the reversals a future session would otherwise
re-litigate. The 2026-08-13 measurements the item opened with (plain `$mod` 32 /
`$mod+Shift` 24 / `$mod+Ctrl` 3 / `$mod+$alt` 8; Shift already ~79% "take the window
with you"; Ctrl definitionally incoherent) were the basis and held up.

**The law: the modifier names what the action acts on.** `$mod` = you — attention,
instruments, summoning (focus, workspaces, launchers, menu, scratchpad show, bar and
touchpad toggles). `$mod+Shift` = the focused window — move, send, stash, toggle
state. `$mod+Ctrl` = the session — `l` lock, `c` reload. `$mod+$alt` = the workspace
row — walk it; +Shift carries the window, so Shift's meaning composes. Two clauses
complete it: **key families override the table on their own key** (Escape = leaving,
graded by weight — the session, then the machine; Print = capture; XF86 = hardware;
the clause is forced by Print regardless, so the endorsed Escape gradient became
lawful in place), and **promotions are a stated, closed list** (`q` kill and `r`
resize: window verbs one tier light for daily frequency; a new window verb defaults
to Shift). The header now states all of this; its self-contradictory "heavier
variant" rule is gone.

**Moves: exactly one.** reload `$mod+Shift+c` → `$mod+Ctrl+c` (same letter, c =
config). Untouched: every launcher, `$mod+q` kill, `$mod+Escape` exit,
`$mod+Shift+Escape` poweroff — whose nag gained a **Reboot** button (machine actions
share the nag rather than claiming chords; the parked `#$mod+Shift+r` comment went
with it) — vim/arrow parity, `$mod+v` free.

**Dropped: the whole container tier**, user decision after its use-cases were laid
out — `splith`/`splitv` (`$mod+Ctrl+h/v`) and `focus parent`/`child`
(`$mod+p`/`$mod+Shift+p`). Splits had never been pressed intentionally, parent/child
never at all: with one or two windows per workspace, the group a parent would select
coincides with the workspace itself, and workspaces-as-the-grouping-unit is a
first-class way to run a tiling WM, not a deficiency. **This supersedes the "preserve
splits on Ctrl+h/v" constraint this item originally recorded** (item 5's Tier 2 note
is flagged too). Nothing is stranded — measured in a nested headless sway the same
day: an orthogonal `$mod+Shift+j/k` move still builds stacked layouts implicitly (two
640x720 columns → two full-width 1280x360 rows on one `move down`), which is also
where accidental vertical splits always came from. Revival chords are recorded in the
config's Layout section — plausibly relevant if a big-screen sway ever lands on
bigfed, where three-plus windows per workspace would make the tree earn its keep.

**Declined** (asked and answered, do not re-propose):

- *Re-grading the Escape column* (lock as its lightest ring, exit/poweroff one
  heavier) — the existing gradient was explicitly endorsed mid-design; the family
  clause covers it with zero moves.
- *`poweroff` → `$mod+Ctrl+Escape`* (this item's own starting hypothesis) — same
  reason: the override clause makes it lawful where it sits.
- *Rehoming `focus child`* to `$mod+i`, an out/in pair on `o`/`i`, or scope brackets —
  mooted by dropping the tier; the `o`/`i` out/in pair is the idiom-pure shape if the
  pair ever returns on letters.
- *A standalone reboot chord* — the nag button plus `reboot` in a terminal cover it.
- *A `tests/desktop` check pinning `sway/README.md` to the config's binding set* —
  declined 2026-08-22, same day the quick-reference card was added: the README is a
  best-effort courtesy that may be hand-edited or deleted at will, and a suite check
  would turn a stale doc into a failing gate, making the card an obligation on every
  binding change rather than a convenience.

Verification: `sway --validate` clean; `tests/desktop/run.sh` 24/24 (the suite adapts
to the binding set, so the dropped and moved chords needed no test edits); the
stacking claim measured, not assumed. GNOME was the live compositor, so no running
session was touched — the next sway login picks the grammar up.

---

## 9. Simplify the live-server root wrapper — COMPLETE 2026-08-22

- [x] Replaced the buffer-juggling in `nvim/lua/plugins/live-server.lua` with
  explicit directories at both ends plus one remembered string. @done(2026-08-22)

Kept rather than folded into Done because the upstream-bug record below is
referenced by the wrapper's own header comment, and the declined shapes are the
ones a future session would re-propose.

**History.** Raised 2026-08-22, off the notification "``require("live-server").setup()``
was removed in v0.2.0", seen on the first `<localleader>hh` of a session: the
plugin was rewritten under us (pin `v0.1.7-7` → `v0.3.0-3` on **2026-06-03**,
`nvim/lazy-lock.json`) and had been erroring on first use ever since — it only
surfaced then because the plugin is lazy-loaded on the command. The dead
`setup()` call and the npm `build` step were removed the same day
(`~/.local/npm-global/bin/live-server` left in place, harmless and usable
standalone). The simplification was first deferred for lack of verification,
then landed the same day after a 52-check measured comparison — old wrapper,
plain form, adopted variant, each against fixture repos, plus a read-only round
trip against the real `bphopkins.net` (fedxps, plugin pin `f1a2def`).

**Why a wrapper exists at all — confirmed, not assumed.** From a body file
under `bphopkins.net/src/`, the bare command serves `src/`, which has no
`index.html`, so the plugin falls through to its directory-listing branch:

| | served | `<title>` |
|---|---|---|
| bare `start()` from a body file | `src/` | `Index of /` |
| `start(root)` | repo root | `Brandon Hopkins' Homepage` |

**The upstream bug the design works around** (recorded here per the standing
rule; **not to be filed**). `start(dir)` keys the instance on the resolved
directory, which for a directory ends in a trailing slash (`:p`); the stop
path's upward walk strips components with `:h`, which never reproduces a
trailing slash — so a *bare* stop finds an instance only when its starting
point resolves to the stored key verbatim. Consequences, each pinned by a
suite canary: bare start serves the buffer's directory; bare stop from
elsewhere in the project silently misses an explicitly-started instance; and a
miss says nothing (`M.stop` has no else branch). The explicit form is immune —
equal input strings resolve to byte-identical keys, and the lookup probes the
exact key before walking — and it is the plugin's *documented* usage
(`:h live-server-api`), where the old wrapper leaned on the undocumented fact
that bare resolution reads the buffer's path.

**What the full investigation added: the plain 4-liner
(`stop(project_root())`) is NOT lossless.** Two losses, measured:

- *Cross-project stop.* The old wrapper stopped the server from any buffer by
  teleporting through a remembered `index.html` buffer; the plain form
  resolves wherever you are *now* — start in `bphopkins.net`, wander into
  `nousowl.net` (the stylesheet flows between exactly those repos), stop, and
  nothing happens, silently.
- *The index-less-root fallback.* Serving the root there renders a bare
  listing **and** — the Linux watch being non-recursive on the served root —
  never live-reloads anything in a subdirectory: the tool inert precisely
  where it runs. Serving the buffer's directory renders the page beside the
  buffer and keeps reload alive for its siblings. Affects no current repo
  (both sites have a root `index.html`); the old notes had marked this
  behaviour change an improvement, which the reload angle overturns.

**The adopted shape** closes both: explicit dir at both ends, `last_root` — a
string — remembered at start and used by stop, and the fallback branch serving
the buffer's directory when the root has no `index.html`. Measured
lossless-or-better against the old wrapper in every scenario, and strictly
better in three: the old buffer memory died on `:bwipeout` (silent stop-miss
that also loaded the *wrong project's* `index.html`; plain `:bdelete` it
survived — the handle stays valid, only a wipe kills it); the old `:edit`
errored outright in a `winfixbuf` window, so no server started; and the old
fallback's `lcd` permanently changed the window's cwd while every start loaded
the generated root `index.html` into the buffer list.

**Declined:**

- *Tracking the root via the `LiveServerStarted` event* instead of assigning
  `last_root` at the call site: the event's `data.root` is the realpath, the
  instance key is the `:p`-expanded path — the exact mismatch class that
  created the original bug.
- *The plain 4-liner* — the losses above, for ~10 saved lines.
- *Filing upstream* (standing rule: local record only, here and in the
  wrapper's header).

**Regression suite:** `tests/live-server/run.sh` — 27 checks, ~10 s, hermetic
(fixtures and XDG state under `mktemp -d`, loopback only on a runtime-free
port, `browser=false`, real repos untouched). W checks pin the wrapper
contract; D checks the no-repo directory semantics (next paragraph); U checks
pin the upstream behaviours above **as canaries** — a U failure after a plugin
update means the ground moved (perhaps upstream fixed its bug), not that
something broke. Mutation-verified in three directions with disjoint
fingerprints: old wrapper → W3 W8 W11 W13 W13b W13c; `last_root` dropped from
stop → W7 W8 W12b; fallback branch dropped → W10 W12 D2. Its README records
the two harness rules the mutation runs forced (pcall every wrapper call so
the summary line always prints; force-stop per section so a leaked server
cannot smear a fingerprint). Run it after editing the wrapper or after any
live-server.nvim update.

**Directory semantics, measured 2026-08-22** (same day, off the planned
`nousowl.net` → `nousowl/` move). `project_root()` resolves in order: nearest
`.git` upward from the *buffer* (`vim.fs.root`), then `git rev-parse
--show-toplevel` in *nvim's cwd*, then `getcwd()` — so outside any repo the
cwd acts as the declared root. Every leg measured, with the wrapper's branch
on top: a site subdirectory inside a repo whose root has no `index.html` (the
nousowl-move shape; fixture `projC` pins the mechanism, and a depth-2
`opsrepo/www/site/` case was measured besides) serves the *site* directory
with live-reload firing on its `index.html`; a git-less directory with
`index.html` at the cwd serves the cwd even from a subdir buffer (D1); a
git-less directory without one serves the buffer's directory (D2); an unnamed
buffer degrades to serving the cwd, because `expand('%:p:h')` on an unnamed
buffer is the cwd — measured, not `''` (D3). One inherited corner,
deliberately recorded rather than pinned: a buffer *outside* any repo while
the cwd sits *inside* a site-shaped repo serves the cwd's repo — the
`git rev-parse` leg asks about the cwd, not the buffer. Identical under the
old wrapper (same `project_root()`, same branch), and rare enough to leave.

**Interactively verified the same day** (live session, `bphopkins.net`):
`<localleader>hh` opened the browser on the served homepage and
`<localleader>hk` stopped it, including under deliberate buffer-hopping
stress — so the one path headless testing cannot reach (`vim.ui.open`) is
confirmed too, and nothing about this item remains unverified. Two adjacent
facts settled from source the same day: a stale server after a crash is structurally impossible (the server runs
in-process on `vim.uv` and dies with Neovim; `VimLeavePre` also stops all
instances), and serving *two* projects at once is broken upstream regardless
of wrapper — the second bind fails silently (`server.lua` checks neither
`bind` nor `listen`), the plugin still notifies "started", and the port keeps
serving the first project.

**Do not rediscover this and panic:** on Linux the rewritten server cannot
watch subdirectories at all (`server.lua`: `local recursive = jit.os ~= 'Linux'`;
libuv's `uv_fs_event` has no recursive mode on inotify; upstream documents it,
`:h live-server-limitations`), so only files directly in the served root
trigger a reload — `css/style.css` never will. Settled 2026-08-22 as **not a
problem here**: `make` in `bphopkins.net` always runs the phony `smarten`
target, whose script unconditionally `mv`s a rewritten temp over root
`index.html`, which fires the watcher and forces a full reload (not a CSS
injection — the changed name doesn't match `%.css$`). *Corrected 2026-08-22:*
this note previously said responses carry `Cache-Control: no-cache`; that was
the npm-era server. Measured on v0.3.0, file responses carry **no** caching
headers at all — no `Cache-Control`, no `Last-Modified`, no `ETag` — so
nothing marks the stylesheet cacheable across the reload (and CSS-only
injections bust with a `?_lr=` query regardless). Reload there is make-driven
rather than save-driven, and structurally has to be: everything hand-edited in
that repo lives in `src/`, `templates/` or `css/`, and the generated root
`index.html` is the only watched file in the tree. `nousowl.net` is the easy
case — hand-edited `index.html` at root, stylesheet a build artifact never
touched there. Noted in passing: upstream development moved to Forgejo
(`git.barrettruth.com`); GitHub is now a mirror, the pin still fetches fine —
relevant only if the mirror ever lags.

---

**Addendum 2026-09-04 — the page-load stall (upstream; recorded, not
filed).** Clicking around a site under the plugin's server, a page load
sometimes hangs for about a minute. Reproduced headlessly against
`bphopkins.net` with Chrome 152 and Brave 152 driven over the DevTools
protocol, and explained by the server's design: every response is
`Connection: close`, and every page that has the site loaded holds one
never-ending Server-Sent-Events connection (`/__live/events`). Chromium's
back/forward cache keeps the pages just left alive, streams included, and
Chromium allows six connections per host — so in one tab loads 1–5 each leave
a stream behind and load 6 has no connection to use until Chromium evicts a
cached page on its own (50 s in Chrome, 58 s in Brave, measured). Every other
tab open on the dev server holds a stream too, so tabs bring the limit
closer (three tabs: the stall arrives on load 3); a suspended or blocked
Neovim stalls the server outright with nothing to release it. With the
back/forward cache disabled the connection count stays at one and nothing
stalls; a plain static server never stalls even with six tabs open on it. The
site is not involved: production is HTTP/2 with no long-lived connections.

The proper fix is two lines in the plugin's injected client (`CLIENT_JS` in
`lua/live-server/server.lua`): close the `EventSource` on `pagehide` and
recreate it on `pageshow`, so a cached page holds no connection. Workarounds
until then: `brave://flags/#back-forward-cache` → Disabled (global, removes
the stall entirely); or, when it happens, wait about a minute or close that
tab and open a fresh one, which drops all its cached pages at once. Opening
pages in new tabs makes it worse. The wrapper cannot reach the client script,
so nothing changes in `nvim/lua/plugins/live-server.lua`.

## Done ledger (moved verbatim from TODO.md, 2026-08-26)

- [x] **Diagnosed and fixed Neovim's LaTeX editing latency on `fedxps`.** Two separate
  faults, which is why no single explanation fitted both symptoms. (1) A per-keystroke
  tax of **212 ms** at the end of an 1860-char paragraph line, against a `nvim -u NONE`
  floor of 3.6 ms on the same line — attributed by ablation to VimTeX's own matchparen
  (62 ms), blink's `snippets` (33) and `vimtex` (26) sources, the custom syntax cmds
  (29) and base VimTeX syntax (20). Fixed by switching VimTeX's matchparen off *during
  insert only* (its public API, so normal-mode `$…$`/`\begin`/`\left` matching survives)
  and gating blink's two heavy sources on being part-way through a `\command` or inside
  its braces → **13/23/84/54 ms** at 585/1001/1417/1860 chars, a 3–4× improvement.
  (2) A one-shot **22.8-second stall on the first backslash of a session**, reproduced
  live: VimTeX spawns `kpsewhich` once per `\usepackage`'d package (97 of them) and one
  spawn costs ~190 ms here — which is process *startup*, not the lookup. Remedied with
  `bin/vimtex-warm`, which pays it deliberately (`-a`: 38 documents covering all 109
  packages under `~/Desktop`, 90 s, once per machine).
  **Corrections to prior beliefs, all measured:** syntax complexity was *not* the cost
  driver (~14% of the bill, not the bulk); Neovim's built-in matchparen costs ~0 here;
  a TeX Live upgrade does *not* invalidate the kpsewhich cache (risk there is staleness,
  not slowness); and latexmk continuous does not multiply write cost (`$sleep_time` is 2 s,
  so writes coalesce). **Declined:** trimming the custom syntax rules (smallest lever,
  costs semantic colour); changing the `tuned` `powersave` profile, which is deliberate
  despite a measured 2.4× cold-clock penalty on post-pause keystrokes; and any change to
  the auto-save, whose two events turn out to be the *minimum* pair yielding "in normal
  mode ⟹ saved" — `TextChanged` does not fire on Esc, `InsertLeavePre` does not fire on
  normal-mode edits, so neither is redundant (`write`→`update` and debouncing were both
  measured/considered and rejected). New suite `tests/nvim-latency/run.sh` (26 checks,
  hermetic, mutation-verified); one bug in the first version of the fix — `E216` on every
  `InsertEnter` when `vimtex_matchparen_enabled=0` — was found by testing the off case and
  is now pinned by its own check. @done(2026-08-22)

- [x] **Tier 1 of item 5: lock before suspend** (`swaylock` + `swayidle`), plus a `mako`
  notification config — both new stow packages, both verified in a live Sway session.
  **The lock is `before-sleep` only**, with no `timeout` clause, so the no-idle-timers
  posture is structurally preserved; it exists solely to close the measured hole that
  lid-close → suspend → reopen landed on an unlocked desktop. `$mod+Ctrl+l` locks on
  demand. Verified: PAM authentication works (password unlock succeeded under a
  watchdog harness that made lockout impossible), and the lid path now locks.
  **mako:** its `default-timeout` defaults to `0` — never expire — which is why the
  NetworkManager "Connection Established" popup persisted until clicked; now 5 s, with
  `ignore-timeout=1` so a sender asking to persist forever cannot override that, and a
  `[urgency=critical]` section giving persistence back where it belongs. Both configs
  had every key validated against their man pages first, because an unrecognised key
  makes swaylock **exit** — i.e. no lock at all, a fail-open direction. Also learned and
  recorded: **sway is `fedxps`-only**; `bigfed` never boots it, which moots the
  cross-machine caveats in these packages. @done(2026-08-13)
- [x] Inspected `sway/config` end to end and restructured it for readability, plus two
  defect fixes (opened item 5 for the deferred tiers). **Verification:** `sway --validate`
  clean, and — because validate provably does *not* check `bindsym` command bodies — all
  83 bindings were additionally executed against a headless nested sway, giving zero
  parse errors; the restructure was diffed as a normalized *set* of active directives to
  prove nothing was lost (115 before, 115 after, only the intended changes).
  **Fixed:** the `$mod+Shift+Escape` poweroff nag's Cancel button did nothing — per
  `man 1 swaynag` only `-z`/`-Z` dismiss, so `-b 'Cancel' 'true'` ran `true` and left the
  bar on screen; now `-s 'Cancel'` renames the built-in dismiss button, and `-b` became
  `-B` on both nags so neither action can be routed through `$TERMINAL`. Also replaced
  the two hardcoded `/home/bph/` paths with `~` (verified sway expands it — validate
  stats the background path, so a bogus one fails rc=1 while the `~` form passes).
  **Readability:** the live touchpad block was sitting under an `# Example configuration:`
  header with more commented example below it; app launchers lived under `### Variables`;
  the trackpad toggle was orphaned flush-left in no section; a stray `# ~/.config/sway/config`
  comment pointed at exactly the file the header warns against editing. Bindings are now
  grouped by function with the binding grammar stated once at the top, every parked
  decision carries its reason inline, and a "Deliberate omissions" section records the
  declined items. @done(2026-08-13)
- [x] Decided how `reboot-check` depends on repo metadata (was item 4): adopted the
  **hybrid fallback**. Full check first (advisories are a documented input, so repos
  stay enabled); on any unparseable verdict a retry with `--disable-repo='*'` — no
  metadata, no keyring, works with zero cache — reports the core-package verdict
  visibly flagged as degraded. Exit codes stay verdict-matched (rc 2 remains "no
  verdict at all"); the degraded message shrinks its claim to its evidence ("no core
  updates or stale services since boot") and carries the failing call's stderr
  excerpt plus a paste-ready remedy (`dnf needs-restarting`). The service scan runs
  `--disable-repo='*'` unconditionally — dnf5-needs-restarting(8) defines `-s` by
  rpmdb facts alone, no advisory input; measured byte-identical and ~1.2s faster
  (the scan was empty that day, so the man-page definition carries the semantic
  claim). Both calls surface stderr's first line in degraded/[WARN] messages.
  **Live findings that correct this item's original account** (same dnf5 5.4.2.1
  as the incident): with a tty on stdin dnf asks and blocks — reproduced via a pty,
  and the question never even flushes through a captured stdout, so the hang is
  signless; with stdin closed the question lands on *stderr*, EOF declines it, and
  dnf **skips the unverifiable repo and succeeds** — so a declined key no longer
  fails the check (the "declined key → [WARN]" model was wrong), and the hybrid's
  real triggers are hard failures. Degraded path live-verified with a cold cache
  behind a dead proxy: flagged core verdict with the true cause in-line, 2.9s.
  Suite grown to 75 checks, mutation-verified five ways (fallback disabled → exactly
  the 15 fallback checks fail; `-s` repos re-enabled → exactly 1; degraded note
  silenced → exactly 5; each `</dev/null` guard → exactly its own stdin probe).
  Declined: always `--disable-repo='*'` for the main check (silently narrows the
  verdict); rc 2 for a degraded no; prompt-text sniffing (dnf's human text is not a
  contract — and its stream choice proved variable within one day); upstream dnf5
  report (user decision 2026-08-09: local workflow only); any gpushall change — an
  independent audit found the dnf bug class absent from `50-git-sync.sh` (git, ssh,
  and gpg all prompt via `/dev/tty`, so nothing blocks invisibly under capture; the
  vet prompt is `[[ -t 0 ]]`-gated), with two adjacent observations recorded under
  Notes. @done(2026-08-09)

- [x] Retired the `scripts` repo (survey + fold-in). Verdict of the survey: 14 of its
  16 items were regenerable one-offs (OCR/PDF/plot/file-management scripts, a stale
  third-party tweet-deleter) — deleted. Adopted the two keepers: the 153-check
  git-sync regression battery as `tests/gsync/` (suites re-rooted via `CFG_ROOT` so
  they test the checkout they live in, not a hardcoded `~/Desktop` path; verified
  153/153 post-move) and `sysinfo.sh` into `bin/` (stowed). Dropped `scripts` from
  `REPOS_DESKTOP`; local repo moved to `~/Desktop/archive/scripts` with full history
  — the **sole** history copy once the GitHub remote is deleted (planned). Docs
  updated here (CLAUDE.md) and in the Desktop-level CLAUDE.md. @done(2026-08-04)

- [x] Post-sweep self-audit (prompted by "did anything break?"): discovered that every
  headless `nvim` run — the day's test probes and `tests/nvim-syntax/run.sh` alike —
  had been saving a session for its CWD on exit, and the smoke tests had overwritten
  the real `configs` session with a scratch-file buffer (unrecoverable, low-value; the
  next interactive exit in `configs` re-creates it). Deleted the five junk/synthetic
  session files (kept `dissertation.vim` — 7 real buffers, genuine). Added a headless
  guard to `persistence.lua`: an init()-registered VimLeavePre autocmd calling
  `stop()` when no UI is attached. First attempt used VimEnter and **failed** —
  `nvim --headless +qa!` exits before VimEnter fires; the VimLeavePre placement is
  load-bearing. Verified: neither headless exit pattern saves; the syntax suite leaves
  no session; a pynvim `ui_attach` instance (interactive-equivalent) still saves
  normally. @done(2026-07-26)

- [x] Staleness sweep of `nvim/` (full-directory audit). Removed the 8 dead
  `vimtex_*` settings from `vimtex.lua` — 7 (`root_markers`, `texmf_home`,
  `includegraphics_search_paths`, `complete_{recursive_bib,input_paths,scan_files_depth}`,
  `include_search_paths`) were never VimTeX options at all, and `compiler_progname` was
  deprecated upstream in 2021. Verified inert three ways: grepped every installed plugin,
  the whole config, and `~/Desktop` scripts for readers (none); confirmed absent from
  VimTeX code *and* docs; diffed VimTeX's resolved runtime state on a dissertation
  chapter before/after (identical — root/main-file detection was always VimTeX's own
  heuristics). Widened persistence autoload from the six-root allowlist to any CWD under
  `~/Desktop` — sessions were already saved for every CWD (80 on file, incl. Carnap,
  LogiKEy, org subdirs) and `<leader>qs` already restored anywhere; the list gated only
  empty-start autoload. Verified end-to-end in a scratch dir (save → autoload-restore →
  negative control outside Desktop). Everything else checked healthy: syntax regression
  suite 24/24 before and after; snippet `--check`/`--coverage` clean; treesitter
  `highlight.disable` still honored by LazyVim's `main`-branch shim (and no latex parser
  installed — double protection); headless startup clean; new `after/syntax/` live via
  the existing `after` symlink (no restow needed); `nvr`/`pandoc`/`live-server`/`latexmk`
  all resolve; lockfile matches installed plugins. `lua/plugins/inactive/` kept
  deliberately (parked experiments, per session decision). Same-day follow-up resolved
  the stylua question: it is *load-bearing* — LazyVim format-on-save (conform → Mason's
  stylua) formats Lua on every in-editor save, which is why the tree was mostly clean;
  the 4 drifted files had last been written outside Neovim. (Headless probes first made
  it look inactive: LazyVim registers format-on-save in its VeryLazy callback, which
  never fires under `--headless` — firing it manually proved the chain.) Formatted the
  4 files via CLI (verified byte-identical to what an in-editor save produces), added
  `nvim/.styluaignore` for the 2 generated snippet files (verified honored by both CLI
  walk and editor path), restowed, corrected CLAUDE.md's formatter docs; `--check` now
  clean. @done(2026-07-26)

- [x] Follow-ups to item 2, same day: `--coverage` mode in the snippet generator
  (cross-references the `.sty` against `vimtex.lua`'s registrations; wired into the
  auto-regen notification, so a new macro without highlighting is flagged on next
  Neovim start); committed the 24-check headless syntax regression suite as
  `tests/nvim-syntax/run.sh` (verified both green and red paths); env snippets no
  longer emit macro-valued optional defaults (`\proof~` dropped its redundant
  `[\proofname]`). @done(2026-07-26)

- [x] Optimized the `french-logic.sty` ↔ Neovim interplay (was item 2). **Coverage:**
  registered the ~60 unhighlighted commands (affirm/deny family, metalanguage
  connectives, `\by`/`\close`/`\infr`/`\hyphantom`, `Rup`/`Rdown`/`Lup`/`Ldown` order
  conditions, `cax`/`Kfour`/`Kfive`/`Kfourfive`/`EN`/`Rlog`, `r[me]?poss` rules, `qed`,
  `tuple`, `precedes`, `metalogic`, `incomp`, I/O connectives) — now 504/509 covered,
  the 5 exclusions deliberate and documented. **Environment names** coloured by family
  via a new `after/syntax/tex.lua` (theorem-family orange, proof/derivation magenta,
  lists default cyan); gentzen math-region registration deliberately skipped (retired
  notation, per session decision). **Three latent bugs found and fixed:** (a) every
  `re()`/`mre()`/`mare()` pattern registration had been silently dead — VimTeX drops
  `cmdre` entries without `name`; all 31 patterns now have group-name slugs and were
  runtime-verified; (b) `argstyle` never accepted highlight groups, so all intended
  argument colouring was dead — replaced with `arglink()` + explicit links applied in
  the ftplugin; (c) an unguarded `serverstart("/tmp/nvimsocket")` aborted the whole
  vimtex `init()` in any second Neovim instance — now `pcall`ed. **Rebalance:**
  `texCmdRule` dark5 → TokyoNight purple (hue-tied to the magenta proof envs).
  **Snippets:** generator now parses `\newtheorem` (11 new env snippets incl.
  `definition`/`theorem`) and env optional args (`proofsketch[Proof sketch]`), stamps
  the `.sty` sha256 into the output, and gained `--check`; `snippets.lua`
  auto-regenerates on stamp mismatch at LuaSnip load (chosen over hook/manual
  options). Verified by a 24-check headless suite plus a live dissertation-chapter
  smoke test (`\CMr` → axiom gold). @done(2026-07-26)

- [x] Configure markdown-tasks.lua(s) to handle all of the following:
    - mt - toggle `[ ]/[x]`
    - md - toggle marked done
    - ms - toggle marked started
    - mD - toggle both `[ ]/[x]` and done
- [x] Configure markdown_tasks.lua(s) to either (a) generate a TASKS.md file with all open tasks in a directory, or (b) write a bash script/function that accomplishes the same thing. @done(2025-11-25 09:16)
- [x] Initialize `~/.bashrc.d` directory and split up aliases and functions. @done(2025-11-24 21:28)
- [x] Update Neovim README when the dust settles @done(2026-03-20)
- [x] Full staleness survey of the repo; fixed the README's missing `bin` package, corrected the Sway accent colour in the docs, cleared stale `.bak`/`.save`/diff artifacts, guarded the dead bun PATH entry @done(2026-07-26)
- [x] Consolidate homegrown scripts into `bin/`: moved `okular-forward` / `okular-inverse` from `~/.local/bin`, verified resolution is unchanged. Left `~/bin/isabelle*` untracked — generated by `isabelle install ~/bin` @done(2026-07-26)
- [x] Add an `okular` stow package for `okularpartrc`, excluding `okularrc` and `docdata/`; confirmed over two write cycles that Okular does not break the symlink @done(2026-07-26)
- [x] Four-lens adversarial audit of the git-sync rewrite (independent reviewers: control flow, bash semantics, git semantics, test blind spots) after a return-status bug reached production. Fixed everything found: unborn-branch guard bypass (gpush could root-commit a fresh `git init`), fail-open vet listing (now fails closed), `:(literal)` unstaging with post-verify (leading-colon/glob filenames could dodge a decline), rename/typechange vet bypass (`git mv x .env` now vetted), embedded-git-repo detection, per-component secrets matching (`.env/` dirs), `REVERT_HEAD` in-progress guard, dropped `--tags` from pulls (force-moved tag wedged every sync), `gpushall` parser (`-f` no longer commits 13 repos with message `-f`; multi-word positional messages no longer truncate), offline no-upstream PEND, push-path integrated-changes reporting + hints (silent fast-forward fixed), rebase-abort verification, prompt context duplicated to stderr under capture, `GSYNC_MAX_MB` validation, exact-ref `ls-remote`. Regression suites grown to 153 checks in four files. @done(2026-07-26)
- [x] Overhauled the git-sync commands (was item 1): collapsed the gpull/gpullall and gpush/gpushall duplication into shared `_gsync_pull_repo`/`_gsync_push_repo` helpers; added new-file vetting (size via `GSYNC_MAX_MB`, secrets globs, y/N prompts), listing of first-time-committed files, an in-progress rebase/merge guard, auto-abort on rebase conflict, offline-aware pushes (commit locally, mark pending), non-main-branch warnings, compact colorized output with named-repo summaries, multi-name `gpull`/`gpush` with `-m` and tab completion, a `gstatall [-f]` dashboard with per-repo sync verdicts (needs push / needs pull / DIVERGED), a post-pull ahead-of-origin warning, post-pull re-source/restow hints, and removal of the redundant pre-pull fetch (~half the network round-trips). Verified by a 37-check sandbox suite plus a live `gstatall`/`gpullall` run. @done(2026-07-26)

---

## 11. Per-window cgroup scopes after the Ghostty launcher change

Opened 2026-09-03, closed 2026-09-05. **Verdict unchanged — `linux-cgroup =
always` stays declined — but the reasoning the item gave for it was wrong and is
corrected here.**

**What was measured.** Under `--gtk-single-instance=true` a shell sat in
`app-ghostty-surface-transient-13234.scope`, a per-surface scope Ghostty creates
itself. Under the sway launcher's `--gtk-single-instance=false` the shell shares
`app-com.mitchellh.ghostty-17355.scope` **with the GUI process itself** — the
launcher's scope, named for the GUI's pid. So the item's expectation is
confirmed: with one process per window, the window is the cgroup. (The item
predicted the GNOME name `app-gnome-ghostty-<pid>.scope`; on sway it is
`app-com.mitchellh.ghostty-<pid>.scope`. Same structure, different launcher.)

**The correction.** The item argued the arrangement is fine because the window
scope "is the unit `systemd-oomd` acts on". **`systemd-oomd` is inactive on
fedxps.** Three readings settle what actually happens:

| | value | consequence |
|---|---|---|
| `systemctl is-active systemd-oomd` | inactive | no pressure-based, cgroup-level killing |
| `memory.oom.group` | `0` | an OOM kill takes one process, not the scope |
| `MemoryMax` | `infinity` | no cgroup bound is in play at all |

So a runaway is handled by the kernel OOM killer picking a single process
system-wide, not by anything cgroup-aware. Per-surface scopes with no limit and
no cgroup reaper are bookkeeping, and `linux-cgroup = always` would cost the
man page's ~100 ms per window to buy nothing observable. The verdict survives;
its justification changes from "the scope is what oomd acts on" to "nothing
cgroup-aware is running to act on it".

**The one variant with teeth is ruled out separately.**
`linux-cgroup-memory-limit` would give each surface a hard `MemoryMax`. That
contradicts an existing recorded policy: `n-cube/notes/isabelle-notes.md`
records that `systemd-run --scope` breaks Isabelle's prover-subprocess spawning
and `ulimit -v` breaks JVM startup, and settles on running **uncapped** with a
process-RSS guardian at ~12 GB. A per-surface cap would be a third capping
mechanism at the wrong layer, and below ~12 GB it would kill runs that policy
intends to allow. Note this is about the *cap*, not scope membership: terminals
already run inside a launcher-made scope (`Delegate=no`, `TasksMax=18924`) and
Isabelle is fine there.

**Premise revised.** The item recorded "one window per task through the WM
rather than terminal tabs or splits (measured 2026-09-03)". He uses tabs
occasionally (2026-09-05), so per-surface and per-window do not partition
sessions quite identically — but the reaper findings above decide the question
regardless.

**Trigger for revisiting:** enabling `systemd-oomd`. Per-surface scopes stop
being bookkeeping the moment something cgroup-aware is choosing victims; the
memory limit still would not follow.

Full context: `docs/ghostty-vs-wezterm-2026-09-03.md`, Addendum 1 "Open" and
Addendum 2.

## git package, and `~/bin` becomes stow-only — 2026-09-07

Opened and closed the same day, inside the home-directory audit recorded at
`org/machines/home-audit-2026-09-07/`.

**The problem.** `~/.gitconfig` was the one shell-level dotfile not managed
here, and the two machines had drifted: fedxps rewrote `https://github.com/`
to SSH, bigfed carried only an obsolete `git://` → https rewrite. Git reads both
the XDG file `~/.config/git/config` and the legacy `~/.gitconfig`, and the
legacy one wins on conflicts — having both is what made the state confusing.

**Decision.** One home, `~/.config/git/`, stowed from the new `git` package:
`config` (the SSH rewrite, `user.useConfigOnly = true`, an `[include]` of
`~/Desktop/org/claude-config/git/identity`) and `ignore` (the two Claude
patterns, commented). Identity lives in that private include so no public file
carries the address. `~/.gitconfig` is deleted on both machines.

**Measured before deciding.** A missing include is ignored silently by git, and
with `useConfigOnly` that silence becomes a refusal to commit. `git config
--global` writes *through* the stow symlink into the repo copy — the symlink
survives — so a setting made that way would be published by the next
`gpushall` (now a root-charter pitfall).

**Declined.** Stowing `.gitconfig` itself at `~` (keeps the legacy file that
outranks the XDG one and invites a second file); per-machine identity files
(two hand-kept copies, the drift that started this); aligning by hand with no
package (nothing enforces it).

**The other-machine step.** After the pull: `reload && rm ~/.gitconfig
~/.config/git/ignore && stow-all` — the real `ignore` file conflicts with the
package, and the legacy file must go or it keeps winning.

**Same day, same audit.** `~/bin` is stow-only: the hand-made launchers that
had accumulated beside the stow links (thirteen on bigfed, two on fedxps) moved
to `~/.local/bin` as symlinks under a tool-homes convention (`~/opt/<Tool>`,
`~/src/<tool>`); `bin/CLAUDE.md` and README §2 and §8 say so. And
`80-clamav.sh`'s setup line now names Fedora 44's `clamav-freshclam`; bigfed,
which had no clamav at all, was given it.

## 13. french-logic: the map, the unit split, the rendering suite — COMPLETE 2026-09-08

Moved here from the map (`latex/french-logic/README.md`, *Open ledger*) on
2026-09-08, when the last of the per-unit ordering passes closed the
reorganisation the ledger tracked; the map keeps one line per item. The map is
the package's living contract, the inventory `AUDIT.md` beside it is generated,
the item closed in `TODO.md` on 2026-09-08 (its checklist is at the foot of
this entry), and the four chats' briefs
(`docs/french-logic-campaign-2026-09/next-chat*.md`) are the dated records of
how each item was decided — the first chat on 2026-09-07 (audit, harness,
suite, map, split, the D items, the faces and labels by eye), the second on
2026-09-08 (the verification against the pre-split package, D14–D15, the
naming grammar), the third on 2026-09-08 (D16, the dates, the charter, the
ordering passes), the fourth on 2026-09-08 (the closing forms, the policy
verdicts, the v1.0 release).
Defects are numbered D, form drift F; the text below is the ledger as it stood
when it moved.

- **D1** orphan `\makeatother` at the end of the theorem block, and the
  citation-block comment that blamed `\ExplSyntaxOn` for it. *Fixed
  2026-09-07.*
- **D2** U+2019 in the `modal` TikZ style's arrow tip. *Fixed 2026-09-07;
  `stealth'` kept, plain `stealth` and arrows.meta `Stealth` verified as
  alternatives.*
- **D3** `\usepackage` for microtype inside the package. *Fixed 2026-09-07,
  in place: the load stays with the STIT code that needs it.*
- **D4** the signed-formula `\af`/`\de` family needs `relsize`, which nothing
  loaded; fourteen members failed in both modes. *Fixed 2026-09-07: relsize
  loaded beside ebproof, where the code lives.*
- **D5** `\DeclareSymbolFont{stmry}` re-declared stmaryrd's symbol font and
  dropped its bold version; `\Yright` re-declares stmaryrd's identical symbol.
  *Resolved 2026-09-07: the font line removed; the `\Yright` declaration
  kept by decision — the sequent arrow is Humberstone's convention and the
  line is its record; `\shortminus` kept, it backs `\unneced` and
  `\unpossed`.*
- **D6** `\IOfn` set bare `\tiny` in a superscript; seven warnings per
  dissertation build, and the label came out at script size. *Fixed
  2026-09-07: first `\text{\tiny\textsf{H}}`, the size the definition asked
  for, then, with the labels pass, `{\scriptscriptstyle\mathsf{H}}` — the
  scaling size, sans because the name is a frame class; the IO-logic chapter's
  23 sites match `\IOhn`'s label height.*
- **D7** `\renewcommand{\qed}` broke `\qedhere` in display math (51 errors
  against 0 for the amsthm original), failed to load under `deon` when
  amsthm came later, and left a ■ orphaned at the left margin on printed
  page 71. *Fixed 2026-09-07: the house placement rebuilt on amsthm's
  mechanism — math branch amsthm's, text branch flush right with no `\quad`
  and no break before the mark — applied only when amsthm is present;
  `proofsketch` takes its □ through a local `\qedsymbol`, so `\qedhere`
  works in sketches. Two dissertation pages changed, as intended.*
- **D8** aliascnt was obsolete on the 2026-06-01 kernel, whose `\newtheorem`
  uses `\newcounteralias`. *Fixed 2026-09-07: plain `\newtheorem{x}[theorem]`
  for the ten kinds, the `\crefname`s kept, and a `\PackageError` on any
  older format, since one would silently print "theorem" for every kind.
  fedxps carries a 2026 TeX Live tree. No page changed; the warning is gone
  from every consumer.*
- **D9** the IO-logic beamer decks passed the removed `conflicts` option, and
  under `deon` then hit the enumitem-under-beamer recursion the completeness
  deck had worked around in its own preamble. *Fixed 2026-09-07: the package
  carries the four-line `\setlist` shim, guarded on beamer, beside enumitem;
  the two decks now pass `deon`. Both build again (27 and 24 pages); the
  completeness deck's copy of the shim is now redundant.*
- **D10** `block` sat inside the amsthm guard though it needs nothing there.
  *Fixed 2026-09-07: defined after the guard, only when no class already
  provides a `block`, with a log note otherwise.*
- **D11** apparent no-ops. *Resolved 2026-09-07: the four `\!\,` kerns
  removed (exactly zero glue). The `proof` renewal, byte-identical to
  amsthm's, and `\renewcommand{\to}`, identical to the kernel's, are kept
  and commented as pins: they declare the two as members with a house form,
  and are why they appear in the inventory and the snippets.*
- **D12** `\ProvidesPackage` carried prose where a date belongs. *Fixed
  2026-09-07: `[2026/09/07 Semantic markup for logic]`; a version number
  comes with the hub-and-units release.*
- **D13** the `% !TEX root` line tied the shared package to one consumer by an
  absolute path. *Resolved 2026-09-07: relative (`../../../dissertation/…`),
  measured to resolve from the repo path and through the texmf symlink alike;
  a tilde path does not resolve. The line exists so that compiling or viewing
  from the package buffer acts on the dissertation; nothing else reads it.*
- **D14** the inventory generator took the last line of a multi-line comment
  as a group heading, so AUDIT.md showed prose fragments as headings, and a
  first group with no heading lost its table header row. *Fixed 2026-09-08: a
  heading is a `%%%` line, or the first line of a run of `%` lines, short and
  not a sentence; the conditional unit's family headings appear for the first
  time; the 543 member rows are unchanged.*
- **D15** the mode table was not re-censused after `\Lc` gained its wrapper,
  so the golden had no text page for it. *Fixed 2026-09-08: recensus (one row
  changed), golden re-accepted at 836 pages.*
- **D16** the stit unit loaded microtype with `[tracking=smallcaps]`, so a
  document that loaded microtype itself before the package failed with an
  option clash (compiled and seen 2026-09-08; no consumer does it). *Fixed
  2026-09-08: microtype loaded bare, `\microtypesetup{tracking=smallcaps}`
  after it — pixel-identical to the option form at 300 dpi, where tracking
  off differs by 2723 pixels; both nets clean; the microtype-first document
  compiles.*
- **F1** mode, face, and naming drift as listed under *Conventions*. *Mode, face, labels, decorations, and structure indices settled 2026-09-07;
  the naming grammar settled and landed 2026-09-08 (59 renames); the ordering
  passes landed 2026-09-08, core first and the thirteen others the same day.
  Closed.*
- **F2** four hand-copied eight-line bodies (`\cnecs`, `\cposs` and their solo
  forms) that were `\condop` with a different glyph and two kerns; two
  identical theorem styles; two near-identical reflexive loop styles. *Fixed
  2026-09-07: one builder `\fl@dyad` with each operator's six tuning numbers,
  one style body under three names, one loop with two defaults; proved
  identical on every net, the diagram included.*
- **F3** header hierarchy, blank-line runs, trailing whitespace, lines over
  100 characters. *Resolved 2026-09-07 by the split; the residue inside the
  units went with the ordering passes on 2026-09-08: the old headers, the
  indents left by the old `\ifdeon` block, the trailing whitespace. The lines
  still over 100 characters are definitions, kept byte-identical. Closed.*

Decisions closed 2026-09-07: the option design (above); hyperref keeps its
defaults, a document that wants otherwise sets `\hypersetup` itself;
`geometry` stays with the documents, where every consumer already sets it.
The opuscula drift was recorded in that repo's inventory (finding 10) on
2026-09-07 and left as it is. The ordering passes and the dissertation
charter's package section both closed on 2026-09-08.

**Post-mortem, 2026-09-08.** Four chats over two days. *Built:* a private
consumer harness that rebuilds the 27 documents loading the stowed package
from scratch against any candidate and compares them page by page (text,
warnings, pixels, side-by-side images), with the heavy steps runnable on
bigfed over SSH; a public rendering suite that typesets every member on its
own page in every mode it survives and hashes it against a golden (836 pages),
compiles the fixture under both option bundles, loads each unit alone, and
regenerates the inventory; the map as a living contract; and the package as a
hub over fourteen units plus a never-loaded quarry, every line of the old
single file placed by multiset, every unit ordered under one comment grammar,
released as v1.0. *Decided,* each by eye on the type board or in an ask with
its five parts: the mode policy; the faces (rule β); the scaling label idiom;
italic structure indices; scaling decorations; the option design with `deon`
and `slim`; the strict naming grammar, 59 renames substituted with no aliases;
the dates rule; the comment grammar; and, at the close, the converse *c* and
the T on SDL as decorations, the per-letter kerns kept, four forms normalised
(`\mcslog`'s trailing space, `\unneced`'s zero-glue chain, five
`\newcommand*` unstarred; `\emptytruthset` kept on the ask, then its kerns
dropped on the confirmation pass the same evening) and four policies recorded
(the unused furniture, `\graphicspath`, `slim` kept; `philogic.sty` out of
scope). Sixteen defects and three form drifts fixed, each proved on both nets;
the pre-split package was compared page by page with the result and the
differences were exactly the deliberate list. *Declined:* deleting any member
(principle 1: unused members are vocabulary); a pure tower split, which would
separate correspondence pairs; aliases for the old names; trimming the
preamble's unused furniture; renaming the dyadic operators so that `solo`
appends everywhere (the trailing *s* is the verb's, "conditionally
necessitates"); and the standing "whatever your reading turns up" item, which
would have made the brief chain never-ending. *Deferred* to item 14: deriving
the template's `philogic.sty` from the units, and one command for a connective
that spaces itself by context. One census correction: the hand-kept
`usage.tsv` carried two opuscula documents' own `\SDLt` under the package's
`\SDLT` until 2026-09-08.

*The confirmation pass* (2026-09-08, evening): every choice re-photographed
from v1.0 on the type board, thirty-three in a ledger. Thirty confirmed;
`\emptytruthset` reversed to the open dot; and two notes became a sixth
sitting — the decorations had lost their `\mkern-2mu` tuck in the scaling
conversion (measured at 600 dpi: the whole 1.33 pt difference, the design
size contributing nothing), restored as `\mkern-3mu` inside the script on the
ten decorated members, the old gap at every size; and the SDL names took the
old 2 pt tuck into the L's void, on `\SDLT` and `\SDLplus` alike. Harness:
24 dissertation pages and their wrappers moved by hair widths, no page count
changed. Left as a fine-tune (item 14): the decoration kern's value, −3 mu
landed against a suspected −2 mu.

**The tracker's checklist for item 13, moved here verbatim at the close:**

- [x] Audit the single-file package end to end; build the consumer harness
  (scratch copy of the dissertation and its siblings, page-by-page diffs) and
  the rendering suite `tests/french-logic/`. @done(2026-09-07)
- [x] Write the map (`latex/french-logic/README.md`) and the inventory
  (`latex/french-logic/AUDIT.md`). @done(2026-09-07)
- [x] Work the open ledger in the map, one item at a time, each verified by
  both nets before it lands. All thirteen D items closed 2026-09-07; D14–D16
  and the three F items by 2026-09-08; the ledger then moved to
  `DECISIONS.md` item 13. @done(2026-09-08)
- [x] Verify the first chat's work on fedxps: both nets, the snippet checks,
  and a page-by-page comparison against the pre-split package (`145aad8`) —
  the differences were exactly the deliberate list. @done(2026-09-08)
- [x] D14 the inventory headings; D15 the mode table re-censused for `\Lc`
  (golden 836 pages). @done(2026-09-08)
- [x] fedxps could not run the harness's `compare.py` from the system Python:
  Pillow was missing; installed from the Fedora package. @done(2026-09-08)
- [x] Split the package into the hub and the unit files the map plans, output-
  identical under both nets; extend the snippet generator to read the units.
  @done(2026-09-07) — fourteen units plus the quarry; no differences across
  27 consumers, no changed fixture page.
- [x] The F items decided by eye on the type board and landed: mode, face
  (rule β), small labels (idiom A), decorations, structure indices, the three
  folds. @done(2026-09-07)
- [x] The naming grammar: decided strict on 2026-09-08 (substituted, no
  aliases) and landed in two rounds the same day, 59 renames, each proved on
  both nets and the harness run on bigfed. @done(2026-09-08)
- [x] The compute-heavy harness steps run on bigfed over SSH
  (`french-logic-harness/remote.sh`: push, suite, census, compare, fetch);
  settled 2026-09-08. @done(2026-09-08)
- [x] Verify the second chat's work on bigfed: both nets, the snippet checks,
  the syntax suite; the map's duplicate split, consumer count and two retired
  names in the unit table corrected. @done(2026-09-08)
- [x] The core ordering pass: 156 members in tower order, every definition
  byte-identical, both nets clean; the comment grammar recorded in the map.
  @done(2026-09-08)
- [x] D16, the stit unit's microtype load: bare, with the tracking set after
  it; pixel-identical, and a document that loads microtype first compiles.
  @done(2026-09-08)
- [x] A unit's `\ProvidesPackage` date is the date of its last change; io,
  modal and conditional dated for the renames. @done(2026-09-08)
- [x] Per-unit ordering passes for the thirteen other units: every definition
  byte-identical, the old headers and indents gone, one comment grammar, both
  nets clean. @done(2026-09-08)
- [x] The closed D and F items moved from the map's ledger to `DECISIONS.md`
  item 13, verbatim; the map keeps one line each. @done(2026-09-08)
- [x] Conclude the campaign: every remaining candidate to a dated verdict
  (landed, or left as it is), the version number on the hub, item 13 closed
  into `DECISIONS.md`, the four briefs moved to a campaign directory under
  `docs/`, no successor brief. @done(2026-09-08) — the converse c, the T on
  SDL and the kerns decided on the board's fifth sitting; four forms landed
  and four policies recorded from one batched ask; v1.0 on the hub; the four
  briefs in `docs/french-logic-campaign-2026-09/`.
- [x] `dissertation/CLAUDE.md`, the package section: rewritten on his say-so
  for the hub and units, the option design, the counter aliases, the stow
  path and the new names. @done(2026-09-08)
- [x] Decide the option design, the two IO-logic beamer decks, `\hypersetup`
  and `geometry`. @done(2026-09-07) — one keyval switch per unit with `deon`
  and `slim` bundles; the decks pass `deon` and build; hyperref defaults kept;
  geometry stays with the documents.
- [x] The opuscula drift: recorded as finding 10 in opuscula's AUDIT.md and
  left as it is; no version of the package builds them. @done(2026-09-07)

Opened 2026-09-07, closed 2026-09-08. The four chats' briefs, each annotated
at its head with its successor and the last with "no successor", are the
dated record in `docs/french-logic-campaign-2026-09/`. The package is a
semantic markup language for logic; the governing principles (nothing deleted
without an accepted case, dependencies ride with the code, one package with
unit files, a preamble by default) are recorded in the map, which is the
living contract — read it before touching `latex/french-logic/`. Run
`tests/french-logic/run.sh` after any edit there.

## nvim/LaTeX: treesitter, keystroke cost, and the completion layers — 2026-09-12

One session that began as "explain treesitter in my config" and ended in
measurements. Verdicts, each with its number:

- **Treesitter stays off for TeX, and the port is declined on measured
  grounds.** The pinned tree-sitter-latex grammar was built in a scratch
  directory and run over the dissertation and opuscula (149 files): 219 of
  the dissertation's 224 error nodes are `\item[(\Kax)]`-style labels, whose
  brackets admit bare words only (313 such labels; a label macro would satisfy
  it). Optional arguments on custom commands detach their mandatory groups in
  the tree, but the only bracketed use is `\tcite`. A french-logic signature
  is expressible in a query (the stock query already partitions commands by
  name), and incremental re-parse of the longest line costs under 2 ms; none
  of that is needed while there is no speed case. No latex parser has ever
  been installed here; `treesitter-tex.lua`'s disable entry is a second lock
  (its header now says so — it used to claim indent and textobjects "remain
  available", which with no parser they never were). The latency suite already
  pins "no treesitter highlighter" on the fixture.
- **The fedxps latency residual was the power mode, not the engine.** Every
  August number was taken in Power Mode power-saver (tuned `powersave`, EPP
  `power`, clocks pinned at 900 MHz). Same bench, same 1841-char line,
  2026-09-12: bigfed 4 ms; fedxps performance 7, balanced 8, power-saver
  17–21 (p50); by line length under balanced 7/12/13/8 against the August
  13/23/84/54. A pure regex microbench puts the laptop at 1.9× bigfed. The
  August→today gap *within* power-saver is unexplained (battery vs mains and
  config drift are the candidates). Verdict: write in balanced or performance
  mode; there is nothing to gain from engine work for speed on either machine.
- **Syntax cost, measured with `:syntime`.** The 250 custom rules are ~60% of
  syntax time; VimTeX's two Unicode character classes ~18% and colour nothing
  in an ASCII-typed source — `g:vimtex_syntax_match_unicode = 0` applied in
  `vimtex.lua`. Merging same-group custom entries into one alternation per
  family (250 → 73 rules) measured no reliable gain: the cost is matching
  work, not rule count — don't retry. Disabling VimTeX's package syntaxes also
  disables the custom layer (it is applied when a package syntax loads). VimTeX
  is bound in one place only: math-zone detection reads the syntax stack, and
  delimiter objects, `%`, math insert maps, matchparen and completion consult
  it, so the base syntax stays whatever hosts the colour layer.
- **VimTeX's candidates left the completion menu.** Its command rows are bare
  names (the scanner keeps a definition's name, never its arity), so each
  duplicated a snippet with less in it; and since the package's hub-and-units
  split it offered no french-logic command at all — it scans only the hub, and
  takes the package list from the chapter's article-wrapper `.fls`, dated
  2026-08-18. Felt annoyance was the 2026-08-22 revisit condition. Filtering by
  kind was verified possible (blink's `transform_items` on the provider;
  cmp-vimtex stamps VimTeX's kind string on each row) and **dropping the whole
  source** chosen instead; the cost, `\cite{` and `\ref{` rows, accepted, with
  VimTeX's omnifunc kept wired for `<C-x><C-o>`. cmp-vimtex and blink.compat
  parked as `enabled = false` fragments. The latency suite's six vimtex-provider
  checks became: no provider, no source list names it, omnifunc wired, gate
  open inside `\cite{`/`\ref{` (38 checks, unchanged in count). A consequence
  for the cold-cache rule: typing no longer triggers VimTeX's kpsewhich scan.
- **texlab stays declined, with the reason recorded.** Read in its source: its
  command items are bare names too (snippet format only for `\begin` and
  paired delimiters); it would follow `\RequirePackage` into the units via
  kpsewhich's TEXMF roots and collect every command token it sees, internal
  macros included. Label and citation navigation is the only thing it would add.
- **Twelve duplicated snippets removed** from `latex-workshop.lua` (the seven
  theorem environments, `\proof`, `\emptyset`, `\qedsymbol`, `\remarkqed`,
  `\sketchqed`; byte-identical to the generated ones, showing as doubled menu
  rows). Rule: the generic file must not carry a name the generator emits;
  `comm -12` over the two `trig =` lists finds any recurrence.
- Open, tracked in `TODO.md`: the gate's brace branch now serves only
  `\begin{`; inside `\cite{` it fuzzy-matches snippets against the key.

Records: `nvim/CLAUDE.md` (three clauses), `docs/insert-latency-2026-08.md`
(addendum), `tests/nvim-latency/README.md` (reference-table note and the
`--file` duration trap).

## nvim/LaTeX: completion rebuilt on TeXstudio's model — 2026-09-13

Two planning chats (2026-09-12 and 13) and five build chats (2026-09-13), all
on fedxps. The LaTeX completion layer of `nvim/` was rebuilt on TeXstudio's
model: one snippet library per package, generated from TeXstudio's completion
word lists and from this repository's french-logic package, loaded per document
from VimTeX's package table; VimTeX's argument completers in the same menu
through blink's built-in omni provider; TeXstudio's context behaviours; and a
record trail. The plan is `docs/latex-completion-campaign-2026-09/PLAN.md`,
annotated closed 2026-09-13 – section 1 is the full form of every verdict
below, section 2 the rules as built, section 3 every measurement, section 9 the
spikes – with the comparison record `comparison-2026-09-12.md`, his study
`texstudio-summary.md`, the briefs (`next-chat*.md`, each annotated at its
head with its successor) and the probes (`spikes/README.md`) beside it. TODO
items 8 and 15 closed with it (below). The generated data is 4,419 files under
`nvim/lua/snippets/pkg/` (38 MB on disk) and 15 under `sty/`; the suites are
`tests/snipgen` (22 checks), `tests/nvim-latency` (71) and `tests/nvim-syntax`
(56), all green on fedxps at the close. bigfed is pending: its twin clone and
its stage-4 numbers are the successor brief's queue, to be annotated here when
they land.

Verdicts, each asked with its measurement or measured in a spike;
comparison-record sections in brackets.

- **The source is the cwl corpus, whole.** Only `#S` (hidden) and `#B`
  (colour-name) rows are dropped, the two TeXstudio's completer hides. The
  LaTeX Workshop file was a lossy copy of a tenth of the data (2.4); the corpus
  adds about 450 missing math commands (2.5) and named placeholders, and its 13
  wrong arities and 21 artefacts vanish by construction. Every one of the 4,524
  cwl files is converted, no package list and no `.fls` tracing on any machine:
  TeXstudio compiles all of them into its binary, and the years of old
  documents on bigfed need no step of their own. Excluded by rule:
  expl3-commands, and any file with neither a row nor an `#include` outside
  option blocks (104, fontenc among them); a file with only includes is
  generated so the loader can follow them, and inputenc keeps its four rows.
  Weight, measured before his call: 24 MB of cwl becomes 29.3 MB of Lua (38 MB
  on disk, `logix.lua` the largest at 392 KB) against a 4.35 MiB pack, about
  11% of files change a year, `--all` runs in 4.3 s. The earlier draft that
  traced about 200 packages from this machine's `.fls` files is declined.
- **`pkg/` is committed to the public repo, with attribution.** His call. Every
  generated file names its cwl source, its sha256, the clone's commit and date,
  and carries the cwl's own leading comment block, which credits its authors;
  `pkg/NOTICE` states that the data derives from TeXstudio's word lists (GPL-3)
  and `pkg/COPYING` is the licence text from the clone. He commits, nothing
  here commits; `gpushall` prompts only for a file over 25 MB or matching a
  secret glob, so the first push should list the 4,419 files once and ask
  nothing (the largest is 392 KB; the push itself had not happened at the
  close). Because the files travel by the normal sync, bigfed needs no clone;
  regeneration and `--all --check` run where the clone exists
  (`~/Desktop/texstudio`, pulled `--ff-only` by hand, at `0362907c2`
  throughout).
- **One file per package, loaded per buffer.** Each file carries an `includes`
  header (the cwl's `#include` lines). The loader is LuaSnip's filetype
  function: on the request path it reads `b:vimtex.packages` and the document
  class (0.09 ms), adds the always-loaded core three (tex, latex-document,
  latex-dev), closes over the headers transitively and registers a file once
  per session under `pkg-<name>`, so a definition appears once however many
  packages carry it (3); a package table refreshed by a compile is seen at the
  next request. The filetype order decides which of two identical rows wins:
  `tex`, the hand file, the document, the core three, the class, the closure in
  walk order. Files are read by path with `dofile` (names carry dots). A name
  with no file is skipped silently and named by `:SnippetsReport`;
  `:SnippetsReload` re-reads everything and cleans LuaSnip's invalidated rows
  (spike: without `clean_invalidated({ inv_limit = 0 })` the old rows stay
  listed).
- **The french-logic files come from the `.sty`, into a sibling directory
  `sty/`.** The old generator's parsing moved into `snipgen.py --sty`: one file
  per unit plus the hub, the hub's includes naming its 14 units and each unit's
  its own requires, so the closure is the loader's transitive walk as for every
  cwl file – TeXstudio's own answer for a package without a list, and the
  fallback whenever there is no fresh `.fls`. A sibling directory because
  `--all` deletes any `pkg/*.lua` without a cwl source and `pkg/NOTICE` claims
  GPL-3 over that directory, and both stay exactly true. Read: the braced
  `\newcommand` family, `\newenvironment`, `\newtheorem`,
  `\DeclareMathOperator` and `\DeclareMathSymbol` (`\Yright`, `\shortminus`,
  `\strictif`, math-wrapped by construction); `@` names skipped; 544 rows over
  540 names, the old 537 plus the three symbols, no trigger with `~`. An
  optional argument gives two rows, the bare and the bracketed: his usage is 93
  bare `\tcite` against 40 with a locator, 8 against 0 for `\pcite`, 42 and 15
  bare proof and proofsketch against none bracketed, so the old single row with
  its bracket always inserted was being hand-corrected. No deduplication
  against the core three for `.sty` rows: four coincide (`\emptyset`, `\iff`,
  `\models`, `\to`), the request-time transform drops them, and `--sty` reading
  nothing but `.sty` files is what lets the startup check regenerate
  byte-identical files on bigfed without the clone. One `sty-sha256` stamp per
  file over its own bytes replaces the blob stamp; the startup check in
  `snippets.lua` compares the 15 and regenerates on a mismatch (0.9 ms to
  check). `--coverage` moved verbatim. `\poscite`, whose arity is biblatex's
  and not in its definition, is deferred.
- **Unusual rows (`#*`) are generated, sunk by a small constant, the flag
  kept.** His usage of unusual-marked commands is half a percent of stock
  tokens, all preamble plumbing (2.6); the prior is sound and nothing is
  hidden, no toggle. The sink is subtracted from the provider's own offset
  (10), never a replacement (a replaced offset of −50 buried the row below
  unrelated matches); its value is 5 (stage 4, below). The description ends
  with a dim `∗`; the marker first, so that a cut never removes it, is his call
  and deferred.
- **One row per distinct signature; the shape in the description column.** The
  label is the plain command, the column TeXstudio's list row minus the name
  (`[position]{width}{text}`; for an environment the whole first line,
  `\begin{alignat}[alignment]{ncols}`), the on-highlight window the full
  expansion with named placeholders and the `\end`. Starred forms are separate
  rows. Placeholders follow TeXstudio's rule with one measured extension: every
  bracket group of any kind is one placeholder named by its content, `(x,y)`
  one per group; in a row with explicit `%<…%>` markers the bare groups
  attached to the row's own command are filled too, so `[scale=%<1%>]{file}`
  gives two stops where TeXstudio gives one, and groups after that chain stay
  literal. A `\begin{env}` row becomes the environment plus a body line and
  `\end{env}`, `\item` in the body when any row of that environment, in the
  file or the core lists, ends in `\item` (TeXstudio chops the `\item`, merges
  the pair by hash and hard-codes it for itemize, enumerate and description).
  `#keyvals` blocks are kept raw as a fifth field of the file, for the deferred
  key-value tier. `cwlAliases.dat` needs no emission (401 entries, six not
  derivable from the class name, none his). He gave the itemize, marker-row and
  keyvals answers tentatively; reversing any is a generator change plus a
  regeneration.
- **Context behaviours are TeXstudio's.** A math-only row (`m`) expanded in
  prose is wrapped in `$…$` at expansion time and bare inside math, through
  function nodes asking `vimtex#syntax#in_mathzone()` (0.05 ms); a sweep of the
  73 math-only commands he uses over all 41 dissertation files found 1,023 uses
  in math and none in prose (100 apparent hits were commented-out code), so
  there is no exception list. A row restricted to an environment (`/env`) is
  hidden outside it, the innermost environment looked up once per request;
  nearly moot for his packages (six typical rows, all hyperref form fields) and
  kept because it is cheap.
- **VimTeX's argument completers join the menu through blink's built-in `omni`
  provider.** Enabled inside a `\command{…` context and nowhere else, and the
  snippets provider while a `\command` name is typed and nowhere else, a
  command name typed inside another command's braces (`\textbf{\al`) counting
  as a snippets context. VimTeX's own completer patterns decide which braces
  yield rows, and its command completer never fires: the 2026-09-12 drop of the
  vimtex source stands. This fixed the measured `\begin{` breakage (2.7:
  `\begin{\begin{align*}` on one line and `\end{align*}}` two below) and closed
  item 15. The gate's look-behind window stays at 300 characters; the path
  provider is unchanged.
- **`\begin{` gives TeXstudio's environment template, over the union of
  VimTeX's names and the loaded files'.** The omni transform rewrites each row
  into a snippet-format edit – `name}`, a body line, `\end{name}` – extended
  over the auto-paired `}`, with `\item` in the body for a list environment
  (one whose begin code opens itemize, enumerate, description or a list already
  known, to a fixpoint; exact on all 24 french-logic environments, where the
  old name heuristic missed axiomproof), then appends every environment name of
  the buffer's files and its document that VimTeX did not return, stamped with
  the fields blink puts on a provider's own rows. Measured: VimTeX knows an
  environment from its own 202 data files, the project's `\newenvironment`
  lines and a scan of the packages a fresh `.fls` names; the fixture (no
  `.fls`) got 65 names and none of french-logic's 25, the root (`.fls` of
  2026-08-09) 179 and none, the completeness chapter (`.fls` of 2026-09-12) 171
  and all 25; the fixture's closure knows 212 names, of which VimTeX's data
  knows 125. Declined: a `regTrig` environment snippet (blink inserted the
  pattern text), a pre-expand callback editing the buffer (blink fixes the
  clear region first), VimTeX's names only (french-logic environments would
  appear only after a fresh compile), a custom blink source for `\begin{`
  (cleaner separation, twice the code).
- **Document-local commands complete with arity, from the whole main file,
  re-read when its mtime changes.** One stat per request, 0.06 ms per re-read
  on the root's 142 lines; the `.sty` rules ported to Lua in `helpers.lua`, the
  rows registered under the document's own pseudo-filetype. The whole file
  because the dissertation defines three of its six own commands after
  `\begin{document}`. Declined: the preamble only; the whole project through
  VimTeX's parser memoised on the project mtime (11.6 ms per re-parse on the
  root, 3.7 on a chapter); the same refreshed on compile success (a definition
  would appear only after the next successful compile).
- **Dedupe in two places, never at registration.** At generation a package row
  identical to a row of the core three is dropped (74 of the closure's 117
  cross-file duplicates; VimTeX's converter does the same); at request time the
  snippets transform drops a repeated (label, description), keyed by a string
  memoised per snippet id, which is also what lets a hand row shadow a
  generated one. Dedupe at registration would make a row's home depend on which
  document loaded first.
- **Triggers are plain `\name`.** The trailing `~` on every old trigger was an
  old chat's misreading of blink's menu; tilde-less triggers expand correctly
  whether typed in full or in part.
- **Option blocks (`#ifOption`) are skipped by default.** They matter for
  babel, biblatex and fontenc only (2.5) and his biblatex options select zero
  lines; `--option PKG:OPT` enables one for a run, and the generator's options
  table is empty.
- **Hand libraries survive as hand files.** `hand/bibtex.lua` holds the 32 bib
  entry templates, without their `~`; `hand/local.lua` is his and starts empty.
  `latex-workshop.lua`, `french-logic.lua` and `sty-lua-snippets.py` are
  retired.
- **Both transforms are idempotent, and every appended row carries blink's
  stamps.** blink re-applies a provider's transform when it resolves an item,
  stamps `source_id`, `source_name`, `cursor_column`, `score_offset` and `kind`
  on a provider's rows before the transform, and adds the provider's offset to
  each row first; so the sink is assigned from the offset rather than
  decremented, the template rewrite is guarded, and a row the transform adds
  carries the stamps or the accept path errors inside blink (found on the
  harness).
- **Stage 4, measured then tuned.** blink's luasnip preset answered
  `snippets.active()` with LuaSnip's `expandable()` – every registered trigger
  of the buffer's filetypes matched against the line – on every `InsertCharPre`
  and `TextChangedI`, where the answer is discarded: 3.5 ms per prose keystroke
  at the end of the fixture's longest line (23 to 19 ms), and the closure load
  on the first insert-mode keystroke of a session, whatever it was. Applied as
  objective: `completions.lua` answers `active()` from LuaSnip's session and
  keeps the expandable check for `<Tab>`/`<S-Tab>`, the four `<Tab>` corners
  measured identical in fresh instances, two pins. His round, asked with the
  measurements: **the sink stays at 5** (frecency never lifts a snippet row,
  blink's sort already lists a typical row before its unusual twin, 5 moved no
  row in any probe and 10 buried one); **the closure is pre-warmed in idle
  time** after `User VimtexEventInitPost`, one file per 10 ms tick (100 files
  in 2.5 s on the harness, 104 in 3.6 s on the chapter), the request path
  unchanged as the fallback; **the description column is 45 cells** (2.3% of
  the chapter's rows still cut, from 9.9% at blink's 30; the `∗` is the last
  character and the first thing a cut removes). Declined: sink 0 (un-decides
  the small sink for no observed gain), sink 10 (buries), a synchronous
  pre-warm at init, the widths 30, 40 and 60. The live look the same day:
  `\name`, `\cite{`, `\begin{` and a math-only row in prose all as intended,
  the math awareness the surprise, nothing reported wrong.

**The numbers of stage 4.** fedxps in performance mode, both trees under one
machine state, interleaved: the live tree against a scratch extraction of the
committed pre-campaign tree (`1bb69b1`, 1,054 snippets). Per keystroke at the
end of the fixture's 2,069-character line, medians of three runs: inside a
command name 53 ms before and 54 after (p90 56 and 64); in prose 19 before, 23
after as landed and 19 after the `snippets.active` fix. Per request in a
command name the luasnip source costs 12 to 13 ms (0.8 to 1.1 before: blink's
shallow copy of 7,760 rows against 1,054), the Rust fuzzy pass 5.4 ms per call
(0.9), the live transform 0.6 ms; six requests for 35 keystrokes in both trees,
none in prose. The transforms at the full row count, isolated: 7,758 rows, cold
memo 5.2 ms, warm 1.4; blink's per-request copy 5.9 ms and its show_condition
pass 3.3 ms (233 rows hidden in prose); the omni transform at `\begin{a` 0.7 to
2.3 ms with 137 rows, VimTeX's env completer 23 ms for the empty prefix and 2
ms for `a`, `loader.envs()` 0.35 ms. The first keystrokes of a session, fresh
instances, medians of three: entering insert mode 107 ms in both trees; the
closure load 660 to 750 ms (`ft_func`), which as landed fell on the first
insert-mode keystroke, after the `active` fix on the first completion request,
and after the pre-warm in idle time; that request's own first build 25 to 75 ms
for the source items, 6 to 22 transform, 18 to 19 fuzzy, the menu 32 to 43 ms
after the keystroke; the second request 27 ms to the menu (before: 15 and 10).
After the pre-warm the first request finds `ft_func` at 0 ms and the menu 27 to
38 ms after the keystroke; typing within the first second leaves about 100 ms
of registration on that request. Memory: the closure adds 123 MB of Lua heap
after a full collect and 174 MB of RSS (before: 1 and 4; headless on the
chapter, heap 10 to 151 MB, 129 after a full collect, 603 ms to execute and
add, 61.5 µs a row). Startup to VimEnter with the fixture, headless, five runs:
216 ms after against 285 before (the old layer built its 1,054 snippets at
`FileType`); the per-file stamp check 0.9 ms. The sink against frecency, a
fresh store per condition: accepting `\AmSfont` three times from `\AmS` changed
nothing at 0, 3, 5, 8 or 10, because blink hands an accepted LuaSnip row to the
source's own `execute`, which never reaches `fuzzy.access` (wrapped: zero
calls; the store stayed at 0 bytes); at 0 the fuzzy score already puts `\AmS`
(99) over `\AmSfont` (91), at 5 the first three rows keep their order, at 10
`\AMSautorefname` drops below the unrelated `\atoms`. The cold package cache on
the chapter (111 packages, a scratch cache root): `\begin{a` 13.3 s cold, 28 ms
in the same session and 31 ms in a new session on the primed root, so
`vimtex-warm` suffices for `\begin{`; `\usepackage{a` 1.3 s cold and 0.9 s in
every new session (VimTeX lists `kpsewhich --all ls-R` per session and caches
nothing on disk), 11 to 23 ms after. On the fixture: `\begin{a` 356 ms cold, 16
to 21 primed; `\usepackage{a` 0.8 s per session. The backslash that opens a
command is itself a request in both trees (blink asks the source on the lone
`\` and refilters the letters locally): 21 ms in the old tree, 50 ms (p90 63)
in the new, so a command word costs about 30 ms more once, at its backslash,
and the same per letter after; cutting that means fewer rows per request or a
source of our own rather than LuaSnip's, and is not proposed. The section 9
before figures (146 and 92 ms, balanced mode) were not reproduced: the same
pre-campaign tree measures 53 and 19 in performance mode, the power mode
explains part, the rest is unexplained.

**Item 8, closed.** The two libraries the item named are gone, and with them
the 13 wrong arities and 21 artefacts of the generic file. Nothing is
hand-edited under `pkg/` or `sty/`: a systematic oddity is a generator change
proved by `tests/snipgen` and a regeneration; a package quirk is a `.sty`
change, which the startup check regenerates from; and the one-off divergence
the item had no mechanism for is a row in `hand/local.lua` with the generated
row's label and description, which shadows it by the loader's order and the
request-time dedupe (pinned by the latency suite). The generator overrides
table the item contemplated was not built; the hand file covers the case it was
for. The item's checklist, moved here verbatim:

- [x] Fix bulk-generation oddities in the two snippet libraries as they surface
  in real use — no sweep, just capture-and-correct when noticed.
  @done(2026-09-13) — both libraries retired with stage 3; the rule above
  replaces the two-files-are-opposites rule.

**Item 15, closed** at stage 3. The brace branch is closed to snippets inside
every `\command{…}` and open to VimTeX's completers through the omni provider,
so `\cite{che` no longer fuzzy-matches the snippet triggers against the key;
`\begin{` is served by the template over the union. The item's premise had been
measured false on 2026-09-13 (accepting a row at `\begin{ali` wrote
`\begin{\begin{align*}` and left the auto-paired `}`); the exact output is
pinned. The item's checklist, moved here verbatim:

- [x] Decide whether `in_latex_context()` should stay open inside every
  `\command{...}` or only after `\begin{`/`\end{`. @done(2026-09-13) — two
  gates now: snippets while a command name is typed, omni inside its braces;
  the `\cite{`/`\ref{` suite checks flipped to snippets-closed and omni-open,
  the 300-character window pins moved to the omni gate.

**Post-mortem.** *Built:* `snipgen.py` (the cwl front end with `--all`,
`--cwl`, `--check`, `--option`; the `.sty` front end with `--sty` and
`--coverage`); `pkg/` with `NOTICE` and `COPYING`; `sty/`; `loader.lua`
(registration on demand, the document parse, `envs()`, the idle pre-warm,
`:SnippetsReport`, `:SnippetsReload`); `helpers.lua`; `hand/`; the thin
`snippets.lua` with the per-file stamp check; `completions.lua` (the two gates,
the omni provider in the TeX source lists, the two transforms, the
`snippets.active` override, the 45-cell column); `tests/snipgen` (22 checks,
two mutations recorded, the goldens written by hand before the parser existed
and met byte for byte); the latency suite from 42 to 71 checks with five
mutations recorded; `tests/stylua.toml`. *Declined,* beyond the per-verdict
list above: a package list of any kind; the stage-2 alternative of reading the
core keys from our own generated files; a custom blink source in place of
LuaSnip's (the one route to a cheaper backslash). *Deferred* to `TODO.md`,
opened at the close: key-value completion inside `[…]` (4,486 keys for 178
targets in the dissertation's closure), with the 77 keyvals-only cwl files the
empty-file rule skips; a comment convention in the `.sty`, read by `--sty`, for
named placeholders (99 of french-logic's 100 bare), math-only marking and
`\poscite`'s arity; ranking from his corpus frequency in place of the `#*`
prior, and the `∗` before the shape; autogenerating a bare list for a package
with no cwl (his mod-cv, eptcs and deon16, the old documents on bigfed); the
harness's hygiene (a scratch `cache_root` and `XDG_STATE_HOME` by default: each
instance writes a `bibcomplete%tmp%…` file into the live `~/.cache/vimtex` and
its accepts feed the live frecency store); a bench sitting for the five stray
colours (1.4). *Left as observed* (PLAN.md section 8): the two looks of the
`\begin{` list (VimTeX's rows with the field icon and a package tag, the loaded
files' with the snippet icon); `in_env` reading the innermost environment only;
the 24 to 33 includes with no file that `:SnippetsReport` names, most of them
keyvals-only or expl3 files skipped by rule; `\usepackage{` at 0.9 s per
session, which nothing primes; the unreproduced balanced-mode before figures.

Records: `nvim/CLAUDE.md` (Completion and Snippets rewritten, the cold-cache
rule, the suites list), `nvim/README.md` and `latex/french-logic/README.md`
(the tooling bullets), `CLAUDE.md` here (`tests/snipgen`),
`~/Desktop/CLAUDE.md` (the `texstudio/` clone), `tests/nvim-latency/README.md`
(the flipped and added checks, the five mutations), `tests/snipgen/README.md`,
and the campaign directory `docs/latex-completion-campaign-2026-09/`.

*Annotated 2026-09-13, bigfed (the sixth chat, the first there).* The bigfed
half landed: the twin clone at `0362907c2` with its charter byte-identical; the
three suites green (syntax 56, latency 71, snipgen 22), `--all --check` and
`--sty --check` 0/0/0, the four plugin commits equal to the lockfile;
`:SnippetsReport` on the completeness chapter 105 files and 7,836 rows over a
97-package table (bigfed's `completeness-article.fls` of 2026-08-18 names the
hub and no unit, so the units come through the hub's includes); the stage-4
probes, three interleaved repetitions on a desktop with no platform profile
(governor performance): 43 ms per command-name keystroke before and 44 after,
17 and 16 in prose; once pre-warmed, the first request's menu 22 ms after the
keystroke and the backslash 30 to 33 ms; the closure 503 ms and 129 MB of heap
after a full collect; `\begin{a` 5.7 s on a cold package cache and 23 ms
primed, `\usepackage{a` 0.57 s per session. The full numbers are under
`PLAN.md` section 3's stage-4 paragraph; bigfed's machine-local
`~/Desktop/CLAUDE.md` carries the two items. Criterion 1 holds on both
machines.


## nvim: the CTRL-D step, and where scroll cost goes — 2026-09-15

One chat on bigfed, opened as a diagnosis: scrolling felt "jolty", especially
in LaTeX but also in other long documents. The finding is that two of the three
things it could have been are not happening, and the third is the syntax layer
seen through a unit the keystroke work never used. One change was made,
`'scroll'` to 10 display rows; the rest is recorded so it is not re-derived.

**The measurements** (bigfed, a live 106x56 window, `completeness.tex`; the
harness is `tests/nvim-latency/harness.py` with a UI attached, so absolute
per-redraw milliseconds are inflated by msgpack serialisation – the syntime
figures, the screen-row geometry and the frame counts do not depend on it):

- **Syntax is the cost, 4.65 ms per screen row scrolled** (`:syntime` over a
  200-row sweep), falling to **1.60** with `vimtex_syntax_custom_cmds = {}`.
  That 66/34 split confirms the ~60% already recorded for keystrokes rather
  than revising it; what is new is the unit. Typing re-evaluates one line, so
  the layer is invisible; scrolling re-evaluates a row for every row
  travelled.
- **The UI layer is noise**, re-confirming the 2026-08-22 verdict from the
  scroll side: ablating statuscolumn, relativenumber, snacks indent guides,
  `list`, cursorline and signcolumn changed nothing measurable, while `syntax
  off` took the same loop from ~29 ms/step to 0.54 ms.
- **Distance per press is constant.** Under `smoothscroll` the whole family
  counts display rows: `<C-e>` 1, `<C-d>` `'scroll'`, `<C-f>`/`<PageDown>`/
  `<S-Down>` 53. With `smoothscroll` off the same commands vary (4–24 and
  10–39 rows) because they revert to buffer lines, which in soft-wrapped prose
  is a paragraph.
- **snacks.scroll drops frames.** LazyVim enables it; it animates any keyboard
  scroll over one line across 200 ms in 10 ms steps, and delivered 9–15 of ~20
  frames at 14–32 ms apart over four trials. A frame advancing three rows owes
  ~14 ms of syntax against a 10 ms budget. Constant distance, uneven velocity
  — that is the jolt.
- **The wheel is a separate mechanism**: 3 display rows per *event*, ~3 events
  per detent on a hi-res MX Master, and a 13x input backlog (60 events arrive
  in 70 ms, drain in 951 ms; ~63 events/s serviced). Open as `TODO.md` item 22.
- Checked and **ruled out**: the terminal (Ghostty, the faster one at
  repaints); conceal reflow (`conceallevel` is 2 but VimTeX's conceal is off —
  zero concealed lines in view, line height unchanged by cursor position);
  `display` (it is `lastline`, so no `@@@` filler jump); and `syntax sync
  minlines`, which made no consistent difference at 1, 50 or 200.

**The change.** `'scroll'` = 10 display rows, from a default of 27 (half the
window), via a `bph_scroll_step` autocmd in `nvim/lua/config/autocmds.lua`.
His words: 27 is "absurd"; 10 is "vastly better".

The autocmd is the mechanism rather than a line in `options.lua` because
`'scroll'` is **window-local and Vim resets it to half the window height on
every size change** – measured decaying from 10 to 19 after a resize to 40
rows, and to 13 in a new `:split`, silently and with no error. It is therefore
re-applied on `VimEnter`, `WinEnter`, `WinNew`, `VimResized` and `WinResized`,
across every window, since a resize hits them all at once. If the autocmd never
fires, stock behaviour returns, so the failure direction is safe. Verified
against the config on disk: 10 across resizes and splits, and `<C-d>` moving
exactly 10 rows every press.

Its height guard turned out to be load-bearing rather than good manners.
Setting `'scroll'` above its own window raises `E49: Invalid scroll size`, and
the autocmd fires on `WinNew`, so an unguarded version throws on every small
window created — a completion menu, a popup. Found by mutation, not by
reasoning: dropping the guard does not fail a check, it aborts the latency
suite on the first `WinNew`. The merits agree anyway; a ten-row step in a
ten-row window is a whole page, and Vim's half-window default is better there.

Eight checks were added to `tests/nvim-latency` (71 → 79) and mutation-verified
in three directions; the exact failure sets are in that suite's README. One of
them is worth repeating here, because it is the argument for the mechanism:
`vim.opt.scroll = 10` in `options.lua` produces the **identical** failure set
to deleting the autocmd entirely. Under the harness that is total, because the
UI attaches after startup and the attach is itself a size change, so Vim has
reset the option before the first check reads it; in an ordinary launch it
would last until the first resize or split instead. Either way a plain option
is not a weaker version of this, and the directly measured decay — 10 to 19
after a resize, to 13 in a split — is the claim that does not depend on how
the harness starts. And
the row-count check was silently vacuous on its first run, reading 0 in the
two-line `enew` Lua buffer an earlier check leaves current; the fixture is now
reopened before it, with a filetype guard beside it.

**Declined, both deliberately.**

1. **Touching the custom colour layer**, though it is two thirds of the cost.
   It is held by the french-logic working agreement and changes only from
   instances he brings to the bench. The answer to a scroll complaint is
   distance per press, not fewer colours.
2. **Changing `mousescroll`**, for now — a lower `ver:` shortens the overshoot
   without touching the lag, and the free-spin/ratchet switch on the mouse is a
   cheaper thing to try first. Recorded as item 22 rather than guessed at.

Also corrected in-session, and worth knowing because the bad method is
inviting: screen-row displacement must be measured with `skipcol`, not by
differencing `topline`. Under `smoothscroll` the view parks part-way into a
wrapped line, so a topline difference counts whole paragraphs where the view
moved a fraction of one. The reliable method is to count `<C-e>` presses
between two saved views.

## tabula: the font trial's arc, and what it declines — 2026-09-15

One chat on bigfed, opened to record a complaint about Atkinson Hyperlegible
Mono's lowercase `l`, which became the design of the trial itself. The standing
question is which monospace faces are sustainable long-term as the **primary
terminal font**, with Source Code Pro the incumbent to unseat. The rotation was
restocked 24 → 39 and the working discipline settled; the operative rules live
in `bin/tabula`'s header and `bin/CLAUDE.md`, and this entry records why.

**The arc.** Phase one sorts through many faces in the scratchpad; phase two
builds a ranking instrument once a shortlist exists; phase three wears the
finalists in the terminal. Each phase produces the requirements of the next: a
shortlist that does not yet exist cannot specify the instrument that would rank
it, and finalists are what a terminal trial is worth running on.

**The measurements worth not re-deriving:**

- **Glyph coverage does not bear on the choice.** A census of 168 live files
  across `n-cube`, `dissertation` and `opuscula` found 29 distinct non-ASCII
  codepoints in 128 occurrences, 92 of them inside one archived file. VimTeX
  conceal is off, so LaTeX source shows `\wedge` rather than the symbol. The
  JuliaMono fallback in `ghostty/config` remains correct insurance and was left
  alone – the terminal also renders Isabelle output and this chat – but judge a
  face here on how ordinary Latin text wears.
- **Cousine and Liberation Mono are one typeface.** Same designer (Steve
  Matteson), identical metrics (0.600 advance, 0.528 x-height, 0.659 cap), and
  identical `g`/`a`/`M` outlines. Of the glyphs probed only the `l` differs:
  Liberation's begins at x=267, Cousine's at x=134. Both were marked liked a day
  apart, 09-13 and 09-14. They are kept as a pair because that makes them a
  controlled test of a letter he has now twice singled out.
- **Source Code Pro is a low-x-height outlier**, 0.486 against a rotation median
  near 0.52, while Liberation and Cousine sit at 0.528 with the shortest
  ascenders in the table. The faces he likes best disagree on the obvious axis,
  which is the argument for recording metrics beside verdicts and leaving the
  theory until there is something to fit it to.
- **Two controlled sets were added deliberately.** The Vera lineage (Bitstream
  Vera Sans Mono, DejaVu Sans Mono, Hack) holds metrics fixed across three
  drawings and 256/3322/1548 glyphs; Cascadia Mono is Cascadia Code minus
  ligatures. Fira Code is *not* the same trick—it moves the advance too, 0.615
  against Fira Mono's 0.600.
- **`SMonoHand` is proportional**, despite the name and despite fontconfig
  indexing it under `:spacing=mono`: `i` 0.280, `m` 0.776, `W` 1.039. Installed,
  rejected, left on disk. Check advances, never the name or the spacing tag.

**Declined**, all three proposed in this chat and all three rejected:

1. **A terminal rotation**, changing the Ghostty font per new window. It would
   produce data fastest, at the cost of the stable baseline the work is done in,
   and it writes to a stowed config on every roll. The terminal is phase three;
   the scratchpad suits phase one precisely because it is low-stakes.
2. **A ranking CLI** doing pairwise insertion into a sorted list. Wanted
   eventually – "there will be a tool built in the future" – but unspecifiable
   before a shortlist exists. Until then the ordering is gathered informally, by
   asking when a comparison is convenient and by recording what he volunteers.
3. **Exposure logging with a weighted draw.** It would give every verdict a
   denominator and converge the table faster. Declined to keep tabula stateless:
   no logs, no counters. He reports in chat, and that is the instrument.

**Method note.** Three claims written into the file during this session were
wrong and were caught on re-reading: a "175 monospace families installed" figure
that counted Nerd Font and CJK variants; "the lowest x-height here" for Intel
One Mono, which is fifth; and an archived-file count of 75 that set a filtered
number against an unfiltered total. A superlative measured over 24 entries does
not survive the table growing to 39, so re-measure superlatives against the
table as it stands.

---

## Terminal colour: the palette made explicit, the prompt taken off it — 2026-09-20

Opened by a question about whether the terminal and Neovim were running the same
TokyoNight variant. They were — both "night" — but the answer exposed that they
are two independent declarations that agree only by descent, and the session
turned into making the terminal's half explicit so it could be tuned.

**What changed.** `ghostty/themes/tokyonight-night-bph` is new, stowed to
`~/.config/ghostty/themes/`, and `ghostty/config` names it instead of the
shipped `TokyoNight Night`. `bash/.bashrc.d/30-prompt.sh` and its nousowl twin
give each machine a truecolor hex off the palette. `ghostty/config` renders bold
at Semibold 600. Charters amended: root `CLAUDE.md` (Visual Consistency, the
ghostty index row), `bash/CLAUDE.md`, `nousowl/configs/README.md`.

**Why a fork rather than overrides.** Ghostty lets a config line override a
theme in either order — `man ghostty`, --theme: "Any additional colors
specified via background, foreground, palette, etc. will override the colors
specified in the theme", confirmed both ways round. So explicitness was never
needed for tweaking; what a fork buys is one editable file with its own history
and a mechanical diff against upstream. The config keeps the override slot for
experiments, which delete cleanly.

**Why folke's generated theme is the baseline, not Ghostty's shipped one.**
tokyonight.nvim generates terminal themes from the palette that colours the
editor, and ships one for Ghostty at `extras/ghostty/tokyonight_night`. It
disagrees with the theme Ghostty ships on six values — brights 9-14, which
Ghostty's copy sets equal to 1-6 where the generator derives them with
`Util.brighten` (+5 lightness, +20 saturation in HSLuv). Measured: Neovim's own
`colors.terminal` for night is folke's set byte for byte, so bright red had been
`#f7768e` in a Ghostty tab and `#ff899d` in a `:terminal` buffer. The extras file
on disk sits at commit cdc07ac7, which `nvim/lazy-lock.json` pins, so the
baseline is the build the editor is running. `cursor-text = #1a1b26` is kept
though the generator emits none; it is the one line the standing diff prints.

**WezTerm is deliberately left on the old baseline.** Its built-in agrees with
Ghostty's shipped theme, so it is now both an unmodified control a tweak can be
judged against and a way to tell the two terminals apart with both open. It also
stays at Bold 700. The header of `ghostty/config` records both divergences; the
2026-09-05 performance verdict the parity protected is closed.

**Neovim stays upstream, by standing preference.** It reads none of the terminal
palette: under `termguicolors` it emits direct RGB from the plugin's own table,
so a change to the theme file reaches the shell world and stops at nvim's edge.
The terminal is the tweakable surface; the editor is not. If the two should ever
move together the hook is `on_colors` — and note it runs *last*, after
`error = red1`, `warning = yellow`, `bg_visual` and the whole `colors.terminal`
table have been snapshotted, so overriding a base name leaves its aliases behind.

**The prompt.** Previously ANSI 31/32/33, chosen in 2026-09-14 precisely so the
prompt would be theme colours with no second source of truth. That reasoning was
right for a prompt meant to look like the theme and wrong for one meant to be a
machine identity: an index is by construction the same colour as everything else
asking for that index, which is why bigfed's rose was also dircolors' ARCHIVE at
`01;31`. The requirement — "stop me running something meant for fedxps on
nousowl" — forces a colour nothing else on screen can be.

The derivation: TokyoNight's sixteen occupy only six hue positions, because the
bright set sits almost on top of the normal set, leaving three wide gaps centred
at 45 (orange), 187 (teal) and 339 (rose). One colour per gap. fedxps `#73daca`,
bigfed `#ff5fd1`, nousowl `#ff9e64` — CIEDE2000 13.3 from the nearest palette
entry at worst against 0.0 before, 41.4 apart from each other against 26.5,
contrast 6.4 / 10.3 / 8.4 on `#1a1b26`. `#73daca` and `#ff9e64` are folke's
green1 and orange; `#ff5fd1` is constructed, the rose gap holding no tokyonight
colour. Root keeps the package's magenta behind the EUID guard, 13.3 or more
from all three. Each host retains its old index as a `$COLORTERM` fallback:
Fedora ships `SendEnv COLORTERM` and nousowl's sshd accepts it, so the variable
survives the ssh hop — measured, it reads `truecolor` on the far side — while a
VT console drops to the index.

**Bold at 600.** The prompt was a tick heavier than wanted and SGR offers no
intermediate intensity, so the tick had to come from what bold *renders as*.
Source Code Pro carries Medium 500 and Semibold 600; Semibold is the single step
down from Bold 700. It reaches every bold glyph, not just the prompt. The
families disagree on the name — Source Code Pro "Semibold", JuliaMono "SemiBold"
— and one value matches both: with the change in place,
`+show-face --style=bold --cp=0x22A2` reports "JuliaMono SemiBold" where it
previously reported "JuliaMono", so the logic-symbol fallback follows the weight
down instead of being stranded at 700.

**Declined.**

- *Inlining the 22 values in `ghostty/config`.* Everything in one file, but it
  loses the mechanical diff against upstream, which is the whole point.
- *Deltas only, keeping `theme = TokyoNight Night`.* Smallest surface, but
  "what is palette 5" still needs `+show-config`.
- *Mirroring the fork into `.wezterm.lua`.* A second hand-synced copy of the
  palette with nothing keeping the two honest. A generator over one source file
  was weighed and declined as machinery for a 22-value table.
- *Declaring nvim's full 34-value palette in `on_colors`.* Owning a snapshot
  while upstream still owns every derivation and all ~2000 group mappings; an
  upstream palette change would silently no-op and the file would go stale.
- *Bringing Ghostty's search colours onto the palette.* `#ffe082` amber and
  `#f2a57e` peach belong to no theme, which is exactly what makes a search hit
  read as the machine pointing at something. Judged in use and kept; the note
  sits at the foot of the theme file.
- *An all-unborrowed identity set.* `#ff49cd` / `#0ea89d` / `#ff6333`, built at
  the same three gap centres with every tokyonight value excluded: further from
  the palette at 17.6 but uniformly at contrast 5.8, and rejected on contrast.
  Per-value replacements for the two borrowed colours (`#19fde5` for green1,
  `#fccdbe` for orange) were declined the same way — they clear every threshold
  and cost the character the set was chosen for.
- *`palette-generate = true`.* Would derive indices 16-255 from the base sixteen
  instead of the xterm cube. Off, as Ghostty ships it, because legacy programs
  hardcode that cube.
- *A background badge for the prompt* (`PROMPT_COLOR='41;30'`). Structurally
  unique, no new colours, no truecolor dependency — and a much heavier prompt.
  Not taken, but it is the fallback if the hexes ever prove too subtle.

**Traps found, recorded where they bite.** Ghostty has no trailing comments: a
`palette` line with one is rejected and the entry reverts to Ghostty's default
silently in a running terminal, though `+validate-config` catches it and exits 1.
`+show-face` prints the family, not the style, so it proves a value resolved
rather than falling through to Noto Sans Mono, and cannot confirm the italic
axis. Stow's `-t` is not optional here: bare `stow -R ghostty` from the repo
targets `~/Desktop`, the stow directory's parent.

**Verification.** The theme resolves byte-identically to its baseline but for
`cursor-text`; the prompt module was exercised across all six host/terminal
combinations with no variables leaking; the restow hint in `50-git-sync.sh` was
read rather than trusted, and fires for a file added to an existing package, so
fedxps will be told. CIEDE2000 was implemented for this work and checked against
five Sharma reference vectors before any colour was judged by it.

## The session environment: `environment.d` becomes a package, and the login shell carries the rest — 2026-09-23

Opened by the question of how the bash configuration should reach this repo
properly, on the map drawn 2026-09-21/22 (`org/machines/environment.md`): the
graphical session inherits one login shell's environment, and `.bashrc` returns
at once for a non-interactive shell, so nothing under `~/.bashrc.d` reached the
desktop — `EDITOR` was nano, and a desktop-launched Okular could not find
`okular-inverse`.

**What changed.**

- `environment.d/` is a stow package, target `~/.config/environment.d`, holding
  `10-editor.conf` (`EDITOR`/`VISUAL`) and `50-xpadneo-sdl.conf` (the Steam
  hint, on both machines by decision). Both arrays in `60-stow.sh`, the index
  row in the root charter, README §1, §4, §5 and §8.
- `bash/.bash_profile` sources `10-env.sh` and `20-path.sh` before `.bashrc`.
  GDM's login shell therefore carries the personal PATH (TeX Live first, in
  `20-path.sh`'s own order), `EDITOR`, `NPM_CONFIG_PREFIX` and an unset
  `BASH_ENV`; gnome-session uploads that to the user manager and to D-Bus, and
  under sway it is inherited directly.
- `10-env.sh` exports `NPM_CONFIG_PREFIX`, replacing `~/.npmrc` (one line,
  deleted on bigfed; fedxps in the other-machine step below).
- `tests/env/run.sh`: 26 checks, caged in a systemd scope (the first suite here
  to be), against a fixture HOME linked the way stow links: the login shell's
  PATH order, no duplicates or empty elements, `EDITOR`/`VISUAL`/`BASH_ENV`/
  `NPM_CONFIG_PREFIX`, idempotence across the interactive passes, `ssh host cmd`
  untouched, and the real generator run over the stowed symlinks.
- The decline of a PATH drop-in, restated in five places, now reads the same
  everywhere: declined 2026-07-26 and again 2026-09-23, PATH has one author.

**Why the login shell and not a drop-in.** Fedora's skeleton `.bashrc` has no
interactive guard and prepends `~/.local/bin:~/bin` unconditionally; GDM's
login shell runs it, so a stock account's desktop sees both directories. The
early return at line 4 of `.bashrc` — worth keeping, it is what makes `ssh host
cmd` and scripts cheap — is what removed that. Sourcing the two environment
modules from `.bash_profile` restores the stock result through the file whose
job it is, keeps `20-path.sh` PATH's one author, and reaches sway as well as
GNOME. `environment.d` cannot do this: it sets constants, and TeX Live's year
is discovered.

**Measured.**

- The desktop callers already in place all use absolute paths: dconf shortcuts
  for `screens-off` and `tabula` on bigfed and `tabula` on fedxps, and two
  `.desktop` files. `okularpartrc`'s bare name was the one that did not.
- `nvim --server … --remote-silent +7 file` ignores the `+7` (a buffer named
  `+7` was opened), so Neovim's own remote cannot replace `nvr`. VimTeX's
  documented `nvim --headless -c "VimtexInverseSearch %l '%f'"` can: 50–70 ms a
  start with this config against `nvr`'s 70–80 ms, no pip package, no fixed
  socket, and it targets the instance that owns the file. It does not
  percent-decode, so the wrapper would stay. Deferred, not adopted: `nvr` works
  and is on the session PATH now.
- gnome-session's upload carries everything the login shell exports —
  `HISTSIZE`, `LESSOPEN`, `MAIL`, `BASH_ENV`, `LMOD_CMD` all reach
  `gnome-shell` — the only filter being systemd's validity check, the only
  explicit unset `NOTIFY_SOCKET`. So PATH goes up: inferred from those
  witnesses, and the logout is the proof.
- bigfed's user manager lingers (`Linger=yes`) and has been up since boot; a
  variable it holds survives re-logins, since the upload sets and never
  removes. Hence the one-off `unset-environment BASH_ENV` below. fedxps does
  not linger.
- `BASH_ENV` is unset over ssh in both directions; bigfed's session carried it
  (gnome-shell's environ); fedxps has no Lmod.
- `~/.local/bin` shadows `/usr/bin` for `f2py`, `numpy-config` and `z3` on
  bigfed (pip shims of 2025 over 2026 binaries), nothing on fedxps; nothing in
  `bin/` collides with any system directory. The shadowing now reaches desktop
  apps too — left for the `~/.local/bin` tidy.
- No Fedora package provides `nvr`; it is a pip user install on both machines.

**Declined.**

- A `~/.config/environment.d` PATH drop-in with `~/bin` alone: `nvr` in
  `~/.local/bin` stays unreachable, so it does not repair the failure that
  reopened the question, and PATH gains a second writer.
- The same with `~/.local/bin` added: reaches `nvr`, same shadowing, second
  writer, and that directory is written by pip, npm and Claude's installer
  without review.
- Fixing the bridge alone (absolute paths in `okularpartrc` and for `nvr`):
  smallest, and it matches the dconf pattern, but it leaves the general problem
  and the stock behaviour unrestored.
- `50-xpadneo-sdl.conf` tracked in `org/machines/bigfed/` and hand-linked on
  bigfed only: a second mechanism for one inert line. In the package for both
  machines instead; on fedxps the hint is consulted only when an SDL program
  opens a joystick.
- Replacing `nvr` with VimTeX's headless route now: its own occasion.

**Verified in session.** `tests/env/run.sh` 26/26 inside its cage;
`tests/gsync/run-all.sh` 168/168; the live drop-ins on bigfed are stow links,
and a transient service still sees all three variables after `daemon-reload`;
a clean login shell on bigfed (`env -i … bash -lc`) yields PATH
`TL2026:npm-global:.local/bin:~/bin:system`, `EDITOR=nvim`, `BASH_ENV` unset,
`okular-inverse` and `nvr` both resolving, and `npm config get prefix` correct
without `~/.npmrc`. On fedxps the same day, over ssh: `gpullall`, `reload`,
`stow-all` (two LINK lines), `~/.npmrc` checked and removed, `npm config get
prefix` still right, the suite 26/26 in its cage, and `daemon-reload` put
`SDL_JOYSTICK_HIDAPI=0` into the manager while the uploaded `EDITOR=/usr/bin/nano`
stayed until `unset-environment EDITOR VISUAL`, after which the generator's
`nvim` showed — the uploaded value outranks the generator's until unset.
**The logout proof, fedxps** (2026-09-23, first login after the pull): the user
manager and `gnome-shell` both carry `PATH=/usr/local/texlive/2026/bin/x86_64-linux:
~/.local/npm-global/bin:~/.local/bin:~/bin:/usr/local/bin:/usr/bin`, no duplicate
and no empty element, `EDITOR`/`VISUAL=nvim`, `NPM_CONFIG_PREFIX`, the SDL hint,
and `MANPATH`/`INFOPATH` from `20-path.sh`; `okular-inverse`, `nvr` and `latex`
resolve on that PATH. The manager had not restarted (an ssh session kept it
alive), which shows the upload overwriting PATH rather than a clean start.
**bigfed:** its logout, taken 2026-09-23 at 17:39, came out identical, as
expected: fedxps's measurement was of the upload overwriting PATH on a manager
that had not restarted, which is bigfed's standing state (it lingers), and
bigfed's own clean login shell already yielded the same PATH over its sbin base
with `BASH_ENV` unset. Measured at that login: the user manager and
`gnome-shell` both carry
`PATH=/usr/local/texlive/2026/bin/x86_64-linux:~/.local/npm-global/bin:~/.local/bin:~/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin`
— the four entries over the unmerged sbin base — `EDITOR`/`VISUAL=nvim`,
`NPM_CONFIG_PREFIX`, `MANPATH` from `20-path.sh`, and no `BASH_ENV`;
`okular-inverse`, `nvr` and `latex` resolve on it. The one bigfed-only step,
`systemctl --user unset-environment BASH_ENV` on the lingering manager, had
been done earlier that day.

**The other-machine step.** On fedxps, done the same day over ssh: `gpullall`,
`reload` (a new package is item 10's blind spot — the stow hint cannot fire),
`stow-all`, `cat ~/.npmrc` then `rm ~/.npmrc`, `npm config get prefix`,
`~/Desktop/configs/tests/env/run.sh`, `systemctl --user daemon-reload`,
`systemctl --user unset-environment EDITOR VISUAL`; then its logout, measured
above. What waited for bigfed's keyboard, done the same evening (the
**bigfed** paragraph above): `systemctl --user unset-environment BASH_ENV`,
log out and in, then `systemctl --user show-environment | grep -E
'^(PATH|EDITOR|BASH_ENV)='`. The inverse search from an Okular opened in Files
is his to try; its preconditions are met, the bridge and `nvr` resolving on
`gnome-shell`'s PATH.

**Left open.** TODO item 3's remainder (shell options, PS1, aliases); the
`~/.local/bin` tidy; the sway boot (`environment.md` §6); bigfed's `/usr/sbin`;
items 23 and 24. Found beside the brief, not fixed: the bin charter's `tabula`
entry says sway binds `$mod+x` to it on fedxps, while `sway/config` binds
`$mod+x` to `gnome-text-editor`.

## Ghostty's flash: a foreign fontconfig cache, and the wrapper guard — 2026-09-23

Reported mid-session: `Super+T` opened a Ghostty window that vanished at once,
while `Ctrl+Shift+N` in the running process kept working. That split named the
cause's shape before anything was read: a fresh process gets today's on-disk
state, a new window in the old process reuses what it loaded at start.

**What was found, in the order it was found.**

- The journal: every fresh Ghostty since 09:37 (09:37:34, 09:42:17, 12:18:33,
  all launched by gsd-media-keys) logged `failed to initialize surface
  err=error.FontconfigNoMatch`. The surviving process started 08:59:26. The
  launcher's environment and the survivor's differ only in systemd's
  per-invocation variables, so the change was on disk between 08:59 and 09:37.
- `fc-match` resolved every request, `Source Code Pro`, `JuliaMono`,
  `monospace` and `sans-serif` alike, to
  `texmf-dist/fonts/opentype/SIL/gentium-sil/Gentium-Bold.woff`, a file with
  no family in the cache; 42 such entries existed, exactly the `.woff` and
  `.woff2` files under `gentium-sil` and `logix`. fontconfig scores a font
  that lacks the requested element as a perfect match, so a nameless entry
  wins everything.
- Every one of the 352 files in `~/.cache/fontconfig` had been rewritten at
  09:17:43–46. No font directory, no TeX Live tree, no package changed after
  08:59. `plocate-updatedb` ran 09:16:54–09:17:58 and Chrome started at
  09:17:42, its first start since its update to 154.0.8037.57 the evening
  before.
- A cache built in the scratchpad by the system's own `fc-cache` against the
  same configuration matched correctly and named all 42 wrappers properly, so
  the configuration was sound and the cache was the fault.
- The layouts differ: Fedora's fontconfig 2.17.0 writes real `cache-9` files
  (and `le32d4.cache-9` for 32-bit clients); the 09:17 writer wrote real
  `cache-12` files with `cache-9`, `-10` and `-11` symlinks pointing at them,
  and Fedora's library, looking for `cache-9`, followed the symlink and
  accepted the file. A fontconfig with cache version 12 is newer than
  Fedora's.
- Chrome's binary and Brave's contain fontconfig's internal strings
  (`FcCacheTimeValid`, `FONTCONFIG_SYSROOT`, twenty-odd "Fontconfig warning"
  messages) beside the system library both also link; Ghostty's contains none.
  Both browsers carry their own copy for their own scanning. Brave's ran at
  08:52 and 09:13 without effect; Chrome's, updated the night before, wrote
  the caches. What its scanner does with a WOFF was not pursued.
- The `gnome-system-monitor` crash at 09:44 is unrelated: GTK tree-model code.

**What changed.**

- `fontconfig/conf.d/09-texlive-fonts.conf` gained a third `rejectfont`
  block, `*.woff` and `*.woff2`. With the bad cache still in place the rule
  alone restored every match and removed all 42 entries from `fc-list`, which
  confirms the charter's standing claim that `selectfont` is applied when a
  cache is loaded, not when it is written. Faces under `/usr/local/texlive`
  go from 2,317 to 2,275; families are unchanged, since every wrapper's face
  ships beside it as `.ttf` or `.otf`.
- `fc-cache -f` on bigfed (4.5 s) replaced the `cache-9` symlinks with the
  system's real files. Chrome's `cache-12` files and the `-10`/`-11` symlinks
  were left: Chrome reads its own and would recreate them.
- `fontconfig/CLAUDE.md` (three blocks, the new figure, the one case where
  `fc-cache -f` is the remedy) and the root index row.

**Declined.**

- Rejecting the two directories by full path: would carry the pinned year and
  would not cover a wrapper TeX Live adds elsewhere. The suffix globs cover
  every `<dir>` and keep the year on one line.
- Dropping the TeX Live `<dir>`s: the package's whole purpose.
- Deleting Chrome's cache files: it would rewrite them at its next start.
- An upstream report: recorded here instead, per standing rule.

**Verified.** After the rebuild, `Super+T` opened five windows between 12:42
and 12:43 with Chrome started four times in between; the journal shows each
one starting its shell and no `FontconfigNoMatch`. Chrome's starts wrote
nothing: no file in `~/.cache/fontconfig` is newer than the rebuild, so its
scanner rewrites only when its own files are missing, and the guard is not
exercised in normal use. fedxps was unaffected at the time (cache last
written 2026-09-16, matches correct) and carries the same Chrome 154; the rule
reaches it with the next pull, and the pull alone repairs it if Chrome runs
there first, since the rule applies at load. A scratch mistake during the
diagnosis wrote 705 cache files into `~/.fontconfig`, the legacy cache
directory, for eight minutes; removed the same session, and it is why the
first "fixed" reading was set aside.

Settled the same afternoon, beside this and unrelated to it: sway's `$mod+x`
on fedxps keeps `gnome-text-editor` rather than calling `tabula` (his call,
2026-09-23; `bin/CLAUDE.md` carries the verdict). The bash session itself
built nothing after the incident: its picture of the interactive half and his
decisions on the shell-options slot are in `TODO.md` item 3 and in the brief
for the next session, which builds them.

## The shell-options slot: the history contract, and what `HISTFILESIZE` counts — 2026-09-23

Session three of the bash campaign built what session two decided (`TODO.md`
item 3, the session-two postscript): `00-shell-opts.sh`, the reserved empty
slot since the modular layout began, now states everything about history and
sets four shell options. Deployed on bigfed the same afternoon; fedxps takes
it at its next pull.

**What changed.**

- `bash/.bashrc.d/00-shell-opts.sh`: `HISTSIZE=20000`, `HISTFILESIZE=40000`,
  `HISTTIMEFORMAT='%F %T '`, `HISTCONTROL=ignoredups`,
  `HISTIGNORE='exit:clear'`, `histappend` restated, `history -a` appended to
  `PROMPT_COMMAND` as an array element behind a guard for `reload`, and
  `globstar`, `checkjobs`, `no_empty_cmd_completion`, `histverify`. Every
  measurement and every declined option is in the file's comments.
- `tests/shell-opts/run.sh`: 45 checks, caged like `tests/env/run.sh`,
  against a fixture HOME and a sandboxed history file. Its shells read their
  commands from a file with `bash -i`, so prompts run and bash-preexec
  installs — `bash -ic` shows no prompt and neither loads nor writes history,
  so it tests a shell no terminal has. Covers a WezTerm-shaped shell and a
  replica of Ghostty's launch.
- The root index and `bash/CLAUDE.md`'s module map; `TODO.md` item 3; the
  memory `configs-intentional-not-stale`.

**Measured, and one premise corrected.** The decision was for 20,000 entries,
written as `HISTFILESIZE=20000`. Built that way the file would have held
10,000: assigned during startup — where every module assignment is —
`HISTFILESIZE` counts *lines*, the `#<epoch>` stamp lines included (a file of
20,010 dated entries, 40,020 lines, kept 20,000 lines and 10,000 entries).
The same assignment typed at a prompt counts entries and skips the stamps,
one short (30 dated entries under a limit of 20 kept 19; from an rc file,
10). The split is by when the assignment runs, not by file size (checked at a
prompt from 941 bytes to 103 KB: entries every time). So the limit is written
as 40,000 lines, which is 20,000 dated entries at steady state, and more
while the old file's 1,000 undated lines remain. `HISTSIZE` counts entries
either way (1,500 dated entries under `HISTSIZE=1000` loaded 1,000).

- The trim runs at every shell start, never at exit. The exit-time save is
  skipped when nothing is left to save, and the per-prompt write leaves
  nothing: 20,000 entries plus a session's three came back from exit at
  20,003, and the next start cut the file to the limit. Measured beside it
  and not explained: with histappend and no per-prompt write, bash 5.3's
  exit-time trim fired for undated session lines and not for dated ones.
- Cost at a terminal shell's start (bigfed, `bash -i` to exit, WezTerm's
  shape, 30 runs each): 106 ms empty; +3.5 ms at 10,000 dated entries; +6.5
  at 20,000 undated; +7.4 at 20,000 dated (40,000 lines); +9.6 at 40,000
  undated. Entries drive it more than lines; session two's +9 at 20,000
  stands.
- `history -a` itself: 14 µs a prompt with one new entry, 2 µs with none
  (1,000 appends over a 20,000-entry list).
- Undated entries stay undated in the file; `history` shows each with the
  time the shell that loaded them started, not blank — bash stamps every
  entry on load and the file's own stamp overrides it where there is one.
  (The brief had them showing undated.)
- Ghostty's PS0 hook runs `HISTTIMEFORMAT='' builtin history 1` in the
  current shell before each command; the entries written after it still
  carry stamps. Pinned by the suite.
- The `history -a` element sits at index 2, after systemd's context hook and
  before Ghostty's; bash-preexec's rewrite of element 0 leaves it alone, and
  `__bp_interactive_mode` stays last. Two sources of `~/.bashrc` leave one
  element; the guard removed, two.
- `HISTIGNORE`'s one side effect: a hook that learns the running command from
  `history 1` — Ghostty's window title, WezTerm's `WEZTERM_PROG` — shows the
  previous command while `clear` or `exit` runs, for as long as they take.

**Declined** (session two, his answers of 2026-09-23): `erasedups` (the log
becomes a set: 247 and 172 distinct lines out of 1,000); `ignorespace` (dead,
bash-preexec strips it at the first prompt); `lithist`; `autocd` and
`cdspell` (offered, not taken); `history -n` (other windows' commands would
interleave into this one's recall); `lsa`, `ls`, `cd ..` in `HISTIGNORE`.
Session three, while building: a trap on EXIT to force an exit-time trim
(clever, where the start-time trim already bounds the file); extending
`tests/env/run.sh` rather than adding a sibling (that suite is about the
login shell's output, this one about the interactive shell's — the cage
prelude is now in two files and could become `tests/cage.sh` when a third
suite wants it).

**Verified.** `tests/shell-opts/run.sh` 45/45 in its cage on bigfed; a new
interactive shell on bigfed shows the whole contract with `history -a` once
among three elements; the module sourced on fedxps's own system layer over
ssh (`TERM=xterm-256color`, bash 5.3.9 there too) shows the same. fedxps's
deployment and its suite run wait for the pull.

**Left open.** B and C of item 3; item 25; the `~/.local/bin` tidy and item
10, this session's next two jobs.

## 10. `gpullall`'s restow hint sees a *new* stow package — COMPLETE 2026-09-23

Found 2026-09-03 by exercising the workflow end to end: a `configs` pull on
bigfed that added the new `ghostty` package printed only
`[HINT] configs: bash files changed — run: source ~/.bashrc`, and never
mentioned `stow-all`. Open as `TODO.md` item 10 until this day; closed by
session three of the bash campaign.

**The gap.** The post-pull hint classification (`_gsync_pull_hints` in
`50-git-sync.sh`) built its package list, `is_pkg`, from `STOW_ORDER` **as
loaded in the running shell**. A brand-new package is by definition absent
from that array, because the pull that added it has only just updated
`60-stow.sh` on disk. So `ghostty/config` classified as "not in a stow
package", `pkg_hit` stayed empty, and the hint could not fire. The same
in-memory-versus-disk trap `stow-all` itself has, one layer up, in the tool
built to warn about it — and missing exactly the case that matters: the hint
was reliable for changes to *existing* packages and structurally blind to a
*new* one, the only case where forgetting to restow fails silently. It did
not bite only because adding a package means editing `60-stow.sh`, which
lives in `bash/`, so the re-source hint fired — luck, not design, and
followed literally it left the new package unlinked. The suite never caught
it because `test-gsync.sh` and `test-audit.sh` both source the current
`60-stow.sh`, so `STOW_ORDER` was always fully populated, and every
stow-hint assertion added files to an existing package.

**The fix.** `is_pkg` is now the repo's top-level directories on disk, read
after the pull, minus the named non-packages `docs`, `tests`, `wallpapers`
and any dotdir, unioned with `STOW_ORDER`. The union keeps a package the pull
deleted, which by then lives only in the array. It degrades in the right
direction: an unrecognised directory yields a spurious hint at worst, never a
missing one. Scoped to the `configs` repo; the `org` call path is unchanged.

**Tests.** Nine checks added to `test-gsync.sh` section 9: a commit adding
`newpkg/config` fires the stow hint and names `newpkg` — both fail against
the pre-fix code, verified by running the new suite against HEAD's
`50-git-sync.sh` in a scratch tree — `docs/`, `tests/`, `wallpapers/` and a
top-level file are not named, and a commit deleting the `nvim` package still
hints and names it. `tests/gsync/run-all.sh`: 177 checks, all passing. The
root charter's `gpullall` bullet and the bash charter's hint paragraph no
longer carry the caveat.
