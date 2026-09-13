import re, os, glob, collections
CWL = os.path.expanduser('~/Desktop/texstudio/completion')
LW  = os.path.expanduser('~/Desktop/configs/nvim/lua/snippets/latex-workshop.lua')
FL  = os.path.expanduser('~/Desktop/configs/nvim/lua/snippets/french-logic.lua')

# --- the dissertation's package closure ---
seed = ['class-memoir','geometry','soul','trimclip','graphicx','amsmath','amssymb','mathtools','stmaryrd','mathrsfs','xspace','tikz','tikzsymbols','enumitem','microtype','ebproof','relsize','fontenc','inputenc','lmodern','babel','ragged2e','setspace','multicol','xcolor','tabularx','mdframed','calc','adjustbox','booktabs','bm','centernot','hyperref','cleveref','footmisc','amsthm','biblatex','csquotes']
core = ['tex','latex-document','latex-dev']
def exists(p): return os.path.exists(f'{CWL}/{p}.cwl')
missing=[p for p in seed if not exists(p)]
print("dissertation packages without a cwl:", missing)
# transitive #include closure
def includes(p):
    out=[]
    try:
        for line in open(f'{CWL}/{p}.cwl', encoding='utf-8', errors='replace'):
            if line.startswith('#include:'): out.append(line[9:].strip())
    except FileNotFoundError: pass
    return out
closure=set(); todo=[p for p in core+seed if exists(p)]
while todo:
    p=todo.pop()
    if p in closure or not exists(p): continue
    closure.add(p); todo+=includes(p)
print("closure size (files that TeXstudio would load for the dissertation):", len(closure))
print(sorted(closure))

# --- parse cwl lines ---
def parse_file(p):
    rows=[]
    inkv=False
    for line in open(f'{CWL}/{p}.cwl', encoding='utf-8', errors='replace'):
        s=line.rstrip('\n')
        if s.startswith('#keyvals'): inkv=True; continue
        if s.startswith('#endkeyvals'): inkv=False; continue
        if inkv or not s.startswith('\\'): continue
        cmd, _, cls = s.partition('#')
        m=re.match(r'\\([A-Za-z@]+\*?|.)', cmd)
        if not m: continue
        rows.append(dict(pkg=p, text=cmd, cls=cls, name=m.group(1), isenv=cmd.startswith('\\begin{') or cmd.startswith('\\end{')))
    return rows
rows=[]
for p in sorted(closure): rows+=parse_file(p)
print("command/env lines in closure:", len(rows))
def flag(r,ch): return ch in r['cls'].split('/')[0].split('\\')[0].replace('L0','').replace('L1','').replace('L2','').replace('L3','').replace('L4','').replace('L5','') if ch!='*' else '*' in r['cls']
unusual=[r for r in rows if '*' in r['cls']]
hidden=[r for r in rows if re.search(r'(^|[^%])S', r['cls'].split('/')[0].split('\\')[0])]
print("  marked unusual (#*):", len(unusual), " hidden (S):", len(hidden))
vis=[r for r in rows if '*' not in r['cls'] and r not in hidden]
cmds=[r for r in vis if not r['isenv']]
envs=[r for r in vis if r['text'].startswith('\\begin{')]
print("  visible ('typical') lines:", len(vis), "of which commands", len(cmds), "begin-env", len(envs))
print("  distinct visible command names:", len({r['name'] for r in cmds}), " distinct env names:", len({re.match(r'\\begin\{([^}]*)\}',r['text']).group(1) for r in envs}))
mathonly=[r for r in cmds if re.search(r'(^|[^%])m', r['cls'].split('/')[0].split('\\')[0]) and not re.search('M',r['cls'])]
print("  visible commands classified math-only (m):", len(mathonly))
percore=collections.Counter(r['pkg'] for r in vis)
print("  visible lines per file (top 15):", percore.most_common(15))

# --- my latex-workshop.lua triggers ---
src=open(LW).read()
trigs=re.findall(r's\(\{ trig = "([^"]+)~"', src)
names=[t for t in trigs if t.startswith('\\\\')]
bibs=[t for t in trigs if t.startswith('@')]
print("\nlatex-workshop.lua: triggers", len(trigs), "commands", len(names), "bib", len(bibs))
# arity: count i( per snippet
arity={}
for m in re.finditer(r's\(\{ trig = "(\\\\[^"]+)~", wordTrig = true \}, \{(.*?)\}\),\n', src, re.S):
    arity[m.group(1)[2:]]=len(re.findall(r'\bi\(', m.group(2)))
allidx=collections.defaultdict(list)
for p in sorted(os.listdir(CWL)):
    if not p.endswith('.cwl'): continue
    for r in parse_file(p[:-4]): allidx[r['name']].append(r)
inclos=collections.defaultdict(list)
for r in rows: inclos[r['name']].append(r)
notany=[]; notclos=[]; unusual_only=[]; arity_mismatch=[]; arity_match=0
for n in sorted(arity):
    key=n
    if key not in allidx: notany.append(n); continue
    if key not in inclos:
        notclos.append((n, sorted({r['pkg'] for r in allidx[key]})[:4])); continue
    rs=inclos[key]
    if all('*' in r['cls'] for r in rs): unusual_only.append(n)
    # arity from cwl: max over variants of count of {..} groups (mandatory) ; my snippets count all i()
    def nargs(t): return len(re.findall(r'\{[^{}]*\}', t))+len(re.findall(r'\[[^\[\]]*\]', t))
    cwl_ar=sorted({nargs(r['text']) for r in rs})
    if arity[n] in cwl_ar: arity_match+=1
    else: arity_mismatch.append((n, arity[n], cwl_ar, [r['text'] for r in rs][:3]))
print("  not in ANY cwl:", len(notany), notany[:40])
print("  in some cwl but not in the dissertation's closure:", len(notclos))
print("    e.g.", notclos[:25])
print("  in closure but only as unusual (#*):", len(unusual_only), unusual_only[:40])
print("  arity agrees with a cwl variant:", arity_match, " disagrees:", len(arity_mismatch))
for x in arity_mismatch[:40]: print("    ", x)

# --- coverage the other way: visible closure commands that my library lacks ---
mine=set(arity)|{t[2:] for t in re.findall(r'trig = "(\\\\[^"]+)~"', open(FL).read())}
lack=sorted({r['name'] for r in cmds} - mine)
print("\nvisible closure commands missing from my two libraries:", len(lack))
bypkg=collections.Counter()
for n in lack:
    bypkg[sorted({r['pkg'] for r in inclos[n]})[0]]+=1
print("  by first package:", bypkg.most_common(20))
print("  sample:", lack[:60])
