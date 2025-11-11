#!/usr/bin/env python3
import re
import json
import argparse
from pathlib import Path

COMMENT_RE = re.compile(r'(?<!\\)%.*')
SPACE_RE = re.compile(r'\s+')

# Patterns for classic LaTeX interfaces
NEWCOMMAND_RE = re.compile(
    r'''\\(?P<kind>re|provide)?newcommand\*?\s*  # \newcommand, \renewcommand, \providecommand
        \{\\(?P<name>[A-Za-z@]+)\}\s*            # {\\name}
        (?:\[(?P<num>\d+)\])?\s*                 # [n] number of args
        (?:\[(?P<default>[^\]]*)\])?             # [default] for first arg (optional)
    ''', re.VERBOSE
)

NEWTENV_RE = re.compile(
    r'''\\(?P<kind>re)?newenvironment\*?\s*      # \newenvironment (or renew)
        \{(?P<name>[A-Za-z*@]+)\}\s*             # {envname}
        (?:\[(?P<num>\d+)\])?\s*                 # [n]
        (?:\[(?P<default>[^\]]*)\])?             # [default]
        \{                                       # begin-body start (ignored)
    ''', re.VERBOSE
)

DECLAREMATHOP_RE = re.compile(
    r'''\\DeclareMathOperator\*?\s*
        \{\\(?P<name>[A-Za-z@]+)\}\s*\{[^}]*\}
    ''', re.VERBOSE
)

DECLAREPAIRED_RE = re.compile(
    r'''\\DeclarePairedDelimiter\*?\s*
        \{\\(?P<name>[A-Za-z@]+)\}\s*
        \{(?P<left>[^}]*)\}\s*
        \{(?P<right>[^}]*)\}
    ''', re.VERBOSE
)

# xparse
NEWDOC_CMD_RE = re.compile(
    r'''\\NewDocumentCommand\s*
        \{\\(?P<name>[A-Za-z@]+)\}\s*
        \{(?P<spec>[^}]*)\}
    ''', re.VERBOSE
)

NEWDOC_ENV_RE = re.compile(
    r'''\\NewDocumentEnvironment\s*
        \{(?P<name>[A-Za-z*@]+)\}\s*
        \{(?P<spec>[^}]*)\}\s*
        \{
    ''', re.VERBOSE
)

def strip_comments(text: str) -> str:
    out_lines = []
    for line in text.splitlines():
        # Remove comments (not escaped)
        line = COMMENT_RE.sub('', line)
        out_lines.append(line)
    return '\n'.join(out_lines)

def compact_ws(s: str) -> str:
    return SPACE_RE.sub(' ', s).strip()

def parse_xparse_spec(spec: str):
    """
    Parse a minimal subset of xparse arg specs.
    Supports tokens: m, o, O{default}, s, t<char>, d<delims> (e.g., d())
    Returns a list of dicts: [{'type': 'm'|'o'|'O'|'s'|'t'|'d', 'meta': ...}, ...]
    """
    spec = spec.strip()
    i = 0
    toks = []
    while i < len(spec):
        c = spec[i]
        if c in ' \t\r\n':
            i += 1
            continue
        if c == 'm':
            toks.append({'type': 'm'}); i += 1; continue
        if c == 'o':
            toks.append({'type': 'o'}); i += 1; continue
        if c == 's':
            toks.append({'type': 's'}); i += 1; continue
        if c == 'O':
            # O{default}
            i += 1
            if i < len(spec) and spec[i] == '{':
                depth = 1; i += 1; start = i
                while i < len(spec) and depth:
                    if spec[i] == '{': depth += 1
                    elif spec[i] == '}': depth -= 1
                    i += 1
                default = spec[start:i-1]
            else:
                default = ''
            toks.append({'type': 'O', 'default': default})
            continue
        if c == 't':
            # t<char> uses angle or any single char in <...> per xparse
            i += 1
            if i < len(spec) and spec[i] == '<':
                j = spec.find('>', i+1)
                token = spec[i+1:j] if j != -1 else ''
                i = j+1 if j != -1 else i+1
            else:
                # fallback: next char as token
                token = spec[i] if i < len(spec) else ''
                i += 1
            toks.append({'type': 't', 'token': token})
            continue
        if c == 'd':
            # d<delims> e.g., d() or d<|> etc.
            i += 1
            if i < len(spec) and spec[i] == '<':
                j = spec.find('>', i+1)
                delims = spec[i+1:j] if j != -1 else ''
                i = j+1 if j != -1 else i+1
            else:
                delims = ''
            toks.append({'type': 'd', 'delims': delims})
            continue
        # Fallback for unrecognized tokens: treat as mandatory
        toks.append({'type': 'm'}); i += 1
    return toks

