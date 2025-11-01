-- Bootstrap lazy.nvim (already in your config)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- TeX Live PATH setup (equivalent to lines 29-36 in init.el)
local texbin = "/usr/local/texlive/2024/bin/x86_64-linux"
if vim.fn.isdirectory(texbin) == 1 then
  vim.env.PATH = texbin .. ":" .. vim.env.PATH
end
vim.env.TEXMFHOME = vim.fn.expand("~/Desktop/texmf")

-- Configure plugins
require("lazy").setup({
  
  -- VimTeX: Core LaTeX support (equivalent to AUCTeX)
  {
    "lervag/vimtex",
    ft = "tex",
    config = function()
      -- Equivalent to AUCTeX settings (lines 101-110)
      vim.g.vimtex_view_method = 'okular'
      vim.g.vimtex_view_general_viewer = 'okular'
      vim.g.vimtex_view_general_options = '--unique file:@pdf\\#src:@line@tex'
      vim.g.vimtex_compiler_method = 'latexmk'
      vim.g.tex_flavor = 'latex'
      vim.g.vimtex_quickfix_mode = 1
      vim.g.vimtex_compiler_latexmk = {
        continuous = 1,  -- Equivalent to TeX-source-correlate-mode
      }
      -- Equivalent to preview-transparent-color
      vim.g.vimtex_view_forward_search_on_start = 1
    end
  },

  -- Completion framework (equivalent to company-mode)
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-omni",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        -- Equivalent to company-idle-delay 0.2
        completion = {
          autocomplete = { require("cmp.types").cmp.TriggerEvent.TextChanged },
        },
        performance = {
          debounce = 200,  -- 0.2 seconds
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping.select_next_item(),
          ['<S-Tab>'] = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'omni' },
        }, {
          { name = 'buffer' },
          { name = 'path' },
        })
      })
    end
  },

  -- Snippet engine (equivalent to yasnippet)
  {
    "L3MON4D3/LuaSnip",
    dependencies = { "rafamadriz/friendly-snippets" },  -- equivalent to yasnippet-snippets
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end
  },

  -- Git integration (equivalent to magit)
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = true
  },

  -- Alternative lightweight git integration
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit" },
  },

-- Session management (equivalent to desktop-save-mode)
{
  "rmagatti/auto-session",
  config = function()
    -- Faithful session contents
    vim.opt.sessionoptions = {
      "buffers","curdir","folds","help","tabpages",
      "winsize","winpos","terminal","localoptions",
    }

    require("auto-session").setup({
      log_level = "error",
      auto_session_root_dir = vim.fn.stdpath("state") .. "/sessions/",
      auto_session_enabled = true,
      auto_save_enabled = true,
      auto_restore_enabled = true,
      auto_session_suppress_dirs = { "~", "~/", "/tmp", "/" },
    })
  end,
},


-- Treesitter for better syntax highlighting
{
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = { "lua", "vim" },  -- removed "latex"
      highlight = { enable = true },
    })
  end
},

  -- Fuzzy finder (like Helm/Ivy in Emacs)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
    },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_config = {
            width = 0.8,
          },
        },
      })
    end
  },

  -- Dark theme (equivalent to modus-vivendi)
  {
    "rebelot/kanagawa.nvim",  -- A sophisticated dark theme similar to modus-vivendi
    lazy = false,
    priority = 1000,
    config = function()
      require("kanagawa").setup({
        theme = "dragon",  -- darkest variant
      })
      vim.cmd([[colorscheme kanagawa]])
    end
  },

  -- Tab line (equivalent to global-tab-line-mode)
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
      require("bufferline").setup({
        options = {
          mode = "tabs",  -- Show tabs, not buffers
          always_show_bufferline = true,
        }
      })
    end
  },

  -- Auto-pairs (equivalent to electric-pair-mode)
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({})
      -- Integration with nvim-cmp
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end
  },

  -- Wrapping with indent (equivalent to adaptive-wrap)
  {
    "preservim/vim-indent-guides",
    config = function()
      vim.g.indent_guides_enable_on_vim_startup = 1
      vim.g.indent_guides_start_level = 2
    end
  },

})

-- General Neovim settings
vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Adaptive-wrap analogue (visual soft wrap with hanging indent)
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.breakindentopt = "shift:2"
vim.opt.showbreak = "↳ "

-- Spell-check: handled per-filetype (see LaTeX autocmd below)
-- Do NOT enable globally, to match Emacs behavior.
-- vim.opt.spell = true
-- vim.opt.spelllang = "en_us"

-- Avoid heavy concealment by default (prefers explicit LaTeX syntax)
vim.opt.conceallevel = 0

-- Disable startup message (equivalent to inhibit-startup-screen)
vim.opt.shortmess:append("I")

-- Leader key
vim.g.mapleader = " "


vim.api.nvim_create_autocmd("FileType", {
  pattern = "tex",
  callback = function()
    -- Indentation settings (equivalent to LaTeX-indent-level, etc.)
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    
    -- Custom keybindings (equivalent to your LaTeX-mode-hook)
    vim.keymap.set("n", "<C-CR>", "<cmd>VimtexCompile<cr>", { buffer = true })
    vim.keymap.set("n", "<F5>", "<cmd>VimtexCompile<cr>", { buffer = true })
    vim.keymap.set("n", "<F6>", "<cmd>VimtexView<cr>", { buffer = true })
    vim.keymap.set("n", "<leader>ll", "<cmd>VimtexCompile<cr>", { buffer = true })
    vim.keymap.set("n", "<leader>lv", "<cmd>VimtexView<cr>", { buffer = true })
    vim.keymap.set("n", "<leader>lc", "<cmd>VimtexClean<cr>", { buffer = true })
    vim.keymap.set("n", "<leader>lt", "<cmd>VimtexTocToggle<cr>", { buffer = true })
    
    -- Visual line mode for LaTeX + spell in TeX only (parity with Emacs)
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
    -- If you prefer no concealment in TeX buffers, uncomment:
    -- vim.opt_local.conceallevel = 0
  end
})


-- LaTeX itemize auto-insert (equivalent to my-latex-insert-item-or-newline)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "tex",
  callback = function()
    vim.keymap.set("i", "<CR>", function()
      local line = vim.api.nvim_get_current_line()
      if line:match("^%s*\\item") then
        return "<CR>\\item "
      else
        return "<CR>"
      end
    end, { buffer = true, expr = true })
  end
})

-- Project management (equivalent to project-list-file)
vim.g.project_list_file = vim.fn.expand("~/.config/nvim/projects")
