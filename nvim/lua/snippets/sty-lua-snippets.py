#!/usr/bin/env python3
r"""
Generate LuaSnip snippets from a LaTeX .sty file.

Usage:
    python3 sty-lua-snippets.py -i french-logic.sty -o french-logic.lua

The script scans the .sty file for command/environment definitions
(\newcommand, \renewcommand, \providecommand, \DeclareMathOperator,
\newenvironment, \renewenvironment) and emits a Lua module matching the
latex-workshop.lua format (table literal + return snippets).
"""

import argparse
import os
import re
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
    r"\\(?:re)?newenvironment\*?\s*{(?P<name>[A-Za-z@]+?)}", re.MULTILINE
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


def collect_environments(text: str) -> List[str]:
    envs = {match.group("name") for match in ENV_PATTERN.finditer(text)}
    return sorted(envs)


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


def build_environment_template(name: str) -> str:
    if is_list_environment(name):
        body = "\t\\item ${1}"
    else:
        body = "\t${1}"
    return f"\\begin{{{name}}}\n{body}\n\\end{{{name}}}"


def collect_snippets(text: str) -> List[SnippetDef]:
    snippets: List[SnippetDef] = []

    envs = collect_environments(text)
    for env in envs:
        template = build_environment_template(env)
        snippets.append(
            SnippetDef(trigger=f"\\{env}~", template=template),
        )

    commands = collect_commands(text)
    for name in sorted(commands.keys()):
        cmd = commands[name]
        template = build_command_template(cmd)
        snippets.append(
            SnippetDef(trigger=f"\\{name}~", template=template),
        )

    return snippets


# ---------- Lua emitter ----------


def write_lua(output_path: str, snippets: List[SnippetDef], source_sty: str) -> None:
    lines: List[str] = []
    lines.append(f"-- Auto-generated from {os.path.basename(source_sty)}")
    lines.append("-- Regenerate via sty-lua-snippets.py")
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

    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


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
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as fh:
        raw_text = fh.read()

    stripped = strip_comments(raw_text)
    snippets = collect_snippets(stripped)
    write_lua(args.output, snippets, args.input)


if __name__ == "__main__":
    main()
