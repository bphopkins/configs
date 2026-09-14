return {
  {
    "L3MON4D3/LuaSnip",
    opts = function(_, opts)
      -- The snippet libraries are generated files under lua/snippets: pkg/<name>.lua from
      -- TeXstudio's completion word lists and sty/<name>.lua from this repository's
      -- french-logic package, one file per package, registered per buffer by the loader
      -- (lua/snippets/loader.lua) from VimTeX's package table.  Stage 3 of the LaTeX
      -- completion campaign, 2026-09-13 (configs/docs/latex-completion-campaign-2026-09).

      -- Keep the french-logic files current.  Each sty/<unit>.lua carries the sha256 of the
      -- .sty it was generated from (`-- sty-sha256:`); the hub and every unit its
      -- \RequirePackage{french-logic-…} lines name are compared here, and on any mismatch the
      -- generator is re-run over the hub (~0.1 s, only when stale), so completions cannot
      -- silently drift from the package.  --sty reads nothing but .sty files, so the result is
      -- byte-identical on both machines without the TeXstudio clone.  Paths resolve through
      -- the stow symlinks; a missing hub or python3 skips silently.
      local snip_dir = vim.fn.stdpath("config") .. "/lua/snippets"
      local gen = vim.fn.resolve(snip_dir .. "/snipgen.py")
      local pkgdir = vim.fn.fnamemodify(gen, ":h:h:h:h") .. "/latex/french-logic"
      local hub = pkgdir .. "/french-logic.sty"
      local fh = io.open(hub, "rb")
      if fh and vim.fn.executable("python3") == 1 then
        local text = fh:read("*a")
        fh:close()
        local files = { hub }
        for unit in text:gmatch("\\RequirePackage{french%-logic%-([%w%-]+)}") do
          local uf = pkgdir .. "/french-logic-" .. unit .. ".sty"
          if vim.fn.filereadable(uf) == 1 then
            files[#files + 1] = uf
          end
        end
        local stale = 0
        for _, f in ipairs(files) do
          local out = snip_dir .. "/sty/" .. vim.fn.fnamemodify(f, ":t:r") .. ".lua"
          local have
          if vim.fn.filereadable(out) == 1 then
            for _, line in ipairs(vim.fn.readfile(out, "", 6)) do
              have = line:match("^%-%- sty%-sha256: (%x+)$")
              if have then
                break
              end
            end
          end
          local data = io.open(f, "rb")
          local want = data and vim.fn.sha256(data:read("*a"))
          if data then
            data:close()
          end
          if want ~= have then
            stale = stale + 1
          end
        end
        if stale > 0 then
          local res = vim.fn.system({ "python3", gen, "--sty", hub })
          if vim.v.shell_error == 0 then
            vim.notify(
              ("french-logic snippets regenerated: %d of %d files were stale"):format(stale, #files)
            )
            -- The package changed, so also check that no command is missing a highlight
            -- registration in vimtex.lua.  Purely informational: highlighting falls back to
            -- the default command colour until registered.
            local cov = vim.fn.system({ "python3", gen, "--sty", hub, "--coverage" })
            if vim.v.shell_error ~= 0 then
              vim.notify(
                "french-logic: commands without highlight registration (vimtex.lua):\n" .. cov,
                vim.log.levels.WARN
              )
            end
          else
            vim.notify("french-logic snippet regeneration failed:\n" .. res, vim.log.levels.WARN)
          end
        end
      elseif fh then
        fh:close()
      end

      -- The loader is LuaSnip's filetype function: a TeX buffer's snippet filetypes are the
      -- pseudo-filetypes of its packages, registered on demand; bib buffers get the hand
      -- file of entry templates; every other filetype keeps LuaSnip's default.
      opts.ft_func = require("snippets.loader").ft_func
      return opts
    end,
    config = function(_, opts)
      require("luasnip").setup(opts)
      require("snippets.loader").setup()
    end,
  },
}
