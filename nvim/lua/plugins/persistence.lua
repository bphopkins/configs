-- persistence.nvim: autoload a session on an empty start (no file args) only
-- when CWD is a directory strictly BELOW ~/Desktop -- the repos and their
-- subdirs.  The ~/Desktop root itself is deliberately excluded: it is where a
-- raw nvim / the LazyVim dashboard is wanted, not a project (settled
-- 2026-09-12).  Saving is gated to match, so no session is written for the
-- ~/Desktop root either (nor for headless runs) -- otherwise a stray file
-- opened from a ~/Desktop shell rides in the root session's argument list and
-- reappears on every bare launch, which `:bd` cannot clear (only `:argdelete`
-- can).  <leader>qs still restores manually anywhere; bypass autoload with
-- NVIM_NOSESSION=1.
-- Uses only vim.fn (stable) for path ops. Plugin loads eagerly for reliability.

return {
  "folke/persistence.nvim",
  lazy = false, -- ensure the module exists when VimEnter fires on an empty start
  opts = {
    dir = vim.fn.stdpath("state") .. "/sessions/", -- per-machine storage
    need = 1, -- save only if ≥1 real file buffer is open
    branch = false, -- single session per dir (no per-branch split)
  },
  keys = {
    {
      "<leader>qs",
      function()
        require("persistence").load()
      end,
      desc = "Restore session for CWD",
    },
    {
      "<leader>qS",
      function()
        require("persistence").select()
      end,
      desc = "Select a session",
    },
    {
      "<leader>ql",
      function()
        require("persistence").load({ last = true })
      end,
      desc = "Restore last session",
    },
    {
      "<leader>qd",
      function()
        require("persistence").stop()
      end,
      desc = "Don't save this session (one-shot)",
    },
  },
  init = function()
    -- Persist buffers, window layout, tabpages; no global-variable snapshot.
    -- ('globals' was added 2026-09-12 to persist bufferline's moved tab order
    -- via vim.g.BufferlinePositions, then dropped: the restore leaned on
    -- bufferline's undocumented internals and cross-plugin load order, too
    -- fragile to carry.  To fix a specific tab order instead, reorder the
    -- `badd` lines in the session file by hand while nvim is closed -- the
    -- default order follows that sequence.)
    vim.opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,terminal"

    -- ---- Autoload gate: a project dir strictly BELOW ~/Desktop ----
    -- (Was a six-repo allowlist until 2026-07-26; load() is a no-op when
    -- no session exists for the CWD, so the broad gate is safe.  The
    -- ~/Desktop root was dropped 2026-09-12 -- see the header.)
    local function abspath(p)
      -- expand ~, resolve symlinks, make absolute (dirs gain a trailing /)
      p = vim.fn.expand(p)
      p = vim.fn.resolve(p)
      return vim.fn.fnamemodify(p, ":p")
    end

    local desktop = abspath("~/Desktop") -- "/home/bph/Desktop/" (trailing slash)
    local function cwd_is_desktop_root()
      return abspath(vim.fn.getcwd()) == desktop
    end
    local function cwd_autoloads()
      local cwd = abspath(vim.fn.getcwd())
      -- Strictly below: a subdirectory of ~/Desktop, never the root itself.
      return cwd ~= desktop and cwd:sub(1, #desktop) == desktop
    end

    -- Autoload only when:
    --  - starting with no file args (argc() == 0)
    --  - and CWD is a project dir below ~/Desktop (not the root)
    --  - unless the user bypasses autoload via NVIM_NOSESSION=1
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("PersistenceAutoLoad", { clear = true }),
      callback = function()
        -- Headless runs must not autoload (see the VimLeavePre guard
        -- below for the save side).
        if #vim.api.nvim_list_uis() == 0 then
          return
        end
        if vim.fn.argc() ~= 0 or vim.env.NVIM_NOSESSION then
          return
        end
        if cwd_autoloads() then
          require("persistence").load()
        end
      end,
    })

    -- Do-not-save guard.  persistence saves for EVERY cwd on VimLeavePre;
    -- two cases must disarm that save before it fires:
    --   * headless runs (test suites, agents, scripts) -- an unguarded
    --     headless run clobbers the real session of whatever dir it ran in
    --     (this happened; found 2026-07-26).  A VimEnter guard is not
    --     enough: `nvim --headless +qa!` exits before VimEnter fires.
    --   * the ~/Desktop root -- the raw-nvim / dashboard directory, never a
    --     project, so it gets no session (matches the autoload gate;
    --     2026-09-12).  cwd is read at quit time, which is exactly what
    --     names the session file, so guarding on it is precise.
    -- Registered in init(), which lazy.nvim runs BEFORE the plugin loads, so
    -- this VimLeavePre autocmd precedes the plugin's own save and disarms it.
    -- stop() removes persistence's save autocmd for the rest of the session.
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("PersistenceSaveGuard", { clear = true }),
      callback = function()
        if #vim.api.nvim_list_uis() == 0 or cwd_is_desktop_root() then
          pcall(function()
            require("persistence").stop()
          end)
        end
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "PersistenceLoadPost",
      group = vim.api.nvim_create_augroup("FixHighlightAfterSession", { clear = true }),
      callback = function()
        vim.cmd("silent! doautoall BufReadPost")
        if vim.fn.exists(":TSEnable") == 2 then
          vim.cmd("silent! TSEnable highlight")
        end
      end,
    })
  end,
}
