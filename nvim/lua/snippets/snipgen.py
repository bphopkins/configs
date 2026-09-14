#!/usr/bin/env python3
r"""
snipgen.py -- LuaSnip snippet libraries from TeXstudio's completion word lists.

One generated Lua file per .cwl file, loaded per document by the loader of
lua/snippets (stage 3 of the 2026-09 completion campaign).  The generation
rules, their rationale and the record trail are in
configs/docs/latex-completion-campaign-2026-09/PLAN.md, section 2; the suite
is configs/tests/snipgen (run it after any edit here).

    snipgen.py --all [--clone DIR] [--out-dir DIR] [--check]
    snipgen.py --cwl FILE... [--core DIR] [--option PKG:OPT]...
               [--out-dir DIR | -o FILE] [--check]
    snipgen.py --sty FILE... [--out-dir DIR] [--check]
    snipgen.py --sty FILE... --coverage [--vimtex FILE]

--all converts every file of the clone's completion/ (default clone
~/Desktop/texstudio) into OUT-DIR (default pkg/ beside this script), skipping
expl3-commands and any file with neither rows nor #include lines, and removes
generated files whose source is gone.  --cwl converts the named files (spot
checks, the suite).  --check compares the would-be output with what is on
disk, writes nothing, and exits 1 on any drift.  Warnings go to stderr and
never change the exit status; exit 2 is a usage or I/O error.

What a cwl line becomes (PLAN.md section 2, in one paragraph): the row is
split at its first '#' into the command and the classification; 'S' (hidden)
and 'B' (colour name) rows are dropped, as TeXstudio's completer drops them;
'\end{...}' rows are dropped.  Every '%suffix' on an argument name is removed,
then '%<x%>' is a placeholder x, '%|' the final cursor, '%\' a newline, and
every remaining bracket group of any kind ({}, [], (), <>) becomes one
placeholder named by its content, except an empty group and a group that
already holds a marker.  That is TeXstudio's bracket rule, which it applies
only to rows without any marker; here a row with markers also has the bare
groups attached to its own command filled (its leading chain of groups,
separated by nothing but whitespace), so '{file}' after '[scale=%<1%>]' is
a placeholder while an inner '\begin{axis}' in a multi-line template stays
literal.  A '\begin{env}' row becomes an environment template, name, arguments,
a body line and '\end{env}', with '\item ' in the body when any row of that
environment, in the file or in the always-loaded lists, ends in '\item'; a row
with '%\' in it is emitted as written.
The trigger is '\name' ('\env' for environments); the description is
TeXstudio's own list row minus the leading name (the whole first line for an
environment), with ' \u2217' appended on an unusual ('#*') row, which also gets
priority 900 (the sink).  'm' rows are wrapped by h.mathwrap, '/env' rows
get show_condition = h.in_env; every classification is kept verbatim as the
snippet's cls field.  Rows identical in (trigger, description) are
deduplicated within a file, first wins except that a typical row replaces its
unusual twin wherever it comes, and against the three always-loaded lists
(tex, latex-document, latex-dev, in that order, each against the previous).  #keyvals blocks are kept verbatim in the file's keyvals table for
the deferred key-value tier; #ifOption blocks are skipped unless OPTIONS (or
--option) enables them; unknown '#word:' directives are comments, with one
warning per word and file.

--sty converts a LaTeX package of this repository (french-logic: the hub, and
every required package whose .sty sits beside it, recursively, so one argument
yields the whole package) into OUT-DIR (default sty/ beside this script), one
file per .sty, and removes a file there whose header names a source that is
gone; --coverage instead cross-references the package's commands against the
highlight registrations in lua/plugins/vimtex.lua and lists the unregistered
ones, minus the known exclusions (exit 1; exit 2 when the registrations cannot
be parsed).  Neither needs the clone.

What a .sty definition becomes (PLAN.md section 2): the braced forms
\newcommand, \renewcommand, \providecommand, \DeclareMathOperator,
\DeclareMathSymbol, \newenvironment, \renewenvironment and \newtheorem are
read after '%' comments are stripped; a name with '@' is internal and skipped.
A command is '\name' plus one bare '{}' placeholder per mandatory argument; a
definition with an optional argument gives two rows, the bare one and one with
the bracket first, whose placeholder text is the default when it is text and
empty when the default is empty or a macro.  An environment is '\begin{name}'
plus its arguments, a body line and '\end{name}', the body '\item ' when the
begin code opens itemize, enumerate or description (TeXstudio's own three) or
an environment already known as a list in this package; the file's lists
table names them.  \DeclareMathOperator and \DeclareMathSymbol rows are math
by construction, wrapped by h.mathwrap with cls 'm'; no other row carries a
classification.  Descriptions are the bare shape ('[]{}'); rows keep source
order, the last definition of a name giving its shape and the first its
place.  Every \RequirePackage name is an include and \usetikzlibrary{x} the
include tikzlibraryx (TeXstudio's mapping); files are generated hub first,
then in require order, each deduplicating its (trigger, description) pairs
against the files before it, and none against the core three.
"""

import argparse
import hashlib
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

GENERATOR_VERSION = "1"
CORE = ("tex", "latex-document", "latex-dev")  # always loaded; deduplicated in this order
EXCLUDED = {"expl3-commands"}  # expl syntax only
# package -> #ifOption names to enable, e.g. {"babel": {"german"}}.  Empty: his
# options select nothing (comparison 2.5); --option PKG:OPT adds to it per run.
OPTIONS: Dict[str, Set[str]] = {}
DIRECTIVES = ("include", "repl", "keyvals", "endkeyvals", "ifOption", "endif")
KNOWN_LETTERS = set("*SMmtTnrcClLdgiIubUKDBsVN0123456789")
GENERIC_TEMPLATE = {
    "%<%:TEXSTUDIO-GENERIC-ENVIRONMENT-TEMPLATE%>",
    "%<%:TEXMAKERX-GENERIC-ENVIRONMENT-TEMPLATE%>",
}
UNUSUAL_MARK = "\u2217"
DEFAULT_CLONE = "~/Desktop/texstudio"

