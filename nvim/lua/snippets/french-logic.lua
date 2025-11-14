-- Auto-generated from french-logic.sty
-- Regenerate via sty-lua-snippets.py

local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

local snippets = {}

-- Environments
table.insert(
  snippets,
  s("Alphlist~", {
    t([[\begin{Alphlist}]]),
    t({ "", [[  \item ]] }),
    i(1),
    t({ "", [[\end{Alphlist}]] }),
  })
)

table.insert(
  snippets,
  s("Romanlist~", {
    t([[\begin{Romanlist}]]),
    t({ "", [[  \item ]] }),
    i(1),
    t({ "", [[\end{Romanlist}]] }),
  })
)

table.insert(
  snippets,
  s("alphlistpar~", {
    t([[\begin{alphlistpar}]]),
    t({ "", [[  \item ]] }),
    i(1),
    t({ "", [[\end{alphlistpar}]] }),
  })
)

table.insert(
  snippets,
  s("answer~", {
    t([[\begin{answer}]]),
    t({ "", [[  ]] }),
    i(1),
    t({ "", [[\end{answer}]] }),
  })
)

table.insert(
  snippets,
  s("arablist~", {
    t([[\begin{arablist}]]),
    t({ "", [[  \item ]] }),
    i(1),
    t({ "", [[\end{arablist}]] }),
  })
)

table.insert(
  snippets,
  s("arablistpar~", {
    t([[\begin{arablistpar}]]),
    t({ "", [[  \item ]] }),
    i(1),
    t({ "", [[\end{arablistpar}]] }),
  })
)

table.insert(
  snippets,
  s("gentzen~", {
    t([[\begin{gentzen}]]),
    t({ "", [[  ]] }),
    i(1),
    t({ "", [[\end{gentzen}]] }),
  })
)

table.insert(
  snippets,
  s("hilbertlist~", {
    t([[\begin{hilbertlist}]]),
    t({ "", [[  \item ]] }),
    i(1),
    t({ "", [[\end{hilbertlist}]] }),
  })
)

table.insert(
  snippets,
  s("itemlist~", {
    t([[\begin{itemlist}]]),
    t({ "", [[  \item ]] }),
    i(1),
    t({ "", [[\end{itemlist}]] }),
  })
)

table.insert(
  snippets,
  s("itemlistflush~", {
    t([[\begin{itemlistflush}]]),
    t({ "", [[  \item ]] }),
    i(1),
    t({ "", [[\end{itemlistflush}]] }),
  })
)

table.insert(
  snippets,
  s("question~", {
    t([[\begin{question}]]),
    t({ "", [[  ]] }),
    i(1),
    t({ "", [[\end{question}]] }),
  })
)

table.insert(
  snippets,
  s("romanlist~", {
    t([[\begin{romanlist}]]),
    t({ "", [[  \item ]] }),
    i(1),
    t({ "", [[\end{romanlist}]] }),
  })
)

