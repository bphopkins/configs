-- The snippet loader.  LuaSnip's ft_func for TeX and bib buffers: it reads VimTeX's package
-- table and document class on every request, closes over the generated files' includes
-- headers, registers any file not yet registered, parses the document's own definitions, and
-- returns the buffer's pseudo-filetypes in the order that decides which of two identical rows
-- wins (the request-time dedupe in completions.lua keeps the first): the hand file, the
-- document, the core three, the class, then the closure.  Also :SnippetsReport and
-- :SnippetsReload.  Stage 3 of the LaTeX completion campaign, 2026-09-13; the contract is
-- PLAN.md section 2 in configs/docs/latex-completion-campaign-2026-09.
--
-- Files are read with dofile by path (names carry dots: tikzlibraryshapes.geometric), first
-- pkg/<name>.lua (TeXstudio's word lists) then sty/<name>.lua (this repository's packages); a
-- name with neither is skipped silently and named by :SnippetsReport.  Registration is once
-- per session per file, under the key pkg-<name>; measured 2026-09-13 on the fixture's closure
-- of 100 files: 0.6 s, of which LuaSnip's snippet construction is 0.57 s (68 us a row), paid
-- at the first request that needs a file.
local M = {}

M.root = vim.fn.stdpath("config") .. "/lua/snippets"
M.CORE = { "tex", "latex-document", "latex-dev" } -- always loaded, in this order (PLAN.md section 1)
M.TEX = { tex = true, latex = true, plaintex = true }

local files = {} -- name -> { path, includes, envs, lists, rows } | false (no file)
local bufs = {} -- bufnr -> { key, fts, loaded, missing, envs, lists }
local docs = {} -- main file path -> { mtime, id, rows, envs, lists }
local hand = {} -- "bibtex" | "local" -> rows registered

M.stats = { dedupe = 0 } -- rows the snippets transform dropped at the last request
M.memo = { key = {}, sink = {} } -- per snippet id, for the transforms in completions.lua
M.prewarm = {} -- bufnr -> { key, done, pending, files, ms }; the idle pre-warm below

local function ls()
  return require("luasnip")
end

local function path_of(name)
  for _, dir in ipairs({ "pkg", "sty" }) do
    local p = M.root .. "/" .. dir .. "/" .. name .. ".lua"
    if vim.uv.fs_stat(p) then
      return p
    end
  end
end

local function read(path)
  local ok, tbl = pcall(dofile, path)
  if not ok then
    return nil, tbl
  end
  if type(tbl) ~= "table" or type(tbl.snippets) ~= "table" then
    return nil, "not a snippet file (no snippets table)"
  end
  return tbl
end

