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

-- Citation commands from french-logic.sty, and the biblatex commands they
-- alias, put through VimTeX's OWN reference machinery rather than
-- g:vimtex_syntax_custom_cmds.  That machinery is what gives \cite its
-- colour (texCmdRef for the command, texRefArg for the key) and, via the
-- texRefOpt chain, what lets a locator through: \tcite[p.~143]{key}.
--
-- Registering these as custom commands instead is wrong twice over -- the
-- command takes a semantic-object colour it has no claim to, and acmd()'s
-- opt=false makes the key fall out of texRefArg into texGroup as soon as a
-- locator appears.  Measured 2026-09-05 before the fix:
--   \cite{k}        texCmdRef / texRefArg      \tcite{k}       texCmdScaffold / texArgName
--   \cite[p]{k}     texCmdRef / texRefArg      \tcite[p]{k}    texCmdScaffold / texGroup
--
-- \textcite and \poscite are included because VimTeX's biblatex package
-- module never loads here: it keys on \usepackage{biblatex} in the .tex
-- preamble, and french-logic.sty requires biblatex indirectly, so the
-- module's own \textcite rule never fires.
vim.cmd([[
  syntax match texCmdRef nextgroup=texRefOpt,texRefArg skipwhite skipnl
    \ /\v\\%([tp]cite|[Tt]extcite|poscite)>/
]])
