# term-bench — comparing terminal emulators on one machine

Harnesses written 2026-09-03 for the Ghostty/WezTerm comparison and extended
2026-09-05. The findings live in `docs/ghostty-vs-wezterm-2026-09-03.md`; this
directory is the instrument, kept so the measurement can be repeated after a
version bump without rediscovering how to make it honest.

**Scroll-shaped** — output appended and scrolled off the top:

- **`term-bench`** — flood throughput (200000 plain lines, 60000 attribute-heavy
  lines, best of 3) plus 300 `CSI 6n` round trips as a proxy for the
  parse-and-respond path. Reports terminal identity, the live graphics stack,
  CPU-versus-wall per phase, and contention.
- **`sgr-sweep`** — the same 40000 lines and 60 visible columns at eight
  attribute densities (0 to 64 SGR changes per line), which is what located the
  crossover where the two terminals draw level.
- **`color-sweep`** — the same eight densities in three SGR *encodings* of one
  set of twelve colours: `\e[31m`, `\e[38;5;1m`, `\e[38;2;r;g;bm`. Built to
  isolate WezTerm's inline-versus-heap attribute storage; it found no such
  effect, which is why it is kept. Needs `gen-color-corpora.py`.

**Repaint-shaped** — alternate screen, cursor addressing, cells overwritten in
place, frames wrapped in synchronized output:

- **`capture-nvim FILE [REPS]`** — runs a real nvim session over `FILE` under
  `ptytee.py`, captures its byte stream, and builds `repaint.bin` from the
  alternate-screen body. Any large syntax-highlighted file works.
- **`ptytee.py`** — a minimal `script(1)`, which Fedora does not ship here. Sets
  the pty winsize explicitly and forwards stdin, so nvim's DECRQM probes reach
  the real terminal and synchronized-output framing survives into the capture.
- **`repaint-bench`** — replays `repaint.bin`, and brackets it with plain floods
  measured **cold**, **warm**, and **in the alternate screen**.

**Neither shape:**

- **`probe OUTFILE`** — reports the settled grid; the settle loop is
  load-bearing (trap 8). Used to verify every grid claim below.
- **`compo.py CAPTURE`** — composition of a captured stream (bytes, SGR,
  truecolour, sync markers, cursor positionings), for checking two captures are
  comparable before comparing what produced them.
- **`latency-bench`** — `CSI 6n` round trips idle and **under sustained
  output**. The loaded figure is the one that tracks what feels laggy; the two
  terminals were within 1.2x idle and 8.6x apart under load on fedxps,
  19.7x on bigfed.

Run each **inside** the terminal under test, one terminal at a time:

    tests/term-bench/term-bench
    tests/term-bench/repaint-bench
    tests/term-bench/latency-bench

Corpora are generated once, deterministically, into
`$TERM_BENCH_CORPUS` (default `$TMPDIR/term-bench-corpus`) — several hundred MB
with the colour and repaint corpora, never committed. **On Fedora `/tmp` is
tmpfs, so that is RAM**; check `df -h /tmp` before generating and delete
afterwards. Set `TERM_BENCH_OUT=<file>` to append the summary to a file as well
as the screen, which is how a terminal spawned non-interactively hands results
back.

## Controlling the grid

`term-bench` says "keep this equal across runs", and getting that is where most
of the setup effort goes. Verify with `probe`, never by assumption:

    ghostty --gtk-single-instance=false -e ./probe /tmp/g && cat /tmp/g

**Best method — ask for cell counts directly.** Both terminals accept an exact
grid, which beats matching pixels because their cell metrics differ:

    ghostty --gtk-single-instance=false --window-width=300 --window-height=60 ...
    wezterm --config initial_cols=300 --config initial_rows=60 start --always-new-process -- ...

⚠ There is a ceiling: a request that will not fit gets clamped, and the two
clamp *differently* — 400x70 yielded Ghostty 400x70 but WezTerm 510x66 on a
5120x1440 display. Always confirm with `probe` before trusting a large grid.

**On GNOME this is free.** With no tiling WM overriding them, both terminals
simply open at the size their configs request; both landed on 100x40 unprompted
on bigfed.

**On sway you must force it**, because sway sizes the window and the two derive
different cell counts from the same pixels — uncontrolled, one pass had Ghostty
at 63x52 against WezTerm at 100x40:

    swaymsg 'for_window [app_id="org.bench.gh"] floating enable, border none, resize set width 1200 px height 700 px'
    swaymsg 'for_window [app_id="org.bench.wz"] floating enable, border none, resize set width 1200 px height 700 px'
    ghostty --gtk-single-instance=false --class=org.bench.gh -e env TERM_BENCH_OUT=... <harness>
    wezterm start --always-new-process --class org.bench.wz -- env TERM_BENCH_OUT=... <harness>

At 1200x700 on a 1920x1080 scale-1 display both land on 100x40 here. The rules
are live-only and vanish on the next `swaymsg reload`; they match nothing
afterwards, so no reload is required. Do **not** reach for a nested compositor
to get a controlled surface — `org/machines/` records one taking the session
down through a Waybar it spawned.

## Running against the other machine

The whole suite drives over ssh into a live graphical session, which is how
bigfed was measured from fedxps on 2026-09-05. Three variables are needed or
the terminals will not find the compositor:

    ssh bigfed 'export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; ...'

