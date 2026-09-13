import re, os, glob, collections
CWL = os.path.expanduser('~/Desktop/texstudio/completion')
FL  = os.path.expanduser('~/Desktop/configs/latex/french-logic')
# options actually used, from the hub's units and the dissertation preamble
opts=collections.defaultdict(set)
texts=[open(f, encoding='utf-8', errors='replace').read() for f in glob.glob(f'{FL}/*.sty')]
texts.append(open(os.path.expanduser('~/Desktop/dissertation/dissertation.tex'), encoding='utf-8', errors='replace').read())
for t in texts:
    t=re.sub(r'(?<!\\)%.*','',t)
    for m in re.finditer(r'\\(?:RequirePackage|usepackage|documentclass)\s*\[([^\]]*)\]\s*\{([^}]*)\}', t, re.S):
        for o in m.group(1).split(','):
            o=o.strip()
            if o: opts[m.group(2).strip()].add(o)
print("options in use:", {k:sorted(v) for k,v in opts.items()})
seed = ['class-memoir','geometry','soul','trimclip','graphicx','amsmath','amssymb','mathtools','stmaryrd','mathrsfs','xspace','tikz','tikzsymbols','enumitem','microtype','ebproof','relsize','fontenc','inputenc','lmodern','babel','ragged2e','setspace','multicol','xcolor','tabularx','mdframed','calc','adjustbox','booktabs','bm','centernot','hyperref','cleveref','footmisc','amsthm','biblatex','csquotes']
core = ['tex','latex-document','latex-dev']
def exists(p): return os.path.exists(f'{CWL}/{p}.cwl')
def parse_file(p):
    rows=[]; inkv=False; cond=[]; 
    pkgopts=opts.get(p.replace('class-',''), set())
    for line in open(f'{CWL}/{p}.cwl', encoding='utf-8', errors='replace'):
        s=line.rstrip('\n')
        if s.startswith('#ifOption:'):
            o=s[10:].strip(); cond.append(o in pkgopts or any(x.split('=')[0]==o.split('=')[0] and o==x for x in pkgopts)); continue
        if s.startswith('#endif'):
            if cond: cond.pop(); continue
        if s.startswith('#keyvals'): inkv=True; continue
        if s.startswith('#endkeyvals'): inkv=False; continue
        if s.startswith('#include:'):
            rows.append(dict(pkg=p, include=s[9:].strip(), active=all(cond))); continue
        if inkv or not s.startswith('\\'): continue
        cmd,_,cls=s.partition('#')
        m=re.match(r'\\([A-Za-z@]+\*?|.)', cmd)
        if not m: continue
        rows.append(dict(pkg=p, text=cmd, cls=cls, name=m.group(1), active=all(cond),
                         isenv=cmd.startswith('\\begin{') or cmd.startswith('\\end{')))
    return rows
# closure honouring #ifOption on includes too
closure={}; todo=[p for p in core+seed if exists(p)]; parent={}
while todo:
    p=todo.pop(0)
    if p in closure or not exists(p): continue
    rs=parse_file(p); closure[p]=rs
    for r in rs:
        if 'include' in r and r['active'] and r['include'] not in closure and exists(r['include']):
            parent.setdefault(r['include'], p); todo.append(r['include'])
print("\nclosure:", len(closure), "files")
def chain(p):
    out=[p]
    while p in parent: p=parent[p]; out.append(p)
    return ' <- '.join(out)
for q in ['expl3-commands','pstricks','siunitx','fontspec','bidi','ulem','xetex','luatex','tagpdf','tabulary','pst-calculate']:
    if q in closure: print("  ", chain(q))
rows=[r for rs in closure.values() for r in rs if 'text' in r and r['active']]
def base(cls): return cls.split('/')[0].split('\\')[0]
vis=[r for r in rows if '*' not in r['cls'] and not re.search(r'(^|[^%])S', base(r['cls']))]
cmds=[r for r in vis if not r['isenv']]
envs=[r for r in vis if r['text'].startswith('\\begin{')]
restricted=[r for r in cmds if '/' in r['cls']]
print("active lines:", len(rows), " visible:", len(vis), " visible commands:", len(cmds), " distinct names:", len({r['name'] for r in cmds}), " begin-envs:", len(envs), " distinct envs:", len({re.match(r'\\begin\{([^}]*)\}',r['text']).group(1) for r in envs}))
print("visible commands with an /env restriction (hidden outside that env):", len(restricted), " distinct:", len({r['name'] for r in restricted}))
unres=[r for r in cmds if '/' not in r['cls']]
print("=> offered on a bare backslash in running text (typical tab):", len({r['name'] for r in unres}), "distinct names")
c=collections.Counter(); 
for n in {r['name'] for r in unres}: pass
per=collections.defaultdict(set)
for r in unres: per[r['pkg']].add(r['name'])
print("  per file:", sorted(((len(v),k) for k,v in per.items()), reverse=True)[:25])
mathonly={r['name'] for r in unres if re.search(r'(^|[^%])m', base(r['cls'])) and 'M' not in base(r['cls'])}
print("  of which math-only (m):", len(mathonly))
print("core three visible distinct names:", {p: len({r['name'] for r in closure[p] if 'text' in r and '*' not in r['cls'] and not r['isenv'] and not re.search(r'(^|[^%])S', base(r['cls']))}) for p in core})
print("core three total lines:", {p: len([r for r in closure[p] if 'text' in r]) for p in core})
# what a bare-name list looks like for the maths packages he actually uses
for p in ['amssymb','stmaryrd','mathtools','amsmath','amsthm','cleveref','biblatex','enumitem','class-memoir','booktabs','csquotes','hyperref','ebproof','tikz']:
    v={r['name'] for r in closure.get(p,[]) if 'text' in r and r['active'] and '*' not in r['cls'] and not r['isenv'] and not re.search(r'(^|[^%])S', base(r['cls'])) and '/' not in r['cls']}
    a={r['name'] for r in closure.get(p,[]) if 'text' in r and not r['isenv']}
    print(f"  {p}: visible {len(v)} / all {len(a)}")

