return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      -- Start from LazyVim's defaults if they exist
      opts = opts or {}
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}

      -- Make explorer show dotfiles by default
      local explorer = opts.picker.sources.explorer or {}
      explorer.hidden = true -- show .bashrc, .config, etc.
      explorer.ignored = true -- uncomment if you ALSO want .gitignored stuff

      opts.picker.sources.explorer = explorer

      return opts
    end,
  },
}
