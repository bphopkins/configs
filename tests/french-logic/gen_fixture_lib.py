"""Shared parser for the french-logic test suite: member collection and call synthesis."""
import re

ARGS = ['A', 'B', 'C', 'D']

def strip_comments(text):
    return '\n'.join(re.split(r'(?<!\\)%', l, maxsplit=1)[0] for l in text.split('\n'))

def collect(paths):
    cmds, envs = {}, []
    for p in paths:
        src = strip_comments(open(p, encoding='utf-8').read())
        for m in re.finditer(r'\\(?:(?:re)?newcommand|providecommand)\s*\*?\s*\{\\([A-Za-z@]+)\}\s*(?:\[(\d+)\])?\s*(?:\[([^\]]*)\])?', src):
            if '@' in m.group(1):
                continue  # internal helper; a document cannot type it
            cmds.setdefault(m.group(1), (int(m.group(2) or 0), m.group(3) is not None))
        for m in re.finditer(r'\\DeclareMathSymbol\{\\([A-Za-z]+)\}', src):
            cmds.setdefault(m.group(1), (0, False))
        for m in re.finditer(r'\\(?:re)?newenvironment\s*\*?\s*\{([A-Za-z]+)\}', src):
            if m.group(1) not in envs: envs.append(m.group(1))
        for m in re.finditer(r'\\newtheorem\s*\*?\s*\{([A-Za-z]+)\}', src):
            if m.group(1) not in envs: envs.append(m.group(1))
    return cmds, envs

# Members that only mean something inside a proof tree (ebproof defines \\hypo and
# \\infer locally in the environment); their calls are synthesised in context.
IN_TREE = {
    'hyp': '\\begin{gentzen}\\hyp{A}\\end{gentzen}',
    'hyphantom': '\\begin{gentzen}\\hyphantom\\infer1{B}\\end{gentzen}',
    'infr': '\\begin{gentzen}\\hypo{A}\\infr{}{1}{R}{B}\\end{gentzen}',  # first slot is ebproof options
    'inf': '\\begin{gentzen}\\hypo{A}\\inf{1}{R}{B}\\end{gentzen}',
}

def call(name, spec):
    if name in IN_TREE:
        return IN_TREE[name]
    n, opt = spec
    mand = n - (1 if opt else 0)
    return '\\' + name + ''.join('{' + ARGS[i] + '}' for i in range(mand))

def envcall(e):
    if 'list' in e or e == 'axiomproof':
        return f'\\begin{{{e}}}\\item A\\end{{{e}}}'
    if e == 'gentzen':
        return '\\begin{gentzen}\\hypo{A}\\infer1{B}\\end{gentzen}'
    return f'\\begin{{{e}}}A\\end{{{e}}}'

