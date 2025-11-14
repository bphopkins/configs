-- persistence.nvim: autoload only in these roots on empty starts
--   - ~/Desktop/dissertation
--   - ~/Desktop/homepage
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

    -- ---- Roots that should autoload on empty start ----
    local roots = {
      "~/Desktop/dissertation",
      "~/Desktop/bphopkins.github.io",
      "~/Desktop/configs",
    }

    -- Normalize to absolute, resolved paths and keep only existing dirs.
    local function abspath(p)
      -- expand ~, resolve symlinks, make absolute
      p = vim.fn.expand(p)
      p = vim.fn.resolve(p)
      return vim.fn.fnamemodify(p, ":p")
    end

    local real_roots = {}
    for _, p in ipairs(roots) do
      local ap = abspath(p)
      if vim.fn.isdirectory(ap) == 1 then
        table.insert(real_roots, ap)
      end
    end

    local function with_slash(s)
      return s:sub(-1) == "/" and s or (s .. "/")
    end
    local function cwd_in_roots()
      local cwd = with_slash(abspath(vim.fn.getcwd()))
      for _, r in ipairs(real_roots) do
        r = with_slash(r)
        if cwd:sub(1, #r) == r then
          return true
        end
      end
      return false
    end

    -- Autoload only when:
    --  - starting with no file args (argc() == 0)
    --  - and CWD is under one of the approved roots
    --  - unless the user bypasses autoload via NVIM_NOSESSION=1
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("PersistenceAutoLoad", { clear = true }),
      callback = function()
        if vim.fn.argc() ~= 0 or vim.env.NVIM_NOSESSION then
          return
        end
        if cwd_in_roots() then
          require("persistence").load()
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
