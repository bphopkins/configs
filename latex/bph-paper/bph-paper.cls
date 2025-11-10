\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{bph-paper}[2014/08/16 Example LaTeX class]

\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass[letterpaper,12pt]{article}

\usepackage[letterpaper,left=1in,right=1in,top=1in,bottom=1in]{geometry}

\usepackage[authordate-trad, backend=biber]{biblatex-chicago}
	\bibliography{./main.bib}
	
%%% USE THESE DURING DOUBLE SPACING
\newenvironment{quot}{\\[-32pt]\begin{quote}\singlespacing\begin{small}}{\end{small}\end{quote}\doublespacing}
%\newenvironment{quot}{\\[-32pt]\begin{quote}\onehalfspacing}{\end{quote}\doublespacing}
\newenvironment{quota}{\\[-32pt]\begin{quotation}\singlespacing\begin{small}}{\end{small}\end{quotation}\doublespacing}
\newenvironment{quotns}{\begin{quote}\singlespacing\begin{small}}{\end{small}\end{quote}\doublespacing}



\newenvironment{titabtoc}{\maketitle\begin{abstract}}{\end{abstract}\vfill\begin{spacing}{.9}\tableofcontents\end{spacing}\clearpage\doublespacing}