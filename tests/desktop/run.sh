#!/usr/bin/env bash
# Regression suite for the Sway desktop configs: sway (with its host layers),
# waybar, swaylock, mako, wofi, rofi. Written 2026-08-13, after a session in which
# four separate SILENT, CATASTROPHIC failure modes were found the hard way;
# rewritten 2026-09-30, after an audit found a third of its checks vacuous.
# The four that began it:
#
#   1. `sway --validate` does NOT check the command body of a bindsym. A typo
#      there passes validation and fails silently at runtime, forever. Nor
#      does it fail on an error inside an included file, such as a host layer.
#   2. A CSS parse error makes Waybar EXIT. Sway does not bring it back, and the
#      bar simply vanishes.
#   3. An unrecognised key makes swaylock stop reading its config at that line
#      and lock with the lines above it, so everything below silently reverts
#      to the defaults, and nothing on the lock screen says why.
#   4. mako refuses to START on an unknown key or a bad value (no notifications
#      at the next login); wofi ignores an unknown key, and GTK ignores a
#      misspelled selector.
#
# What it runs and starts. The suite re-executes itself in its own systemd
# scope (tests/cage.sh: 512M, no swap, 256 tasks, 120 s), and unsets
# WAYLAND_DISPLAY, DISPLAY and I3SOCK: nothing here is a client of the live
# session. It runs `sway --validate` on the headless backend (see validate()
# below), man, python3 and GTK's CSS parser with no display, and mako's own
# parser on its config, with `env -i`, its bus and display pointed at
# nothing in $SB: mako exits at the bus. It reads ~/.config/sway and never
# writes it. It starts ONE nested headless sway, from $SB, on a relative
# socket there (s.sock: a socket path holds 107 bytes, and sway and swaymsg
# cut a longer one short without a word, so two runs could share one);
# SWAYSOCK is that socket for the whole run, so no swaymsg here can reach
# the live session. The nested sway writes its Wayland socket into
# $XDG_RUNTIME_DIR, runs `uname -n` for its include line, and starts what
# its config starts -- so its copy of sway/config has every exec and
# exec_always line, every include but the relative host layer, and the bar
# block stripped, and swaynag_command -, swaybg_command -, xwayland disable
# and one headless output added; the host layers it loads are copies in $SB,
# stripped the same way. The suite asserts all of that before starting it,
# refuses to start it otherwise, and checks that what answers on s.sock
# loaded this run's copy. Why each strip matters is in the comment above
# the copy. Before it exits, the suite reads its own cgroup and fails if any
# sway, foot, swaybg, swaynag, Xwayland, swaymsg, jq, waybar or mako process
# is left in it.
#
# Mutation-verified 2026-09-30: each break was introduced alone into a copy of
# the tree (the real repo is never written to) and failed the check meant for
# it, and those downstream of it, while the unmutated copy passed clean.
#   sway/config: a trailing comment on the border line; a reordered duplicate
#     chord (Shift+$mod+f), a chord bound twice, Escape twice in the resize
#     mode; a misspelled command, and `fullscreenn` as a binding body;
#     repeat_rate a word; the adelotype launcher's path misspelled, and
#     slurpp in a screenshot body; client.urgent off $urgent, client.focused
#     off $accent; the swayidle line deleted; a flag on a swaylock call;
#     $msi's serial changed.
#   the host layers: a misspelled command in bigfed.conf, and in fedxps.conf;
#     $mod+q rebound in each; a swayidle timer in fedxps.conf without
#     inhibit_idle; fedxps.conf missing; ~/.config/sway/hosts unlinked (a
#     fake HOME whose ~/.config/sway points into the copy).
#   the other four: default-timeout=5s, a misspelled key, and the global and
#     the critical border drifted, in mako; #entyr, a misspelled key, and the
#     #window border off @accent, in wofi; a trailing space, a 7-digit
#     colour, `version`, a misspelled key, ring-color and ring-wrong-color
#     drifted, in swaylock; GTK3-invalid CSS, malformed JSON, the clock's
#     interval at 60, the accent define and button.urgent's fill drifted, in
#     waybar; wofi dropped from STOW_TARGETS.
#   the suite itself: `swaymsg exit` before the body loop (NO REPLY); an
#     exec_always line, the /etc include, the bar block and `xwayland
#     disable` each surviving the strip (the copy check fails, and no sway
#     starts); a sway that never starts; an identity check that cannot match;
#     mako's probe made always to pass (its anti-vacuity check); the nested
#     sway left running (the cage check).
#
# 51 checks on fedxps on 2026-09-30: 47, and two for each host layer (its
# inlined validation, its chords).
#
# Run from anywhere after editing any of the five configs or a host layer
# (~4 s). Last line follows the tests/gsync convention: "passed: N  failed:
# M"; exit 0 iff nothing failed. Requires bash 5+, sway, swaymsg, jq,
# python3 + python3-gi, man, ps; mako for its parser check.
set -u
CFG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$CFG_ROOT/tests/cage.sh"
cage desktop "$@"

SB="$(mktemp -d "${TMPDIR:-/tmp}/desktop-cfg.XXXXXX")" || exit 2
cd "$SB" || exit 2
export SWAYSOCK=s.sock
unset I3SOCK WAYLAND_DISPLAY DISPLAY
NESTED_PID=""
# The nested sway is signalled only while it lives and is this suite's own
# child, never by `swaymsg exit` unasked: whatever answers on a socket is not
# known to be this run's until the identity check says so.
nested_alive() {
  local ppid="" stat=""
  [ -n "$NESTED_PID" ] || return 1
  read -r ppid stat < <(ps -o ppid=,stat= -p "$NESTED_PID" 2>/dev/null)
  [ "$ppid" = "$$" ] && [ "${stat:0:1}" != Z ]
}
nested_gone() { for _ in $(seq 1 20); do nested_alive || return 0; sleep 0.25; done; return 1; }
stop_nested() { nested_alive || return 0; kill "$NESTED_PID" 2>/dev/null; nested_gone; }
cleanup() {
  stop_nested
  cd /
  case "$SB" in "${TMPDIR:-/tmp}"/desktop-cfg.??????) rm -rf "$SB" ;; esac
}
trap cleanup EXIT

pass=0 fail=0 skip=0
check()  { local d="$1"; shift; if "$@"; then echo "ok   - $d"; ((pass+=1)); else echo "FAIL - $d"; ((fail+=1)); fi; }
skipit() { echo "skip - $1"; ((skip+=1)); }
have()   { command -v "$1" >/dev/null 2>&1; }
say()    { echo "     $*"; }

