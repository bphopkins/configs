#!/usr/bin/env python3
"""Generate the french-logic rendering fixture: one tiny page per member and mode.

Usage: gen-fixture.py --sty PATH [--sty PATH ...] --modes modes.tsv --out DIR

Parses every \\newcommand / \\renewcommand / \\providecommand / \\DeclareMathSymbol /
\\newenvironment / \\renewenvironment / \\newtheorem in the given .sty files (comments
stripped), reads the mode table, and writes DIR/fixture.tex plus DIR/pages.tsv
(page number -> member, mode).  Members the mode table marks as failing in a mode
are skipped in that mode and listed in DIR/skipped.tsv, so a fixture always compiles
cleanly; a member that starts or stops failing shows up when the mode table is
re-censused (run.sh --recensus).
"""
import argparse, csv, re, os

import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_fixture_lib import collect, call, envcall, IN_TREE

PREAMBLE = r"""\documentclass{article}
\usepackage{PACKAGE}
\usepackage[paperwidth=6cm,paperheight=2.5cm,margin=1mm]{geometry}
\pagestyle{empty}\setlength{\parindent}{0pt}
% Reproducible PDF bytes: no dates, no trailer ID, no pdftex banner.
\ifdefined\pdfinfoomitdate\pdfinfoomitdate=1 \pdftrailerid{} \pdfsuppressptexinfo=-1 \fi
\begin{document}
"""

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sty', action='append', required=True)
    ap.add_argument('--modes', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--package', default='french-logic', help='package to load in the fixture (a unit name for standalone tests)')
    ap.add_argument('--skip', default='', help='comma-separated member names to leave out (members that exist only conditionally)')
    ap.add_argument('--options', default='', help='package options for the \\usepackage line (e.g. deon)')
    a = ap.parse_args()
    cmds, envs = collect(a.sty)
    modes = {r['name']: r for r in csv.DictReader(open(a.modes), delimiter='\t')}
    os.makedirs(a.out, exist_ok=True)
    pages, skipped, body = [], [], []
    def page(member, mode, tex):
        pages.append((len(pages) + 1, member, mode))
        body.append(tex + '\n\\newpage\n')
    skip = set(s for s in a.skip.split(',') if s)
    for name in sorted(cmds):
        if name in skip: continue
        m = modes.get('\\' + name)
        c = call(name, cmds[name])
        if m is None or m['text'] == 'ok':
            page('\\' + name, 'text', f'x {c} y.')
        else:
            skipped.append(('\\' + name, 'text', m['text_error']))
        if name in IN_TREE:
            pass  # a proof tree is a display; the text page above is the test
        elif m is None or m['math'] == 'ok':
            page('\\' + name, 'math', f'$x {c} y$')
        else:
            skipped.append(('\\' + name, 'math', m['math_error']))
    extras = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'extras.tex')
    if os.path.exists(extras) and a.package == 'french-logic' and not a.options:
        blocks = re.split(r'^%% page: ', open(extras).read(), flags=re.M)[1:]
        for blk in blocks:
            name, _, tex = blk.partition('\n')
            # scaled to the fixture's page height, so every page keeps one size
            page('extra:' + name.strip(), 'text', '\\resizebox{!}{2.2cm}{' + tex.strip() + '}')
    for e in envs:
        m = modes.get('env:' + e)
        if m is None or m['text'] == 'ok':
            page('env:' + e, 'text', envcall(e))
        else:
            skipped.append(('env:' + e, 'text', m['text_error']))
    with open(os.path.join(a.out, 'fixture.tex'), 'w') as f:
        use = ('\\usepackage[' + a.options + ']{' + a.package + '}') if a.options else ('\\usepackage{' + a.package + '}')
        f.write(PREAMBLE.replace('\\usepackage{PACKAGE}', use) + ''.join(body) + '\\end{document}\n')
    with open(os.path.join(a.out, 'pages.tsv'), 'w') as f:
        f.write('page\tmember\tmode\n')
        for p in pages: f.write(f'{p[0]}\t{p[1]}\t{p[2]}\n')
    with open(os.path.join(a.out, 'skipped.tsv'), 'w') as f:
        f.write('member\tmode\terror\n')
        for s in skipped: f.write('\t'.join(s) + '\n')
    print(f'fixture: {len(pages)} pages, {len(skipped)} member/mode pairs skipped (see skipped.tsv)')

if __name__ == '__main__':
    main()