Windows open on *that* machine's screen, so only do this when nobody is sitting
at it. Stage the harnesses under `/tmp` rather than pulling the repo, so the far
machine's tree stays clean and no sync is provoked. Check with `git status`
there before and after.

To compare two machines rather than two terminals, hold everything else still:
same package versions, same input file (`md5sum` it), same grid, and compare the
capture compositions with `python3 compo.py` before trusting anything. The
2026-09-05 pair agreed within 0.5% on bytes, SGR count and truecolour count.

## Why the corpus is what it is

Lines carry **varied** text, not a repeated character. A repeated glyph is a
degenerate case that measures the glyph cache rather than the terminal, and the
first version — 60 repeated `x` — produced a zero-density figure that
contradicted `term-bench` on the same terminals in the same session.

The repaint corpus is not synthetic at all. It is a recording of nvim doing what
nvim does, because a synthetic attribute density turned out not to predict it:
see trap 10.

## Twelve traps, each of which produced a plausible number that meant nothing

These are the reason this directory exists rather than a note saying "write a
benchmark". Every one was live at some point and had to be caught.

1. **Capturing the thing being timed.** `$(throughput …)` sent `cat` down a
   pipe, so the first version timed pipe throughput and never rendered to the
   screen at all. It reported both terminals as identically fast. Anything
   measuring a terminal must actually reach the terminal. *This one bit a second
   time on 2026-09-05, in `repaint-bench`, where `rows=$(run …)` swallowed
   1.6 GB of corpus into a variable. The timing helpers now set a global and
   must never be called in a command substitution.*
2. **A tty guard that command substitution falsified.** `dsr_us=$(dsr)` makes
   stdout a pipe, so the function's `[[ -t 1 ]]` test was false on a perfectly
   good terminal and the latency phase silently reported "no tty". Probe
   `/dev/tty` directly; do not infer a terminal from fd 1.
3. **Identity read from the environment.** `GHOSTTY_*` and `WEZTERM_PANE` are
   inherited by children, so a WezTerm launched from a Ghostty window reported
   itself as Ghostty. Walk the process tree to the owning `wezterm-gui` /
   `ghostty` instead; the tree cannot be inherited.
4. **Sampling the renderer before it exists.** `/proc/<pid>/maps` read at
   startup shows no graphics libraries: the terminal spawns the shell before
   its GPU context is up. Sample at both ends of the run — the empty start
   sample is the evidence for the ordering. Getting this wrong made a
   `front_end="WebGpu"` result uninterpretable, since a renderer that silently
   fell back looks identical to one that engaged and did not help.
5. **`LINES` is not yours.** Bash sets it to the terminal height. Using it as a
   loop bound put the derived per-line column out by a factor of 1000.
6. **A degenerate corpus** — see above.
7. **Contention accounting that flatters itself.** Total non-idle CPU minus the
   terminal's own still includes `cat` producing the corpus, so the figure is a
   relative signal across runs of the same shape, not an absolute idleness
   measure. Read it as "was this run like the others", not "was the machine
   quiet".
8. **Reading the grid before it settles.** Under a tiling WM the window is
   resized *after* the shell is spawned, so `tput cols` at t=0 reports the
   pre-resize size. Three consecutive identical readings, then proceed. Without
   this, a search for the pixel size giving a target grid reports the same
   answer for every input.
9. **Cold caches.** The first flood into a fresh terminal measures warm-up, not
   steady state. WezTerm's plain throughput improved 2.6x between its first rep
   and a rep taken after 115 MiB of varied work; Ghostty's improved 1.4x.
   Three reps of the *plain* corpus did not warm it — only the large varied one
   did. Always say which of the two you are reporting.
10. **Assuming one output shape predicts another.** The scroll-shaped sweep says
    Ghostty costs ~1.4x more CPU at 64 SGR changes per line. Real nvim, denser
    still and fully truecolour, has Ghostty costing *half*. A synthetic
    attribute density is not a substitute for a recording of the real thing.
11. **Latency measurements that saturate their own timeout.** A per-trip read
    timeout silently converts "no reply" into "slow reply": one version reported
    1.4 s for WezTerm purely because it was pinned near a 2 s cap. Use a fixed
    wall-clock window, count timeouts separately from completions, and report
    both. Note also that per-trip `date` forks cost ~1.25 ms, which swamps an
    ~80 us idle signal — amortise the idle case, window the loaded one.
12. **A repaint corpus is locked to the grid it was captured at.** It is
    cursor-addressed, so replaying `repaint.bin` at any other grid lays the
    frames out wrongly and times nonsense. Re-run `capture-nvim` for every grid
    you intend to measure, keeping each corpus in its own `TERM_BENCH_CORPUS`
    directory. This is also why the grid must be settled *before* capturing, not
    only before replaying.

## Reading the output

`CONTENTION` far above its usual band, or any non-monotonicity in `sgr-sweep`
(a higher density coming out faster than a lower one), means the run was
disturbed and should be repeated. Both showed up in practice and both were
right to distrust.

Ghostty's figures vary more run to run than WezTerm's, and short phases amplify
it; prefer the longer `term-bench` flood over `sgr-sweep`'s `d=0` row when the
two disagree about sparse text. `sgr-sweep` runs `d=0` first, so it also absorbs
the terminal's warm-up.

Prefer **terminal CPU** over wall clock wherever both are reported. Wall clock
is what contention corrupts, and on a machine also running an editor or an
agent the contention figure routinely reaches 1500 ms over a 1300 ms phase.