HOST="$(uname -n)"
MAIN="$CFG_ROOT/sway/config"
shopt -s nullglob
LAYERS=("$CFG_ROOT"/sway/hosts/*.conf)
shopt -u nullglob
OWN="$CFG_ROOT/sway/hosts/$HOST.conf"
OWN_FILES=("$MAIN"); [ -f "$OWN" ] && OWN_FILES+=("$OWN")

# The sway files are read as sway reads them: lines run on after a trailing
# backslash, words held together by quotes and [criteria], variables replaced
# longest name first, blocks and modes tracked, so a check sees what sway
# loads rather than what a grep matches.
cat >"$SB/swayconf.py" <<'PY'
import json, os, re, shutil, sys

# ---------------------------------------------------------------- sway's reader
BINDS = ('bindsym', 'bindcode', 'bindgesture', 'bindswitch')
# Flags that make two bindings of one chord distinct (sway 1.11
# commands/bind.c, binding_key_compare and the gesture and switch twins);
# every other flag (--no-repeat, --no-warn, --to-code, --reload) is dropped.
DISTINCT = {
    'bindsym': ('--release', '--locked', '--inhibited', '--whole-window',
                '--border', '--exclude-titlebar', '--input-device='),
    'bindgesture': ('--exact', '--input-device='),
    'bindswitch': ('--locked',),
}
DISTINCT['bindcode'] = DISTINCT['bindsym']
MODIFIERS = {'shift': 'Shift', 'caps': 'Caps', 'lock': 'Caps', 'ctrl': 'Ctrl',
             'control': 'Ctrl', 'mod1': 'Mod1', 'alt': 'Mod1', 'mod2': 'Mod2',
             'mod3': 'Mod3', 'mod4': 'Mod4', 'super': 'Mod4', 'mod5': 'Mod5'}


def logical_lines(path):
    """(line number, text): a line ending in a backslash runs on into the next
    unless it starts with '#' (config.c getline_with_cont)."""
    with open(path, encoding='utf-8') as f:
        raw = f.read().split('\n')
    i = 0
    while i < len(raw):
        n, line = i + 1, raw[i]
        while line.endswith('\\') and not line.startswith('#') and i + 1 < len(raw):
            i += 1
            line = line[:-1] + raw[i]
        yield n, line
        i += 1


def split_args(s):
    """Words as sway splits them: quotes and [criteria] hold a word together
    and stay in it (common/stringop.c split_args)."""
    out, tok, in_s, in_c, in_b, esc = [], '', False, False, False, False
    for ch in s + '\0':
        if ch == '\\':
            esc = not esc
            tok += ch
            continue
        if ch == '"' and not in_c and not esc:
            in_s = not in_s
        elif ch == "'" and not in_s and not esc:
            in_c = not in_c
        elif ch == '[' and not (in_s or in_c or in_b or esc):
            in_b = True
        elif ch == ']' and in_b and not (in_s or in_c or esc):
            in_b = False
        elif ch == '\0' or (ch in ' \t' and not (in_s or in_c or in_b or esc)):
            if tok:
                out.append(tok)
            tok, esc = '', False
            continue
        esc = False
        tok += ch
    return out


def var_replace(s, svars):
    """Every $name that begins with a defined variable, longest name first
    (config.c do_var_replacement)."""
    names = sorted(svars, key=len, reverse=True)
    i = 0
    while True:
        i = s.find('$', i)
        if i < 0:
            return s
        if i > 0 and s[i - 1] == '\\' and (i == 1 or s[i - 2] != '\\'):
            i += 1
            continue
        if s[i + 1:i + 2] == '$':
            s = s[:i] + s[i + 1:]
            i += 1
            continue
        for n in names:
            if s.startswith(n, i):
                s = s[:i] + svars[n] + s[i + len(n):]
                i += len(svars[n])
                break
        else:
            i += 1


def unquote(w):
    return w[1:-1] if len(w) > 1 and w[0] == w[-1] and w[0] in '"\'' else w


SVARS = {}


def statements(paths):
    """(path, line, block, words) for each statement, in the order sway reads
    them; `set` lines are collected into SVARS as they come, so a later file
    sees an earlier one's variables, as an include does."""
    for path in paths:
        stack = []
        for n, line in logical_lines(path):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            words = split_args(line)
            if len(words) > 1 and words[-1] == '{':
                stack.insert(0, ' '.join(words[:-1]))
                continue
            if words[-1] == '}':
                if stack:
                    stack.pop(0)
                continue
            block = stack[0] if stack else None
            if words[0] == 'set' and block is None and len(words) > 2:
                SVARS[words[1]] = var_replace(' '.join(words[2:]), SVARS)
                continue
            yield path, n, block, words


def bindings(paths):
    """One dict per key, mouse, gesture or switch binding outside a bar block."""
    out = []
    for path, n, block, words in statements(paths):
        if words[0] not in BINDS:
            continue
        if block is not None and not block.startswith('mode'):
            continue                      # a bar block's bindsym is the bar's
        mode = 'default'
        if block is not None:
            mw = [w for w in split_args(block)[1:] if not w.startswith('--')]
            mode = unquote(mw[0]) if mw else '?'
        args = split_args(var_replace(' '.join(words), SVARS))
        kind, args = args[0], args[1:]
        flags = []
        while args and args[0].startswith('--'):
            flags.append(args.pop(0))
        if not args:
            continue
        chord, body = args[0], ' '.join(args[1:])
        out.append(dict(path=path, line=n, mode=mode, kind=kind, flags=flags,
                        chord=chord, body=body))
    return out


def chord_key(b):
    keep = sorted(f for f in b['flags']
                  if any(f == d or (d.endswith('=') and f.startswith(d))
                         for d in DISTINCT[b['kind']]))
    if b['kind'] in ('bindsym', 'bindcode'):
        parts = [MODIFIERS.get(p.lower(), p) for p in b['chord'].split('+')]
        chord = '+'.join(sorted(parts))
    elif b['kind'] == 'bindgesture':
        head, _, dirs = b['chord'].rpartition(':')
        chord = (head + ':' if head else '') + '+'.join(sorted(dirs.split('+')))
    else:
        chord = b['chord']
    return '%s %s %s %s' % (b['mode'], b['kind'], ','.join(keep) or '-', chord)


def sway_commands(body):
    """The commands of a body, split at ; and , outside quotes and criteria."""
    out, cur, in_s, in_c, in_b = [], '', False, False, False
    for ch in body:
        if ch == '"' and not in_c:
            in_s = not in_s
        elif ch == "'" and not in_s:
            in_c = not in_c
        elif ch == '[' and not (in_s or in_c):
            in_b = True
        elif ch == ']' and not (in_s or in_c):
            in_b = False
        elif ch in ';,' and not (in_s or in_c or in_b):
            out.append(cur.strip())
            cur = ''
            continue
        cur += ch
    out.append(cur.strip())
    return [c for c in out if c]


def exec_lines(body):
    """The shell lines a body hands to sh -c, one per exec command."""
    out = []
    for c in sway_commands(body):
        w = split_args(c)
        while w and w[0].startswith('['):
            w.pop(0)                      # criteria
        if w and w[0] in ('exec', 'exec_always'):
            w.pop(0)
            while w and w[0].startswith('--'):
                w.pop(0)                  # --no-startup-id
            out.append(' '.join(w))
    return out


# -------------------------------------------------------- the shell's reader
# Enough of sh to find the program each simple command runs: operators,
# quoting, $( ) and ` ` substitutions, redirections, assignments.
OPS = ('&&', '||', ';;', '<<', '>>', '<&', '>&', '<>', '>|',
       ';', '&', '|', '(', ')', '<', '>', '\n')
REDIR = {'<<', '>>', '<&', '>&', '<>', '>|', '<', '>'}
LEADING = {'!', '{', 'if', 'then', 'else', 'elif', 'do', 'while', 'until',
           'time', 'exec', 'command'}
ALONE = {'}', 'fi', 'done', 'esac'}
BUILTINS = {':', '.', 'set', 'export', 'local', 'readonly', 'unset', 'shift',
            'exit', 'return', 'eval', 'trap', 'wait', 'read', 'cd', 'echo',
            'printf', 'test', '[', 'true', 'false', 'break', 'continue',
            'kill', 'type', 'hash', 'umask', 'ulimit', 'getopts'}


def skip_arith(s, i):                     # i just after "$(("
    depth = 2
    while depth:
        depth += {'(': 1, ')': -1}.get(s[i], 0)
        i += 1
    return i


def skip_dq(s, i):                        # i just after an opening "
    while s[i] != '"':
        if s[i] == '\\':
            i += 2
        elif s.startswith('$((', i):
            i = skip_arith(s, i + 3)
        elif s.startswith('$(', i):
            i = read_subst(s, i + 2)[1]
        elif s[i] == '`':
            i = s.index('`', i + 1) + 1
        else:
            i += 1
    return i + 1


def read_subst(s, i):                     # i just after "$("
    start, depth = i, 1
    while True:
        c = s[i]
        if c == '\\':
            i += 2
        elif c == "'":
            i = s.index("'", i + 1) + 1
        elif c == '"':
            i = skip_dq(s, i + 1)
        elif s.startswith('$((', i):
            i = skip_arith(s, i + 3)
        elif s.startswith('$(', i):
            i = read_subst(s, i + 2)[1]
        else:
            depth += {'(': 1, ')': -1}.get(c, 0)
            i += 1
            if depth == 0:
                return s[start:i - 1], i


def read_word(s, i):
    lit, subs = '', []
    while i < len(s) and s[i] not in ' \t\n;&|()<>':
        c = s[i]
        if c == '\\':
            lit += s[i + 1:i + 2]
            i += 2
        elif c == "'":
            j = s.index("'", i + 1)
            lit += s[i + 1:j]
            i = j + 1
        elif c == '"':
            i += 1
            while s[i] != '"':
                if s[i] == '\\' and s[i + 1] in '$`"\\\n':
                    lit += s[i + 1]
                    i += 2
                elif s.startswith('$((', i):
                    i = skip_arith(s, i + 3)
                    lit += '$((...))'
                elif s.startswith('$(', i):
                    body, i = read_subst(s, i + 2)
                    subs.append(body)
                    lit += '$(...)'
                elif s[i] == '`':
                    j = s.index('`', i + 1)
                    subs.append(s[i + 1:j])
                    lit += '$(...)'
                    i = j + 1
                else:
                    lit += s[i]
                    i += 1
            i += 1
        elif s.startswith('$((', i):
            i = skip_arith(s, i + 3)
            lit += '$((...))'
        elif s.startswith('$(', i):
            body, i = read_subst(s, i + 2)
            subs.append(body)
            lit += '$(...)'
        elif c == '`':
            j = s.index('`', i + 1)
            subs.append(s[i + 1:j])
            lit += '$(...)'
            i = j + 1
        else:
            lit += c
            i += 1
    return lit, subs, i


def lex(s):
    toks, i = [], 0
    while i < len(s):
        c = s[i]
        if c in ' \t':
            i += 1
        elif c == '#':
            j = s.find('\n', i)
            i = len(s) if j < 0 else j
        else:
            op = next((o for o in OPS if s.startswith(o, i)), None)
            if op:
                toks.append(('op', op, []))
                i += len(op)
            else:
                lit, subs, i = read_word(s, i)
                toks.append(('word', lit, subs))
    return toks


def programs(line):
    """Each program a shell line runs, recursing into substitutions and into
    sh -c / bash -c; a script that sh or bash is handed comes as ('script', p)."""
    out, argv, redirect = [], [], False
    for kind, text, subs in lex(line) + [('op', ';', [])]:
        for sub in subs:
            out += programs(sub)
        if kind == 'word':
            if redirect:
                redirect = False
            else:
                argv.append(text)
        elif text in REDIR:
            redirect = True
        else:
            out += program_of(argv)
            argv = []
    return out


def program_of(argv):
    while argv and (argv[0] in LEADING or re.match(r'[A-Za-z_]\w*=', argv[0])):
        argv = argv[1:]
    if not argv or argv[0] in BUILTINS or (len(argv) == 1 and argv[0] in ALONE):
        return []
    if argv[0] in ('sh', 'bash', 'dash'):
        dash_c = False
        for w in argv[1:]:
            if w.startswith('-') and len(w) > 1:
                dash_c = dash_c or ('c' in w[1:] and not w.startswith('--'))
                continue
            return [argv[0]] + (programs(w) if dash_c else [('script', w)])
    return [argv[0]]


def present(p):
    if isinstance(p, tuple):              # a script handed to sh or bash
        f = os.path.expanduser(p[1])
        return '$' not in p[1] and os.path.isfile(f)
    if '$' in p or p in ('for', 'case', 'select', 'function'):
        return False                      # unresolved, or beyond this reader
    if '/' in p:
        f = os.path.expanduser(p)
        return os.path.isfile(f) and os.access(f, os.X_OK)
    return shutil.which(p) is not None


# ---------------------------------------------------------------- the others
def css_rules(path):
    """(selectors, {property: value}) per rule of a GTK stylesheet."""
    text = re.sub(r'/\*.*?\*/', '', open(path, encoding='utf-8').read(), flags=re.S)
    for prelude, decls in re.findall(r'([^{}]*)\{([^{}]*)\}', text):
        prelude = prelude.split(';')[-1]  # past any @define-color
        sels = [' '.join(s.split()) for s in prelude.split(',')]
        props = {}
        for d in decls.split(';'):
            k, _, v = d.partition(':')
            if v:
                props[k.strip()] = ' '.join(v.split())
        yield sels, props


def jsonc(path):
    """Waybar's JSONC: whole-line // comments stripped, then strict JSON."""
    text = open(path, encoding='utf-8').read()
    return json.loads(re.sub(r'^\s*//.*$', '', text, flags=re.M))


def main(cmd, args):
    if cmd == 'dupes':                    # MAIN [LAYER]: chords bound twice;
        layer = args[1] if len(args) > 1 else None   # with a layer, its own
        seen = {}
        for b in bindings(args):
            seen.setdefault(chord_key(b), []).append(b)
        for key, bs in seen.items():
            if len(bs) > 1 and (layer is None or any(b['path'] == layer for b in bs)):
                where = ' '.join('%s:%d' % (os.path.basename(b['path']), b['line']) for b in bs)
                print('%s  (%s)' % (key, where))
    elif cmd == 'bodies':                 # FILE...: the non-exec bodies
        done = set()
        for b in bindings(args):
            if b['body'] and not exec_lines(b['body']) and b['body'] not in done:
                done.add(b['body'])
                print(b['body'])
    elif cmd == 'programs':               # FILE...: MISSING/CHECKED lines
        skip = set(os.environ.get('SKIP_PROGRAMS', '').split())
        names = []
        for b in bindings(args):
            for line in exec_lines(b['body']):
                names += programs(line)
        checked = set()
        for p in names:
            key = p if isinstance(p, str) else p[1]
            if key in checked or key in skip:
                continue
            checked.add(key)
            if not present(p):
                print('MISSING ' + key)
        print('CHECKED %d %s' % (len(checked), ' '.join(sorted(checked))))
    elif cmd == 'strip':                  # FILE [INCLUDE-PREFIX-TO-KEEP]
        keep = args[1] if len(args) > 1 else None
        depth = 0
        for n, line in logical_lines(args[0]):
            s = line.strip()
            words = split_args(s) if s and not s.startswith('#') else []
            if depth:                     # inside a bar block
                depth += (words[-1:] == ['{']) - (words[-1:] == ['}'])
                continue
            if words[:1] == ['bar']:
                depth = 1 if words[-1] == '{' else 0
                continue
            if words[:1] in (['exec'], ['exec_always'], ['swaybg_command'],
                             ['swaynag_command'], ['xwayland']):
                continue
            if words[:1] == ['include'] and not (keep and s.startswith('include ' + keep)):
                continue
            print(line)
    elif cmd == 'var':                    # NAME FILE...: a `set` value, unquoted
        for _ in statements(args[1:]):
            pass
        print(unquote(SVARS.get('$' + args[0], '')))
    elif cmd == 'client':                 # CLASS FILE...: its first colour, resolved
        for path, n, block, words in statements(args[1:]):
            if words[0] == 'client.' + args[0] and len(words) > 1:
                print(var_replace(words[1], SVARS))
    elif cmd == 'cssprop':                # FILE SELECTOR PROPERTY: its values
        for sels, props in css_rules(args[0]):
            if ' '.join(args[1].split()) in sels and args[2] in props:
                print(props[args[2]])
    elif cmd == 'cssids':                 # FILE: every #id in a selector
        ids = set()
        for sels, _ in css_rules(args[0]):
            for s in sels:
                ids.update(re.findall(r'#[A-Za-z_][\w-]*', s))
        print('\n'.join(sorted(ids)))
    elif cmd == 'jsonc':                  # FILE: the JSON, compact
        print(json.dumps(jsonc(args[0])))


main(sys.argv[1], sys.argv[2:])
PY
swayconf() { python3 "$SB/swayconf.py" "$@"; }
# `sway --validate` builds a backend and a renderer before it reads the file;
# left to the environment that made it a Wayland client of the live session,
# with a GPU renderer (sway 1.11 main.c, server_init; measured 2026-09-30).
# Headless and pixman, it reads the same file and touches nothing.
validate() { WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 sway --validate -c "$1"; }

# ---------------------------------------------------------------- sway config

check "sway/config validates" validate "$MAIN"

# sway/config ends with `include hosts/$(uname -n).conf`, and `sway
# --validate` exits 0 over an error in an included file, only printing it
# (measured 2026-09-30). So each layer is validated inlined in place of that
# line, where its errors are the main file's.
validates_inlined() { # $1 = layer
  local n out="$SB/inlined-${1##*/}"
  n="$(grep -c '^include hosts/' "$MAIN")"
  [ "$n" = 1 ] || { say "sway/config has $n 'include hosts/' lines, not 1"; return 1; }
  sed -e "\\|^include hosts/|{r $1" -e 'd}' "$MAIN" >"$out"
  validate "$out"
}
for hf in "${LAYERS[@]}"; do
  check "sway/config validates with hosts/${hf##*/} inlined" validates_inlined "$hf"
done

# The layer sway loads is the one beside the LIVE config, reached through
# stow; a layer added to the repo reaches ~/.config/sway only after stow-all,
# and sway says nothing when the file is missing. Read-only. When this tree is
# not the one ~/.config/sway loads (a copy, as in mutation testing), skipped.
live="$(readlink -f "$HOME/.config/sway/config" 2>/dev/null)"
if [ "$live" = "$(readlink -f "$MAIN")" ]; then
  check "this machine's layer, hosts/$HOST.conf, is the one ~/.config/sway loads" \
    [ -f "$OWN" -a "$(readlink -f "$HOME/.config/sway/hosts/$HOST.conf" 2>/dev/null)" = "$(readlink -f "$OWN")" ]
elif [ -L "$HOME/.config/sway/config" ] && [ -f "$live" ]; then
  skipit "the live config is $live, not this tree's: layer link not checked"
else
  check "~/.config/sway/config is linked into a configs tree" false
fi

# A comment is one only at the start of a line: sway hands a trailing one to
# the command as more words, which is how `default_border pixel 3` drew 2 px
# from 2025-11-09 to 2026-09-30. A #RRGGBB colour is left alone.
no_trailing_comments() {
  local hits
  hits="$(grep -nE '^\s*[^#[:space:]].*\s#(\s|$)' "$MAIN" "${LAYERS[@]}")"
  [ -z "$hits" ] || { say "trailing comments:"; sed 's/^/       /' <<<"$hits"; return 1; }
}
check "no trailing comments in sway/config or a host layer" no_trailing_comments

# No two bindings may claim one chord: sway keeps the later one and says so
# only in a nag at reload. Per mode; the flags that make bindings distinct
# (--locked, --inhibited, --release, --whole-window, --border) stay in the
# key, the rest go; modifiers sorted and variables resolved, so a reordered
# chord or $mod+$left against Mod4+h counts as the same one (measured
# 2026-09-30: sway --validate passes a reordered duplicate).
dupes_none() { # $@ = sway/config [layer]
  local d
  d="$(swayconf dupes "$@")"
  [ -z "$d" ] || { say "bound twice:"; sed 's/^/       /' <<<"$d"; return 1; }
}
check "no duplicate chords in sway/config" dupes_none "$MAIN"
for hf in "${LAYERS[@]}"; do
  check "hosts/${hf##*/} rebinds no chord and binds none twice" dupes_none "$MAIN" "$hf"
done

# sway reads a word as 0 for these, which turns key repeat off.
repeat_is_digits() {
  local bad
  bad="$(grep -hvE '^\s*#' "$MAIN" "${LAYERS[@]}" | grep -E '\brepeat_(rate|delay)\b' |
         grep -vE '\brepeat_(rate|delay)\s+[0-9]+\s*$')"
  [ -z "$bad" ] || { say "not digits: $bad"; return 1; }
}
check "repeat_rate and repeat_delay are digits" repeat_is_digits

