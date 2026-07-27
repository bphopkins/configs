#!/usr/bin/env python3
r"""
Generate LuaSnip snippets from a LaTeX .sty file.

Usage:
    python3 sty-lua-snippets.py -i french-logic.sty -o french-logic.lua

The script scans the .sty file for command/environment definitions
(\newcommand, \renewcommand, \providecommand, \DeclareMathOperator,
\newenvironment, \renewenvironment, \newtheorem) and emits a Lua module
matching the latex-workshop.lua format (table literal + return snippets).

The output header carries a `-- sty-sha256:` stamp of the input file, so
loaders (see lua/plugins/snippets.lua) can detect a stale snippet file.
`--check` compares the would-be output against the existing file and
exits non-zero on drift, without writing anything.

`--coverage` instead cross-references the .sty's commands against the
highlight registrations in lua/plugins/vimtex.lua (path override via
--vimtex) and prints any command with no registration, minus the known
deliberate exclusions.  Exit codes: 0 fully covered, 1 uncovered
commands listed, 2 the registrations could not be parsed (helper style
in vimtex.lua changed — update collect_registrations here to match).
"""

import argparse
import hashlib
import os
import re
import sys
from dataclasses import dataclass
from typing import Dict, List, Optional


# ---------- Data containers ----------


@dataclass
class CommandDef:
    name: str
    arg_count: int = 0
    has_optional: bool = False
    optional_default: Optional[str] = None


@dataclass
class SnippetDef:
    trigger: str
    template: str


# ---------- Parsing helpers ----------


def strip_comments(text: str) -> str:
    """
    Remove LaTeX comments (% ... end-of-line, unless escaped) so we don't pick
    up disabled definitions.
    """
    lines: List[str] = []
    for line in text.splitlines():
        parts = re.split(r"(?<!\\)%", line, maxsplit=1)
        lines.append(parts[0])
    return "\n".join(lines)


CMD_PATTERN = re.compile(
    r"\\(?:(?:re)?newcommand|providecommand)\s*\*?\s*{\\(?P<name>[A-Za-z@]+?)}"
    r"\s*(?:\[(?P<count>\d+)\])?\s*(?:\[(?P<default>[^\]]+)\])?",
    re.MULTILINE,
)

MATH_OPERATOR_PATTERN = re.compile(
    r"\\DeclareMathOperator\*?\s*{\\(?P<name>[A-Za-z@]+?)}", re.MULTILINE
)

ENV_PATTERN = re.compile(
    r"\\(?:re)?newenvironment\s*\*?\s*{(?P<name>[A-Za-z@]+?)}"
    r"\s*(?:\[(?P<count>\d+)\])?\s*(?:\[(?P<default>[^\]]*)\])?",
    re.MULTILINE,
)

# \newtheorem{name}... — the optional-star form and the [counter]/[section]
# arguments don't affect snippet shape.  The \s*\*?\s*{ tail also keeps
# \newtheoremstyle from matching.
THEOREM_PATTERN = re.compile(
    r"\\newtheorem\s*\*?\s*{(?P<name>[A-Za-z@]+?)}", re.MULTILINE
)


def collect_commands(text: str) -> Dict[str, CommandDef]:
    commands: Dict[str, CommandDef] = {}
    for match in CMD_PATTERN.finditer(text):
        name = match.group("name")
        count = int(match.group("count") or 0)
        default = match.group("default")
        has_optional = default is not None
        commands[name] = CommandDef(
            name=name,
            arg_count=count,
            has_optional=has_optional,
            optional_default=default.strip() if default else None,
        )

    for match in MATH_OPERATOR_PATTERN.finditer(text):
        name = match.group("name")
        commands.setdefault(name, CommandDef(name=name))

    return commands


@dataclass
class EnvDef:
    name: str
    optional_default: Optional[str] = None


def collect_environments(text: str) -> List[EnvDef]:
    envs: Dict[str, EnvDef] = {}
    for match in ENV_PATTERN.finditer(text):
        name = match.group("name")
        # An environment has an optional argument iff a default is given
        # alongside an argument count: \newenvironment{x}[1][default]
        default = match.group("default") if match.group("count") else None
        envs[name] = EnvDef(name=name, optional_default=default)
    for match in THEOREM_PATTERN.finditer(text):
        envs.setdefault(match.group("name"), EnvDef(name=match.group("name")))
    return sorted(envs.values(), key=lambda e: e.name)


# ---------- Template → Lua node conversion ----------

