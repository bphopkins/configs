# Ghostty against WezTerm — measured on fedxps, 2026-09-03

Dated record. Prompted by an impression that Ghostty "feels slightly faster",
taken after the Ghostty stow package was written as a deliberate transcription
of `~/.wezterm.lua` (`ghostty/config`, which carries the settings themselves).

**Verdict, as both ship: the impression is right and understates it.** Ghostty
drains plain output ~2.2–2.6x faster, attribute-heavy output ~1.4–1.5x faster,
and answers a cursor-position query ~37x faster. Process contention, grid size,
frame-rate caps and the graphics stack were each checked and excluded.

**But the latency half of that is one WezTerm default, and it is a one-line
fix.** `mux_output_parser_coalesce_delay_ms` defaults to 3. Setting it to 0
takes WezTerm's round trip from 3588 µs to **137 µs** — against Ghostty's 90 —
closing a 37x gap to about 1.5x, at no measurable throughput cost. The
throughput half is compute and survives: no setting reaches it.

Scope: fedxps, GNOME/Wayland, Mesa GL, 1920x1080@59.934. Ghostty 1.3.1-4.fc44
(RPM), WezTerm nightly 20260901_002820_4fbd6b8e. One machine, one session; not
re-run on bigfed.

## Numbers

Harness: 200000 plain ASCII lines and 60000 lines carrying SGR colour plus
bold/faint/italic, one fixed deterministic corpus so both terminals consume
identical bytes; best of three; plus 300 `CSI 6n` round trips in raw mode.

| run | cells | plain 200k | sgr 60k | cursor round-trip |
|---|---|---|---|---|
| Ghostty, first pass | 4940 | 366 ms | 201 ms | — |
| Ghostty, second pass | 4940 | 433 ms | 219 ms | 95 µs |
| WezTerm, shared GUI process | 4512 | 947 ms | 325 ms | 3585 µs |
| WezTerm, `--always-new-process` | 4000 | 935 ms | 310 ms | 3540 µs |

Per line: Ghostty 1.83–2.17 µs plain and 3.35–3.65 µs with attributes; WezTerm
4.67 µs and 5.17 µs.

## Excluded explanations

- **Process contention.** WezTerm runs every window in one GUI process, so the
  first WezTerm run shared pid 6041 with a live Claude Code TUI. Re-running
  under `wezterm start --always-new-process` in a separate pid moved plain by
  1.3%, sgr by 4.6% and the round trip by 1.3%. Contention explains none of it.
- **Grid size.** Every WezTerm run drew *fewer* cells than Ghostty — 4512 and
  4000 against 4940, the last 19% fewer — and lost anyway. The confound runs
  the wrong way throughout.
- **Line wrapping.** Longest corpus lines are 62 and 38 visible columns, under
  every grid measured, so no run paid a wrap cost another avoided.
- **Frame-rate cap.** WezTerm's `max_fps` defaults to 60 and the panel reports
  59.934 Hz as its only mode. No headroom was being lost.
- **Graphics stack.** WezTerm runs OpenGL here, not the WebGpu its recent
  versions default to: the live `wezterm-gui` maps `libEGL_mesa`, `libEGL`,
  `libgallium` and no `libvulkan`. Forcing `front_end="WebGpu"` in a fresh
  process **did** engage — that process additionally mapped `libvulkan` and
  `libvulkan_intel`, and `wezterm.gui.enumerate_gpus()` ranks the Intel HD 630
  Vulkan adapter above the llvmpipe CPU one, so hardware Vulkan was selected
  and not a software fallback. It changed nothing measurable: 939 ms / 334 ms /
  3566 µs against a same-session OpenGL control at 953 ms / 334 ms / 3555 µs.
  The renderer is not the bottleneck, and this is the strongest of the four
  exclusions because the alternative was proven to be running.

## The multiplexer explanation, withdrawn

An earlier draft of this file attributed the gap to WezTerm routing local pane
*data* through its multiplexer, citing `wezterm_mux_server_impl::local >
writing pdu data buffer` from the journal. Read in context, that line is the
existing GUI instance failing to write a **spawn response** back to a `wezterm
start` client that had already disconnected — window-creation RPC, not per-byte
terminal output. WezTerm does model local panes in a `Mux`, but in-process, and
nothing measured here puts PDU serialisation on the data path. The claim outran
its evidence and is withdrawn.

