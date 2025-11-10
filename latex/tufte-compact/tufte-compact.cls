\NeedsTeXFormat{LaTeX2e}[1994/06/01]

\ProvidesClass{tufte-compact}[2015/06/21 v3.5.2 Tufte-handout class]

%%
% Declare we're tufte-handout
\newcommand{\@tufte@class}{article}% the base LaTeX class (defaults to the article/handout style)
\newcommand{\@tufte@pkgname}{tufte-compact}% the name of the package (defaults to tufte-handout)

%%
% Load the common style elements
\input{tufte-common.def}


%%
% Set up any handout-specific stuff now

\newcommand{\mnote}[1]{\marginnote{#1}}

\newenvironment{tuftitle}{\begin{flushleft}\hangindent=1cm\LARGE\scshape}
{\end{flushleft}}

\RequirePackage{enumitem}
\newenvironment{tuftitem}{\medskip
	\begin{itemize}[nosep]
		\setlength{\itemindent}{1cm}}{\end{itemize}\medskip}

\newenvironment{tuftenum}{\medskip
	\begin{enumerate}[nolistsep,itemsep=4pt,left=10pt]
		\setlength{\itemindent}{1cm}}{\end{enumerate}\medskip}

%%
% Abstract

% TODO The abstract should be printed on its own page of the `titlepage'
% option was specified.
\renewenvironment{abstract}
  {\begin{quotation}\if@tufte@sfsidenotes\begin{sffamily}\fi}
  {\if@tufte@sfsidenotes\end{sffamily}\fi\end{quotation}}


%%
% If there is a `tufte-handout-local.tex' file, load it.

\IfFileExists{tufte-handout-local.tex}{%
  \input{tufte-handout-local}%
  \@tufte@info@noline{Loading tufte-handout-local.tex}%
}{}


%%
% End of file
\endinput