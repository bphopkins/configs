#!/usr/bin/env bash
# Stage 4: startup time to VimEnter with the fixture as the argument, --startuptime, headless,
# NVIM_NOSESSION=1, five runs per tree; and the LuaSnip-related lines of one log.
S=$(cd "$(dirname "$0")" && pwd)
BEFORE=${STAGE4_BEFORE:-$S/before}
T=$(mktemp -d -t stage4-startup-XXXX)
cp ~/Desktop/configs/tests/nvim-latency/fixture.tex ~/Desktop/configs/tests/nvim-latency/fixture.bib "$T/"
FIX=$T/fixture.tex
for tree in before after; do
  times=()
  for i in 1 2 3 4 5; do
    log=$T/st-$tree-$i.log; rm -f "$log"
    if [[ $tree == before ]]; then
      NVIM_NOSESSION=1 XDG_CONFIG_HOME=$BEFORE nvim --headless --startuptime "$log" "$FIX" +qa! >/dev/null 2>&1
    else
      NVIM_NOSESSION=1 nvim --headless --startuptime "$log" "$FIX" +qa! >/dev/null 2>&1
    fi
    times+=("$(awk '/--- NVIM STARTED ---/ {t=$1} END {print t}' "$log")")
  done
  printf '%s: to VimEnter (ms): %s\n' "$tree" "${times[*]}"
  echo "   luasnip/snippets lines of run 5:"
  grep -iE "luasnip|snippets" "$T/st-$tree-5.log" | awk '{printf "     %s\n", $0}' | head -8
done
echo "stamp check alone (live tree, in-process, 20 runs):"
NVIM_NOSESSION=1 nvim --headless +'lua
  local snip_dir = vim.fn.stdpath("config") .. "/lua/snippets"
  local gen = vim.fn.resolve(snip_dir .. "/snipgen.py")
  local pkgdir = vim.fn.fnamemodify(gen, ":h:h:h:h") .. "/latex/french-logic"
  local hub = pkgdir .. "/french-logic.sty"
  local t0 = vim.uv.hrtime()
  local stale, nfiles = 0, 0
  for _ = 1, 20 do
    local fh = io.open(hub, "rb"); local text = fh:read("*a"); fh:close()
    local files = { hub }
    for unit in text:gmatch("\\RequirePackage{french%-logic%-([%w%-]+)}") do
      local uf = pkgdir .. "/french-logic-" .. unit .. ".sty"
      if vim.fn.filereadable(uf) == 1 then files[#files + 1] = uf end
    end
    nfiles = #files
    for _, f in ipairs(files) do
      local out = snip_dir .. "/sty/" .. vim.fn.fnamemodify(f, ":t:r") .. ".lua"
      local have
      if vim.fn.filereadable(out) == 1 then
        for _, line in ipairs(vim.fn.readfile(out, "", 6)) do have = line:match("^%-%- sty%-sha256: (%x+)$"); if have then break end end
      end
      local data = io.open(f, "rb"); local want = data and vim.fn.sha256(data:read("*a")); if data then data:close() end
      if want ~= have then stale = stale + 1 end
    end
  end
  print(string.format("   %d files, %.2f ms per check, stale %d", nfiles, (vim.uv.hrtime() - t0) / 20e6, stale))' +qa! 2>&1 | tail -1
