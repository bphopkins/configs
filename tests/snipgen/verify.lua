-- tests/snipgen/verify.lua: load one generated snippet file under stub LuaSnip and
-- helpers modules and check the shape the loader (stage 3 of the campaign) relies on.
--   nvim --clean -l verify.lua FILE [fixture|sty|styhub]
-- Exit 0 when every check passes; the failing checks are printed otherwise.  With
-- "fixture" as the second argument the cwl fixture's expectations run too; "sty" and
-- "styhub" run the .sty fixture's, for the unit and the hub golden respectively.
local path, profile = arg[1], arg[2]
if not path then
  io.stderr:write("usage: nvim --clean -l verify.lua FILE [fixture|sty|styhub]\n")
  os.exit(2)
end

package.preload["luasnip"] = function()
  return {
    snippet = function(ctx, nodes)
      return { ctx = ctx, nodes = nodes }
    end,
    text_node = function(x)
      return { t = x }
    end,
    insert_node = function(n, d)
      return { i = n, d = d }
    end,
  }
end
package.preload["luasnip.extras"] = function()
  return {
    rep = function(n)
      return { rep = n }
    end,
  }
end
package.preload["snippets.helpers"] = function()
  return {
    mathwrap = function(nodes)
      return { wrapped = nodes }
    end,
    in_env = function(envs)
      return { envs = envs }
    end,
  }
end

local chunk, err = loadfile(path)
if not chunk then
  io.stderr:write("load failed: " .. tostring(err) .. "\n")
  os.exit(1)
end
local ok, lib = pcall(chunk)
if not ok then
  io.stderr:write("run failed: " .. tostring(lib) .. "\n")
  os.exit(1)
end

local fails = 0
local function check(name, cond)
  if not cond then
    fails = fails + 1
    print("FAIL " .. name)
  end