What remains true is narrower: `wezterm cli list` can address a live local
pane, so some such layer exists. Whether it costs anything per byte was never
tested.

Ghostty's io_uring event loop was offered as a second mechanism when this was
first written and is **withdrawn**. Ghostty's own documentation for
`async-backend` states that its benchmarks found no statistically significant
difference between `io_uring` and `epoll` in memory, CPU or latency. The
vendor's published position contradicts the mechanism, so it is not one.

Two Ghostty knobs were checked as possible further gains and rejected:
`window-vsync`, which its documentation says is "only supported currently on
macOS"; and `async-backend`, for the reason just given.

## Where the time actually goes

The harness samples the terminal process's own `utime + stime` around each
phase, which separates work from waiting — the two have identical wall clocks.

| phase | WezTerm | Ghostty |
|---|---|---|
| plain flood | 4020 ms cpu / 2847 ms wall = 141% | 2300 ms cpu / 1440 ms wall = 159% |
| sgr flood | 1410 / 1018 = 138% | 1070 / 681 = 157% |
| 300 round trips | 130 / 1087 = **11%** | 20 / 32 = **62%** |

**There are two bottlenecks here, not one.**

- **Throughput is compute.** Both terminals are CPU-bound and both use more
  than one core. WezTerm burns 4020 ms of CPU where Ghostty burns 2300 ms for
  the same 600000 lines — 1.75x more CPU per byte, 6.7 µs against 3.83 µs per
  line. What that extra work consists of was not identified.
- **Latency is waiting.** WezTerm computes roughly 0.43 ms per reply but takes
  3.6 ms of wall clock, so about 3.2 ms of every round trip is spent not
  running. Ghostty runs at 62% CPU and answers in 0.09 ms. The 37x gap is not
  37x more work; it is a wait that Ghostty does not have.

Typing latency is the wait, not the work. That is why the impression which
prompted this investigation was about feel rather than throughput, and why the
throughput figures alone would have under-predicted it.

Sampling `/proc/<pid>/task/*/wchan` across a 3000-iteration round-trip loop
showed the process almost wholly blocked: `futex_do_wait` on several threads,
and one `wezterm-gui` thread in `hrtimer_nanosleep` — a deliberate timed sleep
— in every sample. That pointed at a timer, and the timer has since been named.

## What WezTerm is waiting on: `mux_output_parser_coalesce_delay_ms`

