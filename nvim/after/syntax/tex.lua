-- after/syntax/tex.lua
-- Per-family colouring of french-logic environment names.
--
-- Layered on top of VimTeX's texEnvArgName (the {...} after \begin/\end)
-- via containedin, so these two matches run only inside those braces —
-- negligible syntax-matching cost on large documents.  Colours for the
-- groups live with the other custom groups in after/ftplugin/tex.lua.
--
-- Deliberately NOT done with g:vimtex_syntax_custom_envs: its non-math
-- regions replace the environment body's contains-list, which would
-- swallow all highlighting inside theorem/proof bodies.
--
-- List/layout environments (hilbertlist, romanlist, block, ...) keep the
-- default texEnvArgName cyan on purpose.

-- The document dimension is one green SPECTRUM (docs/
-- latex-register-taxonomy.md): landmarks > loaded structure >
-- containers > scaffolding.  Theorem-family statements are
-- side-neutral loaded structure: landmarks, green-bold with
-- sectioning.  Proof-family environments and hilbertlist are loaded
-- structure: the mint rung.  (Borrowing the content side's colour for
-- loaded envs was tried and retired 2026-08-28 — it made hilbertlist
-- impersonate the system names and failed the glance test.)
vim.cmd([[
  syntax match texEnvArgNameThm
    \ /\v<%(theorem|lemma|proposition|corollary|definition|example|remark|note|convention|observation|digression)>/
    \ contained containedin=texEnvArgName
  syntax match texEnvArgNameLoaded
    \ /\v<%(proofsketch|proof|gentzen|axiomproof|hilbertlist)>/
    \ contained containedin=texEnvArgName
]])
