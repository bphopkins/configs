return {
  "lervag/vimtex",
  -- Eager on purpose: VimTeX's own docs say not to lazy-load it (it manages
  -- filetype detection itself).  An `ft = {...}` key used to sit here too —
  -- inert, since an explicit lazy=false wins over any trigger, so it only
  -- misled readers into thinking the plugin was filetype-gated.
  lazy = false,

  init = function()
    -- Throws if another instance already owns the socket (inverse search
    -- then targets that instance); unguarded, the error would abort this
    -- whole init() and silently drop every setting below.
    pcall(vim.fn.serverstart, "/tmp/nvimsocket")

    --------------------------------------------------------------------
    -- VIEWER / COMPILER
    --------------------------------------------------------------------
    vim.g.vimtex_view_method = "general"
    vim.g.vimtex_view_general_viewer = "okular-forward"
    vim.g.vimtex_view_general_options = "@pdf @line @tex"
    vim.g.vimtex_view_automatic = 1
    vim.g.vimtex_compiler_method = "latexmk"

    --------------------------------------------------------------------
    -- INCLUDE SCANNING / COMPLETION
    --------------------------------------------------------------------
    -- Eight settings once sat here (root_markers, texmf_home,
    -- includegraphics_search_paths, complete_{recursive_bib,input_paths,
    -- scan_files_depth}, include_search_paths, compiler_progname) — none
    -- is a VimTeX option (the last was deprecated upstream 2021), so
    -- none ever had an effect.  Root/main-file detection is VimTeX's
    -- own heuristics; don't re-add plausible-looking option names.
    vim.g.vimtex_include_search_enabled = 1
    vim.g.vimtex_complete_enabled = 1
    vim.g.vimtex_complete_close_braces = 1

    --------------------------------------------------------------------
    -- INDENTATION / KEYMAPS / UI TWEAKS
    --------------------------------------------------------------------
    vim.g.vimtex_indent_enabled = 1
    vim.g.vimtex_imaps_enabled = 1
    vim.g.vimtex_quickfix_mode = 0
    vim.g.vimtex_syntax_conceal_disable = 1
    vim.g.tex_flavor = "latex"

    --------------------------------------------------------------------
    -- MATCHPAREN: NORMAL MODE ONLY
    --
    -- VimTeX's matchparen hooks CursorMovedI, and its highlight() does a
    -- vimtex#syntax#in_comment() synstack probe plus a delimiter search —
    -- both of which scale with the length of the *logical* line.  On a
    -- paragraph-per-line document that is the dominant per-keystroke cost:
    -- measured 62 ms of a 212 ms keystroke at the end of an 1860-char
    -- paragraph (fedxps, 2026-08-22).
    --
    -- Neovim's own matchparen is left alone and costs ~0 here — it returns
    -- immediately unless the cursor sits on a bracket, which at the end of
    -- a prose line it does not.
    --
    -- Toggled through VimTeX's public API rather than by clearing its
    -- autocmds, so nothing depends on its internal augroup naming.  You
    -- keep $…$, \begin/\end and \left/\right matching in normal mode,
    -- where you are actually looking at delimiters.
    --------------------------------------------------------------------
    vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("VimtexMatchparenInsertOff", { clear = true }),
      pattern = { "*.tex", "*.latex", "*.sty", "*.cls" },
      callback = function(ev)
        -- VimTeX creates its per-buffer matchparen augroup only when the
        -- feature is enabled, and disable() clears that group by name — so
        -- calling it when the feature is off raises E216 on *every*
        -- InsertEnter, which is loud and baffling.  Guard on the option, and
        -- pcall as a backstop for any other buffer VimTeX never claimed.
        if vim.g.vimtex_matchparen_enabled == 0 then
          return
        end
        if vim.fn.exists("*vimtex#matchparen#disable") == 0 then
          return
        end
        local fn = ev.event == "InsertEnter" and "vimtex#matchparen#disable"
          or "vimtex#matchparen#enable"
        pcall(vim.fn[fn])
      end,
    })

    --------------------------------------------------------------------
    -- CUSTOM SYNTAX COMMANDS
    --
    -- Registers french-logic.sty macros (plus a few stock families) into
    -- semantic highlight groups.  Uses `cmdre` (Vim regex on the command
    -- name, no backslash) to collapse repetitive families.  Corresponding
    -- hl() definitions are in after/ftplugin/tex.lua.
    --
    -- The scheme is a scope/type ladder (2026-08-28 redesign):
    --   texCmdTurnstile  metalinguistic relations: ⊢ ⊩ ⊨ ⩴, sequent
    --                    arrows, signed-formula forces — widest scope,
    --                    brightest cool
    --   texCmdIntension  intensional operators, monadic and dyadic:
    --                    O, P, □, ◇, □→, O(·/·), stit, K, B, G, H
    --   texCmdSemObj     semantic objects: models, frames, functions,
    --                    truth/proof sets, languages, theories — the
    --                    coloured family the eye tracks (teal-green)
    --   texCmdGround     object-language glue: connectives and
    --                    set-theoretic plumbing — same tone as stock
    --                    texMathCmd, so \to matches \land and origin
    --                    (.sty vs kernel) never shows
    --   texCmdVariable   Greek letters — variables are body-toned like
    --                    their roman siblings (A, w), not command-toned
    --   texCmdNameSyn    names of syntactic objects: axiom schemata,
    --                    systems, rules, frameworks (warm, bold)
    --   texCmdNameSem    names of semantic objects: frame and order
    --                    conditions (warm, plain — correspondence rung)
    --   texCmdScaffold   proof-tree and table scaffolding
    --   texCmdQed        end-of-proof markers (proof-family magenta)
    --
    -- Standard math symbols (\in, \subseteq, \neg, ...) are NOT
    -- registered here: texMathCmd itself is restyled to the Ground tone,
    -- so an unregistered macro lands in the plumbing colour.  A new
    -- SEMANTIC-OBJECT macro therefore needs a SemObj line to take its
    -- teal — the coverage cross-check flags it.  Greek letters are
    -- lifted OUT of the plumbing tone by the greekfam pattern below.
    --
    -- Deliberately unregistered (not oversights): \versal, \sketchqed,
    -- \remarkqed (internal helpers, unused outside the .sty) and
    -- \inf/\infer (renames of TeX built-ins, retired with gentzen).
    -- Also \tcite/\pcite: they are citation commands, and are hooked
    -- into VimTeX's own texCmdRef machinery in after/syntax/tex.lua so
    -- they colour identically to \cite.  Registering them here instead
    -- gave the command texCmdScaffold and the key texArgName, and the
    -- opt=false in acmd() dropped the key to texGroup whenever a
    -- locator was present (\tcite[p.~7]{key}).
    --
    -- Note on cmdre: patterns are embedded verbatim into a "\v"
    -- (very magic) syntax match with NO implicit trailing ">", so
    -- write an explicit ">" when a pattern must not match longer
    -- command names (e.g. the de-family must not catch \defby).
    -- Later entries take priority over earlier ones (used below to
    -- carve \ccred out of ccmfam and booktabs rules out of rulefam).
    --------------------------------------------------------------------

    local G = {
      tse = "texCmdTurnstileSem",
      tsy = "texCmdTurnstileSyn",
      op = "texCmdIntension",
      gr = "texCmdGround",
      cn = "texCmdConnective",
      so = "texCmdSemObj",
      syo = "texCmdSynObj",
      var = "texCmdVariable",
      nsy = "texCmdNameSyn",
      nse = "texCmdNameSem",
      sc = "texCmdScaffold",
      qed = "texCmdQed",
      argf = "texArgFormula",
      argn = "texArgName",
      argso = "texArgSemObj",
      argsyo = "texArgSynObj",
    }

    -- Helpers
    --
    -- VimTeX requires `name` on EVERY entry — it derives the syntax-group
    -- names from it, and new_cmd() silently drops nameless entries.  When
    -- `cmdre` is present it overrides only the match, so pattern helpers
    -- (re/mre/mare) take an explicit group-name slug as first argument.
    --
    -- VimTeX's `argstyle` key accepts only bold/ital/... keywords, not
    -- highlight groups, so argument colouring is wired via arglink():
    -- it precomputes the generated argument-group names and records the
    -- intended links in `french_logic_arg_links`, which
    -- after/ftplugin/tex.lua applies (it runs after the colorscheme, so
    -- the links survive the scheme's `:hi clear`).
    local arg_links = {}
    local function arglink(name, mathmode, group)
      local cname = "C" .. name:sub(1, 1):upper() .. name:sub(2)
      local pre = mathmode and "texMath" or "tex"
      arg_links[pre .. cname .. "Arg"] = group
      arg_links[pre .. cname .. "ArgChar"] = group
    end

    -- Symbol entries (cmd/re/mcmd/mre) declare opt=false, arg=false:
    -- VimTeX's default argument machinery emits a zero-width ArgSpace
    -- match after every command, which BLOCKS the next match when two
    -- commands are directly adjacent (\M\nmodels lost its colour on
    -- the second command under the old scheme).  Only the arg-taking
    -- entries (acmd/macmd/mare) keep the machinery — there a brace
    -- always intervenes, so adjacency never bites.
    local function cmd(name, hlgroup)
      return { name = name, hlgroup = hlgroup, opt = false, arg = false }
    end
    local function re(name, pattern, hlgroup)
      return { name = name, cmdre = pattern, hlgroup = hlgroup, opt = false, arg = false }
    end
    local function mcmd(name, hlgroup)
      return { name = name, mathmode = true, hlgroup = hlgroup, opt = false, arg = false }
    end
    local function mre(name, pattern, hlgroup)
      return {
        name = name,
        cmdre = pattern,
        mathmode = true,
        hlgroup = hlgroup,
        opt = false,
        arg = false,
      }
    end
    local function acmd(name, hlgroup, arggroup)
      arglink(name, false, arggroup)
      return { name = name, hlgroup = hlgroup, opt = false }
    end
    local function macmd(name, hlgroup, arggroup)
      arglink(name, true, arggroup)
      return { name = name, mathmode = true, hlgroup = hlgroup, opt = false }
    end
    local function mare(name, pattern, hlgroup, arggroup)
      arglink(name, true, arggroup)
      return { name = name, cmdre = pattern, mathmode = true, hlgroup = hlgroup, opt = false }
    end

    vim.g.vimtex_syntax_custom_cmds = {

      ----------------------------------------------------------------
      -- NAMES OF SYNTACTIC OBJECTS  (texCmdNameSyn)
      -- axiom schemata, logic systems, rule names, framework names —
      -- one warm bold identity; system-vs-axiom ambiguity never shows
      ----------------------------------------------------------------
      -- CM_R, CM_L, CC_R, CC_L schema families (40 commands → 1 pattern)
      re("CCMfam", "C[CM][rl]\\w*", G.nsy),
      -- CN schema family
      re("CNfam", "CN[rl]\\w*", G.nsy),
      -- Other conditional-axiom labels
      cmd("cdax", G.nsy),
      cmd("CP", G.nsy),
      cmd("CPs", G.nsy),
      cmd("CTh", G.nsy),
      cmd("cduax", G.nsy),
      -- Classical modal axiom labels + parenthesized + converse
      -- Base: Xax, Xaxpar, Xaxc (where X ∈ {c,k,d,t,u,p,w,n})
      re("axfam", "[ckdtupwn]ax\\w*", G.nsy),
      -- ds/ps/po/pos variants
      cmd("dsax", G.nsy),
      cmd("psax", G.nsy),
      cmd("poax", G.nsy),
      cmd("posax", G.nsy),
      cmd("woax", G.nsy),
      cmd("wocax", G.nsy),
      -- maxi family
      re("maxifam", "maxi\\w*", G.nsy),
      -- duax family
      re("duaxfam", "duax\\w*", G.nsy),
      -- Compound axiom labels: ccax, cnax, cmaxi
      cmd("ccax", G.nsy),
      cmd("cnax", G.nsy),
      cmd("cmaxi", G.nsy),
      -- I/O logic constraints
      cmd("TOP", G.nsy),
      cmd("SI", G.nsy),
      cmd("WO", G.nsy),
      cmd("AND", G.nsy),
      cmd("OR", G.nsy),
      cmd("CT", G.nsy),
      cmd("Ts", G.nsy),
      cmd("SIs", G.nsy),
      cmd("WOs", G.nsy),
      cmd("ANDs", G.nsy),
      cmd("ORs", G.nsy),
      cmd("CTs", G.nsy),
      -- CE-family conditional logics (CE, CEM, CEMD, CEMP, ...)
      re("CEfam", "CE\\w*", G.nsy),
      -- CK-family
      re("CKfam", "CK\\w*", G.nsy),
      -- Other conditional systems
      cmd("VW", G.nsy),
      cmd("Slog", G.nsy),
      -- Classical modal: K, D, T, B compound systems
      -- (single-letter ones need individual entries to avoid clashing)
      cmd("K", G.nsy),
      cmd("D", G.nsy),
      cmd("T", G.nsy),
      cmd("B", G.nsy),
      cmd("four", G.nsy),
      cmd("five", G.nsy),
      re("Kfam", "K[DTBDUW]\\w*", G.nsy),
      -- Kfour, Kfive, Kfourfive; Kfam also covers the KD*ought systems
      re("Kffam", "Kf\\w*", G.nsy),
      cmd("Sfour", G.nsy),
      cmd("Sfive", G.nsy),
      -- Non-normal: E-family
      cmd("E", G.nsy),
      re("Efam", "E[MCN][DNPC]*", G.nsy),
      -- Deontic systems
      re("SDLfam", "SDL\\w*", G.nsy),
      cmd("COc", G.nsy),
      acmd("COvf", G.nsy, G.argn),
      -- I/O logics
      cmd("IO", G.nsy),
      acmd("IOn", G.nsy, G.argn),
      acmd("IOh", G.nsy, G.argn),
      acmd("IOhn", G.nsy, G.argn),
      cmd("IOs", G.nsy),
      acmd("IOsn", G.nsy, G.argn),
      acmd("IOfn", G.nsy, G.argn),
      -- Detachment-principle names
      cmd("FDio", G.nsy),
      cmd("DDio", G.nsy),
      -- Rule names + parenthesized variants (32 commands → 1 pattern;
      -- booktabs \toprule etc. are carved back out by booktabsfam below)
      re("rulefam", "\\w*rule\\w*", G.nsy),
      -- Possibility-rule names: rmposs, reposs, rposs + par variants
      re("rpossfam", "r[me]?poss\\w*", G.nsy),
      -- Consequence-framework names (Set-Set, Set-Fmla, ...)
      cmd("setset", G.nsy),
      cmd("setfmla", G.nsy),
      cmd("fmlaset", G.nsy),
      cmd("fmlafmla", G.nsy),

      ----------------------------------------------------------------
      -- NAMES OF SEMANTIC OBJECTS  (texCmdNameSem)
      -- frame conditions and order conditions — the correspondence rung
      ----------------------------------------------------------------
      -- cm_r, cm_l, cc_r, cc_l families (40 commands → 1 pattern)
      -- (\ccred is also matched, but its own later entry wins priority)
      -- Slug must NOT be "ccmfam": Vim group names are case-INsensitive,
      -- so it would merge with CCMfam's group and inherit the schema
      -- colour — the old scheme had exactly that bug, which is why
      -- \cmr rendered gold-bold instead of amber.
      re("ccmcond", "c[cm][rl]\\w*", G.nse),
      -- cn, ct families
      cmd("cnr", G.nse),
      cmd("cnl", G.nse),
      cmd("cnlr", G.nse),
      re("cthfam", "cth\\w*", G.nse),
      -- Order conditions on frames: Rup, Rdown, Lup, Ldown
      re("orderfam", "[RL]%(up|down)>", G.nse),

      ----------------------------------------------------------------
      -- SEMANTIC RELATIONS  (texCmdTurnstileSem)
      -- satisfaction and validity — the bright pole of the cool side
      ----------------------------------------------------------------
      mcmd("trues", G.tse),
      mcmd("ntrues", G.tse),
      mcmd("models", G.tse),
      mcmd("nmodels", G.tse),
      mcmd("mmodels", G.tse),
      mcmd("mnmodels", G.tse),
      macmd("mtruesat", G.tse, G.argf),
      macmd("mntruesat", G.tse, G.argf),
      macmd("modelsrel", G.tse, G.gr),
      -- Natural-language entailment and bisimulation: semantic side
      mcmd("natent", G.tse),
      mcmd("nnatent", G.tse),
      mcmd("bisim", G.tse),

      ----------------------------------------------------------------
      -- DERIVABILITY RELATIONS  (texCmdTurnstileSyn)
      -- ⊢ and its kin — the bright pole of the warm side
      ----------------------------------------------------------------
      mcmd("proves", G.tsy),
      mcmd("nproves", G.tsy),
      mcmd("gives", G.tsy),
      mcmd("asserts", G.tsy),
      mcmd("derives", G.tsy),
      mre("provesfam", "proves\\w*", G.tsy),
      macmd("provesrel", G.tsy, G.gr),
      -- Sequent arrows
      mcmd("seq", G.tsy),
      mcmd("tseq", G.tsy),

      ----------------------------------------------------------------
      -- INTENSIONAL OPERATORS  (texCmdIntension)
      -- monadic and dyadic modalities — the subject matter
      ----------------------------------------------------------------
      -- Dyadic conditional connectives
      mcmd("cnecs", G.op),
      mcmd("cposs", G.op),
      mcmd("cnecsolo", G.op),
      mcmd("cpossolo", G.op),
      -- Deontic conditional connectives
      mcmd("cobs", G.op),
      mcmd("cperms", G.op),
      mcmd("cobsolo", G.op),
      acmd("condop", G.op, G.op),
      acmd("condopsolo", G.op, G.op),
      -- Monadic modal operators
      mcmd("nec", G.op),
      mcmd("poss", G.op),
      mcmd("neced", G.op),
      mcmd("unneced", G.op),
      mcmd("possed", G.op),
      mcmd("unpossed", G.op),
      -- Counterfactual / strict
      mcmd("cfact", G.op),
      mcmd("sphere", G.op),
      mcmd("strictif", G.op),
      -- Deontic operators
      mcmd("ought", G.op),
      mcmd("may", G.op),
      mcmd("obligatory", G.op),
      mcmd("permissible", G.op),
      mcmd("forbidden", G.op),
      mcmd("gratuitous", G.op),
      mcmd("optional", G.op),
      macmd("cought", G.op, G.argf),
      macmd("better", G.op, G.argf),
      macmd("samevas", G.op, G.argf),
      -- Epistemic operators
      mcmd("know", G.op),
      mcmd("believe", G.op),
      mcmd("cknow", G.op),
      mcmd("cbelieve", G.op),
      macmd("knows", G.op, G.argf),
      macmd("believes", G.op, G.argf),
      macmd("cknows", G.op, G.argf),
      macmd("cbelieves", G.op, G.argf),
      -- Temporal operators
      mcmd("hitherto", G.op),
      mcmd("henceforth", G.op),
      mcmd("was", G.op),
      mcmd("willbe", G.op),
      -- Affirm/deny (signed-formula) forces: af, aff, affirm,
      -- afland, aflor, afneg, afto + the matching de family
      mre("affam", "af\\w*", G.op),
      mre("defam", "de%(land|lor|neg|to|ny|n)?>", G.op),
      -- I/O-style conditional
      mcmd("ecu", G.op),
      -- STIT operators
      mcmd("stit", G.op),
      mcmd("cstito", G.op),
      mcmd("dstito", G.op),
      mcmd("stitought", G.op),
      macmd("cstit", G.op, G.argf),
      macmd("dstit", G.op, G.argf),
      -- Triggers / necessitates
      mcmd("necessitates", G.op),
      mcmd("triggers", G.op),

      ----------------------------------------------------------------
      -- SEMANTIC OBJECTS  (texCmdSemObj) — cool blue
      -- the interpreting machinery: models, frames, neighborhood
      -- functions, truth sets, valuations, truth values, STIT
      -- structures.  The canonical-model family (\Mlog, \flog, ...)
      -- is semantic IN KIND though built from syntax — that is the
      -- point of it.
      ----------------------------------------------------------------
      -- Truth sets ⟦A⟧  (truthset, truthsetm, truthsetml, etc.)
      mare("truthsetfam", "truthset\\w*", G.so, G.argso),
      macmd("emptytruthset", G.so, G.argso),
      -- Double-bar truth sets ‖A‖
      mare("ctruthsetfam", "ctruthset\\w*", G.so, G.argso),
      -- Model-theoretic structure letters
      mcmd("M", G.so),
      mcmd("F", G.so),
      mcmd("A", G.so),
      mcmd("C", G.so),
      mcmd("R", G.so),
      -- Canonical model notation (Mlog, Wlog, Rlog, flog, Vlog)
      mre("logfam", "[MWfVR]log", G.so),
      -- Frame variants: FR*, FN*, MRel, MN*
      mre("Ffam", "F[RN]\\w*", G.so),
      mre("Mfam", "M[NR]\\w*", G.so),
      -- Sigma-variants
      mre("sigfam", "[MWRV]sig", G.so),
      -- Closure/supplementation arrow variants
      mre("arrowfam", "[Mf][nesw][ew]", G.so),
      mre("lrfam", "[Mf]lr", G.so),
      -- Named functions on frames: fn, fm, fd, fs, fr, fsub, fnof, fsof
      macmd("fn", G.so, G.argso),
      macmd("fm", G.so, G.argso),
      macmd("fd", G.so, G.argso),
      macmd("fs", G.so, G.argso),
      macmd("fr", G.so, G.argso),
      macmd("fsub", G.so, G.argso),
      macmd("fnof", G.so, G.argso),
      macmd("fsof", G.so, G.argso),
      -- Valuation
      macmd("val", G.so, G.argso),
      macmd("vw", G.so, G.argso),
      macmd("Val", G.so, G.argso),
      -- Distinguished truth values
      cmd("true", G.so),
      cmd("false", G.so),
      cmd("ind", G.so),
      -- Probability / credence (ccred wins back over ccmfam by order)
      macmd("cprob", G.so, G.argso),
      macmd("cred", G.so, G.argso),
      macmd("ccred", G.so, G.argso),

      ----------------------------------------------------------------
      -- SYNTACTIC OBJECTS  (texCmdSynObj) — warm
      -- proof-theoretic material: proof sets, equivalence classes of
      -- formulas, languages, logics, the formula algebra, maximal
      -- consistent sets, consequence, I/O out(·)
      ----------------------------------------------------------------
      -- Proof sets [A] and equivalence classes |A|
      mare("proofsetfam", "proofset\\w*", G.syo, G.argsyo),
      macmd("eclass", G.syo, G.argsyo),
      macmd("eclassl", G.syo, G.argsyo),
      -- Language symbols — explicit alternation, NOT lang\w*: that
      -- pattern also captured stock \langle (splitting it from \rangle),
      -- and an explicit list keeps the coverage cross-check exact
      mre("langfam", "lang%(p|m|d|md)?>", G.syo),
      mcmd("Lc", G.syo),
      mcmd("logic", G.syo),
      mcmd("logicp", G.syo),
      -- Term algebra / atoms-of-the-language
      mcmd("Fm", G.syo),
      mcmd("atoms", G.syo),
      mcmd("props", G.syo),
      -- Maximal consistent set notation
      cmd("mcslog", G.syo),
      macmd("mcseti", G.syo, G.argsyo),
      -- Consequence / theory
      macmd("cn", G.syo, G.argsyo),
      macmd("theory", G.syo, G.argsyo),
      -- I/O functions
      macmd("iput", G.syo, G.argsyo),
      macmd("oput", G.syo, G.argsyo),
      macmd("oputi", G.syo, G.argsyo),
      macmd("deriv", G.syo, G.argsyo),
      macmd("derivi", G.syo, G.argsyo),
      -- Short model-definition macros
      cmd("mwrv", G.so),
      cmd("mwrp", G.so),
      cmd("mwnv", G.so),
      cmd("mwnp", G.so),
      -- STIT model components (Tree, Agent, Choice, Value)
      cmd("tree", G.so),
      cmd("agent", G.so),
      cmd("choice", G.so),
      cmd("stitval", G.so),
      mcmd("choicema", G.so),

      ----------------------------------------------------------------
      -- OBJECT-LANGUAGE CONNECTIVES  (texCmdConnective)
      -- The gray saddle has two banks (2026-08-28): boolean glue of the
      -- OBJECT language takes the material's warm bank — tan, roman —
      -- so formulas cohere warm; metalanguage/set glue keeps the cool
      -- steel below.  One pattern registers the stock booleans (a
      -- literal "top" entry would collide case-insensitively with the
      -- \TOP axiom's group — hence cmdre, with explicit >).
      ----------------------------------------------------------------
      mcmd("iff", G.cn),
      mcmd("onlyif", G.cn),
      mcmd("then", G.cn),
      mcmd("to", G.cn),
      mcmd("minus", G.cn),
      mcmd("hk", G.cn),
      -- Typed connective variants (intuitionist/classical)
      mcmd("ito", G.cn),
      mcmd("cto", G.cn),
      mcmd("ilor", G.cn),
      mcmd("clor", G.cn),
      -- Stock booleans and logical constants join the same bank
      mre("stockbool", "%(land|lor|neg|lnot|top|bot|equiv|wedge|vee)>", G.cn),

      ----------------------------------------------------------------
      -- METALANGUAGE GLUE  (texCmdGround)
      -- set-theoretic plumbing and metalanguage idiom — the saddle's
      -- cool bank, shared with stock texMathCmd
      ----------------------------------------------------------------
      -- Metalanguage connectives (mland, mlor, mlto, mlnot, mlforall,
      -- mlexists + the six *solo variants)
      mre("mlfam", "ml\\w*", G.gr),
      -- The metalanguage named as a language of its own — the R2
      -- borderline case; gray with its connectives
      mcmd("metalogic", G.gr),
      -- Order / lattice notation and the empty set: ambient set theory
      mcmd("topg", G.gr),
      mcmd("botg", G.gr),
      mcmd("topt", G.gr),
      mcmd("bott", G.gr),
      mcmd("filter", G.gr),
      mcmd("emptyset", G.gr),
      -- Set-theoretic notation (braces and operations; contents are
      -- formulas/terms, so args read as math body)
      macmd("set", G.gr, G.argf),
      macmd("oset", G.gr, G.argf),
      macmd("tuple", G.gr, G.argf),
      macmd("power", G.gr, G.argf),
      macmd("Cl", G.gr, G.argf),
      mcmd("intersect", G.gr),
      mcmd("union", G.gr),
      mcmd("inclin", G.gr),
      -- Definition signs and the ⊢/⊨ interface glyph: metalanguage
      -- interface material, gray like the rest of the glue
      mcmd("defby", G.gr),
      mcmd("defbyvar", G.gr),
      mcmd("ent", G.gr),
      -- Misc notation
      mcmd("suchthat", G.gr),
      cmd("st", G.gr),
      mcmd("dvbar", G.gr),
      acmd("parent", G.gr, G.argn),
      mcmd("wedgeset", G.gr),
      mcmd("tightwedge", G.gr),
      mcmd("precedes", G.gr),

      ----------------------------------------------------------------
      -- VARIABLES  (texCmdVariable)
      -- Greek letters are variables like their roman siblings — body
      -- tone, not command tone (explicit > so nothing prefix-matches)
      ----------------------------------------------------------------
      mre(
        "greekfam",
        "%(alpha|beta|gamma|delta|epsilon|varepsilon|zeta|eta|theta|vartheta"
          .. "|iota|kappa|lambda|mu|nu|xi|pi|varpi|rho|varrho|sigma|varsigma"
          .. "|tau|upsilon|phi|varphi|chi|psi|omega|Gamma|Delta|Theta|Lambda"
          .. "|Xi|Pi|Sigma|Upsilon|Phi|Psi|Omega|ell)>",
        G.var
      ),
      -- Propositional atoms p0..p3 are object-language variables too
      mcmd("pzero", G.var),
      mcmd("pone", G.var),
      mcmd("ptwo", G.var),
      mcmd("pthree", G.var),

      ----------------------------------------------------------------
      -- SCAFFOLDING AND MARKERS
      ----------------------------------------------------------------
      -- Proof-tree helpers (gentzen)
      acmd("hyp", G.sc, G.argf),
      cmd("hyphantom", G.sc),
      cmd("infr", G.sc),
      cmd("close", G.sc),
      mcmd("incomp", G.sc),
      -- Right-margin justifications: \by{(\CMla)}, \by{MP, 1, 2}
      acmd("by", G.sc, G.argn),
      -- booktabs rules are table scaffolding, not derivation rules
      -- (later entry wins over rulefam)
      re("booktabsfam", "%(top|mid|bottom|cmid)rule>", G.sc),
      -- End-of-proof markers (kin to the proof-environment family)
      cmd("qed", G.qed),
    }

    -- Argument-group links accumulated by acmd/macmd/mare above;
    -- applied by after/ftplugin/tex.lua.
    vim.g.french_logic_arg_links = arg_links
  end,
}
