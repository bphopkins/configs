return {
  "saghen/blink.cmp",
  opts = function(_, opts)
    opts.sources = opts.sources or {}

    -- For LaTeX files, exclude 'buffer' source (dictionary words)
    opts.sources.per_filetype = {
      tex = { "lsp", "path", "snippets" }, -- Everything except buffer
      latex = { "lsp", "path", "snippets" },
      plaintex = { "lsp", "path", "snippets" },
    }

    return opts
  end,
}
