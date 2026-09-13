import re, os, glob, collections
CWL=os.path.expanduser('~/Desktop/texstudio/completion')
# 1. his corpus: every \command token in the dissertation's .tex files (not .sty, not archive)
files=[f for f in glob.glob(os.path.expanduser('~/Desktop/dissertation/**/*.tex'), recursive=True)]
cnt=collections.Counter()
for f in files:
    t=open(f,encoding='utf-8',errors='replace').read()
    t=re.sub(r'(?<!\\)%.*','',t)
    cnt.update(re.findall(r'\\([A-Za-z]+\*?)', t))
print(len(files),"tex files;", sum(cnt.values()),"command tokens;", len(cnt),"distinct names")
# 2. french-logic names (own macros) to set aside
sty=''.join(open(p).read() for p in glob.glob(os.path.expanduser('~/Desktop/configs/latex/french-logic/*.sty')))
own=set(re.findall(r'\\(?:(?:re)?newcommand|providecommand|DeclareMathOperator)\s*\*?\s*\{\\([A-Za-z]+)\}', sty))|set(re.findall(r'\\newenvironment\s*\{([A-Za-z]+)\}', sty))|set(re.findall(r'\\newtheorem\s*\*?\s*\{([A-Za-z]+)\}', sty))
# 3. classify each stock name against the whole cwl corpus: typical (some line without *), unusual-only, hidden-only, absent
cls=collections.defaultdict(set)
for p in glob.glob(f'{CWL}/*.cwl'):
    inkv=False
    for line in open(p,encoding='utf-8',errors='replace'):
        if line.startswith('#keyvals'): inkv=True; continue
        if line.startswith('#endkeyvals'): inkv=False; continue
        if inkv or not line.startswith('\\'): continue
        cmd,_,c=line.partition('#'); m=re.match(r'\\([A-Za-z]+\*?)',cmd)
        if not m: continue
        base=c.split('/')[0].split('\\')[0]
        cls[m.group(1)].add('unusual' if '*' in c else ('hidden' if re.search(r'(^|[^%])S',base) else 'typical'))
rows=[]
for n,k in cnt.most_common():
    if n in own: kind='french-logic'
    elif n not in cls: kind='absent'
    elif 'typical' in cls[n]: kind='typical'
    elif 'unusual' in cls[n]: kind='unusual-only'
    else: kind='hidden-only'
    rows.append((n,k,kind))
tot=collections.Counter(); dist=collections.Counter()
for n,k,kind in rows: tot[kind]+=k; dist[kind]+=1
print("tokens by class:", dict(tot)); print("distinct names by class:", dict(dist))
print("\nunusual-only commands he actually uses (count):")
print("  ", [(n,k) for n,k,kind in rows if kind=='unusual-only'][:60])
print("\nabsent from every cwl (count), top 30:")
print("  ", [(n,k) for n,k,kind in rows if kind=='absent'][:30])
print("\nhis 40 most used stock (typical) commands:", [(n,k) for n,k,kind in rows if kind=='typical'][:40])