# Every program a binding runs must exist, since sway reports nothing when one
# does not. sway hands an exec body to sh -c, so it is read as a shell line:
# the config's own variables ($term, $term2, $menu), the command after each
# operator and inside each $( ), the script a bash or sh is handed (the
# adelotype launcher, by its ~ path), and an sh -c body in turn. Bindings of
# sway/config and this machine's layer; startup exec lines are not bindings.
# By hand: the bar (swaybar_command), the lock (swayidle) and jq, which
# bin/sway-split needs. brightnessctl only where a backlight exists (TODO.md
# item 28).
programs_exist() {
  local out missing="" n b skip=""
  [ -n "$(ls -A /sys/class/backlight 2>/dev/null)" ] || skip=brightnessctl
  out="$(SKIP_PROGRAMS="$skip" swayconf programs "${OWN_FILES[@]}")"
  missing="$(sed -n 's/^MISSING //p' <<<"$out" | tr '\n' ' ')"
  n="$(sed -n 's/^CHECKED \([0-9]*\).*/\1/p' <<<"$out")"
  for b in $(sed -nE 's/^\s*swaybar_command\s+(\S+).*/\1/p' "$MAIN") swayidle jq; do
    have "$b" || missing="$missing$b "
  done
  [ -n "$skip" ] && say "not checked here, no backlight: $skip"
  [ "${n:-0}" -gt 0 ] || { say "no program found in any binding: the reader is broken"; return 1; }
  [ -z "$missing" ] || { say "missing: $missing"; return 1; }
}
check "every program a binding runs exists" programs_exist