PLACEHOLDER_PATTERN = re.compile(r"\$\{(\d+)(?::([^}]*))?\}")


def text_to_node(text: str) -> Optional[Dict[str, List[str]]]:
    if not text:
        return None
    lines = text.split("\n")
    return {"type": "text", "lines": lines}


def template_to_nodes(template: str) -> List[Dict[str, Optional[str]]]:
    nodes: List[Dict[str, Optional[str]]] = []
    pos = 0
    buffer: List[str] = []

    for match in PLACEHOLDER_PATTERN.finditer(template):
        buffer.append(template[pos : match.start()])
        text_node = text_to_node("".join(buffer))
        if text_node:
            nodes.append(text_node)
        buffer = []

        index = int(match.group(1))
        default = match.group(2)
        nodes.append({"type": "insert", "index": index, "default": default})
        pos = match.end()

    buffer.append(template[pos:])
    text_node = text_to_node("".join(buffer))
    if text_node:
        nodes.append(text_node)

    return nodes


def lua_quote(s: str) -> str:
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\t", "\\t")
    s = s.replace("\r", "\\r")
    s = s.replace("\n", "\\n")
    return f'"{s}"'


def nodes_to_lua(nodes: List[Dict[str, Optional[str]]]) -> str:
    parts: List[str] = []
    for node in nodes:
        if node["type"] == "text":
            lines: List[str] = node["lines"]  # type: ignore[assignment]
            if len(lines) == 1:
                parts.append(f"t({lua_quote(lines[0])})")
            else:
                inner = ", ".join(lua_quote(line) for line in lines)
                parts.append(f"t({{ {inner} }})")
        else:
            idx = node["index"]
            default = node.get("default")
            if default is None or default == "":
                parts.append(f"i({idx})")
            else:
                parts.append(f"i({idx}, {lua_quote(default)})")
    if not parts:
        parts.append("t(\"\")")
    return "{ " + ", ".join(parts) + " }"


# ---------- Snippet builders ----------


def build_command_template(cmd: CommandDef) -> str:
    parts: List[str] = [f"\\{cmd.name}"]
    next_index = 1

    if cmd.has_optional and cmd.arg_count > 0:
        default = cmd.optional_default or ""
        parts.append("[")
        parts.append(f"${{{next_index}:{default}}}")
        parts.append("]")
        next_index += 1
        mandatory_args = cmd.arg_count - 1
    else:
        mandatory_args = cmd.arg_count

    for _ in range(mandatory_args):
        parts.append("{")
        parts.append(f"${{{next_index}}}")
        parts.append("}")
        next_index += 1

    return "".join(parts)


def is_list_environment(name: str) -> bool:
    return "list" in name.lower()


def build_environment_template(env: EnvDef) -> str:
    name = env.name
    index = 1
    head = f"\\begin{{{name}}}"
    # Emit the optional-argument placeholder only for text defaults
    # ("Proof sketch").  A macro-valued default (proof's [\proofname])
    # means the plain \begin{...} already produces the right output, so
    # the bracket group would be pure source noise.
    if env.optional_default is not None and not env.optional_default.startswith("\\"):
        head += f"[${{{index}:{env.optional_default}}}]"
        index += 1
    if is_list_environment(name):
        body = f"\t\\item ${{{index}}}"
    else:
        body = f"\t${{{index}}}"
    return f"{head}\n{body}\n\\end{{{name}}}"


def collect_snippets(text: str) -> List[SnippetDef]:
    snippets: List[SnippetDef] = []

    envs = collect_environments(text)
    for env in envs:
        template = build_environment_template(env)
        snippets.append(
            SnippetDef(trigger=f"\\{env.name}~", template=template),
        )

    commands = collect_commands(text)
    for name in sorted(commands.keys()):
        cmd = commands[name]
        template = build_command_template(cmd)
        snippets.append(
            SnippetDef(trigger=f"\\{name}~", template=template),
        )

    return snippets


# ---------- Highlight-registration coverage ----------

# Deliberately unregistered commands; mirrors the header comment in
# lua/plugins/vimtex.lua.
KNOWN_UNREGISTERED = {"versal", "sketchqed", "remarkqed", "inf", "infer"}

REG_NAME_PATTERN = re.compile(r'\bm?a?cmd\("([A-Za-z]+)"')
REG_CMDRE_PATTERN = re.compile(r'\bm?a?re\("[A-Za-z]+",\s*"((?:[^"\\]|\\.)*)"')


