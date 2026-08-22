-- stallwatch.lua — catch the multi-second typing stalls.
--
-- Load it in a real session:            :luafile /path/to/stallwatch.lua
-- Then just work.  Every keystroke slower than the threshold is appended to
--   ~/nvim-stalls.log
-- with enough context to say what was going on.  Nothing is written unless a
-- stall actually happens.
--
--   :StallWatchStatus     how many stalls so far, and where the log is
--   :StallWatchDump       write the VimTeX profile now (see below)
--   :StallWatchOff        stop watching
--
-- How it measures: InsertCharPre fires the moment Neovim receives a typed
-- character, before anything else runs.  We stamp the time there and schedule
-- a callback, which the event loop can only run once it is free again.  The
-- gap between the two IS the time the character spent not reaching the screen
-- -- exactly the thing being complained about.
--
-- It also profiles VimTeX's own Vimscript functions, because that is where a
-- seconds-long stall would most plausibly live and Lua-side timing cannot see
-- inside them.  On the first stall it dumps the profile alongside the log.

local M = {}

local THRESHOLD_MS = tonumber(vim.env.STALLWATCH_MS or "") or 400
local LOG = vim.fn.expand("~/nvim-stalls.log")
local PROF = vim.fn.expand("~/nvim-stalls.profile")

M.count = 0
local profiling = false
local dumped = false

-- Profile VimTeX + the tex ftplugin. Vimscript profiling costs something, but
-- this is a diagnostic session, not the steady state.
local function start_profile()
  if profiling then
    return
  end
  -- `profile file` only covers files sourced AFTER it runs, and VimTeX is
  -- long since loaded by the time this is sourced.  `profile func` does apply
  -- to already-defined functions, which is what we need.
  local ok = pcall(function()
    vim.cmd("profile start " .. vim.fn.fnameescape(PROF))
    vim.cmd("profile func vimtex#*")
    vim.cmd("profile func Vimtex*")
  end)
  profiling = ok
end

local function dump_profile()
  if not profiling then
    return false
  end
  return pcall(function()
    vim.cmd("profile dump")
  end)
end

local function jobs_running()
  -- vim.b.vimtex comes back as a plain copy, so its methods are not callable
  -- from Lua; ask Vimscript instead, and never let this throw.
  local ok, vt = pcall(vim.fn.eval, "exists('b:vimtex.compiler') "
    .. "? (b:vimtex.compiler.is_running() ? 'yes' : 'no') : '-'")
  return ok and tostring(vt) or "?"
end

-- Every field is best-effort: a stall report that fails to render is worse
-- than a partial one, so nothing in here may throw.
local function try(f, dflt)
  local ok, v = pcall(f)
  return ok and v or (dflt or "?")
end

local function snapshot_inner(ms, char)
  local buf = vim.api.nvim_get_current_buf()
  local line = try(vim.api.nvim_get_current_line, "")
  local cur = try(function()
    return vim.api.nvim_win_get_cursor(0)
  end, { -1, -1 })
  local vtjob = jobs_running()
  local blink = try(function()
    local cmp = require("blink.cmp")
    return tostring(cmp.is_visible and cmp.is_visible() or false)
  end, "n/a")
  return table.concat({
    os.date("%Y-%m-%d %H:%M:%S"),
    ("STALL %.0f ms  char=%q"):format(ms, char or "?"),
    ("  file       : %s"):format(try(function()
      return vim.api.nvim_buf_get_name(buf)
    end, "?")),
    ("  filetype   : %s   syntax=%s"):format(vim.bo.filetype, vim.bo.syntax),
    ("  cursor     : line %s col %s"):format(tostring(cur[1]), tostring(cur[2])),
    ("  line length: %d chars"):format(#line),
    ("  buffers    : %s listed"):format(try(function()
      return #vim.fn.getbufinfo({ buflisted = 1 })
    end, "?")),
    ("  vimtex root: %s"):format(try(function()
      return vim.b.vimtex and vim.b.vimtex.tex or "-"
    end, "?")),
    ("  packages   : %s"):format(try(function()
      return vim.b.vimtex and vim.tbl_count(vim.b.vimtex.packages or {}) or "-"
    end, "?")),
    ("  compiling  : %s"):format(vtjob),
    ("  blink menu : %s"):format(blink),
    ("  matchparen : vimtex=%s builtin_loaded=%s"):format(
      tostring(vim.g.vimtex_matchparen_enabled),
      tostring(vim.g.loaded_matchparen)
    ),
    ("  undo seq   : %s"):format(try(function()
      return tostring(vim.fn.undotree().seq_cur)
    end, "?")),
    "",
  }, "\n")
end

-- Outermost guard: if the report itself fails, still record the stall.
local function snapshot(ms, char)
  local ok, text = pcall(snapshot_inner, ms, char)
  if ok then
    return text
  end
  return ("%s\nSTALL %.0f ms  char=%q  (report failed: %s)\n\n"):format(
    os.date("%Y-%m-%d %H:%M:%S"),
    ms,
    char or "?",
    tostring(text)
  )
end

local function log(text)
  local fh = io.open(LOG, "a")
  if not fh then
    return
  end
  fh:write(text)
  fh:close()
end

local group = vim.api.nvim_create_augroup("StallWatch", { clear = true })

vim.api.nvim_create_autocmd("InsertCharPre", {
  group = group,
  callback = function()
    local char = vim.v.char
    local t0 = vim.uv.hrtime()
    vim.schedule(function()
      local ms = (vim.uv.hrtime() - t0) / 1e6
      if ms < THRESHOLD_MS then
        return
      end
      M.count = M.count + 1
      log(snapshot(ms, char))
      if not dumped then
        dumped = dump_profile()
        if dumped then
          log(("  -> VimTeX profile written to %s\n\n"):format(PROF))
        end
      end
      vim.notify(
        ("stallwatch: %.0f ms stall (#%d) -> %s"):format(ms, M.count, LOG),
        vim.log.levels.WARN
      )
    end)
  end,
})

vim.api.nvim_create_user_command("StallWatchStatus", function()
  vim.notify(
    ("stallwatch: %d stalls, threshold %d ms\n  log     %s\n  profile %s (%s)"):format(
      M.count,
      THRESHOLD_MS,
      LOG,
      PROF,
      profiling and "profiling vimtex" or "profiling OFF"
    ),
    vim.log.levels.INFO
  )
end, {})

vim.api.nvim_create_user_command("StallWatchDump", function()
  if dump_profile() then
    vim.notify("stallwatch: profile written to " .. PROF)
  else
    vim.notify("stallwatch: profiling is not active", vim.log.levels.WARN)
  end
end, {})

vim.api.nvim_create_user_command("StallWatchOff", function()
  pcall(vim.api.nvim_del_augroup_by_name, "StallWatch")
  if profiling then
    pcall(function()
      vim.cmd("profile stop")
    end)
    profiling = false
  end
  vim.notify("stallwatch: off")
end, {})

start_profile()
log(("\n=== stallwatch armed %s  threshold %d ms  nvim %s ===\n"):format(
  os.date("%Y-%m-%d %H:%M:%S"),
  THRESHOLD_MS,
  tostring(vim.version())
))
vim.notify(("stallwatch armed: >%d ms -> %s"):format(THRESHOLD_MS, LOG))

return M