`wezterm --config <name>=1 ls-fonts` rejects an unknown field by name ("`x` is
not a valid Config field"), which makes it an oracle for probing the config
vocabulary without opening a window. Probing turned up
**`mux_output_parser_coalesce_delay_ms`** — a deliberate delay in the *output
parser*, which is precisely the path a `CSI 6n` reply must traverse.

Established by intervention, three fresh processes, same harness:

| `mux_output_parser_coalesce_delay_ms` | round trip | dsr CPU/wall | plain |
|---|---|---|---|
| unset (control) | 3555–3606 µs | 11% | 935–953 ms |
| `3` | 3588 µs | 12% | 955 ms |
| `0` | **137 µs** | **86%** | 936 ms |

Three findings follow.

1. **The default is 3.** Setting it explicitly to 3 reproduces the control to
   within noise; the option is the whole of the wait.
2. **Zero collapses the latency 26x**, from 3588 µs to 137 µs, and the CPU
   share during the round-trip phase rises from 12% to 86% — the process stops
   waiting and starts working. Ghostty answers in 90 µs, so this closes a 37x
   gap to roughly 1.5x.
3. **It buys nothing here.** Throughput is unchanged: 936 ms against 955 ms
   plain, 324 against 321 sgr, and CPU burned is flat at ~4.1 s either way. On
   this workload the coalescing is pure latency cost.

3 ms of delay plus the 137 µs floor predicts 3.14 ms; 3.59 ms was measured, so
the timer behaves as somewhat more than its nominal value — scheduling and
timer granularity, not investigated further.

The option is named for the **mux**, and that is likely where it earns its
keep: coalescing output arriving over a network from an ssh or tls domain. For
a local pane it is a tax. Not tested against a remote domain, so the case for
the default is untested rather than disproven.

## Why the default is 3, and what zero costs

Wez Furlong's own account: WezTerm deliberately delays escape-sequence
processing to get better batching and less tearing with *non-synchronized*
output, adding up to 3 ms after each read so that a TUI's screen update
coalesces into a single frame. The delay is not carelessness. It is a
**heuristic stand-in for a frame boundary the application never declared** —
the terminal waits a moment to see whether more of the same redraw is coming.

Which raises the question of why WezTerm has to guess when Ghostty does not.
Measured here, the asymmetry is in what each terminal advertises:

| | TERM | `Sync` terminfo capability |
|---|---|---|
| Ghostty | `xterm-ghostty` | `Sync=\E[?2026%?%p1%{1}%-%tl%eh%;` |
| WezTerm | `xterm-256color` | **absent** |

WezTerm ships a `wezterm` terminfo entry that does carry `Sync`, but the
Fedora RPM installs **no terminfo at all** — nothing under `/usr/share/terminfo`
and nothing in `rpm -ql`. So `config.term = "wezterm"` would name an entry this
machine does not have, and is not the fix.

The saving grace is that the good TUIs do not consult terminfo for this. They
ask. `nvim` emits `CSI ? 2026 $ p` (DECRQM) during startup — confirmed by
capturing a bare `nvim -u NONE +q` through a pty — and enables synchronized
output only on an affirmative answer. Both terminals answer affirmatively:

| mode | WezTerm | Ghostty |
|---|---|---|
| 2026 synchronized output | `?2026;2$y` — supported | `?2026;2$y` — supported |
| 2027 grapheme clustering | `?2027;3$y` | `?2027;1$y` |
| 2031 colour-scheme notify | `?2031;0$y` — not recognised | `?2031;2$y` — supported |

So for nvim the coalescing is redundant: nvim declares its frame boundaries
explicitly and WezTerm honours them. **What zero costs is the blanket over
programs that never ask** — anything writing escape sequences without
negotiating 2026 loses the inferred frame boundary and may tear. `1` is the
middle setting if one ever turns up.

Untested: whether the coalescing earns its keep for a *remote* mux domain,
which is what the option is named for. Batching output arriving over ssh or
tls in small packets is a different case from a local pty and may well justify
the default there. A local `unix_domains` pane would test it without a network.

## Can WezTerm be made as fast? Tuned comparison, idle machine

Re-run with the machine handed over and untouched, so these supersede the
earlier figures where noted. WezTerm tuned means
`mux_output_parser_coalesce_delay_ms = 0` and
`mux_output_parser_buffer_size = 1048576`.

**`mux_output_parser_buffer_size` is worth 13%** — two reps each, 200000 lines:

| buffer | plain | | buffer | plain |
|---|---|---|---|---|
| 16 KiB | 1057, 1058 ms | | 1 MiB | **851, 838 ms** |
| default | 968, 973 ms | | 4 MiB | 867, 889 ms |
| 128 KiB | 955, 938 ms | | Ghostty | 446, 400 ms |

The default sits near 128 KiB, 1 MiB is the floor and 4 MiB is past it. It does
not close the gap — tuned WezTerm 844 ms against Ghostty 423 ms is still 2.0x —
it only stops giving away the part that was configuration rather than compute.

**Where the crossover actually is.** Three reps each, 40000 lines of varied
text, 60 visible columns, varying only the number of SGR changes per line:

| SGR/line | WezTerm (3 reps, ms) | Ghostty (3 reps, ms) | median ratio |
|---|---|---|---|
| 0 | 110, 151, 159 | 84, 84, 90 | 1.80x Ghostty |
| 4 | 167, 187, 216 | 145, 152, 172 | 1.23x Ghostty |
| 8 | 223, 226, 236 | 185, 191, 208 | 1.18x Ghostty |
| 16 | 324, 333, 346 | 248, 254, 282 | 1.31x Ghostty |
| 24 | 388, 393, 425 | 354, 382, 394 | 1.03x — tie |
| 32 | 415, 417, 444 | 397, 404, 439 | 1.03x — tie |
| 48 | 551, 575, 579 | 565, 578, 588 | 0.99x — tie |
| 64 | 659, 708, 710 | 712, 714, 751 | 0.99x — tie |

**WezTerm never wins.** The gap closes to a tie by 24 SGR changes per line and
stays flat to 64 — it does not invert. The earlier linear model predicting
WezTerm 1.49x ahead at d=64 was wrong; the curves converge, they do not cross.

Caveat on the d=0 row: it runs first in the sweep and absorbs the terminal's
warm-up, which is why WezTerm's spread there (110–159) is far wider than
anywhere else. The 2.0x figure from the longer 12.6 MB term-bench flood is the
better estimate for sparse text.

**Where real work sits on that curve**, measured on this machine:

| workload | SGR per line |
|---|---|
| `ls --color` (multi-column) | 0.0 |
| `ls --color -la` | 1.7 |
| `git log --oneline --color` | 2.0 |
| `git diff --color` | 2.2 |
| `grep --color` | 11.6 |
| **nvim repaint (treesitter)** | **≥37** |

Everything typed at a shell is sparse and sits where Ghostty leads. Only nvim
is dense enough to reach the tie — and a full nvim repaint is ~75 KB, under a
millisecond either way. **The dense workloads are small and the big workloads
are sparse**, so the crossover is real but lands where the absolute times no
longer matter.

## Method faults found and fixed

Four in the harness (above) and three more in the sweep, all of which produced
plausible numbers that meant nothing:

5. The sweep used `LINES` as a variable. Bash had already set it to the
   terminal height (40), so the derived µs/line column was off by 1000x. The
   `ms` column was unaffected.
6. The first sweep corpus was 60 repeated `x` characters. That is a degenerate
   single-glyph case, and it disagreed with term-bench's ratio on the same
   terminals in the same session. Regenerated with varied text.
7. The contention metric counts all non-terminal CPU, which includes `cat`
   producing the corpus. It is usable as a relative signal across runs of the
   same shape, not as an absolute idleness measure.

Thermal throttling was checked and excluded: counters at zero, package 51 °C,
cores at 3.4–3.8 GHz against a 3.8 GHz max, on a machine whose own records flag
aging thermal paste.

## An inversion worth keeping

Ghostty's lead narrows from ~2.4x to ~1.5x once attributes are involved,
because the marginal cost of the SGR corpus over the plain one is **+1.5 µs per
line for Ghostty against +0.49 µs for WezTerm**. Ghostty pays roughly three
times more per attribute change and still wins on the total, because its
baseline per-line cost is about 2.5x lower. Heavily-coloured output is where
the gap is narrowest; a workload of nothing but SGR churn is where WezTerm
would come closest.

## What was not measured

The round trip times the terminal's parse-and-respond loop, which shares
machinery with the keystroke path but runs the other direction and excludes
compositor presentation. It is not input-to-photon latency; that needs hardware
not available here. The 37x is far too large to be an artefact of the proxy,
but no absolute typing-latency figure follows from it. Each `CSI 6n` iteration
also opens `/dev/tty` twice, a constant that inflates both sides equally and so
understates the ratio rather than flattering it.

## Harness

`term-bench`, written for this and left in the session scratchpad. Two bugs
were found in it before the numbers above were taken, both of which would have
produced a confident wrong answer:

1. `$(throughput …)` captured `cat` into a pipe, so the first version timed
   pipe throughput and never rendered to the screen. It reported both terminals
   as identically fast.
2. `dsr_us=$(dsr)` piped stdout, so the function's `[[ -t 1 ]]` guard was false
   on a perfectly good terminal and the latency test silently reported "no tty"
   in both runs. The guard now probes `/dev/tty` directly and the function sets
   a global rather than being captured.
3. Terminal identity was read from `GHOSTTY_*` / `WEZTERM_PANE` environment
   variables, which children inherit. A WezTerm launched from a Ghostty window
   reported itself as Ghostty. Identity now comes from walking the process tree
   to the owning `wezterm-gui` / `ghostty` process, which cannot be inherited.
4. The renderer libraries were sampled from `/proc/<pid>/maps` at startup, when
   the terminal has already spawned the shell but not yet finished bringing up
   its GPU context — so the field read empty and was mislabelled "unreadable".
   It is now sampled at both ends of the run, and the start sample is reliably
   empty, which is what exposed the ordering.

Anything measuring a terminal must reach the terminal. A capture that makes the
measurement quiet and plausible is the failure mode to watch for here.