# ---- coverage gap against the refined closure ----
import re as _re
LWF=os.path.expanduser('~/Desktop/configs/nvim/lua/snippets/latex-workshop.lua'); FLF=os.path.expanduser('~/Desktop/configs/nvim/lua/snippets/french-logic.lua')
mine=set()
for f in (LWF,FLF):
    mine|={t for t in _re.findall(r'trig = "\\\\([^"~]+)~"', open(f).read())}
offered={r['name'] for r in unres}
gap=sorted(offered-mine)
print("\nREFINED: offered on bare backslash:", len(offered), " covered by my libraries:", len(offered&mine), " missing:", len(gap))
pp=collections.defaultdict(set)
for r in unres:
    if r['name'] in gap: pp[r['pkg']].add(r['name'])
print("  missing per file:", sorted(((len(v),k) for k,v in pp.items()), reverse=True)[:16])
for p in ['amssymb','stmaryrd','mathtools','amsmath','amsthm','cleveref','biblatex','class-memoir','enumitem','booktabs','csquotes','hyperref','ebproof','latex-document','tex']:
    print(f"    {p}: {sorted(pp.get(p,[]))[:14]}{' ...' if len(pp.get(p,[]))>14 else ''}")
# my snippets that TeXstudio would NOT offer for this document (not in refined offered set)
extra=sorted(mine-offered-{t for t in _re.findall(r'trig = "\\\\([^"~]+)~"', open(FLF).read())})
print("  latex-workshop.lua entries TeXstudio would not offer for this document:", len(extra))
print("   ", extra)

envnames={_re.match(r'\\begin\{([^}]*)\}',r['text']).group(1) for r in envs}
lw=set(_re.findall(r'trig = "\\\\([^"~]+)~"', open(LWF).read()))
extra2=sorted(lw-offered-envnames)
print("\nCORRECTED: latex-workshop.lua entries TeXstudio would not offer here (env snippets excluded):", len(extra2), " of", len(lw))
allrows=[r for rs in closure.values() for r in rs if 'text' in r]
for n in ['raisebox','medskip','par','null','makebox','marginpar','providecommand','hrulefill','copyright','displaystyle','footnotemark','Alph','arabic','thepage','def','begin','end']:
    rs=[r for r in allrows if r['name']==n]
    print(f"   {n:14s}", sorted({(r['pkg'], r['cls'] or '-', 'active' if r['active'] else 'INACTIVE-option-block') for r in rs})[:3] or 'not in closure')
envsnips=lw&envnames
print("my env snippets that TeXstudio also offers as \\begin rows:", len(envsnips))

print("\n=== sample rows as TeXstudio shows them (closure, visible) ===")
for n in ['section','cfrac','cref','includegraphics','textcite','frac','newtheorem','parbox','enquote','setlist']:
    rs=[r for r in vis if r['name']==n]
    for r in rs[:4]: print(f"   {r['text']:55s} #{r['cls']:12s} [{r['pkg']}]")
print("\n=== variants: visible commands with more than one cwl line ===")
byname=collections.defaultdict(list)
for r in cmds: byname[r['name']].append(r['text'])
multi={n:set(v) for n,v in byname.items() if len(set(v))>1}
print("  distinct visible commands:", len(byname), " with 2+ distinct variants:", len(multi), " max variants:", max(len(v) for v in multi.values()))
print("  examples:", {n:sorted(v) for n,v in list(multi.items())[:4]})
print("\n=== keyvals available in the closure ===")
kv=0; kvcmds=set()
for p in closure:
    inkv=False
    for line in open(f'{CWL}/{p}.cwl', encoding='utf-8', errors='replace'):
        if line.startswith('#keyvals:'): inkv=True; kvcmds.add(line[9:].strip()); continue
        if line.startswith('#endkeyvals'): inkv=False; continue
        if inkv and line.strip() and not line.startswith('#'): kv+=1
print("  keyval lines:", kv, " for", len(kvcmds), "command/env targets; e.g.", sorted(kvcmds)[:12])
print("\n=== environments: visible begin-lines with an \\item body or arguments ===")
envl=[r['text'] for r in envs]
print("  total", len(envl), " with \\item:", sum('\\item' in t for t in envl), " with args:", sum(('{' in t[7:] or '[' in t[7:]) for t in envl), " e.g.", [t for t in envl if 'enumerate' in t or 'minipage' in t][:6])