# --------------------------------------------- binding bodies, in a nested sway
# sway --validate skips the command body of every binding, so each one that
# is not an exec runs against a real (nested, headless) sway, its reply
# classified below. The copy it loads is where the danger is -- read before
# editing:
#   include /etc/sway/config.d/*  -> runs sway-systemd's session.sh, which
#     rewrites XDG_CURRENT_DESKTOP/XDG_SESSION_TYPE in the LIVE systemd+D-Bus
#     environment of the session you are sitting in. Every include goes but
#     the relative host layer, which then finds the stripped copy in $SB.
#   exec and exec_always lines     -> would launch for real: nm-applet, and
#     a systemd-inhibit that takes a system-wide power-key inhibitor.
#   bar { swaybar_command waybar } -> each nested sway spawns its OWN waybar.
#     Attached to a headless compositor it cannot draw on, such a waybar was
#     measured growing to 9.2 GB RSS / 34 GB virtual and triggering the kernel
#     OOM killer (2026-08-13). Worse, sway-systemd's assign-cgroups.py placed it
#     in the *terminal's* systemd scope, so the OOM kill took down the whole
#     WezTerm scope and closed every window in it. Stripping the bar block is
#     not tidiness; it is the difference between a test and an outage.
#   the wallpaper, the nag and X   -> `output * bg` starts swaybg (with an
#     image-loader sandbox) and a lazy Xwayland takes an X display in /tmp:
#     swaybg_command -, swaynag_command - and xwayland disable go first.
{
  printf '%s\n' 'swaynag_command -' 'swaybg_command -' 'xwayland disable' \
    'output HEADLESS-1 mode --custom 1280x720@60Hz'
  swayconf strip "$MAIN" hosts/
} >"$SB/test.conf"
mkdir -p "$SB/hosts"
for hf in "${LAYERS[@]}"; do
  h="$(basename "$hf" .conf)"
  { swayconf strip "$hf"
    printf 'mode "suite-host-%s" {\n    bindsym Escape mode "default"\n}\n' "$h"; } >"$SB/hosts/${hf##*/}"
