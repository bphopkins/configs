#!/usr/bin/env python3
"""Compile every french-logic member alone, in text mode and in math mode, and record
which modes it survives.  Output is the mode table gen-fixture.py consumes.

Usage: mode-census.py --sty PATH [--sty PATH ...] --out modes.tsv [--jobs N]

Each member gets its own two-line document, so one failure never masks another and
the first error line is captured verbatim.  Honour TEXINPUTS if a candidate package
directory should shadow the stowed one.  About three minutes for ~540 members at
twelve jobs.
"""
import argparse, os, re, subprocess, tempfile, collections
from concurrent.futures import ThreadPoolExecutor
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_fixture_lib import collect, call, envcall, IN_TREE  # shared parser

def run_one(workdir, tag, body):
    tex = os.path.join(workdir, tag + '.tex')
    with open(tex, 'w') as f:
        f.write('\\documentclass{article}\\usepackage{french-logic}\\pagestyle{empty}\\begin{document}\n' + body + '\n\\end{document}\n')
    subprocess.run(['pdflatex', '-interaction=nonstopmode', '-halt-on-error', '-output-directory', workdir, tex], capture_output=True)
    logp = os.path.join(workdir, tag + '.log')
    log = open(logp, encoding='latin-1').read() if os.path.exists(logp) else ''
    err = next((l.strip() for l in log.splitlines() if l.startswith('!')), '')
    warn = next((l.strip() for l in log.splitlines() if 'invalid in math mode' in l or 'Font Warning' in l), '')
    for ext in ('tex', 'log', 'aux', 'pdf', 'out'):
        try: os.remove(os.path.join(workdir, tag + '.' + ext))
        except FileNotFoundError: pass
    return tag, err, warn

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sty', action='append', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--jobs', type=int, default=12)
    a = ap.parse_args()
    cmds, envs = collect(a.sty)
    jobs = []
    for name in sorted(cmds):
        jobs.append((f'c_{name}_text', f'Text: {call(name, cmds[name])} end.'))
        if name not in IN_TREE:
            jobs.append((f'c_{name}_math', f'Math: ${call(name, cmds[name])}$ end.'))
    for e in envs:
        jobs.append((f'e_{e}_text', envcall(e)))
    with tempfile.TemporaryDirectory() as wd:
        with ThreadPoolExecutor(max_workers=a.jobs) as ex:
            res = {t: (e, w) for t, e, w in ex.map(lambda j: run_one(wd, *j), jobs)}
    with open(a.out, 'w') as f:
        f.write('name\ttext\tmath\ttext_error\tmath_error\twarning\n')
        for name in sorted(cmds):
            te, tw = res[f'c_{name}_text']; me, mw = res.get(f'c_{name}_math', ('tree-only', ''))
            f.write('\t'.join(['\\' + name, 'ok' if not te else 'ERR', '-' if me == 'tree-only' else ('ok' if not me else 'ERR'), te[:90], '' if me == 'tree-only' else me[:90], (tw or mw)[:80]]) + '\n')
        for e in envs:
            te, tw = res[f'e_{e}_text']
            f.write('\t'.join(['env:' + e, 'ok' if not te else 'ERR', '-', te[:90], '', tw[:80]]) + '\n')
    c = collections.Counter()
    for name in cmds:
        mm = res.get(f'c_{name}_math', ('tree-only', ''))[0]
        c[('text' if not res[f'c_{name}_text'][0] else 'TEXT-ERR', 'tree' if mm == 'tree-only' else ('math' if not mm else 'MATH-ERR'))] += 1
    print('mode census:', dict(c), '+', len(envs), 'environments')

if __name__ == '__main__':
    main()