SUFFIX_RE = re.compile(r"%[A-Za-z]+")
FLAGS_RE = re.compile(r"%:[^%]*")
# A name runs over letters, digits, @, : and _, except an underscore that opens a
# brace group, which is a subscript (\sum_{min}^{max}); expl3 names keep theirs.
NAME_RE = re.compile(r"\\((?:[A-Za-z@:]|_(?!\{))(?:[A-Za-z0-9@:]|_(?!\{))*\*?|.)")
BEGIN_RE = re.compile(r"\\begin\{([^{}]*)\}")
DIRECTIVE_RE = re.compile(r"#([A-Za-z]+):")
OPEN, CLOSE = "{[(<", "}])>"

Token = tuple  # ("t", text) | ("p", name) | ("c",) | ("n",) | ("rep", n)


# ---------- reading ----------


@dataclass
class KeyvalBlock:
    targets: str
    lines: List[str] = field(default_factory=list)


@dataclass
class Cwl:
    package: str
    sha256: str
    header: List[str]
    includes: List[str]
    rows: List[Tuple[int, str]]
    keyvals: List[KeyvalBlock]
    warnings: List[Tuple[int, str]]


def is_directive(s: str) -> bool:
    return s.startswith(("#include:", "#repl:", "#keyvals:", "#endkeyvals", "#ifOption:", "#endif"))


def read_cwl(path: Path, enabled: Set[str]) -> Cwl:
    package = path.name[:-4] if path.name.endswith(".cwl") else path.name
    data = path.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    warnings: List[Tuple[int, str]] = []
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        warnings.append((0, "not valid UTF-8, undecodable bytes replaced"))
        text = data.decode("utf-8", "replace")
    raw = text.split("\n")
    if raw and raw[-1] == "":
        raw.pop()
    lines = [l.rstrip("\r") for l in raw]

    header: List[str] = []
    for l in lines:
        s = l.strip()
        if s.startswith("#") and not is_directive(s):
            header.append(l.rstrip())
        else:
            break

    includes: List[str] = []
    rows: List[Tuple[int, str]] = []
    keyvals: List[KeyvalBlock] = []
    skip = False
    block: Optional[KeyvalBlock] = None
    warned: Set[str] = set()
    for lineno, l in enumerate(lines, 1):
        s = l.strip()
        if s.startswith("#endif"):
            skip = False
            continue
        if s.startswith("#ifOption:"):
            skip = s[10:].strip() not in enabled
            continue
        if skip:
            continue
        if s.startswith("#include:"):
            name = s[9:].strip()
            if name and name != package and name not in includes:
                includes.append(name)
            continue
        if s.startswith("#keyvals:"):
            block = KeyvalBlock(targets=s[9:].strip())
            keyvals.append(block)
            continue
        if s.startswith("#endkeyvals"):
            block = None
            continue
        if block is not None and not s.startswith("#"):
            if s:
                block.lines.append(s)
            continue
        if s.startswith("#repl:"):
            continue
        if s.startswith("#"):
            m = DIRECTIVE_RE.match(s)
            if m and m.group(1) not in DIRECTIVES and m.group(1) not in warned:
                warned.add(m.group(1))
                warnings.append((lineno, f"unknown directive treated as a comment: #{m.group(1)}"))
            continue
        if not s:
            continue
        rows.append((lineno, s))
    if block is not None:
        warnings.append((len(lines) + 1, f"keyvals block not terminated at end of file: #keyvals:{block.targets}"))
    return Cwl(package, sha, header, includes, rows, keyvals, warnings)


# ---------- rows to snippets ----------


@dataclass
class Snip:
    trigger: str
    dscr: str
    kind: str  # cmd | env | generic
    env: Optional[str] = None
    tokens: List[Token] = field(default_factory=list)
    has_nl: bool = False
    unusual: bool = False
    math: bool = False
    envs: List[str] = field(default_factory=list)
    cls: Optional[str] = None
    nodes: list = field(default_factory=list)


def parse_classification(cls: Optional[str]) -> Tuple[bool, List[str], str]:
    """(unusual, environment restriction, classification letters), TeXstudio's reading."""
    if cls is None:
        return False, [], ""
    c = cls
    unusual = c.startswith("*")
    if unusual:
        c = c[1:]
    k = c.find("#")  # a second '#': the special-definition class (s#%color)
    if k >= 0:
        c = c[:k]
    envs: List[str] = []
    if c.startswith("/"):
        envs = [e for e in c[1:].split(",") if e]
        letters = ""
    else:
        k = c.find("\\")  # environment alias list (#\math,array)
        letters = c[:k] if k >= 0 else c
        k = letters.find("/")  # letters then /env: TeXstudio ignores the restriction; so do we
        if k >= 0:
            letters = letters[:k]
    for word in ("beginEnv", "endEnv"):
        if letters.startswith(word):
            letters = letters[len(word):]
    return unusual, envs, letters


def tokenize(text: str) -> List[Token]:
    """The command text after its name: literal text, explicit placeholders, cursor, newlines."""
    text = SUFFIX_RE.sub("", text)
    out: List[Token] = []
    buf: List[str] = []

    def flush() -> None:
        if buf:
            out.append(("t", "".join(buf)))
            buf.clear()

    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch != "%" or i + 1 >= n:
            buf.append(ch)
            i += 1
            continue
        nx = text[i + 1]
        if nx == "<":
            end = text.find("%>", i + 2)
            if end < 0:
                buf.append("%")
                i += 1
                continue
            flush()
            out.append(("p", FLAGS_RE.sub("", text[i + 2:end])))
            i = end + 2
        elif nx == "|":
            flush()
            out.append(("c",))
            i += 2
        elif nx == "\\":
            flush()
            out.append(("n",))
            i += 2
        elif nx == "%":
            buf.append("%")
            i += 2
        else:
            buf.append("%")
            i += 1
    flush()
    return out