done
shopt -s nullglob
COPY=("$SB/test.conf" "$SB"/hosts/*.conf)
shopt -u nullglob
shown() { # stdin: offending lines of the copy; none is a pass
  local hits
  hits="$(cat)"
  [ -z "$hits" ] || { say "in the copy:"; sed "s|^$SB/|       |" <<<"$hits"; return 1; }
}
copy_no_exec()    { grep -HnE '^\s*exec(_always)?(\s|$)' "${COPY[@]}" | shown; }
copy_no_include() { grep -HnE '^\s*include(\s|$)' "${COPY[@]}" | grep -vE ':[0-9]+:\s*include hosts/' | shown; }
copy_no_bar()     { grep -HnE '^\s*bar(\s|\{|$)|swaybar_command|status_command' "${COPY[@]}" | shown; }
copy_contained()  {
  [ "$(head -n 4 "$SB/test.conf" | tr '\n' '|')" = 'swaynag_command -|swaybg_command -|xwayland disable|output HEADLESS-1 mode --custom 1280x720@60Hz|' ] ||
    { say "the copy does not open with the four lines"; return 1; }
  grep -HnE '^\s*(swaynag_command|swaybg_command|xwayland)(\s|$)' "${COPY[@]}" |
    grep -vE '^[^:]*/test\.conf:[1-3]:' | shown
}
unsafe_before=$fail
check "test copy has no exec or exec_always line" copy_no_exec
check "test copy has no include but the relative host layer" copy_no_include
check "test copy has no bar block (would spawn a real waybar)" copy_no_bar
check "test copy turns off swaynag, swaybg and Xwayland, on one headless output" copy_contained
copy_safe=0
[ "$fail" = "$unsafe_before" ] && copy_safe=1

if ! have sway || ! have jq; then
  check "sway and jq are installed (the body check needs them)" false
elif [ "$copy_safe" != 1 ]; then
  check "nested sway started (not started: the copy failed its checks above)" false
elif [ "${#SWAYSOCK}" -gt 107 ]; then
  check "nested sway's socket path fits in 107 bytes ($SWAYSOCK)" false
else
  WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
    sway -c "$SB/test.conf" >"$SB/sway.log" 2>&1 &
  NESTED_PID=$!
  ours() { [ "$(swaymsg -t get_version 2>/dev/null | jq -r .loaded_config_file_name 2>/dev/null)" = "$SB/test.conf" ]; }
  for _ in $(seq 1 40); do ours && break; sleep 0.25; done
  if ours; then
    check "nested sway started, and answers on s.sock as this run's" true

    own_layer_only() {
      local m
      m="$(swaymsg -t get_binding_modes | jq -r '.[]' | grep '^suite-host-' | tr '\n' ' ')"
      [ "$m" = "suite-host-$HOST " ] || { say "host markers loaded: ${m:-(none)}"; return 1; }
    }
    check "the nested sway loaded this machine's layer, and only it" own_layer_only
    check "nested sway loaded the config without error" \
      bash -c "! grep -qiE '\[error\].*(config|line)' '$SB/sway.log'"

    parse_errors=0 bodies=0
    while IFS= read -r cmd; do
      [ "$cmd" = exit ] && { say "not run, it would end the nested sway: exit"; continue; }
      bodies=$((bodies + 1))
      # Discriminating a config bug from a state complaint is fiddlier than it
      # looks, and BOTH obvious approaches are wrong (each caught by mutation
      # testing, 2026-08-13):
      #   - grepping the raw reply for "Unknown/invalid command" NEVER matches:
      #     sway's IPC JSON escapes the slash, so the bytes read "Unknown\/...".
      #   - the `parse_error` field is NOT a discriminator: sway sets it true for
      #     pure state failures too ("Scratchpad is empty" arrives with
      #     parse_error: true), which flags every valid command as broken.
      # So: decode the JSON with jq (which turns \/ back into /) and match the
      # decoded .error string. And no reply at all is a failure, not a pass: a
      # nested sway that stopped answering once made this check pass over 55
      # commands it never ran (measured 2026-09-30).
      out="$(swaymsg -- "$cmd" 2>/dev/null)"
      if [ -z "$out" ]; then
        say "NO REPLY to: $cmd"
        parse_errors=$((parse_errors + 1))
      elif [ "$(jq -r 'any(.[]?; (.error // "") | test("Unknown/invalid command"))' \
                <<<"$out" 2>/dev/null)" != false ]; then
        say "PARSE ERROR in binding command: $cmd"
        parse_errors=$((parse_errors + 1))
      fi
      swaymsg 'mode "default"' >/dev/null 2>&1
    done < <(swayconf bodies "${OWN_FILES[@]}")
    say "$bodies binding bodies run"
    check "every non-exec binding body parses at runtime" [ "$parse_errors" = 0 -a "$bodies" -gt 0 ]
    check "the nested sway still answers as this run's after the bodies" ours

    swaymsg exit >/dev/null 2>&1
    nested_gone || stop_nested
  else
    check "nested sway started, and answers on s.sock as this run's" false
    sed 's/^/     /' "$SB/sway.log" | tail -n 5
    stop_nested
  fi
