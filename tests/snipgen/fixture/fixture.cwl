# fixture.cwl for tests/snipgen: one row per rule of PLAN.md section 2
# second header line, kept verbatim in the generated header
#include:alpha
#include:beta
#include:alpha
#include:fixture
#modified 2026-09-13 a hash line without a colon is a comment, no warning
#repl:"a ä

\binom{above}{below}#m
\dotsb#m
\sum_{min}^{max}#m
\g_fixture_tl#*
\AmSfont#*
\dag#*
\Hat{arg}#Sm
LineColorA#B
\typein[cmd]{msg}#*
\vector(xslope,yslope){length}#*/picture
\begin{align}#\math,array
\begin{align*}#\math,array
\end{align}
\end{align*}
\begin{aligned}[alignment]#m\array
\begin{alignat}[alignment]{ncols}#\math,array
\begin{itemize}
\begin{itemize}\item
\begin{itemize}[options%keyvals]
\begin{enumerate}\item
\begin{trivlist}
\begin{corelist}[options%keyvals]
\begin{axis}[options%keyvals]#/tikzpicture
\begin{tikzpicture}% function%\\begin{axis}[xlabel=%<x axis label%>]%\\addplot {%|};%\\end{axis}%\\end{tikzpicture}#n
\begin{telefax}{number}{addressee \\ address%text}
\begin{enumerate][widest label]
\parbox[position]{width%l}{text}
\includegraphics[scale=%<1%>]{file}#g
\cfrac[%<align%>]{%<num%:translatable%>}{%<den%:translatable%>}#m
\magstep%<<n>%>#*
\matrix{%<line%> \cr %<... line%> \cr}#m
\left(%|\right)#mM
\item %|
\section{title}#L2
\section*{title}#L2
\hspace{}
\usebeamertemplate<mode>{name}
\begin{frame}[<default overlay specification>]{title}
\label{key}#l
\ref{key}#r
\cite{keylist}#c
\newcommand{cmd}[args]{def}#d
\usepackage[options%keyvals]{package}#u
\definecolor{name%specialDef}{model}{color-spec}#s#%color
\color{color%special}
\begin{Verbatim}#V
\newtheorem{envname}#N
\big#K
\todo{text%todo}#D
\hline#t
\kill#T
\textnormal{text}#n
\weird{arg}#Q
\,
\\[length]
\○{arg}
\%
\#{number of nuclei}#/experimental
\
\parbox[position]{width%l}{text}
\binom{above}{below}#*m
\alpha#m
\thispagestyle{style}
\dag
%<%:TEXSTUDIO-GENERIC-ENVIRONMENT-TEMPLATE%>
a4wide
#ifOption:enabled
\enabledonly{arg}
#endif
#ifOption:disabled
\disabledonly{arg}
#keyvals:\disabledonly
key=value
#endkeyvals
#endif
#ifOpton:typo
\typoblock
#endif
#keyvals:\hypersetup,\usepackage/hyperref#c
# a comment inside the block
addtopdfcreator=%<text%>
allbordercolors=#%color

backref=#section,slide,page,none,false
#endkeyvals
#keyvals:\unterminated
last=key
