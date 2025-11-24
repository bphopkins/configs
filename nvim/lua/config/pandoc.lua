
-- lua/config/pandoc.lua
local M = {}

local function output_path(ext)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("No file name for current buffer", vim.log.levels.ERROR)
    return nil, nil
  end
  local out = file:gsub("%.%w+$", "") .. "." .. ext
  return file, out
end

local function run_pandoc(cmd, out)
  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("Pandoc wrote " .. out, vim.log.levels.INFO)
      else
        vim.notify("Pandoc failed (exit " .. code .. ")", vim.log.levels.ERROR)
      end
    end,
  })
end

function M.to_html()
  local file, out = output_path("html")
  if not file then return end
  run_pandoc({ "pandoc", file, "-o", out }, out)
end

function M.to_pdf()
  local file, out = output_path("pdf")
  if not file then return end
  run_pandoc({
    "pandoc",
    file,
    "--from=markdown+tex_math_dollars",
    "--pdf-engine=lualatex",
    "-o", out,
  }, out)
end

return M