fi

# ------------------------------------------------------- GTK3 CSS (finding 2/4)
# Both Waybar and wofi are GTK3. A parse error costs the whole bar / a broken
# launcher, with no useful error anywhere, so parse them the same way GTK will.
gtk_css_ok() {
  python3 - "$1" <<'PY' >/dev/null 2>&1
import sys, gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
Gtk.CssProvider().load_from_data(open(sys.argv[1], "rb").read())
PY
}
if python3 -c 'import gi' >/dev/null 2>&1; then
  check "waybar/style.css parses as GTK3 CSS" gtk_css_ok "$CFG_ROOT/waybar/style.css"
  check "wofi/style.css parses as GTK3 CSS"   gtk_css_ok "$CFG_ROOT/wofi/style.css"
  # Anti-vacuity: the checker must REJECT known-bad CSS, or every "parses"
  # result above would be meaningless. "tnum" 1 is the exact CSS-spec form GTK3
  # rejects (it accepts a bare "tnum") -- the very mistake that killed the bar.
  css_rejects() { ! gtk_css_ok "$1"; }
  printf '#x { font-feature-settings: "tnum" 1; }\n' > "$SB/bad.css"
  check "CSS checker rejects known-bad CSS (anti-vacuity)" css_rejects "$SB/bad.css"
else
  skipit "python3-gi missing (GTK CSS checks skipped)"
fi

# ------------------------------------------------------------------- waybar
# waybar's config is JSONC -- valid JSON once // comments are stripped.
WAYBAR_JSON="$(swayconf jsonc "$CFG_ROOT/waybar/config")"
check "waybar/config is valid JSON (comments stripped)" [ -n "$WAYBAR_JSON" ]

# A clock format showing seconds needs interval 1: waybar defaults to 60 and
# polls on the minute, which renders %S as '00' forever.
if grep -qE '"format"\s*:\s*"\{:[^"]*%[TS]' "$CFG_ROOT/waybar/config"; then
  check "clock shows seconds => interval is 1" \
    [ "$(jq -r '.clock.interval' <<<"$WAYBAR_JSON")" = 1 ]
fi

# The MSI is named in two languages, sway's $msi and Waybar's excluded
# output; if one changes alone the bar comes back on the MSI and the two bars
# trade heights, re-laying every tiled window (2026-09-28).
msi_excluded() {
  local msi
  msi="$(swayconf var msi "$MAIN")"
  [ -n "$msi" ] && jq -e --arg o "!$msi" '[.output] | flatten | index($o) != null' <<<"$WAYBAR_JSON" >/dev/null ||
    { say "\$msi \"$msi\"; Waybar's output: $(jq -c .output <<<"$WAYBAR_JSON")"; return 1; }
}
check "Waybar excludes the output sway calls \$msi" msi_excluded

# ------------------------------------------- man-page key validation (finding 3)
# swaylock stops reading at an unknown key, mako refuses to start on one and
# wofi ignores it, so every key must appear in its own man page. The option
# lists are scraped from the man pages themselves, so they track the installed
# version rather than a snapshot.
validate_keys() { # $1=config  $2=option-list  $3=label
  local cfg="$1" opts="$2" label="$3" bad="" k
  while IFS= read -r line; do
    case "$line" in ''|\#*|\[*) continue;; esac
    k="${line%%=*}"; k="${k%% *}"
    grep -qx "$k" "$opts" || bad="$bad $k"
  done < "$cfg"
  [ -z "$bad" ] || { say "undocumented in $label:$bad"; return 1; }
}

if man 1 swaylock >/dev/null 2>&1; then
  man 1 swaylock 2>/dev/null | col -b | grep -oE '^\s+(-[A-Za-z], )?--[a-z-]+' \
    | grep -oE -- '--[a-z-]+' | sed 's/^--//' | sort -u > "$SB/swaylock.opts"
  check "every swaylock/config key is documented" \
    validate_keys "$CFG_ROOT/swaylock/config" "$SB/swaylock.opts" "man 1 swaylock"
else
  skipit "man 1 swaylock unavailable"
fi
# Documented, and so passed above, but `version` exits before locking: the one
# line in this file that means no lock at all.
check "swaylock/config carries no version or help line" \
  bash -c "! grep -qxE '(version|help)' '$CFG_ROOT/swaylock/config'"
# Values too: swaylock keeps trailing whitespace (a flag with a trailing space
# is unrecognised and ends the file there) and turns a colour of the wrong
# length into opaque white, silently.
swaylock_values_ok() {
  local bad
  bad="$(grep -nE '[[:space:]]$' "$1" | sed 's/$/<- trailing space/'
         grep -nE '^([a-z-]+-)?color=' "$1" | grep -vE ':([a-z-]+-)?color=#?[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$')"
  [ -z "$bad" ] || { say "swaylock/config:"; sed 's/^/       /' <<<"$bad"; return 1; }
}
check "swaylock/config values are well-formed (6 or 8 hex digits, no trailing space)" \
  swaylock_values_ok "$CFG_ROOT/swaylock/config"

if man 5 mako >/dev/null 2>&1; then
  man 5 mako 2>/dev/null | col -b | grep -oE '^\s{5,9}[a-z][a-z0-9-]*=' \
    | tr -d ' =' | sort -u > "$SB/mako.opts"
  check "every mako/config key is documented" \
    validate_keys "$CFG_ROOT/mako/config" "$SB/mako.opts" "man 5 mako"
else
  skipit "man 5 mako unavailable"
