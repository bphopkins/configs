import re,os,collections
CWL=os.path.expanduser('~/Desktop/texstudio/completion')
closure="adjcalc adjustbox amsbsy amsfonts amsmath amsopn amssymb amstext amsthm array auxhook babel biblatex bigintcalc bitset bm booktabs calc centernot class-memoir cleveref collectbox color csquotes ebproof enumitem etoolbox footmisc geometry gettitlestring graphicx hyperref ifoddpage iftex ifthen intcalc keyval kvoptions kvsetkeys l3keys2e latex-dev latex-document lmodern logreq mathrsfs mathtools mdframed microtype multicol nameref needspace patch-common pdfescape pdfmanagement pdftexcmds pgf pgfcore pgffor pgfkeys pgfmath pgfrcs pgfsys ragged2e refcount relsize rerunfilecheck setspace soul stmaryrd stringenc tabularx tagpdf tex tikz tikzsymbols translations trig trimclip uniquecounter url varwidth xcolor xkeyval xspace zref-abspage zref-base".split()
rows=collections.defaultdict(set)   # (trigger, signature) -> files
unusual_restricted=collections.Counter()
for p in closure:
    f=f'{CWL}/{p}.cwl'
    if not os.path.exists(f): continue
    inkv=False; inopt=False
    for line in open(f,encoding='utf-8',errors='replace'):
        if line.startswith('#keyvals'): inkv=True; continue
        if line.startswith('#endkeyvals'): inkv=False; continue
        if line.startswith('#ifOption'): inopt=True; continue
        if line.startswith('#endif'): inopt=False; continue
        if inkv or inopt or not line.startswith('\\'): continue
        cmd,_,c=line.partition('#'); cmd=cmd.strip()
        if re.search(r'(^|[^%])S', c.split('/')[0].split('\\')[0]): continue
        m=re.match(r'\\([A-Za-z]+\*?|.)',cmd)
        if not m or cmd.startswith('\\end{'): continue
        rows[(m.group(1), cmd[len(m.group(0)):])].add(p)
        if '*' in c and '/' in c: unusual_restricted[c.split('/',1)[1].split('\\')[0]]+=1
multi={k:v for k,v in rows.items() if len(v)>1}
print("distinct (trigger,signature) rows:", len(rows), " present in 2+ files:", len(multi))
pairs=collections.Counter(tuple(sorted(v)) for v in multi.values())
print("  file pairs carrying the same rows (top 10):", pairs.most_common(10))
print("  examples:", [k for k in list(multi)[:8]])
print("unusual rows with an environment restriction, by environment:", unusual_restricted.most_common(8))