def auto_placeholders(tokens: List[Token]) -> List[Token]:
    """TeXstudio's bracket rule over the token list: a group of any bracket kind whose
    content is plain text becomes a placeholder named by that content; an empty group
    stays literal; a group already holding a marker is left alone (it is never all text)."""
    out: List[Token] = []
    for tok in tokens:
        if tok[0] != "t":
            out.append(tok)
            continue
        cur: List[str] = []
        last: Optional[Tuple[int, int]] = None  # (index of the open bracket in cur, bracket kind)
        for ch in tok[1]:
            k = OPEN.find(ch)
            if k >= 0:
                last = (len(cur), k)
                cur.append(ch)
                continue
            k = CLOSE.find(ch)
            if k >= 0 and last is not None and last[1] == k:
                start = last[0]
                if len(cur) - start - 1 == 0:  # empty group stays, its bracket stays armed
                    cur.append(ch)
                    continue
                out.append(("t", "".join(cur[: start + 1])))
                out.append(("p", "".join(cur[start + 1:])))
                cur = [ch]
                last = None
                continue
            cur.append(ch)
        if cur:
            out.append(("t", "".join(cur)))
    return out


def attached_placeholders(tokens: List[Token]) -> List[Token]:
    """The marker-row variant of the bracket rule: only the groups attached to the row's
    own command are filled, its leading chain of bracket groups separated by nothing but
    whitespace; a group holding a marker or nothing stays literal, and the chain ends at
    the first other character, so an inner \\begin{axis} in a multi-line template is
    left alone."""
    parts: List[str] = []
    markers: List[Token] = []
    for tok in tokens:
        if tok[0] == "t":
            parts.append(tok[1])
        else:
            parts.append("\x00")
            markers.append(tok)
    s = "".join(parts)
    pieces: List[Token] = []
    cur: List[str] = []
    last: Optional[Tuple[int, int]] = None
    pos = 0
    while pos < len(s):
        ch = s[pos]
        k_open, k_close = OPEN.find(ch), CLOSE.find(ch)
        if last is None:
            if ch.isspace():
                cur.append(ch)
            elif k_open >= 0:
                last = (len(cur), k_open)
                cur.append(ch)
            else:
                break
        elif k_open >= 0:
            last = (len(cur), k_open)
            cur.append(ch)
        elif k_close >= 0 and k_close == last[1]:
            content = "".join(cur[last[0] + 1:])
            if content and "\x00" not in content:
                pieces.append(("t", "".join(cur[: last[0] + 1])))
                pieces.append(("p", content))
                cur = [ch]
            else:
                cur.append(ch)
            last = None
        else:
            cur.append(ch)
        pos += 1
    cur.append(s[pos:])
    text = "".join(cur)
    if text:
        pieces.append(("t", text))
    out: List[Token] = []  # put the markers back where their sentinels are
    for piece in pieces:
        if piece[0] != "t":
            out.append(piece)
            continue
        for j, chunk in enumerate(piece[1].split("\x00")):
            if j > 0:
                out.append(markers.pop(0))
            if chunk:
                out.append(("t", chunk))
    return out


def placeholders(tokens: List[Token]) -> List[Token]:
    """A row without any marker gets TeXstudio's rule over every group; a row with
    markers keeps them and fills only the groups attached to its own command."""
    if any(t[0] in ("p", "c", "n") for t in tokens):
        return attached_placeholders(tokens)
    return auto_placeholders(tokens)


def render_first_line(tokens: List[Token]) -> str:
    out: List[str] = []
    for tok in tokens:
        if tok[0] == "n":
            break
        if tok[0] in ("t", "p"):
            out.append(tok[1])
    return "".join(out)


def build_nodes(tokens: List[Token]) -> list:
    nodes: list = []
    lines: List[str] = [""]
    n = 0

    def flush() -> None:
        nonlocal lines
        if lines != [""]:
            nodes.append(("t", lines))
        lines = [""]

    for tok in tokens:
        if tok[0] == "t":
            lines[-1] += tok[1]
        elif tok[0] == "n":
            lines.append("")
        elif tok[0] == "p":
            flush()
            n += 1
            nodes.append(("i", n, tok[1]))
        elif tok[0] == "c":
            flush()
            nodes.append(("i", 0, None))
        elif tok[0] == "rep":
            flush()
            nodes.append(("rep", tok[1]))
    flush()
    return nodes


def generic_snip() -> Snip:
    sn = Snip(trigger="\\begin", dscr="\\begin{environment}", kind="generic")
    sn.nodes = build_nodes([
        ("t", "\\begin{"), ("p", "environment"), ("t", "}"), ("n",), ("t", "\t"), ("c",),
        ("n",), ("t", "\\end{"), ("rep", 1), ("t", "}"),
    ])
    return sn