def vim_regex_to_python(pattern: str) -> str:
    """Translate the very-magic Vim regexes used in vimtex.lua's cmdre
    entries (as written in Lua source, i.e. with doubled backslashes)."""
    pattern = pattern.replace("\\\\", "\\")  # Lua escaping -> actual string
    pattern = pattern.replace(r"\w", "[A-Za-z0-9_]")
    pattern = pattern.replace(r"\+", "+")  # \+ = one or more
    pattern = pattern.replace("%(", "(?:")  # %( = group
    pattern = pattern.replace(">", r"\b")  # > = end of word
    return pattern


def strip_lua_comments(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def report_coverage(sty_text: str, vimtex_path: str) -> int:
    with open(vimtex_path, "r", encoding="utf-8") as fh:
        vimtex_text = strip_lua_comments(fh.read())

    names = set(REG_NAME_PATTERN.findall(vimtex_text))
    patterns = REG_CMDRE_PATTERN.findall(vimtex_text)
    # Sanity floor: if parsing collapses (helper call style changed in
    # vimtex.lua), say so instead of reporting everything uncovered.
    if len(names) < 100 or len(patterns) < 10:
        print(
            f"could not parse registrations in {vimtex_path} "
            f"(found {len(names)} names, {len(patterns)} patterns; "
            "expected hundreds/dozens)"
        )
        return 2

    compiled = [re.compile(vim_regex_to_python(p) + r"$") for p in patterns]
    commands = set(collect_commands(sty_text).keys())

    def covered(name: str) -> bool:
        return name in names or any(rx.match(name) for rx in compiled)

    uncovered = sorted(
        c for c in commands if not covered(c) and c not in KNOWN_UNREGISTERED
    )
    if uncovered:
        for name in uncovered:
            print(f"\\{name}")
        return 1
    return 0


# ---------- Lua emitter ----------


def render_lua(snippets: List[SnippetDef], source_sty: str, sty_sha256: str) -> str:
    lines: List[str] = []
    lines.append(f"-- Auto-generated from {os.path.basename(source_sty)}")
    lines.append("-- Regenerate via sty-lua-snippets.py")
    lines.append(f"-- sty-sha256: {sty_sha256}")
    lines.append("")
    lines.append('local ls = require("luasnip")')
    lines.append("local s  = ls.snippet")
    lines.append("local t  = ls.text_node")
    lines.append("local i  = ls.insert_node")
    lines.append("")
    lines.append("local snippets = {")

    snippets.sort(key=lambda s: s.trigger)
    for snip in snippets:
        nodes = template_to_nodes(snip.template)
        lua_body = nodes_to_lua(nodes)
        trig = lua_quote(snip.trigger)
        lines.append(f"  s({{ trig = {trig}, wordTrig = true }}, {lua_body}),")

    lines.append("}")
    lines.append("")
    lines.append("return snippets")
    return "\n".join(lines) + "\n"


# ---------- CLI ----------


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert a LaTeX .sty file into a LuaSnip snippet module."
    )
    parser.add_argument(
        "-i",
        "--input",
        default="french-logic.sty",
        help="Path to the .sty file (default: %(default)s)",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="french-logic.lua",
        help="Path to the output Lua file (default: %(default)s)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Compare the would-be output with the existing output file; "
        "exit 1 on drift, write nothing.",
    )
    parser.add_argument(
        "--coverage",
        action="store_true",
        help="Cross-reference the .sty against the vimtex.lua highlight "
        "registrations; exit 1 listing unregistered commands, write nothing.",
    )
    parser.add_argument(
        "--vimtex",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "..", "plugins", "vimtex.lua"),
        help="Path to vimtex.lua for --coverage (default: %(default)s)",
    )
    args = parser.parse_args()

    with open(args.input, "rb") as fh:
        raw_bytes = fh.read()
    sty_sha256 = hashlib.sha256(raw_bytes).hexdigest()
    raw_text = raw_bytes.decode("utf-8")

    stripped = strip_comments(raw_text)

    if args.coverage:
        sys.exit(report_coverage(stripped, args.vimtex))

    snippets = collect_snippets(stripped)
    content = render_lua(snippets, args.input, sty_sha256)

    if args.check:
        try:
            with open(args.output, "r", encoding="utf-8") as fh:
                existing = fh.read()
        except FileNotFoundError:
            existing = None
        if existing != content:
            print(f"{args.output}: stale (regenerate from {args.input})")
            sys.exit(1)
        print(f"{args.output}: up to date")
        return

    with open(args.output, "w", encoding="utf-8") as fh:
        fh.write(content)


if __name__ == "__main__":
    main()
