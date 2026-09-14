-- Helpers the generated snippet files bind to.  lua/snippets/pkg/*.lua and sty/*.lua (never
-- hand-edited; snipgen.py regenerates them) call h.mathwrap and h.in_env, and the loader's
-- parser for a document's own definitions lives here too.  Stage 3 of the LaTeX completion
-- campaign, 2026-09-13; the contract is PLAN.md section 2 in
-- configs/docs/latex-completion-campaign-2026-09.
local M = {}

local function in_math()
  local ok, r = pcall(vim.fn["vimtex#syntax#in_mathzone"])
  return ok and r == 1
end

-- A math-only row (cwl "#m") expanded in prose is wrapped in $…$; inside math it expands bare.
-- Function nodes evaluate when the snippet expands (and again for the on-highlight docstring),
-- so one snippet serves both places.  Verified on the harness 2026-09-13 (PLAN.md section 9).
function M.mathwrap(nodes)
  local f = require("luasnip").function_node
  local wrap = function()
    return in_math() and "" or "$"
  end
  local out = { f(wrap) }
  for _, n in ipairs(nodes) do
    out[#out + 1] = n
  end
  out[#out + 1] = f(wrap)
  return out
end

-- The innermost environment at the cursor, looked up once per completion request: blink calls
-- every row's show_condition in one pass with buffer and cursor unchanged, so the memo is keyed
-- on buffer, changedtick and cursor.  vimtex#env#get_inner() is a search, hence the memo.
local env_memo = { key = "", name = "" }
local function innermost_env()
  local buf = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local key = buf .. ":" .. vim.api.nvim_buf_get_changedtick(buf) .. ":" .. pos[1] .. ":" .. pos[2]
  if env_memo.key ~= key then
    local ok, env = pcall(vim.fn["vimtex#env#get_inner"])
    env_memo.key = key
    env_memo.name = (ok and type(env) == "table" and env.name) or ""
  end
  return env_memo.name
end

-- show_condition for a row restricted to environments (a cwl "/env1,env2" classification).
function M.in_env(names)
  local set = {}
  for _, n in ipairs(names) do
    set[n] = true
  end
  return function()
    return set[innermost_env()] == true
  end
end

----------------------------------------------------------------------------
-- Document-local definitions (TeXstudio's "user commands").  The loader reads the main file
-- whenever its mtime changes and registers what this returns under the document's own
-- pseudo-filetype.  The rules are those of snipgen.py --sty (PLAN.md section 2, ".sty
-- definition to snippet"), ported so that no process is spawned: the braced forms
-- \newcommand, \renewcommand, \providecommand, \DeclareMathOperator, \DeclareMathSymbol,
-- \newenvironment, \renewenvironment and \newtheorem, read after % comments are stripped; a
-- name with @ skipped; the first definition of a name gives its place and the last its shape;
-- the two \Declare… forms define a name only where the \newcommand family has not, and are
-- math-wrapped; an optional argument gives two rows, the bare one first; an environment gets a
-- body line, with \item when its begin code opens a list, and its \end.
----------------------------------------------------------------------------

local LISTS = { itemize = true, enumerate = true, description = true } -- TeXstudio's three

-- '%' to end of line removed unless escaped, so a commented-out definition is not read.
local function strip_comments(lines)
  local out = {}
  for k, line in ipairs(lines) do
    local cut, init = nil, 1
    while true do
      local p = line:find("%", init, true)
      if not p then
        break
      end
      if p == 1 or line:sub(p - 1, p - 1) ~= "\\" then
        cut = p
        break
      end
      init = p + 1
    end
    out[k] = cut and line:sub(1, cut - 1) or line
  end
  return table.concat(out, "\n")
end

-- The content of the brace group at pos (whitespace skipped), or "" when there is none.
local function balanced_group(text, pos)
  local n = #text
  while pos <= n and text:sub(pos, pos):match("%s") do
    pos = pos + 1
  end
  if pos > n or text:sub(pos, pos) ~= "{" then
    return ""
  end
  local depth, k = 0, pos
  while k <= n do
    local ch = text:sub(k, k)
    if ch == "\\" then
      k = k + 2
    else
      if ch == "{" then
        depth = depth + 1
      elseif ch == "}" then
        depth = depth - 1
        if depth == 0 then
          return text:sub(pos + 1, k - 1)
        end
      end
      k = k + 1
    end
  end
  return text:sub(pos + 1)
end

-- After position e: an optional [count], then an optional [default] (empty allowed: an empty
-- default is still an optional argument).  Returns count, default (nil when absent), next pos.
local function args_after(text, e)
  local count, default
  local c, e2 = text:match("^%s*%[(%d+)%]()", e)
  if c then
    count, e = tonumber(c), e2
  end
  local d, e3 = text:match("^%s*%[([^%]]*)%]()", e)
  if d then
    default, e = d, e3
  end
  return count or 0, default, e
end

local function definitions(text)
  local cmds, envs, found = {}, {}, {}
  local function scan(word, kind)
    local name_pat = kind == "cmd" and "{\\([A-Za-z@]+)}" or "{([A-Za-z@]+)}"
    for pos, name, e in text:gmatch("()\\" .. word .. "%s*%*?%s*" .. name_pat .. "()") do
      found[#found + 1] = { pos = pos, kind = kind, name = name, e = e }
    end
  end
  for _, w in ipairs({ "newcommand", "renewcommand", "providecommand" }) do
    scan(w, "cmd")
  end
  for _, w in ipairs({ "newenvironment", "renewenvironment" }) do
    scan(w, "env")
  end
  table.sort(found, function(a, b)
    return a.pos < b.pos
  end)
  for _, m in ipairs(found) do
    if not m.name:find("@", 1, true) then
      local count, default, e = args_after(text, m.e)
      if m.kind == "cmd" then
        local d = { pos = m.pos, kind = "cmd", name = m.name, count = count, optional = default }
        if cmds[m.name] then
          d.pos = cmds[m.name].pos
        end
        cmds[m.name] = d
      else
        local d = {
          pos = m.pos,
          kind = "env",
          name = m.name,
          count = count,
          optional = count > 0 and default or nil,
          opens = {},
        }
        for env in balanced_group(text, e):gmatch("\\begin{([^{}]*)}") do
          d.opens[#d.opens + 1] = env
        end
        if envs[m.name] then
          d.pos = envs[m.name].pos
        end
        envs[m.name] = d
      end
    end
  end
  for _, pat in ipairs({
    "()\\DeclareMathOperator%s*%*?%s*{\\([A-Za-z@]+)}",
    "()\\DeclareMathSymbol%s*{\\([A-Za-z@]+)}",
  }) do
    for pos, name in text:gmatch(pat) do
      if not name:find("@", 1, true) and not cmds[name] then
        cmds[name] = { pos = pos, kind = "cmd", name = name, count = 0, math = true }
      end
    end
  end
  for pos, name in text:gmatch("()\\newtheorem%s*%*?%s*{([A-Za-z@]+)}") do
    if not name:find("@", 1, true) and not envs[name] then
      envs[name] = { pos = pos, kind = "env", name = name, count = 0, opens = {} }
    end
  end
  local defs = {}
  for _, d in pairs(cmds) do
    defs[#defs + 1] = d
  end
  for _, d in pairs(envs) do
    defs[#defs + 1] = d
  end
  table.sort(defs, function(a, b)
    return a.pos < b.pos
  end)
  return defs
end

-- Mirrors snipgen's build_nodes: text runs merge into one node, "n" starts a line, "p" is a
-- placeholder (an empty or absent text gives a bare insert node).
local function nodes_of(tokens)
  local ls = require("luasnip")
  local t, i = ls.text_node, ls.insert_node
  local nodes, lines, n = {}, { "" }, 0
  local function flush()
    if not (#lines == 1 and lines[1] == "") then
      nodes[#nodes + 1] = t(lines)
    end
    lines = { "" }
  end
  for _, tok in ipairs(tokens) do
    if tok[1] == "t" then
      lines[#lines] = lines[#lines] .. tok[2]
    elseif tok[1] == "n" then
      lines[#lines + 1] = ""
    elseif tok[1] == "p" then
      flush()
      n = n + 1
      nodes[#nodes + 1] = (tok[2] and tok[2] ~= "") and i(n, tok[2]) or i(n)
    end
  end
  flush()
  return nodes
end

-- One row: the bare shape, or the one with the optional argument's bracket first.
local function signature(d, bracket)
  local mandatory = d.count - (d.optional ~= nil and 1 or 0)
  local head = d.kind == "env" and ("\\begin{" .. d.name .. "}") or ("\\" .. d.name)
  local tokens, shape = { { "t", head } }, head
  if bracket then
    local default = d.optional or ""
    local ph = default:sub(1, 1) == "\\" and "" or vim.trim(default)
    tokens[#tokens + 1] = { "t", "[" }
    tokens[#tokens + 1] = { "p", ph }
    tokens[#tokens + 1] = { "t", "]" }
    shape = shape .. "[" .. ph .. "]"
  end
  for _ = 1, mandatory do
    tokens[#tokens + 1] = { "t", "{" }
    tokens[#tokens + 1] = { "p", "" }
    tokens[#tokens + 1] = { "t", "}" }
    shape = shape .. "{}"
  end
  return tokens, d.kind == "env" and shape or shape:sub(#head + 1)
end

-- docsnippets(lines, lists_before): the snippets of a document's own definitions, plus the
-- names of its environments and of those among them that are lists.  lists_before is the set
-- of list environments already known for the buffer (from the loaded package files).
function M.docsnippets(lines, lists_before)
  local ls = require("luasnip")
  local defs = definitions(strip_comments(lines))
  local effective = {}
  for k in pairs(LISTS) do
    effective[k] = true
  end
  for k in pairs(lists_before or {}) do
    effective[k] = true
  end
  local changed = true
  while changed do -- a wrapper of a wrapper is a list too, whichever is defined first
    changed = false
    for _, d in ipairs(defs) do
      if d.kind == "env" and not effective[d.name] then
        for _, e in ipairs(d.opens) do
          if effective[e] then
            effective[d.name] = true
            changed = true
            break
          end
        end
      end
    end
  end
  local snippets, seen, envs, lists = {}, {}, {}, {}
  for _, d in ipairs(defs) do
    local variants = { false }
    if d.optional ~= nil then
      variants[2] = true
    end
    for _, bracket in ipairs(variants) do
      local tokens, dscr = signature(d, bracket)
      local key = d.name .. "\1" .. dscr
      if not seen[key] then
        seen[key] = true
        if d.kind == "env" then
          tokens[#tokens + 1] = { "n" }
          tokens[#tokens + 1] = { "t", "\t" .. (effective[d.name] and "\\item " or "") }
          tokens[#tokens + 1] = { "p" }
          tokens[#tokens + 1] = { "n" }
          tokens[#tokens + 1] = { "t", "\\end{" .. d.name .. "}" }
        end
        local nodes = nodes_of(tokens)
        if d.math then
          nodes = M.mathwrap(nodes)
        end
        local sn = ls.snippet({ trig = "\\" .. d.name, dscr = dscr }, nodes)
        sn.cls = d.math and "m" or nil
        snippets[#snippets + 1] = sn
      end
    end
    if d.kind == "env" then
      envs[#envs + 1] = d.name
      if effective[d.name] then
        lists[#lists + 1] = d.name
      end
    end
  end
  return { snippets = snippets, envs = envs, lists = lists }
end

return M