def convert(cwl: Cwl, core_keys: Set[Tuple[str, str]], core_lists: Set[str]) -> Tuple[List[Snip], List[str]]:
    snips: List[Snip] = []
    seen: Dict[Tuple[str, str], Snip] = {}
    list_envs: Set[str] = set()
    warned_letters: Set[str] = set()

    def warn(lineno: int, msg: str) -> None:
        cwl.warnings.append((lineno, msg))

    for lineno, line in cwl.rows:
        body, _, cls = line.partition("#")
        cls_raw: Optional[str] = cls if "#" in line else None
        if body == "\\":
            warn(lineno, f"bare backslash row skipped (the format cannot express it): {line}")
            continue
        if body in GENERIC_TEMPLATE:
            key = ("\\begin", "\\begin{environment}")
            if key not in seen and key not in core_keys:
                seen[key] = generic_snip()
                snips.append(seen[key])
            continue
        unusual, envs, letters = parse_classification(cls_raw)
        hidden = "S" in letters or "B" in letters
        if not body.startswith("\\"):
            if not hidden:
                warn(lineno, f"row without a leading backslash skipped: {line}")
            continue
        for ch in letters:
            if ch not in KNOWN_LETTERS and ch not in warned_letters:
                warned_letters.add(ch)
                warn(lineno, f"unknown classification letter {ch}: {line}")
        if hidden or body.startswith("\\end{"):
            continue
        if body.startswith("\\begin{"):
            m = BEGIN_RE.match(body)
            if not m:
                warn(lineno, f"environment row unparsable, skipped: {line}")
                continue
            env = m.group(1)
            rest = body[m.end():]
            if rest.endswith("\\item"):
                rest = rest[:-5]
                list_envs.add(env)
            tokens = placeholders(tokenize(rest))
            sn = Snip(
                trigger="\\" + env,
                dscr="\\begin{" + env + "}" + render_first_line(tokens),
                kind="env",
                env=env,
                tokens=tokens,
            )
        else:
            m = NAME_RE.match(body)
            assert m is not None
            tokens = placeholders(tokenize(body[m.end():]))
            sn = Snip(
                trigger=m.group(0),
                dscr=render_first_line(tokens).lstrip(),
                kind="cmd",
                tokens=tokens,
            )
        sn.has_nl = any(t[0] == "n" for t in tokens)
        sn.unusual, sn.math, sn.envs, sn.cls = unusual, "m" in letters, envs, cls_raw
        key = (sn.trigger, sn.dscr)
        if key in core_keys:
            continue
        if key in seen:
            old = seen[key]
            if old.unusual and not sn.unusual:  # the typical twin wins, in the first row's place
                old.unusual, old.math, old.envs, old.cls = False, sn.math, sn.envs, sn.cls
            continue
        seen[key] = sn
        snips.append(sn)

    effective = list_envs | core_lists  # a list environment is one anywhere among the loaded lists
    for sn in snips:
        if sn.kind == "generic":
            continue
        if sn.kind == "env":
            assert sn.env is not None
            toks: List[Token] = [("t", "\\begin{" + sn.env + "}")] + sn.tokens
            if not sn.has_nl:
                body_line = "\t" + ("\\item " if sn.env in effective else "")
                toks += [("n",), ("t", body_line), ("p", None), ("n",), ("t", "\\end{" + sn.env + "}")]
        else:
            toks = [("t", sn.trigger)] + sn.tokens
        sn.nodes = build_nodes(toks)
    return snips, sorted({sn.env for sn in snips if sn.kind == "env" and sn.env in effective})


# ---------- Lua emitter ----------


def lua_quote(s: str) -> str:
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\t", "\\t")
    s = s.replace("\r", "\\r")
    s = s.replace("\n", "\\n")
    return f'"{s}"'


def node_lua(node: tuple) -> str:
    if node[0] == "t":
        lines = node[1]
        if len(lines) == 1:
            return f"t({lua_quote(lines[0])})"
        return "t({ " + ", ".join(lua_quote(l) for l in lines) + " })"
    if node[0] == "i":
        _, n, default = node
        return f"i({n})" if not default else f"i({n}, {lua_quote(default)})"
    return f"rep({node[1]})"


def snippet_lua(sn: Snip) -> str:
    ctx = [f"trig = {lua_quote(sn.trigger)}"]
    dscr = sn.dscr
    if sn.unusual:
        dscr = f"{dscr} {UNUSUAL_MARK}" if dscr else UNUSUAL_MARK
    ctx.append(f"dscr = {lua_quote(dscr)}")
    if sn.unusual:
        ctx.append("priority = 900")
    if sn.envs:
        ctx.append("show_condition = h.in_env({ " + ", ".join(lua_quote(e) for e in sn.envs) + " })")
    nodes = "{ " + ", ".join(node_lua(n) for n in sn.nodes) + " }"
    if sn.math:
        nodes = f"h.mathwrap({nodes})"
    tail = f", {lua_quote(sn.cls)}" if sn.cls is not None else ""
    return f"    S({{ {', '.join(ctx)} }}, {nodes}{tail}),"


def lua_list(items: List[str]) -> str:
    return "{ " + ", ".join(lua_quote(x) for x in items) + " }" if items else "{}"


def cwl_header(cwl: Cwl, source_note: str) -> List[str]:
    out = [
        f"-- Generated by snipgen {GENERATOR_VERSION} from {cwl.package}.cwl; do not edit, regenerate.",
        f"-- source: {source_note}",
        f"-- cwl-sha256: {cwl.sha256}",
    ]
    if cwl.header:
        out.append("-- cwl-header:")
        out.extend(f"--   {h}" for h in cwl.header)
    out.append("-- licence: GPL-3; see NOTICE and COPYING beside the generated files")
    return out


def render(header: List[str], package: str, includes: List[str], snips: List[Snip], lists: List[str],
           keyvals: List[KeyvalBlock]) -> str:
    out = list(header)
    out.append("")
    out.append('local ls = require("luasnip")')
    if any(sn.math or sn.envs for sn in snips):
        out.append('local h = require("snippets.helpers")')
    out.append("local s, t, i = ls.snippet, ls.text_node, ls.insert_node")
    if any(sn.kind == "generic" for sn in snips):
        out.append('local rep = require("luasnip.extras").rep')
    out += [
        "local function S(ctx, nodes, cls)",
        "  local sn = s(ctx, nodes)",
        "  sn.cls = cls",
        "  return sn",
        "end",
        "",
        "return {",
        f"  package = {lua_quote(package)},",
        f"  includes = {lua_list(includes)},",
        f"  lists = {lua_list(lists)},",
        "  snippets = {",
    ]
    out.extend(snippet_lua(sn) for sn in snips)
    out.append("  },")
    if keyvals:
        out.append("  keyvals = {")
        for kv in keyvals:
            out += ["    {", f"      targets = {lua_quote(kv.targets)},", "      lines = {"]
            out.extend(f"        {lua_quote(l)}," for l in kv.lines)
            out += ["      },", "    },"]
        out.append("  },")
    else:
        out.append("  keyvals = {},")
    out.append("}")
    return "\n".join(out) + "\n"


