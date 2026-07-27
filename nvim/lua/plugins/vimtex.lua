return {
  "lervag/vimtex",
  lazy = false,
  ft = { "tex", "plaintex", "latex" },

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
    -- CUSTOM SYNTAX COMMANDS
    --
    -- Registers french-logic.sty macros into semantic highlight groups.
    -- Uses `cmdre` (Vim regex on the command name, no backslash) to
    -- collapse repetitive families.  Corresponding hl() definitions
    -- are in after/ftplugin/tex.lua.
    --
    -- Standard math symbols (\omega, \subseteq, etc.) are NOT
    -- registered here.  They are already caught by VimTeX's built-in
    -- texMathCmd group, which the ftplugin restyles to periwinkle.
    --
    -- Deliberately unregistered (not oversights): \versal, \sketchqed,
    -- \remarkqed (internal helpers, unused outside the .sty) and
    -- \inf/\infer (renames of TeX built-ins, retired with gentzen).
    --
    -- Note on cmdre: patterns are embedded verbatim into a "\v"
    -- (very magic) syntax match with NO implicit trailing ">", so
    -- write an explicit ">" when a pattern must not match longer
    -- command names (e.g. the de-family must not catch \defby).
    --------------------------------------------------------------------

    local G = {
      ax = "texCmdAxiom",
      fc = "texCmdFrameCond",
      ls = "texCmdLogicSys",
      sem = "texCmdSemantic",
      mo = "texCmdModalOp",
      ru = "texCmdRule",
      nt = "texCmdNotation",
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

    local function cmd(name, hlgroup)
      return { name = name, hlgroup = hlgroup }
    end
    local function re(name, pattern, hlgroup)
      return { name = name, cmdre = pattern, hlgroup = hlgroup }
    end
    local function mcmd(name, hlgroup)
      return { name = name, mathmode = true, hlgroup = hlgroup }
    end
    local function mre(name, pattern, hlgroup)
      return { name = name, cmdre = pattern, mathmode = true, hlgroup = hlgroup }
    end
    local function acmd(name, hlgroup, arggroup)
      arglink(name, false, arggroup)
      return { name = name, hlgroup = hlgroup }
    end
    local function macmd(name, hlgroup, arggroup)
      arglink(name, true, arggroup)
      return { name = name, mathmode = true, hlgroup = hlgroup }
    end
    local function mare(name, pattern, hlgroup, arggroup)
      arglink(name, true, arggroup)
      return { name = name, cmdre = pattern, mathmode = true, hlgroup = hlgroup }
    end

    vim.g.vimtex_syntax_custom_cmds = {

      ----------------------------------------------------------------
      -- AXIOM SCHEMA LABELS  (texCmdAxiom)
      ----------------------------------------------------------------
      -- CM_R, CM_L, CC_R, CC_L families (40 commands → 1 pattern)
      re("CCMfam", "C[CM][rl]\\w*", G.ax),
      -- CN family
      re("CNfam", "CN[rl]\\w*", G.ax),
      -- Other axiom labels
      cmd("cdax", G.ax),
      cmd("CP", G.ax),
      cmd("CPs", G.ax),
      cmd("CTh", G.ax),
      cmd("cduax", G.ax),
      -- Classical modal axiom labels + parenthesized + converse
      -- Base: Xax, Xaxpar, Xaxc (where X ∈ {c,k,d,t,u,p,w,n})
      re("axfam", "[ckdtupwn]ax\\w*", G.ax),
      -- ds/ps/po/pos variants
      cmd("dsax", G.ax),
      cmd("psax", G.ax),
      cmd("poax", G.ax),
      cmd("posax", G.ax),
      cmd("woax", G.ax),
      cmd("wocax", G.ax),
      -- maxi family
      re("maxifam", "maxi\\w*", G.ax),
      -- duax family
      re("duaxfam", "duax\\w*", G.ax),
      -- Compound axiom labels: ccax, cnax, cmaxi
      cmd("ccax", G.ax),
      cmd("cnax", G.ax),
      cmd("cmaxi", G.ax),
      -- I/O logic constraints
      cmd("TOP", G.ax),
      cmd("SI", G.ax),
      cmd("WO", G.ax),
      cmd("AND", G.ax),
      cmd("OR", G.ax),
      cmd("CT", G.ax),
      cmd("Ts", G.ax),
      cmd("SIs", G.ax),
      cmd("WOs", G.ax),
      cmd("ANDs", G.ax),
      cmd("ORs", G.ax),
      cmd("CTs", G.ax),

      ----------------------------------------------------------------
      -- FRAME CONDITION LABELS  (texCmdFrameCond)
      ----------------------------------------------------------------
      -- cm_r, cm_l, cc_r, cc_l families (40 commands → 1 pattern)
      -- (\ccred is also matched, but its own later entry wins priority)
      re("ccmfam", "c[cm][rl]\\w*", G.fc),
      -- cn, ct families
      cmd("cnr", G.fc),
      cmd("cnl", G.fc),
      cmd("cnlr", G.fc),
      re("cthfam", "cth\\w*", G.fc),
      -- Order conditions on frames: Rup, Rdown, Lup, Ldown
      re("orderfam", "[RL]%(up|down)>", G.fc),

      ----------------------------------------------------------------
      -- LOGIC SYSTEM NAMES  (texCmdLogicSys)
      ----------------------------------------------------------------
      -- CE-family conditional logics (CE, CEM, CEMD, CEMP, ...)
      re("CEfam", "CE\\w*", G.ls),
      -- CK-family
      re("CKfam", "CK\\w*", G.ls),
      -- Other conditional
      cmd("VW", G.ls),
      cmd("Slog", G.ls),
      -- Classical modal: K, D, T, B compound systems
      -- (single-letter ones need individual entries to avoid clashing)
      cmd("K", G.ls),
      cmd("D", G.ls),
      cmd("T", G.ls),
      cmd("B", G.ls),
      cmd("four", G.ls),
      cmd("five", G.ls),
      re("Kfam", "K[DTBDUW]\\w*", G.ls),
      -- Kfour, Kfive, Kfourfive
      re("Kffam", "Kf\\w*", G.ls),
      cmd("Sfour", G.ls),
      cmd("Sfive", G.ls),
      -- Non-normal: E-family
      cmd("E", G.ls),
      re("Efam", "E[MCN][DNPC]*", G.ls),
      -- Deontic
      re("SDLfam", "SDL\\w*", G.ls),
      re("Koughtfam", "K[DUW]\\+ought", G.ls),
      cmd("COc", G.ls),
      acmd("COvf", G.ls, G.ls),
      -- I/O logics
      cmd("IO", G.ls),
      acmd("IOn", G.ls, G.ls),
      acmd("IOh", G.ls, G.ls),
      acmd("IOhn", G.ls, G.ls),
      cmd("IOs", G.ls),
      acmd("IOsn", G.ls, G.ls),
      acmd("IOfn", G.ls, G.ls),
      -- Consequence style labels
      cmd("FDio", G.ls),
      cmd("DDio", G.ls),

      ----------------------------------------------------------------
      -- SEMANTIC NOTATION  (texCmdSemantic)
      ----------------------------------------------------------------
      -- Truth sets ⟦A⟧  (truthset, truthsetm, truthsetml, etc.)
      mare("truthsetfam", "truthset\\w*", G.sem, "texArgSemantic"),
      macmd("emptytruthset", G.sem, "texArgSemantic"),
      -- Double-bar truth sets ‖A‖
      mare("ctruthsetfam", "ctruthset\\w*", G.sem, "texArgSemantic"),
      -- Proof sets [A]
      mare("proofsetfam", "proofset\\w*", G.sem, "texArgSemantic"),
      -- Equivalence classes |A|
      macmd("eclass", G.sem, "texArgSemantic"),
      macmd("eclassl", G.sem, "texArgSemantic"),
      -- Satisfaction and validity relations
      mcmd("trues", G.sem),
      mcmd("ntrues", G.sem),
      mcmd("models", G.sem),
      mcmd("nmodels", G.sem),
      mcmd("mmodels", G.sem),
      mcmd("mnmodels", G.sem),
      macmd("mtruesat", G.sem, "texArgSemantic"),
      macmd("mntruesat", G.sem, "texArgSemantic"),
      -- Entailment
      mcmd("natent", G.sem),
      mcmd("nnatent", G.sem),
      mcmd("ent", G.sem),
      -- Model-theoretic structure letters
      mcmd("M", G.sem),
      mcmd("F", G.sem),
      mcmd("A", G.sem),
      mcmd("C", G.sem),
      mcmd("R", G.sem),
      -- Canonical model notation (Mlog, Wlog, Rlog, flog, Vlog)
      mre("logfam", "[MWfVR]log", G.sem),
      -- Frame variants: FR*, FN*, MRel, MN*
      mre("Ffam", "F[RN]\\w*", G.sem),
      mre("Mfam", "M[NR]\\w*", G.sem),
      -- Sigma-variants
      mre("sigfam", "[MWRV]sig", G.sem),
      -- Closure/supplementation arrow variants
      mre("arrowfam", "[Mf][nesw][ew]", G.sem),
      mre("lrfam", "[Mf]lr", G.sem),
      -- Named functions on frames: fn, fm, fd, fs, fr, fsub, fnof, fsof
      macmd("fn", G.sem, "texArgSemantic"),
      macmd("fm", G.sem, "texArgSemantic"),
      macmd("fd", G.sem, "texArgSemantic"),
      macmd("fs", G.sem, "texArgSemantic"),
      macmd("fr", G.sem, "texArgSemantic"),
      macmd("fsub", G.sem, "texArgSemantic"),
      macmd("fnof", G.sem, "texArgSemantic"),
      macmd("fsof", G.sem, "texArgSemantic"),
      -- Valuation
      macmd("val", G.sem, "texArgSemantic"),
      macmd("vw", G.sem, "texArgSemantic"),
      macmd("Val", G.sem, "texArgSemantic"),
      -- Propositional variables
      mcmd("props", G.sem),
      mcmd("pzero", G.sem),
      mcmd("pone", G.sem),
      mcmd("ptwo", G.sem),
      mcmd("pthree", G.sem),
      -- Truth values
      cmd("true", G.sem),
      cmd("false", G.sem),
      cmd("ind", G.sem),
      -- Language symbols
      mre("langfam", "lang\\w*", G.sem),
      mcmd("Lc", G.sem),
      mcmd("logic", G.sem),
      mcmd("logicp", G.sem),
      mcmd("metalogic", G.sem),
      -- Term algebra / atoms
      mcmd("Fm", G.sem),
      mcmd("atoms", G.sem),
      -- Bisimulation
      mcmd("bisim", G.sem),
      -- Maximal consistent set notation
      cmd("mcslog", G.sem),
      macmd("mcseti", G.sem, "texArgSemantic"),
      -- Metalanguage connectives (mland, mlor, mlto, mlnot, mlforall,
      -- mlexists + the six *solo variants)
      mre("mlfam", "ml\\w*", G.sem),
      -- Consequence / theory
      macmd("cn", G.sem, "texArgSemantic"),
      macmd("theory", G.sem, "texArgSemantic"),
      -- I/O functions
      macmd("iput", G.sem, "texArgSemantic"),
      macmd("oput", G.sem, "texArgSemantic"),
      macmd("oputi", G.sem, "texArgSemantic"),
      macmd("deriv", G.sem, "texArgSemantic"),
      macmd("derivi", G.sem, "texArgSemantic"),
      -- Probability / credence
      macmd("cprob", G.sem, "texArgSemantic"),
      macmd("cred", G.sem, "texArgSemantic"),
      macmd("ccred", G.sem, "texArgSemantic"),
      -- Order notation
      mcmd("topg", G.sem),
      mcmd("botg", G.sem),
      mcmd("topt", G.sem),
      mcmd("bott", G.sem),
      mcmd("filter", G.sem),

      ----------------------------------------------------------------
      -- MODAL / CONDITIONAL OPERATORS  (texCmdModalOp)
      ----------------------------------------------------------------
      -- Dyadic conditional connectives
      mcmd("cnecs", G.mo),
      mcmd("cposs", G.mo),
      mcmd("cnecsolo", G.mo),
      mcmd("cpossolo", G.mo),
      -- Deontic conditional connectives
      mcmd("cobs", G.mo),
      mcmd("cperms", G.mo),
      mcmd("cobsolo", G.mo),
      acmd("condop", G.mo, G.mo),
      acmd("condopsolo", G.mo, G.mo),
      -- Monadic modal operators
      mcmd("nec", G.mo),
      mcmd("poss", G.mo),
      mcmd("neced", G.mo),
      mcmd("unneced", G.mo),
      mcmd("possed", G.mo),
      mcmd("unpossed", G.mo),
      -- Counterfactual / strict
      mcmd("cfact", G.mo),
      mcmd("sphere", G.mo),
      mcmd("strictif", G.mo),
      -- Deontic operators
      mcmd("ought", G.mo),
      mcmd("may", G.mo),
      mcmd("obligatory", G.mo),
      mcmd("permissible", G.mo),
      mcmd("forbidden", G.mo),
      mcmd("gratuitous", G.mo),
      mcmd("optional", G.mo),
      macmd("cought", G.mo, G.mo),
      macmd("better", G.mo, G.mo),
      macmd("samevas", G.mo, G.mo),
      -- Epistemic operators
      mcmd("know", G.mo),
      mcmd("believe", G.mo),
      mcmd("cknow", G.mo),
      mcmd("cbelieve", G.mo),
      macmd("knows", G.mo, G.mo),
      macmd("believes", G.mo, G.mo),
      macmd("cknows", G.mo, G.mo),
      macmd("cbelieves", G.mo, G.mo),
      -- Temporal operators
      mcmd("hitherto", G.mo),
      mcmd("henceforth", G.mo),
      mcmd("was", G.mo),
      mcmd("willbe", G.mo),
      mcmd("precedes", G.mo),
      -- Affirm/deny (signed-formula) connectives: af, aff, affirm,
      -- afland, aflor, afneg, afto + the matching de family
      mre("affam", "af\\w*", G.mo),
      mre("defam", "de%(land|lor|neg|to|ny|n)?>", G.mo),
      -- I/O-style connectives
      mcmd("ecu", G.mo),
      mcmd("ito", G.mo),
      mcmd("cto", G.mo),
      mcmd("ilor", G.mo),
      mcmd("clor", G.mo),
      -- STIT operators
      mcmd("stit", G.mo),
      mcmd("cstito", G.mo),
      mcmd("dstito", G.mo),
      macmd("cstit", G.mo, G.mo),
      macmd("dstit", G.mo, G.mo),
      -- STIT model components
      cmd("tree", G.mo),
      cmd("agent", G.mo),
      cmd("choice", G.mo),
      cmd("stitought", G.mo),
      cmd("stitval", G.mo),
      mcmd("choicema", G.mo),
      -- Triggers / necessitates
      mcmd("necessitates", G.mo),
      mcmd("triggers", G.mo),

      ----------------------------------------------------------------
      -- DERIVATION / PROOF RULES  (texCmdRule)
      ----------------------------------------------------------------
      -- All rule names + parenthesized variants (32 commands → 1 pattern)
      re("rulefam", "\\w*rule\\w*", G.ru),
      -- Possibility-rule names: rmposs, reposs, rposs + par variants
      re("rpossfam", "r[me]?poss\\w*", G.ru),
      -- Proof relation symbols
      mcmd("proves", G.ru),
      mcmd("nproves", G.ru),
      mcmd("gives", G.ru),
      mcmd("asserts", G.ru),
      mcmd("derives", G.ru),
      mre("provesfam", "proves\\w*", G.ru),
      macmd("provesrel", G.ru, G.ru),
      macmd("modelsrel", G.ru, G.ru),
      -- Sequent notation
      mcmd("seq", G.ru),
      mcmd("tseq", G.ru),
      cmd("setset", G.ru),
      cmd("setfmla", G.ru),
      cmd("fmlaset", G.ru),
      cmd("fmlafmla", G.ru),
      -- Proof-tree / proof-listing helpers
      acmd("hyp", G.ru, G.ru),
      acmd("by", G.ru, G.ru),
      cmd("close", G.ru),
      cmd("infr", G.ru),
      cmd("hyphantom", G.ru),
      cmd("qed", G.ru),
      mcmd("incomp", G.ru),

      ----------------------------------------------------------------
      -- SET-THEORETIC / GENERAL NOTATION  (texCmdNotation)
      ----------------------------------------------------------------
      macmd("set", G.nt, "texArgNotation"),
      macmd("oset", G.nt, "texArgNotation"),
      macmd("tuple", G.nt, "texArgNotation"),
      macmd("power", G.nt, "texArgNotation"),
      macmd("Cl", G.nt, "texArgNotation"),
      -- Set operations
      mcmd("intersect", G.nt),
      mcmd("union", G.nt),
      mcmd("emptyset", G.nt),
      mcmd("inclin", G.nt),
      -- Definition symbols
      mcmd("defby", G.nt),
      mcmd("defbyvar", G.nt),
      -- Connective redefinitions
      mcmd("iff", G.nt),
      mcmd("onlyif", G.nt),
      mcmd("then", G.nt),
      mcmd("to", G.nt),
      -- Misc notation
      mcmd("suchthat", G.nt),
      cmd("st", G.nt),
      mcmd("minus", G.nt),
      mcmd("dvbar", G.nt),
      macmd("parent", G.nt, "texArgNotation"),
      mcmd("wedgeset", G.nt),
      mcmd("tightwedge", G.nt),
      -- Short model-definition macros
      cmd("mwrv", G.nt),
      cmd("mwrp", G.nt),
      cmd("mwnv", G.nt),
      cmd("mwnp", G.nt),
      mcmd("hk", G.nt),
    }

    -- Argument-group links accumulated by acmd/macmd/mare above;
    -- applied by after/ftplugin/tex.lua.
    vim.g.french_logic_arg_links = arg_links
  end,
}