def snippet_body_for_cmd(name: str, nargs: int, default: str|None):
    """
    Build a VSCode snippet body for \name with nargs mandatory args.
    If default is provided (meaning first arg is optional), we output [${1:default}] then mandatory args ${2..}.
    """
    body = f'\\{name}'
    idx = 1
    if default is not None:
        body += f'[${{ {idx} :{default}}}]'.replace(' ', '')
        idx += 1
    for _ in range(nargs):
        body += f'{{${{{idx}}}}}'
        idx += 1
    return body

def snippet_body_for_xparse(name: str, toks):
    body = f'\\{name}'
    idx = 1
    for t in toks:
        if t['type'] == 'm':
            body += f'{{${{{idx}}}}}'; idx += 1
        elif t['type'] == 'o':
            body += f'[${{{idx}}}]'; idx += 1
        elif t['type'] == 'O':
            default = t.get('default','')
            # sanitize default for snippet (remove braces/newlines)
            default = default.replace('\n',' ').replace('\r',' ').replace('{','').replace('}','')
            body += f'[${{{idx}:{default}}}]'; idx += 1
        elif t['type'] == 's':
            body += f'${{{idx}:*}}'; idx += 1
        elif t['type'] == 't':
            token = t.get('token','')
            body += f'${{{idx}:{token}}}'; idx += 1
        elif t['type'] == 'd':
            delims = t.get('delims','')
            if len(delims) >= 2:
                left, right = delims[0], delims[-1]
            elif len(delims) == 1:
                left, right = delims, delims
            else:
                left, right = '{', '}'
            # escape snippet braces if using {}
            if left == '{': left = '\\{'
            if right == '}': right = '\\}'
            body += f'{left}${{{idx}}}{right}'; idx += 1
        else:
            body += f'{{${{{idx}}}}}'; idx += 1
    return body

def env_snippet(name: str, nargs: int, default: str|None):
    idx = 1
    header = f'\\begin{{{name}}}'
    if default is not None:
        header += f'[${{ {idx} :{default}}}]'.replace(' ', '')
        idx += 1
    for _ in range(nargs):
        header += f'{{${{{idx}}}}}'; idx += 1
    lines = [
        header,
        '\t${%d}' % idx,
        f'\\end{{{name}}}',
    ]
    return lines

def env_snippet_xparse(name: str, toks):
    idx = 1
    header = f'\\begin{{{name}}}'
    for t in toks:
        if t['type'] == 'm':
            header += f'{{${{{idx}}}}}'; idx += 1
        elif t['type'] == 'o':
            header += f'[${{{idx}}}]'; idx += 1
        elif t['type'] == 'O':
            default = t.get('default','')
            default = default.replace('\n',' ').replace('\r',' ').replace('{','').replace('}','')
            header += f'[${{{idx}:{default}}}]'; idx += 1
        elif t['type'] == 's':
            header += f'${{{idx}:*}}'; idx += 1
        elif t['type'] == 't':
            token = t.get('token','')
            header += f'${{{idx}:{token}}}]'; idx += 1
        elif t['type'] == 'd':
            delims = t.get('delims','')
            if len(delims) >= 2:
                left, right = delims[0], delims[-1]
            elif len(delims) == 1:
                left, right = delims, delims
            else:
                left, right = '{', '}'
            if left == '{': left = '\\{'
            if right == '}': right = '\\}'
            header += f'{left}${{{idx}}}{right}'; idx += 1
        else:
            header += f'{{${{{idx}}}}}'; idx += 1
    lines = [
        header,
        '\t${%d}' % idx,
        f'\\end{{{name}}}',
    ]
    return lines