# ---------- the .sty front end ----------
#
# A LaTeX package of this repository read for its definitions: TeXstudio's own
# autogeneration for a package without a word list (src/latexstyleparser.cpp), done
# with visible rows.  The rules are in the module docstring; the suite's fixture is
# tests/snipgen/fixture/sty/.  No clone is needed on this path: the startup check
# regenerates these files on a machine without one, and the request-time transform
# drops the few rows that coincide with the core three.

STY_LISTS = {"itemize", "enumerate", "description"}  # the three TeXstudio hard-codes (src/codesnippet.cpp)
STY_LIBRARIES = {"usetikzlibrary": "tikzlibrary", "usepgfplotslibrary": "pgfplotslibrary",
                 "tcbuselibrary": "tcolorboxlibrary"}  # \usetikzlibrary{x} loads tikzlibraryx.cwl (src/latexdocument.cpp)
# An empty optional default, \newcommand{\x}[2][]{...}, is still an optional argument: [^\]]* not [^\]]+.
STY_CMD_RE = re.compile(r"\\(?:(?:re)?newcommand|providecommand)\s*\*?\s*\{\\(?P<name>[A-Za-z@]+)\}"
                        r"\s*(?:\[(?P<count>\d+)\])?\s*(?:\[(?P<default>[^\]]*)\])?")
STY_OP_RE = re.compile(r"\\DeclareMathOperator\s*\*?\s*\{\\(?P<name>[A-Za-z@]+)\}")
STY_SYM_RE = re.compile(r"\\DeclareMathSymbol\s*\{\\(?P<name>[A-Za-z@]+)\}")
STY_ENV_RE = re.compile(r"\\(?:re)?newenvironment\s*\*?\s*\{(?P<name>[A-Za-z@]+)\}"
                        r"\s*(?:\[(?P<count>\d+)\])?\s*(?:\[(?P<default>[^\]]*)\])?")
STY_THM_RE = re.compile(r"\\newtheorem\s*\*?\s*\{(?P<name>[A-Za-z@]+)\}")  # the brace right after keeps \newtheoremstyle out
STY_REQ_RE = re.compile(r"\\RequirePackage(?:WithOptions)?\s*(?:\[[^\]]*\])?\s*\{(?P<names>[^}]*)\}")  # the bracket may span lines
STY_LIB_RE = re.compile(r"\\(?P<cmd>" + "|".join(STY_LIBRARIES) + r")\s*\{(?P<names>[^}]*)\}")
STY_PROVIDES_RE = re.compile(r"\\ProvidesPackage\s*\{[^}]*\}\s*(?:\[(?P<desc>[^\]]*)\])?")
STY_SOURCE_RE = re.compile(r"^-- source: (?P<path>.+) in this repository$")


@dataclass
class Sty:
    package: str
    path: Path
    sha256: str
    provides: Optional[str]
    requires: List[str]  # every required package, in source order, once
    text: str  # comment-stripped


@dataclass
class StyDef:
    pos: int
    kind: str  # cmd | env
    name: str
    count: int = 0  # every argument, the optional one included
    optional: Optional[str] = None  # the optional argument's default, "" when empty; None without one
    math: bool = False  # \DeclareMathOperator, \DeclareMathSymbol: math by construction
    opens: List[str] = field(default_factory=list)  # the environments an environment's begin code opens


def strip_tex_comments(text: str) -> str:
    """'%' to end of line removed unless escaped, so a commented-out definition is not read."""
    return "\n".join(re.split(r"(?<!\\)%", line, maxsplit=1)[0] for line in text.splitlines())


def balanced_group(text: str, pos: int) -> str:
    """The content of the brace group at pos (whitespace skipped), or "" when there is none."""
    n = len(text)
    while pos < n and text[pos].isspace():
        pos += 1
    if pos >= n or text[pos] != "{":
        return ""
    depth, i = 0, pos
    while i < n:
        ch = text[i]
        if ch == "\\":
            i += 2
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[pos + 1:i]
        i += 1
    return text[pos + 1:]


def read_sty(path: Path) -> Sty:
    data = path.read_bytes()
    text = strip_tex_comments(data.decode("utf-8"))
    m = STY_PROVIDES_RE.search(text)
    provides = " ".join(m.group("desc").split()) if m and m.group("desc") else None
    found: List[Tuple[int, str]] = []
    for m in STY_REQ_RE.finditer(text):
        found += [(m.start(), n.strip()) for n in m.group("names").split(",")]
    for m in STY_LIB_RE.finditer(text):
        found += [(m.start(), STY_LIBRARIES[m.group("cmd")] + n.strip()) for n in m.group("names").split(",")]
    requires: List[str] = []
    for _, name in sorted(found, key=lambda f: f[0]):
        if name and name not in requires:
            requires.append(name)
    return Sty(path.stem, path, hashlib.sha256(data).hexdigest(), provides, requires, text)