-- Commands
table.insert(
  snippets,
  s({ trig = [[\A~]], wordTrig = true }, {
    t([[\A]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\AND~]], wordTrig = true }, {
    t([[\AND]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ANDs~]], wordTrig = true }, {
    t([[\ANDs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\B~]], wordTrig = true }, {
    t([[\B]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\C~]], wordTrig = true }, {
    t([[\C]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CCl~]], wordTrig = true }, {
    t([[\CCl]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CCls~]], wordTrig = true }, {
    t([[\CCls]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CCr~]], wordTrig = true }, {
    t([[\CCr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CCrs~]], wordTrig = true }, {
    t([[\CCrs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CE~]], wordTrig = true }, {
    t([[\CE]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CEC~]], wordTrig = true }, {
    t([[\CEC]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CECN~]], wordTrig = true }, {
    t([[\CECN]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CEM~]], wordTrig = true }, {
    t([[\CEM]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CEMC~]], wordTrig = true }, {
    t([[\CEMC]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CEMD~]], wordTrig = true }, {
    t([[\CEMD]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CEMN~]], wordTrig = true }, {
    t([[\CEMN]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CEMP~]], wordTrig = true }, {
    t([[\CEMP]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CEMPs~]], wordTrig = true }, {
    t([[\CEMPs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CEN~]], wordTrig = true }, {
    t([[\CEN]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CK~]], wordTrig = true }, {
    t([[\CK]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CKD~]], wordTrig = true }, {
    t([[\CKD]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CKPs~]], wordTrig = true }, {
    t([[\CKPs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CMl~]], wordTrig = true }, {
    t([[\CMl]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CMls~]], wordTrig = true }, {
    t([[\CMls]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CMr~]], wordTrig = true }, {
    t([[\CMr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CMrs~]], wordTrig = true }, {
    t([[\CMrs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CNl~]], wordTrig = true }, {
    t([[\CNl]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CNlr~]], wordTrig = true }, {
    t([[\CNlr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CNr~]], wordTrig = true }, {
    t([[\CNr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CNra~]], wordTrig = true }, {
    t([[\CNra]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\COc~]], wordTrig = true }, {
    t([[\COc]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\COvf~]], wordTrig = true }, {
    t([[\COvf{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CP~]], wordTrig = true }, {
    t([[\CP]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CPs~]], wordTrig = true }, {
    t([[\CPs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CT~]], wordTrig = true }, {
    t([[\CT]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CTh~]], wordTrig = true }, {
    t([[\CTh]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\CTs~]], wordTrig = true }, {
    t([[\CTs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Cl~]], wordTrig = true }, {
    t([[\Cl{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\D~]], wordTrig = true }, {
    t([[\D]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\DDio~]], wordTrig = true }, {
    t([[\DDio]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\E~]], wordTrig = true }, {
    t([[\E]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\EC~]], wordTrig = true }, {
    t([[\EC]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ECN~]], wordTrig = true }, {
    t([[\ECN]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\EM~]], wordTrig = true }, {
    t([[\EM]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\EMC~]], wordTrig = true }, {
    t([[\EMC]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\EMD~]], wordTrig = true }, {
    t([[\EMD]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\EMN~]], wordTrig = true }, {
    t([[\EMN]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\EMP~]], wordTrig = true }, {
    t([[\EMP]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\EN~]], wordTrig = true }, {
    t([[\EN]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\F~]], wordTrig = true }, {
    t([[\F]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\FDio~]], wordTrig = true }, {
    t([[\FDio]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\FN~]], wordTrig = true }, {
    t([[\FN]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\FNo~]], wordTrig = true }, {
    t([[\FNo]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\FNt~]], wordTrig = true }, {
    t([[\FNt]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\FR~]], wordTrig = true }, {
    t([[\FR]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\FRo~]], wordTrig = true }, {
    t([[\FRo]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\FRt~]], wordTrig = true }, {
    t([[\FRt]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Fm~]], wordTrig = true }, {
    t([[\Fm]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\IO~]], wordTrig = true }, {
    t([[\IO]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\IOfn~]], wordTrig = true }, {
    t([[\IOfn{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\IOh~]], wordTrig = true }, {
    t([[\IOh]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\IOhn~]], wordTrig = true }, {
    t([[\IOhn{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\IOn~]], wordTrig = true }, {
    t([[\IOn{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\IOs~]], wordTrig = true }, {
    t([[\IOs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\IOsn~]], wordTrig = true }, {
    t([[\IOsn{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\K~]], wordTrig = true }, {
    t([[\K]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KB~]], wordTrig = true }, {
    t([[\KB]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KD~]], wordTrig = true }, {
    t([[\KD]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KDU~]], wordTrig = true }, {
    t([[\KDU]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KDUW~]], wordTrig = true }, {
    t([[\KDUW]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KDUWought~]], wordTrig = true }, {
    t([[\KDUWought]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KDUought~]], wordTrig = true }, {
    t([[\KDUought]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KDW~]], wordTrig = true }, {
    t([[\KDW]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KDWought~]], wordTrig = true }, {
    t([[\KDWought]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KDfourfive~]], wordTrig = true }, {
    t([[\KDfourfive]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KDought~]], wordTrig = true }, {
    t([[\KDought]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KT~]], wordTrig = true }, {
    t([[\KT]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KU~]], wordTrig = true }, {
    t([[\KU]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KUW~]], wordTrig = true }, {
    t([[\KUW]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KUWought~]], wordTrig = true }, {
    t([[\KUWought]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KUought~]], wordTrig = true }, {
    t([[\KUought]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KW~]], wordTrig = true }, {
    t([[\KW]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\KWought~]], wordTrig = true }, {
    t([[\KWought]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Kfive~]], wordTrig = true }, {
    t([[\Kfive]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Kfour~]], wordTrig = true }, {
    t([[\Kfour]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Kfourfive~]], wordTrig = true }, {
    t([[\Kfourfive]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Lc~]], wordTrig = true }, {
    t([[\Lc]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\M~]], wordTrig = true }, {
    t([[\M]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\MN~]], wordTrig = true }, {
    t([[\MN]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\MNo~]], wordTrig = true }, {
    t([[\MNo]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\MNt~]], wordTrig = true }, {
    t([[\MNt]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\MRel~]], wordTrig = true }, {
    t([[\MRel]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Mlog~]], wordTrig = true }, {
    t([[\Mlog]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Mlr~]], wordTrig = true }, {
    t([[\Mlr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Mne~]], wordTrig = true }, {
    t([[\Mne]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Mnw~]], wordTrig = true }, {
    t([[\Mnw]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Mse~]], wordTrig = true }, {
    t([[\Mse]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Msig~]], wordTrig = true }, {
    t([[\Msig]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Msw~]], wordTrig = true }, {
    t([[\Msw]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\OR~]], wordTrig = true }, {
    t([[\OR]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ORs~]], wordTrig = true }, {
    t([[\ORs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\R~]], wordTrig = true }, {
    t([[\R]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Rsig~]], wordTrig = true }, {
    t([[\Rsig]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\SDL~]], wordTrig = true }, {
    t([[\SDL]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\SDLplus~]], wordTrig = true }, {
    t([[\SDLplus]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\SDLt~]], wordTrig = true }, {
    t([[\SDLt]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\SI~]], wordTrig = true }, {
    t([[\SI]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\SIs~]], wordTrig = true }, {
    t([[\SIs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Sfive~]], wordTrig = true }, {
    t([[\Sfive]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Sfour~]], wordTrig = true }, {
    t([[\Sfour]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Slog~]], wordTrig = true }, {
    t([[\Slog]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\T~]], wordTrig = true }, {
    t([[\T]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\TOP~]], wordTrig = true }, {
    t([[\TOP]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Ts~]], wordTrig = true }, {
    t([[\Ts]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\VW~]], wordTrig = true }, {
    t([[\VW]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Val~]], wordTrig = true }, {
    t([[\Val{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Vlog~]], wordTrig = true }, {
    t([[\Vlog]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Vsig~]], wordTrig = true }, {
    t([[\Vsig]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\WO~]], wordTrig = true }, {
    t([[\WO]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\WOs~]], wordTrig = true }, {
    t([[\WOs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Wlog~]], wordTrig = true }, {
    t([[\Wlog]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\Wsig~]], wordTrig = true }, {
    t([[\Wsig]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\abreak~]], wordTrig = true }, {
    t([[\abreak]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\af~]], wordTrig = true }, {
    t([[\af]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\aff~]], wordTrig = true }, {
    t([[\aff]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\affirm~]], wordTrig = true }, {
    t([[\affirm{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\afland~]], wordTrig = true }, {
    t([[\afland]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\aflor~]], wordTrig = true }, {
    t([[\aflor]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\afneg~]], wordTrig = true }, {
    t([[\afneg]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\afto~]], wordTrig = true }, {
    t([[\afto]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\agent~]], wordTrig = true }, {
    t([[\agent]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\asserts~]], wordTrig = true }, {
    t([[\asserts]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\atoms~]], wordTrig = true }, {
    t([[\atoms]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\believe~]], wordTrig = true }, {
    t([[\believe]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\believes~]], wordTrig = true }, {
    t([[\believes{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\better~]], wordTrig = true }, {
    t([[\better{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\bisim~]], wordTrig = true }, {
    t([[\bisim]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\botg~]], wordTrig = true }, {
    t([[\botg]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\bott~]], wordTrig = true }, {
    t([[\bott]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cax~]], wordTrig = true }, {
    t([[\cax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\caxc~]], wordTrig = true }, {
    t([[\caxc]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\caxpar~]], wordTrig = true }, {
    t([[\caxpar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cbelieve~]], wordTrig = true }, {
    t([[\cbelieve]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cbelieves~]], wordTrig = true }, {
    t([[\cbelieves{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ccax~]], wordTrig = true }, {
    t([[\ccax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ccl~]], wordTrig = true }, {
    t([[\ccl]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ccls~]], wordTrig = true }, {
    t([[\ccls]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cclss~]], wordTrig = true }, {
    t([[\cclss]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ccr~]], wordTrig = true }, {
    t([[\ccr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ccred~]], wordTrig = true }, {
    t([[\ccred{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ccrs~]], wordTrig = true }, {
    t([[\ccrs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cdax~]], wordTrig = true }, {
    t([[\cdax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cduax~]], wordTrig = true }, {
    t([[\cduax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cfact~]], wordTrig = true }, {
    t([[\cfact]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\choice~]], wordTrig = true }, {
    t([[\choice]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\choicema~]], wordTrig = true }, {
    t([[\choicema]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cknow~]], wordTrig = true }, {
    t([[\cknow]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cknows~]], wordTrig = true }, {
    t([[\cknows{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\clor~]], wordTrig = true }, {
    t([[\clor]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\close~]], wordTrig = true }, {
    t([[\close{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cmaxi~]], wordTrig = true }, {
    t([[\cmaxi]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cml~]], wordTrig = true }, {
    t([[\cml]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cmls~]], wordTrig = true }, {
    t([[\cmls]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cmlss~]], wordTrig = true }, {
    t([[\cmlss]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cmlsss~]], wordTrig = true }, {
    t([[\cmlsss]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cmr~]], wordTrig = true }, {
    t([[\cmr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cmrs~]], wordTrig = true }, {
    t([[\cmrs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cn~]], wordTrig = true }, {
    t([[\cn{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cnax~]], wordTrig = true }, {
    t([[\cnax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cnecs~]], wordTrig = true }, {
    t([[\cnecs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cnecsolo~]], wordTrig = true }, {
    t([[\cnecsolo]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cnl~]], wordTrig = true }, {
    t([[\cnl]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cnlr~]], wordTrig = true }, {
    t([[\cnlr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cnr~]], wordTrig = true }, {
    t([[\cnr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cobs~]], wordTrig = true }, {
    t([[\cobs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cobsolo~]], wordTrig = true }, {
    t([[\cobsolo]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\condop~]], wordTrig = true }, {
    t([[\condop{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\condopsolo~]], wordTrig = true }, {
    t([[\condopsolo{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cought~]], wordTrig = true }, {
    t([[\cought{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cperms~]], wordTrig = true }, {
    t([[\cperms]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cposs~]], wordTrig = true }, {
    t([[\cposs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cpossolo~]], wordTrig = true }, {
    t([[\cpossolo]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cprob~]], wordTrig = true }, {
    t([[\cprob{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cred~]], wordTrig = true }, {
    t([[\cred{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cstit~]], wordTrig = true }, {
    t([[\cstit{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cstito~]], wordTrig = true }, {
    t([[\cstito]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cth~]], wordTrig = true }, {
    t([[\cth]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cths~]], wordTrig = true }, {
    t([[\cths]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cthss~]], wordTrig = true }, {
    t([[\cthss]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\cto~]], wordTrig = true }, {
    t([[\cto]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ctruthset~]], wordTrig = true }, {
    t([[\ctruthset{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ctruthsetm~]], wordTrig = true }, {
    t([[\ctruthsetm{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ctruthsetmm~]], wordTrig = true }, {
    t([[\ctruthsetmm{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ctruthsetmsub~]], wordTrig = true }, {
    t([[\ctruthsetmsub{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\dax~]], wordTrig = true }, {
    t([[\dax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\daxc~]], wordTrig = true }, {
    t([[\daxc]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\daxpar~]], wordTrig = true }, {
    t([[\daxpar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\de~]], wordTrig = true }, {
    t([[\de]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\defby~]], wordTrig = true }, {
    t([[\defby]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\defbyvar~]], wordTrig = true }, {
    t([[\defbyvar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\deland~]], wordTrig = true }, {
    t([[\deland]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\delor~]], wordTrig = true }, {
    t([[\delor]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\den~]], wordTrig = true }, {
    t([[\den]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\deneg~]], wordTrig = true }, {
    t([[\deneg]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\deny~]], wordTrig = true }, {
    t([[\deny{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\deriv~]], wordTrig = true }, {
    t([[\deriv{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\derives~]], wordTrig = true }, {
    t([[\derives]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\derivi~]], wordTrig = true }, {
    t([[\derivi{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\deto~]], wordTrig = true }, {
    t([[\deto]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\drule~]], wordTrig = true }, {
    t([[\drule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\drulepar~]], wordTrig = true }, {
    t([[\drulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\dsax~]], wordTrig = true }, {
    t([[\dsax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\dstit~]], wordTrig = true }, {
    t([[\dstit{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\dstito~]], wordTrig = true }, {
    t([[\dstito]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\duax~]], wordTrig = true }, {
    t([[\duax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\duaxpar~]], wordTrig = true }, {
    t([[\duaxpar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\dvbar~]], wordTrig = true }, {
    t([[\dvbar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ecu~]], wordTrig = true }, {
    t([[\ecu]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\emptytruthset~]], wordTrig = true }, {
    t([[\emptytruthset]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ent~]], wordTrig = true }, {
    t([[\ent]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\eruledj~]], wordTrig = true }, {
    t([[\eruledj{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\erulej~]], wordTrig = true }, {
    t([[\erulej{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\false~]], wordTrig = true }, {
    t([[\false]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fd~]], wordTrig = true }, {
    t([[\fd]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\filter~]], wordTrig = true }, {
    t([[\filter]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\five~]], wordTrig = true }, {
    t([[\five]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\flog~]], wordTrig = true }, {
    t([[\flog]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\flr~]], wordTrig = true }, {
    t([[\flr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fm~]], wordTrig = true }, {
    t([[\fm]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fmlafmla~]], wordTrig = true }, {
    t([[\fmlafmla]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fmlaset~]], wordTrig = true }, {
    t([[\fmlaset]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fn~]], wordTrig = true }, {
    t([[\fn]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fne~]], wordTrig = true }, {
    t([[\fne]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fnof~]], wordTrig = true }, {
    t([[\fnof{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fnw~]], wordTrig = true }, {
    t([[\fnw]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\forbidden~]], wordTrig = true }, {
    t([[\forbidden]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\four~]], wordTrig = true }, {
    t([[\four]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fr~]], wordTrig = true }, {
    t([[\fr]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fs~]], wordTrig = true }, {
    t([[\fs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fse~]], wordTrig = true }, {
    t([[\fse]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fsof~]], wordTrig = true }, {
    t([[\fsof{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fsub~]], wordTrig = true }, {
    t([[\fsub{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\fsw~]], wordTrig = true }, {
    t([[\fsw]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\gives~]], wordTrig = true }, {
    t([[\gives]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\gratuitous~]], wordTrig = true }, {
    t([[\gratuitous]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\henceforth~]], wordTrig = true }, {
    t([[\henceforth]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\hitherto~]], wordTrig = true }, {
    t([[\hitherto]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\hk~]], wordTrig = true }, {
    t([[\hk]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\hyp~]], wordTrig = true }, {
    t([[\hyp{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\hyphantom~]], wordTrig = true }, {
    t([[\hyphantom]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\iff~]], wordTrig = true }, {
    t([[\iff]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ilor~]], wordTrig = true }, {
    t([[\ilor]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\inclin~]], wordTrig = true }, {
    t([[\inclin]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\incomp~]], wordTrig = true }, {
    t([[\incomp]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ind~]], wordTrig = true }, {
    t([[\ind]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\inf~]], wordTrig = true }, {
    t([[\inf{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}{]]),
    i(3),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\infer~]], wordTrig = true }, {
    t([[\infer]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\infr~]], wordTrig = true }, {
    t([[\infr{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}{]]),
    i(3),
    t([[}{]]),
    i(4),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\intersect~]], wordTrig = true }, {
    t([[\intersect]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\iput~]], wordTrig = true }, {
    t([[\iput{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\iruledj~]], wordTrig = true }, {
    t([[\iruledj{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\irulej~]], wordTrig = true }, {
    t([[\irulej{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ito~]], wordTrig = true }, {
    t([[\ito]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\kax~]], wordTrig = true }, {
    t([[\kax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\kaxc~]], wordTrig = true }, {
    t([[\kaxc]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\kaxpar~]], wordTrig = true }, {
    t([[\kaxpar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\know~]], wordTrig = true }, {
    t([[\know]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\knows~]], wordTrig = true }, {
    t([[\knows{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\krule~]], wordTrig = true }, {
    t([[\krule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\krulepar~]], wordTrig = true }, {
    t([[\krulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\lang~]], wordTrig = true }, {
    t([[\lang]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\langd~]], wordTrig = true }, {
    t([[\langd]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\langm~]], wordTrig = true }, {
    t([[\langm]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\langmd~]], wordTrig = true }, {
    t([[\langmd]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\langp~]], wordTrig = true }, {
    t([[\langp]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\logic~]], wordTrig = true }, {
    t([[\logic]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\logicp~]], wordTrig = true }, {
    t([[\logicp]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\manrule~]], wordTrig = true }, {
    t([[\manrule{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\maxi~]], wordTrig = true }, {
    t([[\maxi]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\maxic~]], wordTrig = true }, {
    t([[\maxic]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\maxipar~]], wordTrig = true }, {
    t([[\maxipar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\may~]], wordTrig = true }, {
    t([[\may]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mcseti~]], wordTrig = true }, {
    t([[\mcseti{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mcslog~]], wordTrig = true }, {
    t([[\mcslog]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\minus~]], wordTrig = true }, {
    t([[\minus]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mmodels~]], wordTrig = true }, {
    t([[\mmodels]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mnmodels~]], wordTrig = true }, {
    t([[\mnmodels]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mntruesat~]], wordTrig = true }, {
    t([[\mntruesat{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\models~]], wordTrig = true }, {
    t([[\models]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\modelsrel~]], wordTrig = true }, {
    t([[\modelsrel{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mprule~]], wordTrig = true }, {
    t([[\mprule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mprulepar~]], wordTrig = true }, {
    t([[\mprulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mtruesat~]], wordTrig = true }, {
    t([[\mtruesat{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mwnp~]], wordTrig = true }, {
    t([[\mwnp]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mwnv~]], wordTrig = true }, {
    t([[\mwnv]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mwrp~]], wordTrig = true }, {
    t([[\mwrp]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\mwrv~]], wordTrig = true }, {
    t([[\mwrv]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\natent~]], wordTrig = true }, {
    t([[\natent]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\nax~]], wordTrig = true }, {
    t([[\nax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\naxc~]], wordTrig = true }, {
    t([[\naxc]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\naxpar~]], wordTrig = true }, {
    t([[\naxpar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\nec~]], wordTrig = true }, {
    t([[\nec]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\neced~]], wordTrig = true }, {
    t([[\neced]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\necessitates~]], wordTrig = true }, {
    t([[\necessitates]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\negedrule~]], wordTrig = true }, {
    t([[\negedrule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\negidrule~]], wordTrig = true }, {
    t([[\negidrule{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\negiprule~]], wordTrig = true }, {
    t([[\negiprule{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\negipstarrule~]], wordTrig = true }, {
    t([[\negipstarrule{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\nmodels~]], wordTrig = true }, {
    t([[\nmodels]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\nnatent~]], wordTrig = true }, {
    t([[\nnatent]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\nproves~]], wordTrig = true }, {
    t([[\nproves]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\nrule~]], wordTrig = true }, {
    t([[\nrule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\nrulepar~]], wordTrig = true }, {
    t([[\nrulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ntrues~]], wordTrig = true }, {
    t([[\ntrues]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\obligatory~]], wordTrig = true }, {
    t([[\obligatory]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\onlyif~]], wordTrig = true }, {
    t([[\onlyif]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\optional~]], wordTrig = true }, {
    t([[\optional]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\oput~]], wordTrig = true }, {
    t([[\oput{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\oputi~]], wordTrig = true }, {
    t([[\oputi{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\oset~]], wordTrig = true }, {
    t([[\oset{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ought~]], wordTrig = true }, {
    t([[\ought]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\p~]], wordTrig = true }, {
    t([[\p{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\parent~]], wordTrig = true }, {
    t([[\parent{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\pax~]], wordTrig = true }, {
    t([[\pax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\permissible~]], wordTrig = true }, {
    t([[\permissible]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\plrule~]], wordTrig = true }, {
    t([[\plrule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\plrulepar~]], wordTrig = true }, {
    t([[\plrulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\poax~]], wordTrig = true }, {
    t([[\poax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\pone~]], wordTrig = true }, {
    t([[\pone]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\porule~]], wordTrig = true }, {
    t([[\porule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\porulepar~]], wordTrig = true }, {
    t([[\porulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\posax~]], wordTrig = true }, {
    t([[\posax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\posrule~]], wordTrig = true }, {
    t([[\posrule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\posrulepar~]], wordTrig = true }, {
    t([[\posrulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\poss~]], wordTrig = true }, {
    t([[\poss]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\possed~]], wordTrig = true }, {
    t([[\possed]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\power~]], wordTrig = true }, {
    t([[\power{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\pp~]], wordTrig = true }, {
    t([[\pp{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\precedes~]], wordTrig = true }, {
    t([[\precedes]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\proofset~]], wordTrig = true }, {
    t([[\proofset{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\proofsetl~]], wordTrig = true }, {
    t([[\proofsetl{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\props~]], wordTrig = true }, {
    t([[\props]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\proves~]], wordTrig = true }, {
    t([[\proves]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\provesc~]], wordTrig = true }, {
    t([[\provesc]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\provesio~]], wordTrig = true }, {
    t([[\provesio]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\provesm~]], wordTrig = true }, {
    t([[\provesm]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\provesrel~]], wordTrig = true }, {
    t([[\provesrel{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\provestf~]], wordTrig = true }, {
    t([[\provestf]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\psax~]], wordTrig = true }, {
    t([[\psax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\pthree~]], wordTrig = true }, {
    t([[\pthree]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\ptwo~]], wordTrig = true }, {
    t([[\ptwo]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\pzero~]], wordTrig = true }, {
    t([[\pzero]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\qed~]], wordTrig = true }, {
    t([[\qed]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\relrule~]], wordTrig = true }, {
    t([[\relrule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\relrulepar~]], wordTrig = true }, {
    t([[\relrulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\reposs~]], wordTrig = true }, {
    t([[\reposs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\reposspar~]], wordTrig = true }, {
    t([[\reposspar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\reprule~]], wordTrig = true }, {
    t([[\reprule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\reprulepar~]], wordTrig = true }, {
    t([[\reprulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\rerrule~]], wordTrig = true }, {
    t([[\rerrule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\rerrulepar~]], wordTrig = true }, {
    t([[\rerrulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\rerule~]], wordTrig = true }, {
    t([[\rerule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\rerulepar~]], wordTrig = true }, {
    t([[\rerulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\rmposs~]], wordTrig = true }, {
    t([[\rmposs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\rmposspar~]], wordTrig = true }, {
    t([[\rmposspar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\rposs~]], wordTrig = true }, {
    t([[\rposs]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\rposspar~]], wordTrig = true }, {
    t([[\rposspar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\samevas~]], wordTrig = true }, {
    t([[\samevas{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\seq~]], wordTrig = true }, {
    t([[\seq]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\set~]], wordTrig = true }, {
    t([[\set{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\setfmla~]], wordTrig = true }, {
    t([[\setfmla]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\setset~]], wordTrig = true }, {
    t([[\setset]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\sphere~]], wordTrig = true }, {
    t([[\sphere]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\st~]], wordTrig = true }, {
    t([[\st]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\stit~]], wordTrig = true }, {
    t([[\stit]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\stitought~]], wordTrig = true }, {
    t([[\stitought]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\stitval~]], wordTrig = true }, {
    t([[\stitval]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\subought~]], wordTrig = true }, {
    t([[\subought]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\subrule~]], wordTrig = true }, {
    t([[\subrule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\subrulepar~]], wordTrig = true }, {
    t([[\subrulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\suchthat~]], wordTrig = true }, {
    t([[\suchthat]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\tautrule~]], wordTrig = true }, {
    t([[\tautrule]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\tautrulepar~]], wordTrig = true }, {
    t([[\tautrulepar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\taxc~]], wordTrig = true }, {
    t([[\taxc]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\taxpar~]], wordTrig = true }, {
    t([[\taxpar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\then~]], wordTrig = true }, {
    t([[\then]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\theory~]], wordTrig = true }, {
    t([[\theory{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\tightwedge~]], wordTrig = true }, {
    t([[\tightwedge]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\to~]], wordTrig = true }, {
    t([[\to]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\topg~]], wordTrig = true }, {
    t([[\topg]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\topt~]], wordTrig = true }, {
    t([[\topt]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\tree~]], wordTrig = true }, {
    t([[\tree]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\triggers~]], wordTrig = true }, {
    t([[\triggers]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\true~]], wordTrig = true }, {
    t([[\true]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\trues~]], wordTrig = true }, {
    t([[\trues]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\truthset~]], wordTrig = true }, {
    t([[\truthset{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\truthsetm~]], wordTrig = true }, {
    t([[\truthsetm{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\truthsetmm~]], wordTrig = true }, {
    t([[\truthsetmm{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\truthsetmsub~]], wordTrig = true }, {
    t([[\truthsetmsub{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\tseq~]], wordTrig = true }, {
    t([[\tseq]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\uax~]], wordTrig = true }, {
    t([[\uax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\uaxc~]], wordTrig = true }, {
    t([[\uaxc]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\uaxpar~]], wordTrig = true }, {
    t([[\uaxpar]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\union~]], wordTrig = true }, {
    t([[\union]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\unneced~]], wordTrig = true }, {
    t([[\unneced]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\unpossed~]], wordTrig = true }, {
    t([[\unpossed]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\val~]], wordTrig = true }, {
    t([[\val{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\versal~]], wordTrig = true }, {
    t([[\versal{]]),
    i(1),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\vw~]], wordTrig = true }, {
    t([[\vw{]]),
    i(1),
    t([[}{]]),
    i(2),
    t([[}]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\was~]], wordTrig = true }, {
    t([[\was]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\wax~]], wordTrig = true }, {
    t([[\wax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\waxc~]], wordTrig = true }, {
    t([[\waxc]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\wedgeset~]], wordTrig = true }, {
    t([[\wedgeset]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\willbe~]], wordTrig = true }, {
    t([[\willbe]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\woax~]], wordTrig = true }, {
    t([[\woax]]),
  })
)

table.insert(
  snippets,
  s({ trig = [[\wocax~]], wordTrig = true }, {
    t([[\wocax]]),
  })
)

return snippets
