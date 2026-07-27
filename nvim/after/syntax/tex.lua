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

-- Theorem-family statements (the .sty's \newtheorem declarations)
vim.cmd([[
  syntax match texEnvArgNameThm
    \ /\v<%(theorem|lemma|proposition|corollary|definition|example|remark|note|convention|observation|digression)>/
    \ contained containedin=texEnvArgName
  syntax match texEnvArgNameProof
    \ /\v<%(proofsketch|proof|gentzen|axiomproof)>/
    \ contained containedin=texEnvArgName
]])