-- The environment names a file's rows define: trigger \env with a description starting
-- \begin{ (TeXstudio's generic \begin{environment} row excluded).
local function env_names(snippets)
  local seen, out = {}, {}
  for _, sn in ipairs(snippets) do
    local d = sn.dscr and sn.dscr[1]
    if d and d:sub(1, 7) == "\\begin{" and sn.trigger ~= "\\begin" then
      local name = sn.trigger:sub(2)
      if not seen[name] then
        seen[name] = true
        out[#out + 1] = name
      end
    end
  end
  return out
end

local function record(tbl, path)
  return {
    path = path,
    includes = tbl.includes or {},
    envs = env_names(tbl.snippets),
    lists = tbl.lists or {},
    rows = #tbl.snippets,
  }
end

-- Register pkg/<name>.lua or sty/<name>.lua once; false when there is no such file.
local function register(name)
  local rec = files[name]
  if rec ~= nil then
    return rec
  end
  local p = path_of(name)
  if not p then
    files[name] = false
    return false
  end
  local tbl, err = read(p)
  if not tbl then
    vim.notify(("snippets: %s: %s"):format(p, err), vim.log.levels.WARN)
    files[name] = false
    return false
  end
  ls().add_snippets("pkg-" .. name, tbl.snippets, { key = "pkg-" .. name })
  rec = record(tbl, p)
  files[name] = rec
  return rec
end

local function tex_state(bufnr)
  local st = bufnr and vim.b[bufnr].vimtex or vim.b.vimtex
  if type(st) ~= "table" or type(st.packages) ~= "table" then
    return nil
  end
  return st
end

local function package_key(st)
  local names = vim.tbl_keys(st.packages)
  table.sort(names)
  return (st.documentclass or "") .. "|" .. table.concat(names, ","), names
end

-- The document's own definitions, re-read whenever the main file's mtime changes (one stat
-- per request).  The whole main file is read, not only its preamble: the dissertation defines
-- three of its six commands after \begin{document} (decided 2026-09-13).
local function document(st, lists, bufnr)
  local main = st.tex
  if type(main) ~= "string" or main == "" then
    return nil
  end
  local stat = vim.uv.fs_stat(main)
  if not stat then
    return nil
  end
  local mtime = stat.mtime.sec .. "." .. stat.mtime.nsec .. ":" .. stat.size
  local rec = docs[main]
  if rec and rec.mtime == mtime then
    return rec
  end
  local id = vim.b[bufnr or 0].vimtex_id or vim.fn.sha256(main):sub(1, 8)
  local parsed = require("snippets.helpers").docsnippets(vim.fn.readfile(main), lists)
  ls().add_snippets("doc-" .. id, parsed.snippets, { key = "doc-" .. id })
  rec = {
    mtime = mtime,
    id = id,
    rows = #parsed.snippets,
    envs = parsed.envs,
    lists = parsed.lists,
    main = main,
  }
  docs[main] = rec
  return rec
end

-- The roots of a buffer's closure: the core three, the class, the package table.
local function roots_of(st, names)
  local roots = {}
  for _, c in ipairs(M.CORE) do
    roots[#roots + 1] = c
  end
  if type(st.documentclass) == "string" and st.documentclass ~= "" then
    roots[#roots + 1] = "class-" .. st.documentclass
  end
  for _, n in ipairs(names) do
    roots[#roots + 1] = n
  end
  return roots
end

-- The buffer's closure: breadth-first over the includes headers from the core three, the class
-- and the package table, registering on the way.
local function build(bufnr, st, key, names)
  local roots = roots_of(st, names)
  local seen, loaded, missing, envs, envseen, lists = {}, {}, {}, {}, {}, {}
  local queue, head = roots, 1
  while head <= #queue do
    local name = queue[head]
    head = head + 1
    if not seen[name] then
      seen[name] = true
      local rec = register(name)
      if rec then
        loaded[#loaded + 1] = name
        for _, e in ipairs(rec.envs) do
          if not envseen[e] then
            envseen[e] = true
            envs[#envs + 1] = e
          end
        end
        for _, l in ipairs(rec.lists) do
          lists[l] = true
        end
        for _, inc in ipairs(rec.includes) do
          queue[#queue + 1] = inc
        end
      else
        missing[#missing + 1] = name
      end
    end
  end
  local fts = {
    "tex",
    "hand-local",
    "doc-" .. (vim.b[bufnr].vimtex_id or vim.fn.sha256(st.tex or ""):sub(1, 8)),
  }
  for _, n in ipairs(loaded) do
    fts[#fts + 1] = "pkg-" .. n
  end
  local b = { key = key, fts = fts, loaded = loaded, missing = missing, envs = envs, lists = lists }
  bufs[bufnr] = b
  return b
end

-- The pseudo-filetypes of a TeX buffer, as LuaSnip asks for them.  Always a fresh table:
-- LuaSnip appends "all" to what it gets.
function M.filetypes(bufnr)
  local st = tex_state()
  if not st then
    -- VimTeX has not initialised this buffer (or skipped it): the hand file and the core three
    local fts = { "tex", "hand-local" }
    for _, c in ipairs(M.CORE) do
      if register(c) then
        fts[#fts + 1] = "pkg-" .. c
      end
    end
    return fts
  end
  local key, names = package_key(st)
  local b = bufs[bufnr]
  if not b or b.key ~= key then
    b = build(bufnr, st, key, names)
  end
  document(st, b.lists, bufnr)
  return vim.list_extend({}, b.fts)
end

-- The idle pre-warm (stage 4, 2026-09-13).  The first request that needed a buffer's closure paid
-- its registration, 660 to 750 ms measured on the fixture and on the chapter, once per session
-- per document.  After VimTeX has initialised a TeX buffer the closure is registered here instead,
-- one file per timer tick, so the work is spread over a couple of seconds of idle time and the
-- first request finds everything in place; a request that arrives earlier registers what is left
-- on the spot (build, above) and the remaining ticks find their files memoised.  Memory is the
-- same either way, paid at open rather than at the first request.
local TICK_MS = 10

local function prewarm_step(bufnr, st, queue, seen, t0)
  local p = M.prewarm[bufnr]
  if not p or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if queue.head > #queue then
    local key, names = package_key(st)
    local b = bufs[bufnr]
    if not b or b.key ~= key then
      b = build(bufnr, st, key, names)
    end
    document(st, b.lists, bufnr)
    p.done, p.pending, p.files, p.ms = true, 0, #b.loaded, (vim.uv.hrtime() - t0) / 1e6
    return
  end
  local name = queue[queue.head]
  queue.head = queue.head + 1
  if not seen[name] then
    seen[name] = true
    local rec = register(name)
    if rec then
      for _, inc in ipairs(rec.includes) do
        queue[#queue + 1] = inc
      end
    end
  end
  p.pending = #queue - queue.head + 1
  vim.defer_fn(function()
    prewarm_step(bufnr, st, queue, seen, t0)
  end, TICK_MS)
end

function M.prewarm_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) or not M.TEX[vim.bo[bufnr].filetype] then
    return
  end
  local st = tex_state(bufnr)
  if not st then
    return
  end
  local key, names = package_key(st)
  local p = M.prewarm[bufnr]
  if p and p.key == key then
    return -- already done, or in progress, for this package table
  end
  local queue = { head = 1 }
  for _, r in ipairs(roots_of(st, names)) do
    queue[#queue + 1] = r
  end
  M.prewarm[bufnr] = { key = key, done = false, pending = #queue, files = 0, ms = 0 }
  prewarm_step(bufnr, st, queue, {}, vim.uv.hrtime())
end

function M.ft_func()
  local ft = vim.bo.filetype
  if M.TEX[ft] then
    return M.filetypes(vim.api.nvim_get_current_buf())
  elseif ft == "bib" or ft == "bibtex" then
    return { ft, "hand-bibtex" }
  end
  return vim.split(ft, ".", { plain = true })
end

-- For the \begin{ transform: every environment name the buffer's files and its document
-- define, in order, and the set of those whose body is \item.
function M.envs(bufnr)
  local b = bufs[bufnr]
  local st = tex_state()
  local doc = st and docs[st.tex] or nil
  local names, lists, seen = {}, {}, {}
  local function take(list)
    for _, e in ipairs(list or {}) do
      if not seen[e] then
        seen[e] = true
        names[#names + 1] = e
      end
    end
  end
  if doc then -- the document first, as in the filetype order
    take(doc.envs)
    for _, l in ipairs(doc.lists) do
      lists[l] = true
    end
  end
  if b then
    take(b.envs)
    for l in pairs(b.lists) do
      lists[l] = true
    end
  end
  return { names = names, lists = lists }
end

local function load_hand()
  for _, name in ipairs({ "bibtex", "local" }) do
    local p = M.root .. "/hand/" .. name .. ".lua"
    if vim.uv.fs_stat(p) then
      local tbl, err = read(p)
      if tbl then
        ls().add_snippets("hand-" .. name, tbl.snippets, { key = "hand-" .. name })
        hand[name] = #tbl.snippets
      else
        vim.notify(("snippets: %s: %s"):format(p, err), vim.log.levels.WARN)
      end
    end
  end
end

function M.report()
  local out = {}
  local st = tex_state()
  if not st then
    out[#out + 1] =
      "snippets: no VimTeX state in this buffer; TeX buffers get the hand file and the core three"
  else
    local bufnr = vim.api.nvim_get_current_buf()
    M.filetypes(bufnr)
    local b = bufs[bufnr]
    local doc = docs[st.tex]
    local _, names = package_key(st)
    out[#out + 1] = ("main: %s  class: %s  packages in VimTeX's table: %d"):format(
      st.tex,
      st.documentclass or "?",
      #names
    )
    local rows = 0
    for _, n in ipairs(b.loaded) do
      rows = rows + files[n].rows
    end
    out[#out + 1] = ("loaded: %d files, %d rows (the core three first, then the class, then the closure)"):format(
      #b.loaded,
      rows
    )
    out[#out + 1] = "  " .. table.concat(b.loaded, " ")
    local p = M.prewarm[bufnr]
    out[#out + 1] = p == nil and "pre-warm: not run for this buffer"
      or p.done and ("pre-warm: done, %d files in %.0f ms of idle ticks"):format(p.files, p.ms)
      or ("pre-warm: in progress, %d names pending"):format(p.pending)
    local miss = {}
    for _, n in ipairs(b.missing) do
      miss[#miss + 1] = n:match("^class%-") and (n .. " (no list for this class)") or n
    end
    out[#out + 1] = ("missing: %d names with no generated file"):format(#b.missing)
    if #miss > 0 then
      out[#out + 1] = "  " .. table.concat(miss, " ")
    end
    if doc then
      out[#out + 1] = ("document: %d rows from the main file's own definitions (%d environments), re-read on mtime change"):format(
        doc.rows,
        #doc.envs
      )
    end
    local e = M.envs(bufnr)
    local nl = 0
    for _ in pairs(e.lists) do
      nl = nl + 1
    end
    out[#out + 1] = ("environments for \\begin{: %d names from the loaded files and the document, %d of them lists"):format(
      #e.names,
      nl
    )
    out[#out + 1] = ("dedupe: %d repeated (label, description) rows dropped at the last request with more than one row"):format(
      M.stats.dedupe
    )
  end
  out[#out + 1] = ("hand files: bibtex %d rows, local %d rows"):format(
    hand.bibtex or 0,
    hand["local"] or 0
  )
  print(table.concat(out, "\n"))
end

-- Re-read every registered file and the hand files under their keys, forget the document
-- parses and the buffer closures, and drop the invalidated rows LuaSnip keeps listing until
-- clean_invalidated runs (spike, 2026-09-13).
function M.reload()
  local n = 0
  for name, rec in pairs(files) do
    if rec then
      local tbl, err = read(rec.path)
      if tbl then
        ls().add_snippets("pkg-" .. name, tbl.snippets, { key = "pkg-" .. name })
        files[name] = record(tbl, rec.path)
        n = n + 1
      else
        vim.notify(("snippets: %s: %s"):format(rec.path, err), vim.log.levels.WARN)
      end
    else
      files[name] = nil -- a file missing before may exist now
    end
  end
  load_hand()
  docs, bufs, M.prewarm = {}, {}, {}
  M.memo = { key = {}, sink = {} }
  ls().clean_invalidated({ inv_limit = 0 })
  vim.notify(("snippets: reloaded %d files and the hand files"):format(n))
end

function M.setup()
  load_hand()
  vim.api.nvim_create_autocmd("User", {
    pattern = "VimtexEventInitPost",
    group = vim.api.nvim_create_augroup("SnippetsPrewarm", { clear = true }),
    desc = "Register the buffer's snippet closure in idle time",
    callback = function(ev)
      local bufnr = ev.buf
      vim.defer_fn(function()
        M.prewarm_buffer(bufnr)
      end, 100)
    end,
  })
  vim.api.nvim_create_user_command(
    "SnippetsReport",
    M.report,
    { desc = "What the snippet loader holds for this buffer" }
  )
  vim.api.nvim_create_user_command(
    "SnippetsReload",
    M.reload,
    { desc = "Re-read every registered snippet file" }
  )
end

return M
