-- This machine's git role, and the lazy.nvim lockfile that follows from it
-- (2026-10-26; org/machines/transport-2026-10, rules.md fedxps-5).
--
-- ~/Desktop/configs travels between the machines, by git until the cutover and
-- by Syncthing after it, lazy-lock.json with it, and bigfed alone adds, updates
-- and removes plugins (the habit fedxps-5 names). lazy rewrites its
-- lockfile from the installed plugins at every install, restore, update and
-- clean -- one ordinary start after a plugin arrives is enough -- so on the
-- reader it keeps a lock of its own, refreshed from the shared one at every
-- start: the shared lock then has one writer, and the reader still converges
-- on bigfed's commits with `:Lazy restore`. One case takes two: a restore that
-- is the first start after a plugin was added, whose install pass rewrites
-- the copy from what was installed before the restore reads it (measured;
-- the suite pins the second).
--
-- The role is read the way bash/.bashrc.d/10-env.sh reads it, from the same
-- two host files: configs/git/hosts/<hostname>.inc (the hostname short,
-- lowercased, without whitespace) and the file ~/.config/git/host.inc points
-- at. A reader when either names a role other than `writer` or any reader
-- repository (the pilot's readerRepo counts, as it does for
-- GIT_OPTIONAL_LOCKS); a reader too when a host file exists but cannot be read
-- or parsed, or the link dangles: the safe side. No host file, no role: a
-- writer, which is what anyone else using this repository gets. The files are
-- read here without spawning git -- section headers, `key = value` with the key
-- case-insensitive, `#` and `;` comments, quoted values, and `[include]` paths,
-- as git honours them -- so a start costs no process.
--
-- Suite: configs/tests/lazy-lock/run.sh, which checks this parse against
-- git's own on every fixture.
local M = {}

local uv = vim.uv or vim.loop

