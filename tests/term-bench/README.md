# term-bench — comparing terminal emulators on one machine

Two harnesses, written 2026-09-03 for the Ghostty/WezTerm comparison. The
findings live in `docs/ghostty-vs-wezterm-2026-09-03.md`; this directory is the
instrument, kept so the measurement can be repeated after a version bump
without rediscovering how to make it honest.

- **`term-bench`** — flood throughput (200000 plain lines, 60000 attribute-heavy
  lines, best of 3) plus 300 `CSI 6n` round trips as a proxy for the
  parse-and-respond path. Reports terminal identity, the live graphics stack,
  CPU-versus-wall per phase, and contention.
- **`sgr-sweep`** — the same 40000 lines and 60 visible columns at eight
  attribute densities (0 to 64 SGR changes per line), which is what located the
  crossover where the two terminals draw level.

Run each **inside** the terminal under test, one terminal at a time:

    tests/term-bench/term-bench
    tests/term-bench/sgr-sweep

Corpora are generated once, deterministically, into
`$TERM_BENCH_CORPUS` (default `$TMPDIR/term-bench-corpus`) — about 75 MB, never
committed. Set `TERM_BENCH_OUT=<file>` to append the summary to a file as well
as the screen, which is how a terminal spawned non-interactively hands results
back.

## Why the corpus is what it is

Lines carry **varied** text, not a repeated character. A repeated glyph is a
degenerate case that measures the glyph cache rather than the terminal, and the
first version — 60 repeated `x` — produced a zero-density figure that
contradicted `term-bench` on the same terminals in the same session.

## Seven traps, each of which produced a plausible number that meant nothing

These are the reason this directory exists rather than a note saying "write a
benchmark". Every one was live at some point and had to be caught.

1. **Capturing the thing being timed.** `$(throughput …)` sent `cat` down a
   pipe, so the first version timed pipe throughput and never rendered to the
   screen at all. It reported both terminals as identically fast. Anything
   measuring a terminal must actually reach the terminal.
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

## Reading the output

`CONTENTION` far above its usual band, or any non-monotonicity in `sgr-sweep`
(a higher density coming out faster than a lower one), means the run was
disturbed and should be repeated. Both showed up in practice and both were
right to distrust.

Ghostty's figures vary more run to run than WezTerm's, and short phases amplify
it; prefer the longer `term-bench` flood over `sgr-sweep`'s `d=0` row when the
two disagree about sparse text. `sgr-sweep` runs `d=0` first, so it also absorbs
the terminal's warm-up.
