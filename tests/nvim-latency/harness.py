"""Shared pynvim harness for the nvim-latency suite.

Starts a real Neovim on the live config with a UI attached — without a UI
there is no screen, so no syntax evaluation and no redraw, and every timing
would be meaningless.

Two safety properties, both load-bearing:
  * persistence.nvim is disarmed, so attaching a UI cannot cause a session to
    be written for whatever directory the suite runs in;
  * everything happens on a copy of the fixture under $TMPDIR, because the
    config's auto-save writes on every change.
"""

import os
import shutil
import tempfile
import time

try:
    import pynvim
except ImportError:  # pragma: no cover - reported by run.sh
    raise SystemExit("pynvim not installed: python3 -m pip install --user pynvim")

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURE = os.path.join(HERE, "fixture.tex")


class Nvim:
    """A Neovim instance on a throwaway copy of the fixture."""

    def __init__(self, config_home=None, cache_root=None, gvars=None):
        self.tmp = tempfile.mkdtemp(prefix="nvim-latency-")
        self.doc = os.path.join(self.tmp, "fixture.tex")
        shutil.copy2(FIXTURE, self.doc)

        # NVIM_LATENCY_CONFIG points the suite at a different Neovim config
        # tree — used to mutation-test it against the pre-fix code, which is
        # the only way to know these checks are not vacuous.
        config_home = config_home or os.environ.get("NVIM_LATENCY_CONFIG")
        env_config = os.environ.pop("XDG_CONFIG_HOME", None)
        if config_home:
            os.environ["XDG_CONFIG_HOME"] = config_home
        os.environ["NVIM_NOSESSION"] = "1"
        self._saved_config_home = env_config

        cwd = os.getcwd()
        os.chdir(self.tmp)
        self.nvim = pynvim.attach("child", argv=["nvim", "--embed", "--headless"])
        os.chdir(cwd)
        self.nvim.ui_attach(200, 50, rgb=True, ext_linegrid=True)
        self._wait_ready()
        self.nvim.exec_lua("pcall(function() require('persistence').stop() end)")
        if cache_root:
            self.nvim.exec_lua("vim.g.vimtex_cache_root = select(1, ...)", cache_root)
        for k, v in (gvars or {}).items():
            self.nvim.exec_lua("vim.g[select(1,...)] = select(2,...)", k, v)

    def _wait_ready(self, timeout=90):
        t0 = time.time()
        while time.time() - t0 < timeout:
            try:
                if self.nvim.eval("v:vim_did_enter") == 1:
                    return
            except Exception:
                pass
            time.sleep(0.05)
        raise RuntimeError("nvim never entered")

    # -- convenience -----------------------------------------------------
    def open_fixture(self):
        self.nvim.command("edit " + self.doc)
        self.nvim.command("redraw")
        return self

    def lua(self, src, *a):
        return self.nvim.exec_lua(src, *a)

    def eval(self, expr):
        return self.nvim.eval(expr)

    def cmd(self, c):
        return self.nvim.command(c)

    def para_lines(self):
        """(lnum, length) for each long paragraph line, shortest first."""
        return self.lua("""
          local out = {}
          for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
            if #l > 300 then out[#out+1] = { i, #l } end
          end
          table.sort(out, function(a, b) return a[2] < b[2] end)
          return out
        """)

    def goto_end_of(self, lnum):
        n = self.lua("""
          local l = ...
          vim.api.nvim_win_set_cursor(0, { l, 0 })
          vim.cmd('normal! zz$')
          return #vim.api.nvim_get_current_line()
        """, lnum)
        self.cmd("redraw!")
        return n

    def type(self, text, per=0.30, settle=0.8):
        for ch in text:
            self.nvim.input(ch)
            self.cmd("redraw")
            time.sleep(per)
        time.sleep(settle)

    def menu_visible(self):
        return self.lua(
            "local ok, c = pcall(require, 'blink.cmp') "
            "if not ok then return false end "
            "return (c.is_visible and c.is_visible()) and true or false")

    def insert(self):
        self.nvim.input("a")
        self.cmd("redraw")
        time.sleep(0.4)

    def escape(self):
        self.nvim.input("\x1b")
        self.cmd("redraw")
        time.sleep(0.3)

    def reset_tail(self, lnum, text="Fixture scratch line."):
        """Put a short known line at lnum and park the cursor at its end."""
        self.escape()
        self.lua("""
          local l, t = ...
          vim.api.nvim_buf_set_lines(0, l - 1, l, false, { t })
          vim.api.nvim_win_set_cursor(0, { l, 0 })
          vim.cmd('normal! $')
        """, lnum, text)
        self.insert()

    def close(self):
        try:
            self.cmd("qa!")
        except Exception:
            pass
        shutil.rmtree(self.tmp, ignore_errors=True)
        os.environ.pop("XDG_CONFIG_HOME", None)
        if self._saved_config_home is not None:
            os.environ["XDG_CONFIG_HOME"] = self._saved_config_home


class Checks:
    """`ok  - ` / `FAIL- ` reporting, matching the other suites' conventions."""

    def __init__(self):
        self.passed = 0
        self.failed = 0

    def check(self, desc, got, want):
        if got == want:
            self.passed += 1
            print(f"ok   - {desc}")
        else:
            self.failed += 1
            print(f"FAIL - {desc}  (got {got!r}, want {want!r})")

    def report(self):
        print(f"\npassed: {self.passed}  failed: {self.failed}")
        return 1 if self.failed else 0
