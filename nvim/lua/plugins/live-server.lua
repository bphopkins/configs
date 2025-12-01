-- lua/plugins/live-server.lua
-- Minimal live-server config with root-aware start/stop.
-- Uses the plugin's own LiveServerStart/LiveServerStop commands. :contentReference[oaicite:0]{index=0}

return {
  "barrett-ruth/live-server.nvim",
  build = "npm install -g live-server",

  -- Lazy-load on the base commands or our root helpers
  cmd = {
    "LiveServerStart",
    "LiveServerStop",
    "LiveServerStartRoot",
    "LiveServerStopRoot",
  },

  -- Two keybindings, as requested:
  --   <localleader>hh -> start from project root
  --   <localleader>hk -> stop (root-aware)
  keys = {
    {
      "<localleader>hh",
      "<cmd>LiveServerStartRoot<CR>",
      desc = "Live Server start (project root)",
    },
    {
      "<localleader>hk",
      "<cmd>LiveServerStopRoot<CR>",
      desc = "Live Server stop (project root)",
    },
  },

  config = function()
    -- Use plugin defaults
    require("live-server").setup()

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
    local live_server_root_buf = nil

    local function live_server_start_root()
      local root = project_root()
      if not root then
        vim.notify("live-server.nvim: could not determine project root", vim.log.levels.WARN)
        return
      end

      -- Prefer <root>/index.html if it exists
      local index
      if vim.fs and vim.fs.joinpath then
        index = vim.fs.joinpath(root, "index.html")
      else
        index = root .. "/index.html"
      end

      local cur_win = vim.api.nvim_get_current_win()
      local cur_buf = vim.api.nvim_get_current_buf()

      if index and vim.fn.filereadable(index) == 1 then
        -- Temporarily visit the root index.html buffer
        vim.cmd("edit " .. vim.fn.fnameescape(index))
      else
        -- Fallback: at least set cwd to the project root
        vim.cmd("lcd " .. vim.fn.fnameescape(root))
      end

      -- Remember which buffer owns this server (for stopping later)
      live_server_root_buf = vim.api.nvim_get_current_buf()

      -- Start the actual server using the plugin's command
      vim.cmd("LiveServerStart")

      -- Go back to whatever you were editing
      if vim.api.nvim_buf_is_valid(cur_buf) then
        vim.api.nvim_set_current_win(cur_win)
        vim.api.nvim_set_current_buf(cur_buf)
      end
    end

    local function live_server_stop_root()
      local cur_win = vim.api.nvim_get_current_win()
      local cur_buf = vim.api.nvim_get_current_buf()

      -- If we still know the "owner" buffer, switch to it
      if live_server_root_buf and vim.api.nvim_buf_is_valid(live_server_root_buf) then
        vim.api.nvim_set_current_buf(live_server_root_buf)
      else
        -- Fallback: reconstruct the root buffer context
        local root = project_root()
        local index
        if vim.fs and vim.fs.joinpath then
          index = vim.fs.joinpath(root, "index.html")
        else
          index = root .. "/index.html"
        end

        if index and vim.fn.filereadable(index) == 1 then
          vim.cmd("edit " .. vim.fn.fnameescape(index))
        else
          vim.cmd("lcd " .. vim.fn.fnameescape(root))
        end
      end

      -- Now we're in the same context we started from; use the plugin's stop
      vim.cmd("silent! LiveServerStop")

      live_server_root_buf = nil

      -- Restore previous buffer/window
      if vim.api.nvim_buf_is_valid(cur_buf) then
        vim.api.nvim_set_current_win(cur_win)
        vim.api.nvim_set_current_buf(cur_buf)
      end
    end

    ------------------------------------------------------------------
    -- User commands
    ------------------------------------------------------------------
    vim.api.nvim_create_user_command("LiveServerStartRoot", live_server_start_root, {})
    vim.api.nvim_create_user_command("LiveServerStopRoot", live_server_stop_root, {})
  end,
}
