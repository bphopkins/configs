return {
  {
    "hrsh7th/cmp-omni",
    ft = { "tex", "latex", "plaintex" },
    config = function()
      -- Make VimTeX provide completion + add it as a cmp source for TeX buffers
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "tex", "latex", "plaintex" },
        callback = function()
          vim.bo.omnifunc = "vimtex#complete#omnifunc"
          local ok, cmp = pcall(require, "cmp")
          if not ok then
            return
          end
          cmp.setup.buffer({
            sources = cmp.config.sources({
              { name = "omni" },
              { name = "luasnip" },
              { name = "path" },
              { name = "buffer" },
            }, cmp.get_config().sources),
          })
        end,
      })

      -- ⬇️ Disable the cmp→autopairs brace insertion in TeX buffers
      local ok_cmp, cmp = pcall(require, "cmp")
      local ok_ap, cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")
      if ok_cmp and ok_ap then
        cmp.event:on(
          "confirm_done",
          cmp_autopairs.on_confirm_done({
            filetypes = {
              tex = false,
              plaintex = false,
              latex = false,
            },
          })
        )
      end
    end,
  },
  -- Nice extras (optional):
  { "micangl/cmp-vimtex", ft = { "tex", "latex", "plaintex" } },
  { "kdheepak/cmp-latex-symbols", ft = { "tex", "latex", "plaintex" } },
}
