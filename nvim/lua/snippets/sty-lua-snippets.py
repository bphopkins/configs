
#!/usr/bin/env python3
"""
Generate LuaSnip snippets from a LaTeX .sty file.

Usage:
    cd ~/Desktop/configs/nvim/lua/snippets
    python3 sty-lua-snippets.py ~/Desktop/configs/latex/french-logic/french-logic.sty tex.lua

This script extracts:
  - All custom commands defined via \newcommand, \renewcommand, \providecommand,
    and \DeclareMathOperator (and starred variants), with any number of arguments.
  - All environments defined via \newenvironment.

Lines that are fully commented out (first non-space char is %) are ignored.
"""
import re
import sys
from pathlib import Path


def parse_sty(text: str):
    """
    Return (macros, envs) where:
      macros: dict name -> nargs (n >= 0)
      envs:   dict name -> nargs (n >= 0)
    """
    macros = {}
    envs = {}

    for line in text.splitlines():
        stripped = line.lstrip()
        if not stripped or stripped.startswith("%"):
            continue

        # \newcommand{\foo}[3]{...}
        # \renewcommand{\foo}[2]{...}
        # \providecommand{\foo}[1]{...}
        m = re.match(
            r"\\(?:newcommand|renewcommand|providecommand)\*?\s*{\\([A-Za-z@]+)}\s*(?:\[(\d+)\])?",
            stripped,
        )
        if m:
            name = m.group(1)
            nargs = int(m.group(2)) if m.group(2) is not None else 0
            macros[name] = nargs
            continue

        # \DeclareMathOperator{\Foo}{bar}
        # \DeclareMathOperator*{\Foo}{bar}
        d = re.match(r"\\DeclareMathOperator\*?\s*{\\([A-Za-z@]+)}", stripped)
        if d:
            name = d.group(1)
            # Treat declared math operators as 1-argument macros in snippets.
            macros.setdefault(name, 1)
            continue

        # \newenvironment{env}[n]{...}{...}
        e = re.match(
            r"\\newenvironment\*?\s*{([A-Za-z@]+)}\s*(?:\[(\d+)\])?", stripped
        )
        if e:
            name = e.group(1)
            nargs = int(e.group(2)) if e.group(2) is not None else 0
            envs[name] = nargs
            continue

    return macros, envs


def is_list_env(name: str) -> bool:
    """
    Heuristic: treat environments whose name contains 'list' (case-insensitive)
    as 'list-like', so the snippet pre-populates a \\item line.
    """
    return "list" in name.lower()


def make_lua_snippet_file(macros, envs, sty_path: Path) -> str:
    def L(tex: str) -> str:
        # Represent TeX code as a Lua long string literal.
        return f"[[{tex}]]"

    lines = []
    lines.append(f'-- Auto-generated from {sty_path.name}')
    lines.append('-- Regenerate via sty-lua-snippets.py')
    lines.append('')
    lines.append('local ls = require("luasnip")')
    lines.append('local s = ls.snippet')
    lines.append('local t = ls.text_node')
    lines.append('local i = ls.insert_node')
    lines.append('')
    lines.append('local snippets = {}')
    lines.append('')

    # Environments
    if envs:
        lines.append('-- Environments')
        for env in sorted(envs):
            nargs = envs[env]
            begin_tex = "\\begin{%s}" % env
            end_tex = "\\end{%s}" % env
            if is_list_env(env):
                middle_tex = "  \\item "
            else:
                middle_tex = "  "
            trig = env + "~"  # e.g. "Hilbertlist~"

            lines.append(f'table.insert(snippets, s("{trig}", {{')

            if nargs == 0:
                # \begin{env}
                lines.append(f'  t({L(begin_tex)}),')
            else:
                # \begin{env}{arg1}{arg2}...
                lines.append(f'  t({L(begin_tex + "{")}),')
                # First argument
                lines.append('  i(1),')
                for idx in range(2, nargs + 1):
                    lines.append(f'  t({L("}{")}),')
                    lines.append(f'  i({idx}),')
                lines.append(f'  t({L("}")}),')

            body_index = nargs + 1
            # Newline + body line (with or without \item)
            lines.append(f'  t({{ "", {L(middle_tex)} }}), i({body_index}),')
            # Newline + \end{env}
            lines.append(f'  t({{ "", {L(end_tex)} }}),')
            lines.append('}))')
            lines.append('')

        lines.append('')

    # Macros
    if macros:
        lines.append('-- Commands')
        for name in sorted(macros):
            n = macros[name]
            trig_tex = "\\" + name          # e.g. "\CMr"
            trig = trig_tex + "~"           # e.g. "\CMr~"

            lines.append(
                f'table.insert(snippets, s({{ trig = {L(trig)}, wordTrig = true }}, {{'
            )

            if n == 0:
                # No-argument macro: just \Foo
                lines.append(f'  t({L(trig_tex)}),')
            else:
                # \Foo{arg1}{arg2}...{argn}
                lines.append(f'  t({L(trig_tex + "{")}),')
                for idx in range(1, n + 1):
                    lines.append(f'  i({idx}),')
                    if idx < n:
                        lines.append(f'  t({L("}{")}),')
                    else:
                        lines.append(f'  t({L("}")}),')

            lines.append('}))')
            lines.append('')

    lines.append('return snippets')
    lines.append('')
    return "\n".join(lines)


def main(argv=None):
    if argv is None:
        argv = sys.argv

    if len(argv) != 3:
        print(
            "Usage: python3 sty-lua-snippets.py path/to/file.sty path/to/output.lua",
            file=sys.stderr,
        )
        return 1

    sty_path = Path(argv[1]).expanduser()
    out_path = Path(argv[2]).expanduser()

    text = sty_path.read_text(encoding="utf-8")
    macros, envs = parse_sty(text)

    lua_code = make_lua_snippet_file(macros, envs, sty_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(lua_code, encoding="utf-8")
    print(f"Wrote {out_path} with {len(envs)} envs and {len(macros)} commands.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