end
local function find(trig)
  local hits = {}
  for _, sn in ipairs(lib.snippets) do
    if sn.ctx.trig == trig then
      hits[#hits + 1] = sn
    end
  end
  return hits
end

-- shape every generated file must have
check("package is a string", type(lib.package) == "string")
check("includes is a table", type(lib.includes) == "table")
check("lists is a table", type(lib.lists) == "table")
check("snippets is a table", type(lib.snippets) == "table")
check("keyvals is a table", type(lib.keyvals) == "table")
for k, sn in ipairs(lib.snippets) do
  check("snippet " .. k .. " has a string trigger", type(sn.ctx.trig) == "string")
  check("snippet " .. k .. " has a string dscr", type(sn.ctx.dscr) == "string")
  check(
    "snippet " .. k .. " has nodes",
    type(sn.nodes) == "table" and (sn.nodes.wrapped ~= nil or #sn.nodes > 0)
  )
  check("snippet " .. k .. " cls is nil or a string", sn.cls == nil or type(sn.cls) == "string")
end
for k, kv in ipairs(lib.keyvals) do
  check(
    "keyvals " .. k .. " has targets and lines",
    type(kv.targets) == "string" and type(kv.lines) == "table"
  )
end

if profile == "fixture" then
  check("package name", lib.package == "fixture")
  check(
    "two includes, in file order",
    #lib.includes == 2 and lib.includes[1] == "alpha" and lib.includes[2] == "beta"
  )
  check(
    "lists sorted, core list environment included",
    #lib.lists == 3
      and lib.lists[1] == "corelist"
      and lib.lists[2] == "enumerate"
      and lib.lists[3] == "itemize"
  )
  check("54 snippets", #lib.snippets == 54)
  check("two keyvals blocks", #lib.keyvals == 2)
  check(
    "keyvals targets kept raw",
    lib.keyvals[1].targets == "\\hypersetup,\\usepackage/hyperref#c"
  )
  check(
    "keyvals lines kept raw, comments and blanks dropped",
    #lib.keyvals[1].lines == 3 and lib.keyvals[1].lines[2] == "allbordercolors=#%color"
  )
  check("unterminated block still captured", lib.keyvals[2].lines[1] == "last=key")
  local binom = find("\\binom")
  check("one \\binom row", #binom == 1)
  check("\\binom is math-wrapped", binom[1] and binom[1].nodes.wrapped ~= nil)
  check("\\binom carries cls m", binom[1] and binom[1].cls == "m")
  local vec = find("\\vector")[1]
  check("\\vector sinks to priority 900", vec and vec.ctx.priority == 900)
  check(
    "\\vector hidden outside picture",
    vec and vec.ctx.show_condition and vec.ctx.show_condition.envs[1] == "picture"
  )
  check("\\vector cls is the raw classification", vec and vec.cls == "*/picture")
  local generic = find("\\begin")[1]
  local has_rep = false
  if generic then
    for _, n in ipairs(generic.nodes) do
      if n.rep == 1 then
        has_rep = true
      end
    end
  end
  check("generic environment template mirrors its name", has_rep)
  check("\\itemize has two signatures", #find("\\itemize") == 2)
  local core = find("\\corelist")[1]
  check(
    "\\corelist gets the \\item body from the core lists",
    core ~= nil and core.nodes[3] ~= nil and core.nodes[3].t[2] == "\t\\item "
  )
  check("\\Hat (hidden) absent", #find("\\Hat") == 0)
  check("\\alpha (core) absent", #find("\\alpha") == 0)
  check("\\thispagestyle (core) absent", #find("\\thispagestyle") == 0)
  check("\\disabledonly (option block) absent", #find("\\disabledonly") == 0)
  check("\\enabledonly (enabled option block) present", #find("\\enabledonly") == 1)
  check("typical row wins over its unusual twin", #binom == 1 and binom[1].ctx.priority == nil)
  local dag = find("\\dag")
  check(
    "typical row wins over an earlier unusual twin, in its place",
    #dag == 1 and dag[1].ctx.priority == nil and dag[1].cls == nil and lib.snippets[6] == dag[1]
  )
  check(
    "subscript underscore ends the name",
    #find("\\sum") == 1 and find("\\sum")[1].ctx.dscr == "_{min}^{max}"
  )
  check("expl3 variable keeps its underscores", #find("\\g_fixture_tl") == 1)
end

if profile == "sty" then
  -- the .sty front end's unit golden (tests/snipgen/fixture/sty/fixhub-unit.sty)
  check("package name", lib.package == "fixhub-unit")
  check("one include", #lib.includes == 1 and lib.includes[1] == "epsilon")
  check(
    "lists: the two wrappers sorted, the own-item environment absent",
    #lib.lists == 2 and lib.lists[1] == "wrapslist" and lib.lists[2] == "wrapswraps"
  )
  check("29 snippets", #lib.snippets == 29)
  check("no keyvals", #lib.keyvals == 0)
  check(
    "rows keep source order: plainenv sits third, among the commands",
    lib.snippets[3] and lib.snippets[3].ctx.trig == "\\plainenv"
  )
  local optdef = find("\\optdef")
  check(
    "\\optdef has two signatures, bare first",
    #optdef == 2 and optdef[1].ctx.dscr == "{}" and optdef[2].ctx.dscr == "[blue]{}"
  )
  check(
    "\\optdef bracket row carries the text default as placeholder text",
    #optdef == 2 and optdef[2].nodes[2].i == 1 and optdef[2].nodes[2].d == "blue"
  )
  local optempty = find("\\optempty")
  check(
    "an empty default is still an optional argument, bare bracket",
    #optempty == 2 and optempty[2].ctx.dscr == "[]{}" and optempty[2].nodes[2].d == nil
  )
  local optmacro = find("\\optmacro")
  check(
    "a macro default gives a bare bracket",
    #optmacro == 2 and optmacro[1].ctx.dscr == "" and optmacro[2].ctx.dscr == "[]"
  )
  local dup = find("\\dup")
  check("\\dup: one row, the last definition's shape", #dup == 1 and dup[1].ctx.dscr == "{}")
  check("\\shared dropped (the hub defined it first)", #find("\\shared") == 0)
  for _, absent in ipairs({ "\\ghost", "\\dead", "\\unit@helper", "\\fl@sym", "\\nomatch" }) do
    check(absent .. " absent", #find(absent) == 0)
  end
  for _, m in ipairs({ "\\op", "\\opstar", "\\sym" }) do
    local r = find(m)[1]
    check(m .. " math-wrapped with cls m", r ~= nil and r.nodes.wrapped ~= nil and r.cls == "m")
  end
  local plain = find("\\plain")[1]
  check(
    "\\plain carries no cls and no priority",
    plain ~= nil and plain.cls == nil and plain.ctx.priority == nil
  )
  local textdef = find("\\textdef")
  check(
    "textdef: bare and [Sketch] rows",
    #textdef == 2
      and textdef[2].ctx.dscr == "\\begin{textdef}[Sketch]"
      and textdef[2].nodes[2].d == "Sketch"
  )
  local argenv = find("\\argenv")[1]
  check(
    "argenv: two mandatory groups, then the body",
    argenv ~= nil and argenv.ctx.dscr == "\\begin{argenv}{}{}" and argenv.nodes[6].i == 3
  )
  local ww = find("\\wrapswraps")[1]
  check(
    "wrapswraps gets \\item through the wrapslist defined after it",
    ww ~= nil and ww.nodes[1].t[2] == "\t\\item "
  )
  local own = find("\\ownitem")[1]
  check(
    "ownitem writes its own \\item, so the body is bare",
    own ~= nil and own.nodes[1].t[2] == "\t"
  )
  check("thmstar from \\newtheorem*", #find("\\thmstar") == 1)
end

if profile == "styhub" then
  -- the hub golden: includes in source order, deduplicated, tikz libraries mapped
  check("package name", lib.package == "fixhub")
  local want = {
    "fixhub-unit",
    "fontenc",
    "multiline",
    "alpha",
    "beta",
    "gamma",
    "tikzlibraryarrows",
    "tikzlibraryshapes",
    "delta",
  }
  local same = #lib.includes == #want
  for k, v in ipairs(want) do
    if lib.includes[k] ~= v then
      same = false
    end
  end
  check("nine includes in source order", same)
  check("no lists", #lib.lists == 0)
  check(
    "one snippet, the hub's own row",
    #lib.snippets == 1 and lib.snippets[1].ctx.trig == "\\shared"
  )
  check("\\fl@internal absent", #find("\\fl@internal") == 0)
end

if fails > 0 then
  print(fails .. " check(s) failed in " .. path)
  os.exit(1)
end
print(
  "verify.lua: " .. #lib.snippets .. " snippets, " .. #lib.keyvals .. " keyvals blocks, shape ok"
)
