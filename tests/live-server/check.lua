-- Regression checks for the live-server root wrapper. Run via run.sh, which
-- provides LS_SANDBOX (fixture/state dir), LS_SPEC (the plugin spec under
-- test) and LS_PLUGIN (the live-server.nvim checkout). Two sections:
--
--   W* — the wrapper's own contract (what our commands must do)
--   U* — upstream-behavior canaries: plugin facts the wrapper's design rests
--        on. A U failure after a plugin update means the ground moved, not
--        necessarily that anything is broken — re-read the wrapper's header
--        comment and TODO.md item 9 before "fixing" either.
--
-- Everything is hermetic: fixture repos in the sandbox, loopback only, a
-- free port picked at runtime, browser=false, no real repo touched.
--
-- Two harness rules, learned by mutation-testing (see README.md): every
-- wrapper invocation goes through cmd() (pcall), so a spec that throws
-- mid-run still yields the final `passed:` line; and each section force-stops
-- whatever it may have leaked, so one failure cannot cascade into unrelated
-- checks and smear a mutant's fingerprint.

local SANDBOX = assert(os.getenv("LS_SANDBOX"), "LS_SANDBOX not set (run via run.sh)")
local SPEC = assert(os.getenv("LS_SPEC"), "LS_SPEC not set (run via run.sh)")
local PLUGIN = assert(os.getenv("LS_PLUGIN"), "LS_PLUGIN not set (run via run.sh)")

local npass, nfail = 0, 0
local function check(name, cond, detail)
  if cond then
    npass = npass + 1
    io.write("PASS ", name, "\n")
  else
    nfail = nfail + 1
    io.write("FAIL ", name, detail and (" -- " .. tostring(detail)) or "", "\n")
  end
end