-- One git-config file, the keys under [gsync] with their values, following
-- [include] paths. Returns nil, reason when the file cannot be read or parsed.
local function gsync_keys(path, keys, depth)
  if depth > 10 then
    return nil, "include depth"
  end
  local f = io.open(path, "rb")
  if not f then
    return nil, "unreadable"
  end
  local text = f:read("*a")
  f:close()
  if not text then
    return nil, "unreadable"
  end
  local section = nil
  for raw in (text .. "\n"):gmatch("(.-)\r?\n") do
    local line = raw:match("^%s*(.-)%s*$")
    if line:sub(1, 1) == "[" then
      local head, rest = line:match("^%[([^%]]*)%](.*)$")
      if not head then
        return nil, "bad section header"
      end
      local name = head:match("^([%w%.%-]+)$")
      if name then
        section = name:lower()
      else
        local base, sub = head:match('^([%w%.%-]+)%s+"(.*)"$')
        if not base then
          return nil, "bad section header"
        end
        -- [gsync "x"] is gsync.x.*, and [includeIf "..."] is a condition
        -- this read does not evaluate: neither is [gsync] or [include].
        section = base:lower() .. "." .. sub
      end
      -- git reads a key that follows the header on its line
      line = rest:match("^%s*(.-)$")
    end
    if line == "" or line:match("^[#;]") then
      -- blank or comment
    else
      -- a key before any section is one git reads too, in no section
      local key, rest = line:match("^(%a[%w%-]*)(.*)$")
      if not key then
        return nil, "bad line"
      end
      local value
      if rest:match("^%s*$") or rest:match("^%s*[#;]") then
        value = "true" -- a bare key is a boolean true, as git reads it
      else
        local v = rest:match("^%s*=(.*)$")
        if not v then
          return nil, "bad line"
        end
        -- the value: quotes removed, a comment outside quotes dropped
        local out, quoted = {}, false
        for i = 1, #v do
          local c = v:sub(i, i)
          if c == '"' then
            quoted = not quoted
          elseif (c == "#" or c == ";") and not quoted then
            break
          else
            out[#out + 1] = c
          end
        end
        value = table.concat(out):match("^%s*(.-)%s*$")
      end
      key = key:lower()
      if section == "gsync" and (key == "role" or key == "readerrepo") then
        keys[#keys + 1] = { key, value }
      elseif section == "include" and key == "path" then
        local inc = value
        if inc:sub(1, 2) == "~/" then
          inc = (os.getenv("HOME") or "") .. inc:sub(2)
        elseif inc:sub(1, 1) ~= "/" then
          inc = vim.fn.fnamemodify(path, ":h") .. "/" .. inc
        end
        -- git skips a missing include in silence; one that exists must read
        if uv.fs_stat(inc) then
          local ok, why = gsync_keys(inc, keys, depth + 1)
          if not ok then
            return nil, why
          end
        end
      end
    end
  end
  return keys
end

-- The host files this machine reads, and whether one fails safe on its own:
-- the link dangling.
local function host_files()
  local home = os.getenv("HOME") or ""
  local files = {}
  local host = (uv.os_gethostname() or ""):gsub("%..*$", ""):lower():gsub("%s", "")
  if host ~= "" then
    files[#files + 1] = home .. "/Desktop/configs/git/hosts/" .. host .. ".inc"
  end
  local link = home .. "/.config/git/host.inc"
  if uv.fs_lstat(link) then
    local target = uv.fs_realpath(link)
    if not target then
      return files, true
    end
    files[#files + 1] = target
  end
  return files, false
end

local reader_cache
--- True when this machine reads by git's rules: a role, or a reader repository.
function M.reader()
  if reader_cache ~= nil then
    return reader_cache
  end
  local ok, verdict = pcall(function()
    local files, dangling = host_files()
    if dangling then
      return true
    end
    local seen = {}
    for _, f in ipairs(files) do
      if not seen[f] then
        seen[f] = true
        if uv.fs_lstat(f) then
          -- present but no regular file (a dangling link, a directory), or
          -- unreadable, or unparsable: the safe side
          local st = uv.fs_stat(f)
          local keys = st and st.type == "file" and gsync_keys(f, {}, 0)
          if not keys then
            return true
          end
          for _, kv in ipairs(keys) do
            if
              (kv[1] == "role" and kv[2] ~= "writer") or (kv[1] == "readerrepo" and kv[2] ~= "")
            then
              return true
            end
          end
        end
      end
    end
    return false
  end)
  -- An error here is a reader: the lock it then keeps is a copy, and the
  -- shared one stays bigfed's.
  reader_cache = (not ok) or verdict
  if not ok then
    vim.notify(
      "config.role: " .. tostring(verdict) .. " -- keeping lazy's lock as a reader",
      vim.log.levels.WARN
    )
  end
  return reader_cache
end

-- The reader's lock in DIR: DIR/lazy-lock.json, made afresh from the shared
-- lock when there is one, by a copy beside it and a rename, so a second
-- instance starting at the same moment never reads half a file. Returns the
-- path, or nil and the reason; raises nothing.
local function lock_in(dir, shared)
  local made, err = pcall(vim.fn.mkdir, dir, "p")
  if not made then
    return nil, tostring(err)
  end
  if vim.fn.isdirectory(dir) ~= 1 then
    return nil, dir .. " is no directory"
  end
  local mine = dir .. "/lazy-lock.json"
  if uv.fs_stat(shared) then
    local tmp = mine .. "." .. uv.os_getpid() .. ".tmp"
    local ok, cerr = uv.fs_copyfile(shared, tmp)
    if ok then
      ok, cerr = uv.fs_rename(tmp, mine)
    end
    if not ok then
      pcall(uv.fs_unlink, tmp)
      return nil, tostring(cerr)
    end
  end
  return mine
end

--- The lockfile lazy.nvim is to write, for setup()'s `lockfile`: nil on a
--- writer (lazy's default, the tracked <config>/lazy-lock.json); on a reader its
--- own copy, made afresh from the shared lock at every start. The other rule
--- offered, a copy only when the shared lock is newer, fails twice: mtimes
--- cross from the other machine as Syncthing found them, and lazy's own
--- install pass rewrites the copy from what is installed, so a copy kept by
--- age can pin the reader below bigfed's lock until that moves.
---
--- The copy goes under stdpath("state"); where that cannot be made or
--- written (its place taken by a file, a full or read-only disk), under
--- stdpath("cache"), and then in this session's temporary directory, each
--- with a WARN, since each still keeps lazy off the shared lock. Only when all
--- three fail is the answer nil, with a WARN that lazy may write the shared
--- lock this session: a lockfile lazy cannot open would raise inside every
--- install, restore and clean, and read as an empty lock, so that a restore
--- would move every plugin to its branch's tip (lazy.nvim's source,
--- manage/lock.lua and manage/task/git.lua). Raises nothing.
function M.lazy_lockfile()
  if not M.reader() then
    return nil
  end
  local shared = vim.fn.stdpath("config") .. "/lazy-lock.json"
  local names = { 'stdpath("state")', 'stdpath("cache")', "the session's temporary directory" }
  local function dir_of(i)
    if i == 1 then
      return vim.fn.stdpath("state")
    elseif i == 2 then
      return vim.fn.stdpath("cache")
    end
    return vim.fn.fnamemodify(vim.fn.tempname(), ":h")
  end
  local failed = {}
  for i, name in ipairs(names) do
    local ok, path, err = pcall(function()
      return lock_in(dir_of(i), shared)
    end)
    if ok and path then
      if #failed > 0 then
        local why = table.concat(failed, "; ")
        vim.notify(
          "config.role: lazy's lock kept under " .. name .. " (" .. why .. ")",
          vim.log.levels.WARN
        )
      end
      return path
    end
    failed[#failed + 1] = name .. ": " .. tostring(ok and err or path)
  end
  vim.notify(
    "config.role: no place for lazy's own lock ("
      .. table.concat(failed, "; ")
      .. ") -- lazy may write the shared lazy-lock.json this session",
    vim.log.levels.WARN
  )
  return nil
end

return M
