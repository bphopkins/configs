import re, os, sys
root = os.path.expanduser("~/Desktop/configs/nvim/lua/snippets")
names = """tex latex-document latex-dev adjcalc adjustbox amsbsy amsfonts amsmath amsopn amssymb amstext amsthm array auxhook babel biblatex bigintcalc bitset bm booktabs calc centernot cleveref collectbox color csquotes ebproof enumitem etoolbox footmisc french-logic french-logic-applied french-logic-cite french-logic-conditional french-logic-core french-logic-deontic french-logic-diagrams french-logic-gentzen french-logic-io french-logic-lists french-logic-modal french-logic-preamble french-logic-proof french-logic-stit french-logic-structure geometry gettitlestring graphics graphicx hyperref ifoddpage iftex ifthen ifvtex inputenc intcalc keyval kvoptions kvsetkeys logreq mathrsfs mathtools mdframed mhsetup microtype multicol nameref needspace pdfescape pdftexcmds pgf pgfcore pgffor pgfkeys pgfmath pgfrcs pgfsys ragged2e refcount relsize rerunfilecheck setspace soul stmaryrd stringenc tabularx tikz tikzsymbols trig trimclip uniquecounter url varwidth xcolor xkeyval xspace zref-abspage zref-base tagpdf tikzlibraryshapes tikzlibrarydecorations.pathmorphing atbegshi pdfmanagement tikzlibrarydecorations""".split()
pat = re.compile(r'S\(\{ trig = "((?:[^"\\]|\\.)*)", dscr = "((?:[^"\\]|\\.)*)"')
def unlua(s): return s.encode().decode('unicode_escape').encode('latin-1').decode('utf-8') if '\\' in s else s
rows = []  # (pkg, trig, dscr, is_env)
for n in names:
    for d in ("pkg", "sty"):
        p = f"{root}/{d}/{n}.lua"
        if os.path.exists(p):
            for m in pat.finditer(open(p, encoding='utf-8').read()):
                trig, dscr = unlua(m.group(1)), unlua(m.group(2))
                rows.append((n, trig, dscr, dscr.startswith("\\begin{")))
            break
cmds = [r for r in rows if not r[3]]; envs = [r for r in rows if r[3]]
print(f"rows {len(rows)} (commands {len(cmds)}, environments {len(envs)})")
print("width  commands>w  envs>w   share")
for w in (30, 35, 40, 45, 50, 60, 70, 80):
    c = sum(1 for r in cmds if len(r[2]) > w); e = sum(1 for r in envs if len(r[2]) > w)
    print(f"{w:5d} {c:11d} {e:8d}   {100*(c+e)/len(rows):5.1f}%")
lens = sorted(len(r[2]) for r in rows)
print("p50 %d p90 %d p95 %d p99 %d max %d" % (lens[len(lens)//2], lens[int(len(lens)*.9)], lens[int(len(lens)*.95)], lens[int(len(lens)*.99)], lens[-1]))
from collections import Counter
over = Counter(r[0] for r in rows if len(r[2]) > 30)
print("over 30 by package:", ", ".join(f"{k} {v}" for k, v in over.most_common(12)))
print("longest french-logic / core / memoir rows:")
for r in sorted((r for r in rows if r[0].startswith("french-logic") or r[0] in ("tex","latex-document","latex-dev","class-memoir","mathtools")), key=lambda r: -len(r[2]))[:8]:
    print(f"  {len(r[2]):3d} {r[0]:16s} {r[1]:22s} {r[2]}")
print("some 31-45 char descriptions he might meet:")
for r in [r for r in rows if 30 < len(r[2]) <= 45 and r[0] in ("biblatex","hyperref","graphicx","amsmath","mathtools","enumitem","cleveref","tikz")][:12]:
    print(f"  {len(r[2]):3d} {r[0]:10s} {r[1]:22s} {r[2]}")
