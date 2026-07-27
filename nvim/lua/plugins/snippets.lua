return {
  {
    "L3MON4D3/LuaSnip",
    opts = function(_, opts)
      local ls = require("luasnip")

      -- Auto-regenerate french-logic.lua when french-logic.sty changes.
      -- The generator stamps the .sty's sha256 into the output header;
      -- on mismatch it is re-run (~100 ms, and only when stale), so
      -- completions can never silently drift from the package.  Paths
      -- are resolved through the stow symlinks so this follows the repo
      -- wherever it lives; missing .sty or python3 skips silently.
      local snip_dir = vim.fn.stdpath("config") .. "/lua/snippets"
      local gen = vim.fn.resolve(snip_dir .. "/sty-lua-snippets.py")
      local out = snip_dir .. "/french-logic.lua"
      local sty = vim.fn.fnamemodify(gen, ":h:h:h:h") .. "/latex/french-logic/french-logic.sty"
      local fh = io.open(sty, "rb")
      if fh and vim.fn.executable("python3") == 1 then
        local want = vim.fn.sha256(fh:read("*a"))
        fh:close()
        local have
        if vim.fn.filereadable(out) == 1 then
          for _, line in ipairs(vim.fn.readfile(out, "", 5)) do
            have = line:match("^%-%- sty%-sha256: (%x+)$")
            if have then
              break
            end
          end
        end
        if want ~= have then
          local res = vim.fn.system({ "python3", gen, "-i", sty, "-o", out })
          if vim.v.shell_error == 0 then
            vim.notify("french-logic snippets regenerated from french-logic.sty")
            -- The .sty changed, so also check that no new command is
            -- missing a highlight registration in vimtex.lua.  Purely
            -- informational — highlighting falls back to the default
            -- command colour until registered.
            local cov = vim.fn.system({ "python3", gen, "-i", sty, "--coverage" })
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

      -- Load all Lua snippet modules from ~/.config/nvim/lua/snippets
      require("luasnip.loaders.from_lua").lazy_load({
        paths = vim.fn.stdpath("config") .. "/lua/snippets",
      })

      -- Each file in lua/snippets is treated as its own "filetype":
      --   french-logic.lua    -> "french-logic"
      --   latex-workshop.lua  -> "latex-workshop"
      --
      -- Make those snippet-sets visible when editing TeX / LaTeX.
      ls.filetype_extend("tex", { "latex-workshop", "french-logic" })
      ls.filetype_extend("latex", { "tex" })
      ls.filetype_extend("plaintex", { "tex" })
      ls.filetype_extend("bib", { "latex-workshop", "french-logic" })
      ls.filetype_extend("bibtex", { "latex-workshop", "french-logic" })

      return opts
    end,
  },
}