fi
# Key names are not enough for mako: it parses every value strictly (a colour
# without its '#', a timeout with a unit) and refuses to START on a bad one,
# so the next login has no notification daemon at all -- the critical battery
# warning included. So mako's own parser reads the file, with `env -i` and its
# bus and display pointed at nothing in $SB: a file that parses gets as far as
# the bus and fails there, before any connection is made.
if have mako; then
  mako_parses() {
    local rt="$SB/mako-rt" out
    mkdir -p "$rt" && chmod 700 "$rt"
    out="$(env -i PATH=/usr/bin:/bin HOME="$rt" XDG_RUNTIME_DIR="$rt" XDG_CONFIG_HOME="$rt" \
           DBUS_SESSION_BUS_ADDRESS="unix:path=$rt/none" WAYLAND_DISPLAY="$rt/none" \
           timeout 5 mako -c "$1" 2>&1)"
    ! grep -q 'Failed to parse' <<<"$out" && grep -q 'Failed to connect to user bus' <<<"$out" ||
      { say "mako: $(head -n 2 <<<"$out" | tr '\n' ' ')"; return 1; }
  }
  check "mako/config passes mako's own parser (values and criteria included)" \
    mako_parses "$CFG_ROOT/mako/config"
  # Anti-vacuity: the probe must reject the slip it exists for.
  sed -E 's/^(border-color=)#/\1/' "$CFG_ROOT/mako/config" > "$SB/bad-mako.conf"
  mako_rejects() { ! mako_parses "$1" >/dev/null; }
  check "mako's parser rejects a colour without its # (anti-vacuity)" \
    mako_rejects "$SB/bad-mako.conf"
else
  skipit "mako missing (its parser check skipped)"
fi

if man 5 wofi >/dev/null 2>&1; then
  man 5 wofi 2>/dev/null | col -b | sed -n '/^CONFIG OPTIONS/,/^CSS SELECTORS/p' \
    | grep -oE '^\s{7}[a-z_]+=' | tr -d ' =' | sort -u > "$SB/wofi.opts"
  check "every wofi/config key is documented" \
    validate_keys "$CFG_ROOT/wofi/config" "$SB/wofi.opts" "man 5 wofi"
  # GTK parses a misspelled id without complaint; the rule just styles
  # nothing. The names wofi gives its widgets are listed in wofi(5), CSS
  # SELECTORS.
  man 5 wofi 2>/dev/null | col -b | awk '/^CSS SELECTORS/ {f=1; next} /^[A-Z][A-Z ]+$/ {f=0} f' \
    | grep -oE '#[a-z-]+' | sort -u > "$SB/wofi.sel"
  wofi_selectors() {
    local s bad=""
    [ -s "$SB/wofi.sel" ] || { say "no selectors scraped from wofi(5)"; return 1; }
    for s in $(swayconf cssids "$CFG_ROOT/wofi/style.css"); do
      grep -qx -- "$s" "$SB/wofi.sel" || bad="$bad $s"
    done
    [ -z "$bad" ] || { say "undocumented selectors:$bad"; return 1; }
  }
  check "every wofi/style.css #id selector is documented" wofi_selectors
else
  skipit "man 5 wofi unavailable"
fi

# ----------------------------------------------------------------- rofi
# rofi reads its options and its theme silently: an unknown option, a missing
# theme file and a theme syntax error all exit 0 with no message (measured
# 2026-09-30). So every key in config.rasi's configuration block must be an
# option rofi itself lists, and the dumped theme must carry the sheet's own
# colour names, which rofi's built-in theme -- the fallback on any failure --
# lacks. Neither dump needs a display.
if have rofi; then
  env -u WAYLAND_DISPLAY -u DISPLAY rofi -dump-config 2>/dev/null \
    | grep -oE '^[[:space:]/*]*[a-z][a-z0-9-]*:' | tr -d ' \t/*:' | sort -u > "$SB/rofi.opts"
  rofi_keys_ok() {
    local bad
    bad="$(sed -n '/^configuration {/,/^}/p' "$CFG_ROOT/rofi/config.rasi" \
      | grep -oE '^[[:space:]]*[a-z][a-z0-9-]*:' | tr -d ' \t:' | sort -u \
      | comm -23 - "$SB/rofi.opts")"
    [ -s "$SB/rofi.opts" ] || { echo "     rofi listed no options"; return 1; }
    [ -z "$bad" ] || { echo "     unknown to rofi:$bad"; return 1; }
  }
  check "every rofi/config.rasi option is one rofi lists" rofi_keys_ok
  rofi_theme_ok() {
    [ "$(env -u WAYLAND_DISPLAY -u DISPLAY rofi -config "$CFG_ROOT/rofi/config.rasi" -dump-theme 2>/dev/null \
        | grep -cE '^[[:space:]]*(wash|accent|muted):')" = 3 ]
  }
  check "rofi loads theme.rasi whole (its colour names reach the dumped theme)" rofi_theme_ok
  # A reference to a colour the * block does not define (@accnt) is silent
  # too, and reaches the dump as nothing; only the file itself can show it.
  rofi_refs_ok() {
    local undef
    undef="$(grep -E '^[[:space:]]*[a-z-]+:' "$CFG_ROOT/rofi/theme.rasi" | grep -oE '@[a-z]+' | sort -u | sed 's/^@//' \
      | comm -23 - <(sed -n '/^\* {/,/^}/p' "$CFG_ROOT/rofi/theme.rasi" | grep -oE '^[[:space:]]*[a-z]+:' | tr -d ' \t:' | sort -u))"
    [ -z "$undef" ] || { echo "     undefined in theme.rasi's * block:$undef"; return 1; }
  }
  check "every @colour in rofi/theme.rasi is defined in its * block" rofi_refs_ok
else
  skipit "rofi missing (rofi checks skipped)"
fi

# ------------------------------------------------------------ cross-config wiring

# The stow arrays must agree with each other and with what is on disk, or
# stow-all silently skips a package (the documented silent-skip trap).
check "stow arrays are consistent and every package dir exists" \
  bash -c '
    source "'"$CFG_ROOT"'/bash/.bashrc.d/60-stow.sh"
    rc=0
    for p in "${STOW_ORDER[@]}"; do
      [ -n "${STOW_TARGETS[$p]:-}" ] || { echo "     no target: $p"; rc=1; }
      [ -d "'"$CFG_ROOT"'/$p" ]      || { echo "     no dir: $p";    rc=1; }
    done
    for k in "${!STOW_TARGETS[@]}"; do
      printf "%s\n" "${STOW_ORDER[@]}" | grep -qx "$k" || { echo "     not in ORDER: $k"; rc=1; }
    done
    exit $rc'