def sty_definitions(text: str) -> List[StyDef]:
    r"""Every definition of the comment-stripped text in source order.  The first definition
    of a name gives its place and the last its shape; \DeclareMathOperator and
    \DeclareMathSymbol define a name only where the \newcommand family has not."""
    cmds: Dict[str, StyDef] = {}
    for m in STY_CMD_RE.finditer(text):
        name = m.group("name")
        if "@" in name:
            continue
        d = StyDef(m.start(), "cmd", name, int(m.group("count") or 0), m.group("default"))
        if name in cmds:
            d.pos = cmds[name].pos
        cmds[name] = d
    for rx in (STY_OP_RE, STY_SYM_RE):
        for m in rx.finditer(text):
            name = m.group("name")
            if "@" not in name:
                cmds.setdefault(name, StyDef(m.start(), "cmd", name, math=True))
    envs: Dict[str, StyDef] = {}
    for m in STY_ENV_RE.finditer(text):
        name = m.group("name")
        if "@" in name:
            continue
        count = int(m.group("count") or 0)
        d = StyDef(m.start(), "env", name, count, m.group("default") if count else None)
        d.opens = re.findall(r"\\begin\{([^{}]*)\}", balanced_group(text, m.end()))
        if name in envs:
            d.pos = envs[name].pos
        envs[name] = d
    for m in STY_THM_RE.finditer(text):
        name = m.group("name")
        if "@" not in name:
            envs.setdefault(name, StyDef(m.start(), "env", name))
    return sorted(list(cmds.values()) + list(envs.values()), key=lambda d: d.pos)


def sty_signature(d: StyDef, bracket: bool) -> Snip:
    """One row: the bare shape, or the one with the optional argument's bracket first."""
    mandatory = d.count - (1 if d.optional is not None else 0)
    head = "\\begin{" + d.name + "}" if d.kind == "env" else "\\" + d.name
    tokens: List[Token] = [("t", head)]
    if bracket:
        default = d.optional or ""
        tokens += [("t", "["), ("p", "" if default.startswith("\\") else default.strip()), ("t", "]")]
    for _ in range(mandatory):
        tokens += [("t", "{"), ("p", ""), ("t", "}")]
    shape = render_first_line(tokens)
    sn = Snip(trigger="\\" + d.name, dscr=shape if d.kind == "env" else shape[len(head):], kind=d.kind,
              env=d.name if d.kind == "env" else None, tokens=tokens)
    sn.math, sn.cls = d.math, ("m" if d.math else None)
    return sn


def sty_convert(sty: Sty, keys_before: Set[Tuple[str, str]], lists_before: Set[str]) -> Tuple[List[Snip], List[str]]:
    defs = sty_definitions(sty.text)
    effective = STY_LISTS | lists_before
    changed = True
    while changed:  # a wrapper of a wrapper is a list too, whichever is defined first
        changed = False
        for d in defs:
            if d.kind == "env" and d.name not in effective and any(e in effective for e in d.opens):
                effective.add(d.name)
                changed = True
    snips: List[Snip] = []
    seen: Set[Tuple[str, str]] = set(keys_before)
    for d in defs:
        rows = [sty_signature(d, False)]
        if d.optional is not None:
            rows.append(sty_signature(d, True))
        for sn in rows:
            key = (sn.trigger, sn.dscr)
            if key in seen:
                continue
            seen.add(key)
            toks = list(sn.tokens)
            if sn.kind == "env":
                body = "\t" + ("\\item " if d.name in effective else "")
                toks += [("n",), ("t", body), ("p", None), ("n",), ("t", "\\end{" + d.name + "}")]
            sn.nodes = build_nodes(toks)
            snips.append(sn)
    return snips, sorted(d.name for d in defs if d.kind == "env" and d.name in effective)


def sty_header(sty: Sty, root: Path) -> List[str]:
    try:
        source = f"{sty.path.resolve().relative_to(root).as_posix()} in this repository"
    except ValueError:
        source = f"{sty.path} (outside this repository)"
    out = [
        f"-- Generated by snipgen {GENERATOR_VERSION} from {sty.path.name}; do not edit, regenerate.",
        f"-- source: {source}",
    ]
    if sty.provides:
        out.append(f"-- provides: {sty.provides}")
    out.append(f"-- sty-sha256: {sty.sha256}")
    return out


def sty_closure(start: Path) -> List[Sty]:
    """The input and, recursively, every required package whose .sty sits beside it, in require order."""
    queue = [start.resolve()]
    seen = {queue[0]}
    order: List[Sty] = []
    while queue:
        sty = read_sty(queue.pop(0))
        order.append(sty)
        for name in sty.requires:
            sibling = sty.path.parent / f"{name}.sty"
            if sibling.is_file() and sibling.resolve() not in seen:
                seen.add(sibling.resolve())
                queue.append(sibling.resolve())
    return order


def sty_source_gone(path: Path, root: Path) -> bool:
    """True for a generated file whose header names a source under root that no longer exists;
    a file with another header (a cwl file, a hand file) is never touched."""
    try:
        with path.open(encoding="utf-8") as fh:
            for _ in range(4):
                m = STY_SOURCE_RE.match(fh.readline().rstrip("\n"))
                if m:
                    return not (root / m.group("path")).is_file()
    except OSError:
        pass
    return False


# --coverage: the .sty's commands against the highlight registrations in vimtex.lua,
# moved as it was from sty-lua-snippets.py.  Deliberately unregistered commands; mirrors
# the header comment in lua/plugins/vimtex.lua.  tcite/pcite are citation commands,
# coloured by VimTeX's texCmdRef machinery in after/syntax/tex.lua, not by a custom-cmd
# entry -- see the note there.
KNOWN_UNREGISTERED = {
    "versal",
    "sketchqed",
    "remarkqed",
    "qedsymbol",
    "inf",
    "infer",
    "tcite",
    "pcite",
}

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


def coverage_names(text: str) -> Set[str]:
    r"""The names --coverage checks: the \newcommand family and \DeclareMathOperator, the set
    the old generator's collect_commands had; \DeclareMathSymbol names stay outside it."""
    names = {m.group("name") for m in STY_CMD_RE.finditer(text)} | {m.group("name") for m in STY_OP_RE.finditer(text)}
    return {n for n in names if "@" not in n}


def report_coverage(commands: Set[str], vimtex_path: Path) -> int:
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


# ---------- driving ----------


