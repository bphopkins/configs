-- lua/plugins/live-server.lua
-- Root-aware start/stop for live-server.nvim.
--
-- Design (settled 2026-08-22, DECISIONS.md item 9): pass the directory explicitly
-- at BOTH ends. The plugin normalizes an explicit argument through the same
-- resolver at start and stop, so identical strings yield identical instance
-- keys and stop reliably finds the server. Bare start/stop resolve from the
-- current buffer instead: from a body file under src/ a bare start serves the
-- wrong directory, and a bare stop misses the instance key outright — the key
-- is stored with a trailing slash the upward walk never reproduces. Upstream
-- bug, recorded in DECISIONS.md item 9; deliberately not filed.
--
-- last_root remembers the directory we started, so the stop works from any
-- buffer in any project. It is a plain string – unlike the buffer handle this
-- file used to juggle for the same purpose – so :bwipeout cannot invalidate
-- it, and its lifetime matches the server's exactly (the server runs in-process
-- on vim.uv and dies with Neovim).
--
-- Regression suite: tests/live-server/run.sh — run it after any edit here or
-- any plugin update (the v0.1.7 → v0.3.0 rewrite broke this file silently).

-- No build step: since v0.2.0 the server runs entirely in Lua on vim.uv, so the
-- npm `live-server` package it used to wrap is no longer a dependency
-- (`:checkhealth live-server` says so if the npm one is still installed).
return {
  "barrett-ruth/live-server.nvim",

  -- Lazy-load on the base commands or our root helpers
  cmd = {
    "LiveServerStart",
    "LiveServerStop",
    "LiveServerStartRoot",
    "LiveServerStopRoot",
  },

  -- Two keybindings:
  --   <localleader>hh -> start, serving the project root
  --   <localleader>hk -> stop the server hh started, from anywhere
  keys = {
    {
      "<localleader>hh",
      "<cmd>LiveServerStartRoot<CR>",
      desc = "Live Server start (project root)",
    },
    {
      "<localleader>hk",
      "<cmd>LiveServerStopRoot<CR>",
      desc = "Live Server stop",
    },
  },

  config = function()
    -- No setup() call: it was removed in v0.2.0 and now only logs an error.
    -- Configuration would go in `vim.g.live_server` (see :h live-server-config);
    -- the defaults are what we want, so there is nothing to set.

    ------------------------------------------------------------------
    -- Project root: prefer .git, fall back to cwd
    ------------------------------------------------------------------
    local function project_root()
      -- Neovim ≥ 0.10: use vim.fs.root if available
      if vim.fs and vim.fs.root then
        local root = vim.fs.root(0, { ".git" })
        if root then
          return root
        end
      end

      -- Fallback: search upwards for .git
      if vim.fs and vim.fs.find and vim.fs.dirname then
        local found = vim.fs.find(".git", {
          path = vim.fn.expand("%:p:h"),
          upward = true,
        })[1]
        if found then
          return vim.fs.dirname(found)
        end
      end

      -- Last resort: ask git, then cwd
      local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
      if vim.v.shell_error == 0 and git_root and git_root ~= "" then
        return git_root
      end

      return vim.fn.getcwd()
    end

    ------------------------------------------------------------------
    -- Root-aware start/stop
    ------------------------------------------------------------------
    local last_root = nil

    vim.api.nvim_create_user_command("LiveServerStartRoot", function()
      local root = project_root()
      local dir = root
      if vim.fn.filereadable(root .. "/index.html") ~= 1 then
        -- No index.html at the root: serve the buffer's directory instead.
        -- Serving the root there would render a bare listing and – the watch
        -- being non-recursive on Linux – never live-reload anything in a
        -- subdirectory; the buffer's directory renders whatever page sits
        -- beside the buffer and keeps the reload alive for its siblings.
        dir = vim.fn.expand("%:p:h")
      end
      last_root = dir
      require("live-server").start(dir)
    end, {})

    vim.api.nvim_create_user_command("LiveServerStopRoot", function()
      -- Stop with the same string start() was given — the only form
      -- guaranteed to match the plugin's instance key. (The LiveServerStarted
      -- event's data.root is the realpath, not the key; don't switch to it.)
      require("live-server").stop(last_root or project_root())
      last_root = nil
    end, {})
  end,
}