def make_entry_key(base: str, suffix: str|None=None):
    return base if not suffix else f"{base} ({suffix})"

def main():
    ap = argparse.ArgumentParser(description="Generate VSCode/LuaSnip snippets from a LaTeX macros file.")
    ap.add_argument("macros_file", help="Path to LaTeX macros file (.tex or .sty)")
    ap.add_argument("--out", default="tex.json", help="Output JSON path (VSCode snippet format)")
    ap.add_argument("--prefix", choices=["bare", "backslash", "both"], default="both",
                    help="Snippet trigger style: 'bare' (CCl), 'backslash' (\\CCl), or 'both'")
    args = ap.parse_args()

    text = Path(args.macros_file).read_text(encoding='utf-8', errors='ignore')
    text_nc = strip_comments(text)

    snippets = {}

    def add_snippet(name, body, description=None, env=False, star_variant=False):
        if isinstance(body, list):
            body_out = body
        else:
            body_out = [body]

        # prefixes
        if args.prefix == 'bare':
            prefix = [name]
        elif args.prefix == 'backslash':
            prefix = [f'\\{name}']
        else:
            prefix = [name, f'\\{name}']

        key = make_entry_key(name, "env" if env else ("*" if star_variant else None))
        snippets[key] = {
            "prefix": prefix,
            "body": body_out,
            "description": description or ""
        }

    # \DeclareMathOperator
    for m in DECLAREMATHOP_RE.finditer(text_nc):
        name = m.group('name')
        add_snippet(name, f'\\{name}', description="DeclareMathOperator")

    # \DeclarePairedDelimiter
    for m in DECLAREPAIRED_RE.finditer(text_nc):
        name = m.group('name')
        # Normal and starred variants
        add_snippet(name, f'\\{name}' + '{${1}}', description="DeclarePairedDelimiter")
        add_snippet(name + '*', f'\\{name}*' + '{${1}}', description="DeclarePairedDelimiter (starred)", star_variant=True)

    # Classic \newcommand
    for m in NEWCOMMAND_RE.finditer(text_nc):
        name = m.group('name')
        num = int(m.group('num') or 0)
        default = m.group('default') if m.group('default') is not None else None
        body = snippet_body_for_cmd(name, num, default)
        add_snippet(name, body, description="(re|provide)newcommand")

    # \NewDocumentCommand
    for m in NEWDOC_CMD_RE.finditer(text_nc):
        name = m.group('name')
        spec = compact_ws(m.group('spec'))
        toks = parse_xparse_spec(spec)
        body = snippet_body_for_xparse(name, toks)
        add_snippet(name, body, description=f'NewDocumentCommand {{{spec}}}')

    # \newenvironment + \renewenvironment
    for m in NEWTENV_RE.finditer(text_nc):
        name = m.group('name')
        num = int(m.group('num') or 0)
        default = m.group('default') if m.group('default') is not None else None
        body = env_snippet(name, num, default)
        add_snippet(name, body, description="(re)newenvironment", env=True)

    # \NewDocumentEnvironment
    for m in NEWDOC_ENV_RE.finditer(text_nc):
        name = m.group('name')
        spec = compact_ws(m.group('spec'))
        toks = parse_xparse_spec(spec)
        body = env_snippet_xparse(name, toks)
        add_snippet(name, body, description=f'NewDocumentEnvironment {{{spec}}}', env=True)

    # Write output
    out_path = Path(args.out).expanduser()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(snippets, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f"Wrote {out_path} with {len(snippets)} snippets.")

if __name__ == "__main__":
    main()