# One urgent colour and one accent desktop-wide, in four config languages,
# deliberately not derived from one another -- so only a test keeps them in
# step. Each is pinned where it is drawn, not merely present in the file: a
# define, a comment or a neighbouring key satisfied the old grep (measured
# 2026-09-30). A swap of either colour is a deliberate change to every file.
is_colour() { # $1 = want (RRGGBB), $2 = got: #? RRGGBB, an alpha of ff allowed
  local g="${2#\#}"
  [ "${g,,}" = "${1,,}" ] || [ "${g,,}" = "${1,,}ff" ] || { say "drawn as: ${2:-(nothing)}"; return 1; }
}
URGENT=d08770 ACCENT=0088FF
CSS_W="$CFG_ROOT/waybar/style.css" CSS_O="$CFG_ROOT/wofi/style.css"
mako_border() { # $1 = section ("" for the globals): its border-color
  awk -v s="$1" '/^\[/ {cur=$0; next} cur==s && /^border-color=/ {sub(/^border-color=/, ""); print}' \
    "$CFG_ROOT/mako/config" | tail -n 1
}
swaylock_key() { sed -n "s/^$1=//p" "$CFG_ROOT/swaylock/config" | tail -n 1; }
css_define()   { sed -nE "s/^@define-color $2[[:space:]]+(#[0-9A-Fa-f]+);.*/\1/p" "$1"; }
urgent_sway()     { is_colour "$URGENT" "$(swayconf client urgent "$MAIN")"; }
accent_sway()     { is_colour "$ACCENT" "$(swayconf var accent "$MAIN")" &&
                    is_colour "$ACCENT" "$(swayconf client focused "$MAIN")"; }
urgent_waybar()   { is_colour "$URGENT" "$(css_define "$CSS_W" urgent)" &&
                    css_uses "$CSS_W" '#workspaces button.urgent' background @urgent; }
accent_waybar()   { is_colour "$ACCENT" "$(css_define "$CSS_W" accent)" &&
                    css_uses "$CSS_W" '#workspaces button.focused' background @accent; }
accent_wofi()     { is_colour "$ACCENT" "$(css_define "$CSS_O" accent)" &&
                    css_uses "$CSS_O" '#window' border @accent; }
urgent_mako()     { is_colour "$URGENT" "$(mako_border '[urgency=critical]')"; }
accent_mako()     { is_colour "$ACCENT" "$(mako_border '')"; }
urgent_swaylock() { is_colour "$URGENT" "$(swaylock_key ring-wrong-color)"; }
accent_swaylock() { is_colour "$ACCENT" "$(swaylock_key ring-color)"; }
rasi_define()     { sed -n '/^\* {/,/^}/p' "$CFG_ROOT/rofi/theme.rasi" \
                    | sed -nE "s/^[[:space:]]*$1:[[:space:]]+(#[0-9A-Fa-f]+);.*/\1/p" | tail -n 1; }
rasi_uses()       { sed -n "/^$1 {/,/^}/p" "$CFG_ROOT/rofi/theme.rasi" | grep -qE "^[[:space:]]*$2:[[:space:]]+$3;"; }
accent_rofi()     { is_colour "$ACCENT" "$(rasi_define accent)" && rasi_uses window border-color @accent; }
css_uses() { # $1 = sheet, $2 = selector, $3 = property, $4 = the define its value names
  local v
  v="$(swayconf cssprop "$1" "$2" "$3" | tail -n 1)"
  case " $v " in *" $4 "*) ;; *) say "$2 { $3: ${v:-(unset)} }"; return 1;; esac
}
check "urgent colour #$URGENT drawn in sway/config (client.urgent)" urgent_sway
check "urgent colour #$URGENT drawn in waybar/style.css (@urgent, button.urgent)" urgent_waybar
check "urgent colour #$URGENT drawn in mako/config ([urgency=critical] border)" urgent_mako
check "urgent colour #$URGENT drawn in swaylock/config (ring-wrong-color)" urgent_swaylock
check "accent #$ACCENT drawn in sway/config (\$accent, client.focused)" accent_sway
check "accent #$ACCENT drawn in waybar/style.css (@accent, button.focused)" accent_waybar
check "accent #$ACCENT drawn in wofi/style.css (@accent, #window border)" accent_wofi
check "accent #$ACCENT drawn in mako/config (the global border)" accent_mako
check "accent #$ACCENT drawn in rofi/theme.rasi (accent, window border)" accent_rofi
check "accent #$ACCENT drawn in swaylock/config (ring-color)" accent_swaylock

# The lock before sleep must exist, and stay free of a timer: a deleted line
# reopens the lid hole of 2026-08-13, and a `timeout` clause would bring back
# idle locking, a standing decline. Pinned whole, so a changed or doubled line
# fails too.
SWAYIDLE="exec swayidle -w before-sleep 'swaylock -f' lock 'swaylock -f'"
swayidle_pinned() {
  local got
  got="$(grep -E '\bswayidle\b' "$MAIN" | grep -vE '^\s*#')"
  [ "$got" = "$SWAYIDLE" ] || { say "swayidle lines: ${got:-(none)}"; return 1; }
}
check "swayidle: exactly the before-sleep and lock line, once, with no timeout" swayidle_pinned

# swaylock is invoked bare from every call site, so its config file stays the
# one source of how the lock looks; the binding and swayidle make two at least.
lock_sites_bare() {
  local sites
  sites="$(grep -hvE '^\s*#' "$MAIN" "${LAYERS[@]}" | grep -oE "swaylock[^'\";|&]*" | sed 's/[[:space:]]*$//')"
  [ "$(grep -c . <<<"$sites")" -ge 2 ] && ! grep -qvx 'swaylock -f' <<<"$sites" ||
    { say "swaylock call sites: $(tr '\n' '|' <<<"$sites")"; return 1; }
}
check "every swaylock call site is a bare 'swaylock -f', two at least" lock_sites_bare

# A host layer may one day carry an idle timer (bigfed's, say); if it does, a
# fullscreen window must hold it off, the standing pairing (2026-09-30).
timers_paired() {
  local hf bad=""
  for hf in "${LAYERS[@]}"; do
    grep -vE '^\s*#' "$hf" | grep -E '\bswayidle\b' | grep -qE '\btimeout\b' || continue
    grep -vE '^\s*#' "$hf" | grep -qE '\binhibit_idle\s+fullscreen\b' || bad="$bad ${hf##*/}"
  done
  [ -z "$bad" ] || { say "a timer without inhibit_idle fullscreen in:$bad"; return 1; }
}
check "a host layer's idle timer comes with inhibit_idle fullscreen" timers_paired

# The suite must leave nothing behind. A leaked nested sway or waybar is how a
# test turns into an OOM (see the bar-block comment above), so this is an
# assertion, not hygiene. Read from the cage's own cgroup, which also holds
# what the nested sway spawned, whatever its command line says.
sleep 0.5
cg="$(sed -n 's/^0::\(.*\)$/\1/p' /proc/self/cgroup)"
leaked=""
for p in $(cat "/sys/fs/cgroup$cg/cgroup.procs" 2>/dev/null); do
  case "$(cat "/proc/$p/comm" 2>/dev/null)" in
    sway|foot|swaybg|swaynag|Xwayland|swaymsg|jq|waybar|mako)
      leaked="$leaked $p:$(cat "/proc/$p/comm" 2>/dev/null)" ;;
  esac
done
check "no sway, foot, swaybg, swaynag, Xwayland, swaymsg, jq, waybar or mako left in the cage" [ -z "$leaked" ]
[ -n "$leaked" ] && say "leaked:$leaked"

echo
echo "passed: $pass  failed: $fail$( ((skip)) && printf '  skipped: %s' "$skip")"
((fail == 0))
