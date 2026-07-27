-- persistence.nvim: autoload a session only on an empty start (no file args) and
-- only when CWD is under ~/Desktop.  Sessions are SAVED per-CWD everywhere
-- regardless (saving is not gated), and <leader>qs restores manually anywhere;
-- the gate below controls only autoload on empty start.
-- Bypass with NVIM_NOSESSION=1.
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
    -- Persist buffers, window layout, tabpages; avoid global option snapshots.
    vim.opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,terminal"

    -- ---- Autoload gate: any CWD under ~/Desktop ----
    -- (Was a six-repo allowlist until 2026-07-26; load() is a no-op when
    -- no session exists for the CWD, so the broad gate is safe.)
    local function abspath(p)
      -- expand ~, resolve symlinks, make absolute (dirs gain a trailing /)
      p = vim.fn.expand(p)
      p = vim.fn.resolve(p)
      return vim.fn.fnamemodify(p, ":p")
    end

    local desktop = abspath("~/Desktop") -- "/home/bph/Desktop/"
    local function cwd_autoloads()
      local cwd = abspath(vim.fn.getcwd())
      return cwd:sub(1, #desktop) == desktop
    end

    -- Autoload only when:
    --  - starting with no file args (argc() == 0)
    --  - and CWD is under ~/Desktop
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

    -- Headless runs (test suites, agents, scripts) must never overwrite
    -- a session: persistence saves for EVERY cwd on VimLeavePre, so an
    -- unguarded headless run clobbers the real session of whatever dir
    -- it ran in (this actually happened; found 2026-07-26).  A VimEnter
    -- guard is not enough — `nvim --headless +qa!` exits before VimEnter
    -- fires.  Registered here in init(), which lazy.nvim runs BEFORE the
    -- plugin loads, so this VimLeavePre autocmd precedes the plugin's
    -- own and can disarm its save.
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("PersistenceHeadlessGuard", { clear = true }),
      callback = function()
        if #vim.api.nvim_list_uis() == 0 then
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
