import re,os,glob,collections
# where does he use env-restricted commands? innermost environment at each use, by a begin/end stack
restricted={'draw','node','path','fill','coordinate','clip','shade','filldraw','pic','matrix','graph','scope','foreach','pgfmathsetmacro','item','multicolumn','cline','hline','cmidrule','toprule','midrule','bottomrule','addlinespace','put','line','vector','circle','oval','makebox','framebox','dashbox','qbezier','thicklines','thinlines','multiput','shortstack','mathstrut','intertext','shortintertext','tag','notag','nonumber','label'}
files=glob.glob(os.path.expanduser('~/Desktop/dissertation/**/*.tex'),recursive=True)
ctx=collections.defaultdict(collections.Counter)
tok=re.compile(r'\\(begin|end)\{([A-Za-z*]+)\}|\\([A-Za-z]+)')
for f in files:
    stack=[]
    for line in open(f,encoding='utf-8',errors='replace'):
        line=re.sub(r'(?<!\\)%.*','',line)
        for m in tok.finditer(line):
            if m.group(1)=='begin': stack.append(m.group(2))
            elif m.group(1)=='end':
                if stack and stack[-1]==m.group(2): stack.pop()
            elif m.group(3) in restricted:
                ctx[m.group(3)][stack[-1] if stack else '(none)']+=1
for n in ['draw','node','item','tag','multicolumn','hline','cmidrule','toprule','midrule','bottomrule','label','intertext','notag','path','fill','coordinate','foreach']:
    if ctx[n]: print(f"  \\{n:12s} {dict(ctx[n].most_common(6))}")
