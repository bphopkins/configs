r"""Shared pieces of the stage-4 probes (build chat 4, 2026-09-13): the harness, the scratch copy of
the committed pre-campaign tree, in-process hooks that time the luasnip source, blink's fuzzy pass,
the two live transforms and the loader's ft_func per request, a rows readout with scores, memory."""
import os, sys, time, statistics
sys.path.insert(0, os.path.expanduser("~/Desktop/configs/tests/nvim-latency"))
from harness import Nvim  # noqa: F401

S = os.path.dirname(os.path.abspath(__file__))
BEFORE = os.environ.get("STAGE4_BEFORE", os.path.join(S, "before"))  # git archive 1bb69b1 nvim latex, extracted outside any repo

HOOKS = r"""
  _G.newacc = function()
    return { src = 0, fuzzy = 0, xform = 0, oxform = 0, ft = 0, n = 0, nfz = 0, nx = 0, nox = 0, nft = 0,
             first_src = -1, first_ft = -1, first_fuzzy = -1, first_xform = -1 }
  end
  _G.ACC = _G.newacc()
  local function acc(field, nfield, firstfield, dt)
    _G.ACC[field] = _G.ACC[field] + dt; _G.ACC[nfield] = _G.ACC[nfield] + 1
    if firstfield and _G.ACC[firstfield] < 0 then _G.ACC[firstfield] = dt end
  end
  if not _G.HOOKED then
    _G.HOOKED = true
    local ls_src = require('blink.cmp.sources.snippets.luasnip')
    local orig = ls_src.get_completions
    ls_src.get_completions = function(self, ctx, cb)
      local t0 = vim.uv.hrtime()
      return orig(self, ctx, function(res) acc('src', 'n', 'first_src', (vim.uv.hrtime() - t0) / 1e6); cb(res) end)
    end
    local fz = require('blink.cmp.fuzzy'); local of = fz.fuzzy
    fz.fuzzy = function(...)
      local t0 = vim.uv.hrtime(); local r = of(...)
      acc('fuzzy', 'nfz', 'first_fuzzy', (vim.uv.hrtime() - t0) / 1e6); return r
    end
    local lib = require('blink.cmp.sources.lib')
    for _, id in ipairs({ 'snippets', 'omni' }) do
      local ok, prov = pcall(lib.get_provider_by_id, id)
      if ok and prov and prov.config and type(prov.config.transform_items) == 'function' then
        local ot = prov.config.transform_items
        local f, nf, ff = 'oxform', 'nox', nil
        if id == 'snippets' then f, nf, ff = 'xform', 'nx', 'first_xform' end
        prov.config.transform_items = function(ctx, items)
          local t0 = vim.uv.hrtime(); local r = ot(ctx, items)
          acc(f, nf, ff, (vim.uv.hrtime() - t0) / 1e6); return r
        end
      end
    end
    local okl, L = pcall(require, 'snippets.loader')
    if okl and type(L.filetypes) == 'function' then
      local oft = L.filetypes
      L.filetypes = function(...)
        local t0 = vim.uv.hrtime(); local r = oft(...)
        acc('ft', 'nft', 'first_ft', (vim.uv.hrtime() - t0) / 1e6); return r
      end
    end
  end
  return require('blink.cmp.fuzzy').implementation_type
"""

ROWS = r"""
  local n = ...
  local ok, list = pcall(require, 'blink.cmp.completion.list')
  if not ok then return {} end
  local out = {}
  for i, it in ipairs(list.items or {}) do
    if i > n then break end
    out[#out + 1] = { it.label or '', it.source_id or '', (it.labelDetails and it.labelDetails.description) or '',
                      it.score or -1, it.score_offset or 0 }
  end
  return out
"""


def install_hooks(v):
    """blink must be loaded: enter and leave insert mode once first."""
    v.insert(); v.escape()
    return v.lua(HOOKS)


def rows(v, n=40):
    return v.lua(ROWS, n)


def pct(xs, p):
    return sorted(xs)[min(len(xs) - 1, int(len(xs) * p))]


def mem(v, pid):
    heap = v.lua("collectgarbage('collect'); return collectgarbage('count') / 1024")
    rss = -1
    with open(f"/proc/{pid}/status") as fh:
        for line in fh:
            if line.startswith("VmRSS:"):
                rss = int(line.split()[1]) / 1024
    return heap, rss


def wait_menu(v, t0, limit=60.0):
    """seconds from t0 until blink's menu is visible (each poll is an RPC, so it returns only once
    Neovim's loop is free again); -1 if it never shows."""
    while time.perf_counter() - t0 < limit:
        if v.menu_visible():
            return time.perf_counter() - t0
        time.sleep(0.005)
    return -1
