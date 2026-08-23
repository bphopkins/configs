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
      explorer.hidden = true -- show dotfiles: .bashrc, .config, etc.
      explorer.ignored = true -- also show .gitignored files (build artifacts, etc.)

      opts.picker.sources.explorer = explorer

      -- Notifier: the stock bubbles clipped and vanished (verified
      -- 2026-08-22: vim.notify → noice → snacks.notifier renders the
      -- top-right bubbles, and noice adds no sizing or timing, so these
      -- values govern.  Stock: timeout 3000 ms, width max 0.4, and
      -- wrap=false in the window style — long lines clipped at the bubble
      -- edge and everything died in three seconds).  Units per dim() in
      -- snacks/notifier.lua: ≤ 1 is a fraction of the editor, > 1 is
      -- cells — and min/max only *clamp* the content-sized bubble, so
      -- ordinary short notifications render exactly as before.
      opts.notifier = vim.tbl_deep_extend("force", opts.notifier or {}, {
        timeout = 10000, -- ms; stock 3000 is too quick to read
        width = { min = 40, max = 0.55 },
        height = { min = 1, max = 0.8 },
        -- style: the default "compact" is kept, chosen after comparing all
        -- three live (2026-08-22): "fancy" adds a timestamp header at the
        -- cost of two rows per bubble, "minimal" drops titles entirely.
      })
      -- Auto-dismissal deliberately kept (no `keep` override) — every
      -- notification lands in the <leader>n history regardless.
      opts.styles = vim.tbl_deep_extend("force", opts.styles or {}, {
        notification = { wo = { wrap = true } }, -- wrap long lines, don't clip
      })

      return opts
    end,
  },
}