def clone_info(clone: Path) -> Optional[Tuple[str, str]]:
    try:
        sha = subprocess.run(["git", "-C", str(clone), "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
        date = subprocess.run(["git", "-C", str(clone), "log", "-1", "--format=%cs", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
        return sha, date
    except (OSError, subprocess.CalledProcessError):
        return None


def source_note(path: Path, completion: Optional[Path], info: Optional[Tuple[str, str]], package: str) -> str:
    if completion is not None and info is not None:
        try:
            path.resolve().relative_to(completion.resolve())
            return f"TeXstudio completion/{package}.cwl at commit {info[0]} ({info[1]})"
        except ValueError:
            pass
    return f"{package}.cwl (not from the TeXstudio clone)"


def emit_warnings(cwl: Cwl, quiet: bool) -> None:
    if quiet:
        return
    for _, msg in sorted(cwl.warnings, key=lambda w: w[0]):
        print(f"{cwl.package}.cwl: {msg}", file=sys.stderr)


class Options:
    def __init__(self, cli: List[str]) -> None:
        self.per_package: Dict[str, Set[str]] = {k: set(v) for k, v in OPTIONS.items()}
        for spec in cli:
            pkg, sep, opt = spec.partition(":")
            if not sep or not pkg or not opt:
                raise SystemExit(f"--option wants PKG:OPT, got {spec!r}")
            self.per_package.setdefault(pkg, set()).add(opt)

    def enabled(self, package: str) -> Set[str]:
        return self.per_package.get(package, set())


def generate(path: Path, options: Options, core_keys: Set[Tuple[str, str]], core_lists: Set[str],
             completion: Optional[Path], info: Optional[Tuple[str, str]],
             quiet: bool = False) -> Tuple[str, Set[Tuple[str, str]], Set[str], bool]:
    """Returns (text, this file's dedupe keys, its list environments, empty) for one cwl file."""
    cwl = read_cwl(path, options.enabled(path.name[:-4]))
    snips, lists = convert(cwl, core_keys, core_lists)
    emit_warnings(cwl, quiet)
    keys = {(sn.trigger, sn.dscr) for sn in snips}
    empty = not snips and not cwl.includes
    header = cwl_header(cwl, source_note(path, completion, info, cwl.package))
    return render(header, cwl.package, cwl.includes, snips, lists, cwl.keyvals), keys, set(lists), empty


def core_before(package: str, core_dir: Path, options: Options) -> Tuple[Set[Tuple[str, str]], Set[str]]:
    """Dedupe keys and list environments of the always-loaded lists that precede `package`
    (all three for any other package)."""
    keys: Set[Tuple[str, str]] = set()
    lists: Set[str] = set()
    for name in CORE:
        if name == package:
            break
        p = core_dir / f"{name}.cwl"
        if not p.is_file():
            print(f"{name}.cwl: core file missing in {core_dir}, no deduplication against it", file=sys.stderr)
            continue
        _, k, l, _ = generate(p, options, keys, lists, None, None, quiet=True)
        keys |= k
        lists |= l
    return keys, lists


def write_if_changed(path: Path, text: str) -> bool:
    if path.is_file() and path.read_text(encoding="utf-8") == text:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return True


def run_all(args: argparse.Namespace, options: Options) -> int:
    clone = Path(args.clone).expanduser()
    completion = clone / "completion"
    if not completion.is_dir():
        print(f"no completion/ directory under {clone}", file=sys.stderr)
        return 2
    out_dir = Path(args.out_dir) if args.out_dir else Path(__file__).resolve().parent / "pkg"
    info = clone_info(clone)
    t0 = time.monotonic()
    produced: Dict[str, str] = {}
    counts = {"excluded": 0, "empty": 0}
    core_keys: Set[Tuple[str, str]] = set()
    core_lists: Set[str] = set()
    for name in CORE:
        p = completion / f"{name}.cwl"
        if not p.is_file():
            print(f"{name}.cwl: core file missing from the clone", file=sys.stderr)
            continue
        text, keys, lists, _ = generate(p, options, core_keys, core_lists, completion, info)
        core_keys |= keys
        core_lists |= lists
        produced[name] = text
    for p in sorted(completion.glob("*.cwl")):
        name = p.name[:-4]
        if name in CORE:
            continue
        if name in EXCLUDED:
            counts["excluded"] += 1
            continue
        text, _, _, empty = generate(p, options, core_keys, core_lists, completion, info)
        if empty:
            counts["empty"] += 1
            continue
        produced[name] = text
    existing = {q.name[:-4]: q for q in out_dir.glob("*.lua")} if out_dir.is_dir() else {}
    extra = sorted(set(existing) - set(produced))
    total = sum(len(t.encode("utf-8")) for t in produced.values())
    if args.check:
        stale = [n for n in produced if n in existing and existing[n].read_text(encoding="utf-8") != produced[n]]
        missing = [n for n in produced if n not in existing]
        for label, names in (("stale", stale), ("missing", missing), ("extra", extra)):
            for n in names[:20]:
                print(f"{label}: {out_dir / (n + '.lua')}")
            if len(names) > 20:
                print(f"{label}: ... and {len(names) - 20} more")
        print(f"{out_dir}: {len(produced)} files would be generated, {len(stale)} stale, {len(missing)} missing, {len(extra)} extra")
        return 1 if stale or missing or extra else 0
    changed = 0
    for name, text in produced.items():
        if write_if_changed(out_dir / f"{name}.lua", text):
            changed += 1
    for n in extra:
        existing[n].unlink()
        print(f"removed {existing[n]} (no source)")
    elapsed = time.monotonic() - t0
    print(f"{out_dir}: {len(produced)} files ({changed} written, {len(produced) - changed} unchanged), "
          f"{total / 1e6:.1f} MB; skipped {counts['empty']} with no rows and no includes, "
          f"{counts['excluded']} excluded; {elapsed:.1f} s")
    return 0


def run_cwl(args: argparse.Namespace, options: Options) -> int:
    clone = Path(args.clone).expanduser()
    completion = clone / "completion" if (clone / "completion").is_dir() else None
    core_dir = Path(args.core).expanduser() if args.core else completion
    info = clone_info(clone) if completion is not None else None
    files = [Path(f) for f in args.cwl]
    if args.output and len(files) != 1:
        print("-o takes exactly one --cwl file", file=sys.stderr)
        return 2
    out_dir = Path(args.out_dir) if args.out_dir else Path(__file__).resolve().parent / "pkg"
    drift = False
    for path in files:
        if not path.is_file():
            print(f"{path}: no such file", file=sys.stderr)
            return 2
        package = path.name[:-4] if path.name.endswith(".cwl") else path.name
        core_keys, core_lists = core_before(package, core_dir, options) if core_dir is not None else (set(), set())
        text, _, _, _ = generate(path, options, core_keys, core_lists, completion, info)
        target = Path(args.output) if args.output else out_dir / f"{package}.lua"
        if args.check:
            if not target.is_file():
                print(f"{target}: missing")
                drift = True
            elif target.read_text(encoding="utf-8") != text:
                print(f"{target}: stale")
                drift = True
            else:
                print(f"{target}: up to date")
        else:
            write_if_changed(target, text)
    return 1 if drift else 0


def run_sty(args: argparse.Namespace) -> int:
    root = Path(__file__).resolve().parents[3]  # the configs checkout; headers name sources relative to it
    out_dir = Path(args.out_dir) if args.out_dir else Path(__file__).resolve().parent / "sty"
    produced: Dict[str, str] = {}
    names: Set[str] = set()
    siblings = 0
    for arg in args.sty:
        start = Path(arg)
        if not start.is_file():
            print(f"{start}: no such file", file=sys.stderr)
            return 2
        closure = sty_closure(start)
        siblings += len(closure) - 1
        if args.coverage:
            for sty in closure:
                names |= coverage_names(sty.text)
            continue
        keys: Set[Tuple[str, str]] = set()
        lists: Set[str] = set()
        for sty in closure:
            snips, own = sty_convert(sty, keys, lists)
            keys |= {(sn.trigger, sn.dscr) for sn in snips}
            lists |= set(own)
            produced[sty.package] = render(sty_header(sty, root), sty.package, sty.requires, snips, own, [])
    if args.coverage:
        return report_coverage(names, Path(args.vimtex))
    existing = {q.stem: q for q in out_dir.glob("*.lua")} if out_dir.is_dir() else {}
    extra = sorted(n for n, q in existing.items() if n not in produced and sty_source_gone(q, root))
    if args.check:
        stale = [n for n in produced if n in existing and existing[n].read_text(encoding="utf-8") != produced[n]]
        missing = [n for n in produced if n not in existing]
        for label, found in (("stale", stale), ("missing", missing), ("extra", extra)):
            for n in found:
                print(f"{label}: {out_dir / (n + '.lua')}")
        print(f"{out_dir}: {len(produced)} files would be generated, {len(stale)} stale, {len(missing)} missing, {len(extra)} extra")
        return 1 if stale or missing or extra else 0
    changed = sum(write_if_changed(out_dir / f"{name}.lua", text) for name, text in produced.items())
    for n in extra:
        existing[n].unlink()
        print(f"removed {existing[n]} (no source)")
    print(f"{out_dir}: {len(produced)} files ({changed} written, {len(produced) - changed} unchanged) "
          f"from {len(args.sty)} package(s) and {siblings} sibling unit(s)")
    return 0


def main() -> None:
    ap = argparse.ArgumentParser(description="LuaSnip snippet libraries from TeXstudio's cwl word lists and this repository's .sty packages.")
    ap.add_argument("--all", action="store_true", help="convert the clone's whole completion/")
    ap.add_argument("--cwl", nargs="+", metavar="FILE", help="convert the named cwl files")
    ap.add_argument("--sty", nargs="+", metavar="FILE", help="convert the named .sty packages, each with the required packages beside it")
    ap.add_argument("--clone", default=DEFAULT_CLONE, metavar="DIR", help="the TeXstudio clone (default %(default)s)")
    ap.add_argument("--core", metavar="DIR", help="directory holding tex/latex-document/latex-dev.cwl for the core deduplication (default: the clone's completion/)")
    ap.add_argument("--option", action="append", default=[], metavar="PKG:OPT", help="enable an #ifOption block of a package for this run (repeatable)")
    ap.add_argument("--out-dir", metavar="DIR", help="where <package>.lua files go (default: pkg/ beside this script for cwl files, sty/ for .sty packages)")
    ap.add_argument("-o", "--output", metavar="FILE", help="output file for a single --cwl input")
    ap.add_argument("--check", action="store_true", help="compare with what is on disk, write nothing, exit 1 on drift")
    ap.add_argument("--coverage", action="store_true", help="with --sty: list the package's commands without a highlight registration in vimtex.lua, exit 1 if any; write nothing")
    ap.add_argument("--vimtex", default=str(Path(__file__).resolve().parent.parent / "plugins" / "vimtex.lua"), metavar="FILE", help="vimtex.lua for --coverage (default %(default)s)")
    args = ap.parse_args()
    if sum(map(bool, (args.all, args.cwl, args.sty))) != 1:
        ap.error("give exactly one of --all, --cwl and --sty")
    if args.coverage and not args.sty:
        ap.error("--coverage goes with --sty")
    if args.output and args.sty:
        ap.error("-o is for a single --cwl input; --sty writes one file per package into --out-dir")
    if args.sty:
        sys.exit(run_sty(args))
    options = Options(args.option)
    sys.exit(run_all(args, options) if args.all else run_cwl(args, options))


if __name__ == "__main__":
    main()