-- Capture notifications instead of displaying them.
local notes = {}
vim.notify = function(msg)
  notes[#notes + 1] = tostring(msg)
end
local function clear_notes()
  notes = {}
end
local function all_notes()
  return table.concat(notes, " | ")
end

-- pcall'd vim.cmd, so a broken spec under test cannot abort the run.
local function cmd(s)
  local ok, err = pcall(vim.cmd, s)
  return ok, err
end

-- Raw HTTP GET; the server closes after responding, so read to EOF.
local function http_get(port, path)
  local done, result = false, nil
  local chunks = {}
  local sock = vim.uv.new_tcp()
  sock:connect("127.0.0.1", port, function(err)
    if err then
      result = { err = err }
      done = true
      if not sock:is_closing() then
        sock:close()
      end
      return
    end
    sock:read_start(function(_, data)
      if data then
        chunks[#chunks + 1] = data
      else
        result = { body = table.concat(chunks) }
        done = true
        if not sock:is_closing() then
          sock:close()
        end
      end
    end)
    sock:write(("GET %s HTTP/1.1\r\nHost: localhost\r\n\r\n"):format(path))
  end)
  vim.wait(3000, function()
    return done
  end, 10)
  return result or { err = "timeout" }
end

local function listening(port)
  local done, ok = false, false
  local sock = vim.uv.new_tcp()
  sock:connect("127.0.0.1", port, function(err)
    ok = (err == nil)
    done = true
    if not sock:is_closing() then
      sock:close()
    end
  end)
  vim.wait(2000, function()
    return done
  end, 10)
  return ok
end

local function serves(port, path, needle)
  local r = http_get(port, path)
  return r.body ~= nil and r.body:find(needle, 1, true) ~= nil, r.err or (r.body or ""):sub(1, 120)
end

-- Section cleanup: stop instances under any of the given dirs, so a check
-- failure cannot leak a server (and the port) into the next section. Probes
-- each dir explicitly because the plugin's upward walk cannot find a
-- root-keyed instance from below (the trailing-slash bug the wrapper is
-- built around).
local function force_stop(dirs)
  for _, d in ipairs(dirs) do
    pcall(function()
      require("live-server").stop(d)
    end)
  end
end

local function writefile(p, content)
  vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
  local f = assert(io.open(p, "w"))
  f:write(content)
  f:close()
end

local function append(p, content)
  local f = assert(io.open(p, "a"))
  f:write(content)
  f:close()
end

-- One LiveServerReload listener; report-and-reset whether a reload fired.
local reload_flag = false
vim.api.nvim_create_autocmd("User", {
  pattern = "LiveServerReload",
  callback = function()
    reload_flag = true
  end,
})
local function reload_fired(timeout_ms)
  vim.wait(timeout_ms, function()
    return reload_flag
  end, 20)
  local was = reload_flag
  reload_flag = false
  return was
end

------------------------------------------------------------------
-- Setup: options, free port, plugin, spec under test, fixtures
------------------------------------------------------------------
vim.o.swapfile = false
vim.opt.rtp:prepend(PLUGIN)

local probe = vim.uv.new_tcp()
probe:bind("127.0.0.1", 0)
local PORT = probe:getsockname().port
probe:close()

vim.g.live_server = { browser = false, port = PORT }
vim.cmd("runtime! plugin/live-server.lua")

local spec = dofile(SPEC)
assert(type(spec) == "table" and type(spec.config) == "function", "spec has no config()")
spec.config()

local FIX = SANDBOX .. "/fixtures"
-- projA: root index.html + a body file under src/ (the bphopkins.net shape)
writefile(
  FIX .. "/projA/index.html",
  "<html><head><title>PROJ-A-ROOT</title></head><body>a</body></html>\n"
)
writefile(FIX .. "/projA/src/page.body.html", "<p>fragment A</p>\n")
writefile(FIX .. "/projA/css/style.css", "body{color:black}\n")
vim.fn.mkdir(FIX .. "/projA/.git", "p")
-- projB: a second project
writefile(
  FIX .. "/projB/index.html",
  "<html><head><title>PROJ-B-ROOT</title></head><body>b</body></html>\n"
)
writefile(FIX .. "/projB/src/other.body.html", "<p>fragment B</p>\n")
vim.fn.mkdir(FIX .. "/projB/.git", "p")
-- projC: no root index.html; content one level down (the fallback case)
writefile(
  FIX .. "/projC/pub/index.html",
  "<html><head><title>PROJ-C-PUB</title></head><body>c</body></html>\n"
)
writefile(FIX .. "/projC/rootnote.txt", "x\n")
vim.fn.mkdir(FIX .. "/projC/.git", "p")

local A, B, C = FIX .. "/projA", FIX .. "/projB", FIX .. "/projC"
local A_DIRS = { A, A .. "/src" }
local C_DIRS = { C, C .. "/pub" }

------------------------------------------------------------------
-- W: the wrapper's contract
------------------------------------------------------------------

-- W1: stop with nothing running is a silent no-op
clear_notes()
local ok0, err0 = cmd("LiveServerStopRoot")
check(
  "W1  stop with nothing running: no error, silent",
  ok0 and #notes == 0,
  tostring(err0) .. " " .. all_notes()
)

-- W2/W3/W4: start from a body file serves the root, with zero buffer churn
cmd("edit " .. A .. "/src/page.body.html")
cmd("LiveServerStartRoot")
local okA, det = serves(PORT, "/", "PROJ-A-ROOT")
check("W2  start from body file serves the project root index", okA, det)
check("W3  no buffer churn: root index.html never loaded", vim.fn.bufnr(A .. "/index.html") == -1)
check(
  "W4  editor still on the body file",
  vim.api.nvim_buf_get_name(0):find("page.body.html", 1, true) ~= nil,
  vim.api.nvim_buf_get_name(0)
)

-- W5: double start is deduplicated
clear_notes()
cmd("LiveServerStartRoot")
check(
  "W5  second start reports already running",
  all_notes():find("already running", 1, true) ~= nil,
  all_notes()
)

-- W6: stop from within the same project
cmd("LiveServerStopRoot")
check("W6  stop from same project stops the server", not listening(PORT))
force_stop(A_DIRS)

-- W7: stop from a DIFFERENT project (the capability the old buffer-juggling
-- form provided and a plain stop(project_root()) loses)
cmd("edit " .. A .. "/src/page.body.html")
cmd("LiveServerStartRoot")
cmd("edit " .. B .. "/src/other.body.html")
cmd("LiveServerStopRoot")
check("W7  stop from a different project stops the server", not listening(PORT))
force_stop(A_DIRS)

-- W8: buffer wipes cannot break the stop (string state, not a buffer handle)
cmd("edit " .. A .. "/src/page.body.html")
cmd("LiveServerStartRoot")
cmd("edit " .. B .. "/src/other.body.html")
for _, b in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_get_name(b):find("projA", 1, true) then
    pcall(vim.api.nvim_buf_delete, b, { force = true })
  end
end
cmd("LiveServerStopRoot")
check("W8  stop survives :bwipeout of every buffer of the served project", not listening(PORT))
force_stop(A_DIRS)

-- W9: start/stop/start-again cycle
cmd("edit " .. A .. "/src/page.body.html")
cmd("LiveServerStartRoot")
check("W9  restart after stop serves again", (serves(PORT, "/", "PROJ-A-ROOT")))
cmd("LiveServerStopRoot")
check("W9b and stops again", not listening(PORT))
force_stop(A_DIRS)

-- W10–W12: fallback case (no root index.html): serve the buffer's directory,
-- keep live-reload alive beside the buffer, leave cwd alone
cmd("edit " .. C .. "/pub/index.html")
local cwd_before = vim.fn.getcwd()
cmd("LiveServerStartRoot")
local okC, detC = serves(PORT, "/", "PROJ-C-PUB")
check("W10 index-less root: serves the BUFFER's directory", okC, detC)
check("W11 index-less root: cwd untouched", vim.fn.getcwd() == cwd_before, vim.fn.getcwd())
append(C .. "/pub/index.html", "<!-- edit -->\n")
check("W12 index-less root: editing beside the buffer triggers reload", reload_fired(2000))
cmd("edit " .. A .. "/src/page.body.html")
cmd("LiveServerStopRoot")
check("W12b index-less-root server stops cross-project", not listening(PORT))
force_stop(C_DIRS)

-- W13: windows that refuse buffer swaps are no obstacle (no :edit anywhere)
cmd("edit " .. A .. "/src/page.body.html")
vim.wo.winfixbuf = true
local okW, errW = cmd("LiveServerStartRoot")
check("W13 start works from a winfixbuf window", okW, tostring(errW))
check("W13b and serves the root", (serves(PORT, "/", "PROJ-A-ROOT")))
local okS, errS = cmd("LiveServerStopRoot")
check("W13c stop works from a winfixbuf window", okS and not listening(PORT), tostring(errS))
vim.wo.winfixbuf = false
force_stop(A_DIRS)

------------------------------------------------------------------
-- U: upstream-behavior canaries (the wrapper's design premises)
------------------------------------------------------------------

-- U1: bare start from a body file serves the buffer's directory (a listing
-- here), which is why a root-aware wrapper exists at all
cmd("edit " .. A .. "/src/page.body.html")
cmd("LiveServerStart")
local rU = http_get(PORT, "/")
check(
  "U1  bare start from body file serves a src/ listing, not the root",
  rU.body ~= nil
    and rU.body:find("Index of /", 1, true) ~= nil
    and rU.body:find("PROJ-A-ROOT", 1, true) == nil,
  rU.err or (rU.body or ""):sub(1, 120)
)
cmd("LiveServerStop") -- same buffer, so the bare stop resolves the same key
check("U1b bare stop from the same buffer stops its own server", not listening(PORT))
force_stop(A_DIRS)

-- U2: bare stop from elsewhere in the project MISSES an explicitly-started
-- server (trailing-slash key vs. the upward walk) — why stop passes the dir
cmd("LiveServerStartRoot")
cmd("LiveServerStop") -- bare, from the body file
check("U2  bare stop from the body file misses the explicit-root instance", listening(PORT))

-- U3: the watch is non-recursive on Linux: a subdirectory edit never fires,
-- a root-level edit does — why the fallback serves the buffer's directory
reload_flag = false
append(A .. "/css/style.css", "/* edit */\n")
check("U3  subdirectory edit does NOT trigger reload (non-recursive watch)", not reload_fired(900))
append(A .. "/index.html", "<!-- edit -->\n")
check("U3b root-level edit DOES trigger reload", reload_fired(2000))
cmd("LiveServerStopRoot")
force_stop(A_DIRS)

------------------------------------------------------------------
-- D: directory semantics outside git repos (measured 2026-08-22, off the
-- planned nousowl.net -> nousowl/ move). project_root()'s git legs search
-- upward from the BUFFER; with no repo anywhere it lands on getcwd(), so the
-- cwd acts as the declared root. For an unnamed buffer, expand('%:p:h') is
-- the cwd (measured, not obvious), so the fallback branch degrades to
-- serving the cwd.
------------------------------------------------------------------
local NOGIT = FIX .. "/nogit"
writefile(
  NOGIT .. "/site/index.html",
  "<html><head><title>NOGIT-SITE</title></head><body>n</body></html>\n"
)
writefile(
  NOGIT .. "/site/sub/page.html",
  "<html><head><title>NOGIT-SUB-PAGE</title></head><body>p</body></html>\n"
)
writefile(
  NOGIT .. "/plain/pages/page.html",
  "<html><head><title>NOGIT-PLAIN-PAGE</title></head><body>q</body></html>\n"
)

-- D0: precondition — these checks are meaningless if the sandbox sits under
-- a git repo (project_root would find that repo instead of falling to cwd)
check(
  "D0  sandbox is not inside a git repo (else: point TMPDIR at a non-repo path)",
  vim.fs.find(".git", { path = NOGIT, upward = true })[1] == nil
)

local orig_cwd = vim.fn.getcwd()

-- D1: no git, cwd = site top with index.html, buffer in a subdir
cmd("cd " .. NOGIT .. "/site")
cmd("edit " .. NOGIT .. "/site/sub/page.html")
cmd("LiveServerStartRoot")
check(
  "D1  no-git: cwd with index.html acts as the served root",
  (serves(PORT, "/", "NOGIT-SITE")) and (serves(PORT, "/sub/page.html", "NOGIT-SUB-PAGE"))
)
cmd("LiveServerStopRoot")
force_stop({ NOGIT .. "/site", NOGIT .. "/site/sub" })

-- D2: no git, no index.html at cwd: serves the buffer's directory
cmd("cd " .. NOGIT .. "/plain")
cmd("edit " .. NOGIT .. "/plain/pages/page.html")
cmd("LiveServerStartRoot")
check(
  "D2  no-git, no index at cwd: serves the buffer's directory",
  (serves(PORT, "/page.html", "NOGIT-PLAIN-PAGE"))
)
cmd("LiveServerStopRoot")
force_stop({ NOGIT .. "/plain", NOGIT .. "/plain/pages" })

-- D3: unnamed buffer, no index at cwd: degrades to serving the cwd
cmd("enew")
cmd("LiveServerStartRoot")
local rD = http_get(PORT, "/")
check(
  "D3  unnamed buffer: serves the cwd (listing)",
  rD.body ~= nil
    and rD.body:find("Index of /", 1, true) ~= nil
    and rD.body:find("pages", 1, true) ~= nil,
  rD.err or (rD.body or ""):sub(1, 120)
)
cmd("LiveServerStopRoot")
check("D3b and stop works", not listening(PORT))
force_stop({ NOGIT .. "/plain" })

cmd("cd " .. orig_cwd)

io.write(("passed: %d  failed: %d\n"):format(npass, nfail))
io.flush()
os.exit(nfail == 0 and 0 or 1)
