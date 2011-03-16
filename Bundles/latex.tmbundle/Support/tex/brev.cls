% brev.cls,v 4.22 2003/11/18 17:07:55 ambolt Exp
%
% Copyright © 1999-2003 Asgeir Nilsen <brevcls@asgeirnilsen.com>.  
%
%    This program is free software; you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation; either version 2 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program; if not, write to the Free Software
%    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
%
% This package has shamelessly stolen the mailing label definitions
% from Sebastian Rahtz' and Grant Gustafson's labels package.  The
% original copyright is within the redefinition of letter.cls'
% \startlabels at the end of this file.
%
% A little letter class for personal letters.  It is called ``brev''
% because that is the Norwegian name for letter, and for avoiding name
% clashes with the standard LaTeX letter class. 
%
% Note: This class loads the babel package.
% Specify the language in the \documentclass command:
% \documentclass[norsk,...]{brev}
% or
% \documentclass[nynorsk,...]{brev}
% or
% \documentclass[english,...]{brev}
% or
% \documentclass[american,...]{brev}
%
% Feel free to add more languages as necessary (and please do inform me) 
%
% This class left-justifies the text (with \raggedright) by default.
% To override this, use the `blockadjust' class option.
%
% The to-address is placed 5.4mm to the left of the left margin of the
% letter, to place it correctly with respect to window envelopes.  To
% disable this, use the 'nowindow' class option.
%
% This class introduces three new commands:
% \yourref{text}          Inserts a ``Your ref'' caption with text at an
%                         appropriate place.
% \ourref{text}           Does the same for ``Our ref''.
% \LetterDate{yyyy/mm/dd} This command makes it easier to date a
%                         letter at a fixed date in a babel-compatible
%                         way.  If this command is used (and \date is
%                         not), the class will insert the given date
%                         in the default form for the selected
%                         language. 
%
% This class also supports mailing labels via two class options and
% two new commands.
% The label sheets supported are the ones with 7x3 labels on letter
% paper, and 8x3 labels on A4 paper.
% 
% labels                Creates mailing labels for the recipient of
%                       each letter environment.  To create extra
%                       labels, insert empty letter environments.
% returnlabels          Creates mailing labels for the return
%                       addresses of each letter environment.
% \skiplabels{num}      Skips the given number of labels before
%                       starting populating the labels.  This is handy
%                       for using the same label sheet several times.
%                       WARNING: If you insert a label sheet with some
%                       of the labels removed, the paper might jam in
%                       your printer.  Use with caution!
%                       This command must be given in the preamble.
% \labelsheet{dim}      Gives the dimensions of the label sheet.
%                       Default is \labelsheet{3x8}, which gives a
%                       sheet with 8 rows with 3 labels each (quite
%                       standard for A4 sheets).
%
% The special characteristics of this class is the addresses field at
% the top of the first page. This one is placed within a 7cm by 8cm
% picture element adjusted to the paper edge at the top and 1in from
% the paper edge at the left.  The recipient address should be placed
% within the window of window envelopes, and the sender address above
% the window.
% Two folding lines is also provided for folding the letter correctly
% both in C5 og E65 envelopes.  These lines are placed 10.5cm and
% 14.8cm from the top edge of the paper. 
% The class is made and tested with A4 paper, but should be portable
% to other dimensions as well.  
%
% This class assumes that the window is placed 40mm from the top edge
% of the envelope, 15mm from the left edge and is 95mm wide and 30mm
% tall. 
%
% The newest version of this class is always available at
% http://www.asgeirnilsen.com/latex/
%
% Written by Asgeir Nilsen <brevcls@asgeirnilsen.com>
% With thanks to 
%   Sebastian Rahtz and Grant Gustafson
%   Dag Langmyhr <dag@ifi.uio.no>
%   Svend Tollak Munkejord <stm@stud.ntnu.no>
%   Hans Peter Verne <hpv@kjemi.uio.no>
%   Harald Hanche-Olsen <hanche@math.ntnu.no>
%   Morten Simonsen <mortensi@idt.ntnu.no>
%   Helge Avlesen <avle@ii.uib.no>
%   Tage Stabell-Kulø <tage@ACM.org>
%   Anders Andersen <aa@computer.org>
%   Nikolai Langfeldt <janl@linpro.no>
%   Knut Anders Hatlen <kahatlen@online.no>
%   Petter Reinholdtsen <pere@opera.com>
%   Toni Brkic <tbrkic@yahoo.com>
%   Dennis Jørgensen <dnj@x.dtu.dk>
%   Hans Fredrik Nordhaug <hansfn@mi.uib.no>
%
%% Latex requirement part:
%
\NeedsTeXFormat{LaTeX2e}[1995/12/01]
%
%% Identification part:
%
\ProvidesClass{brev}[2003/11/18 17:07:55 v4.22 Class for private letters]
%
%% Initial code part:
%
\newlength{\box@width}
\newlength{\box@height}
\newlength{\half@box}
\newlength{\window@top}
\newlength{\FIRST@textheight}
\newlength{\OLD@textheight}
\newlength{\OLD@headsep}
\newlength{\to@address}
\newcommand*{\ourref}[1]{\def\O@ref{#1}}
\newcommand*{\yourref}[1]{\def\Y@ref{#1}}
\def\Letter@Date(#1-#2-#3){%
  \ifx\@empty#1\ClassWarning{brev}{Invalid date for \protect\LetterDate}\else%
  \ifx\@empty#2\ClassWarning{brev}{Invalid date for \protect\LetterDate}\else%
  \ifx\@empty#3\ClassWarning{brev}{Invalid date for \protect\LetterDate}\else%
  \def\Date@Year{#1}\def\Date@Month{#2}\def\Date@Day{#3}\fi\fi\fi}
\newcommand*{\LetterDate}[1]{\Letter@Date(#1)}
\def\Date@Year{}
\ourref{}
\yourref{}
\def\O@nofoldinglines{}
\newif\ifl@bels
\newif\ifl@@bels
\newif\ifl@@@bels
\newif\ifr@gged
\l@belsfalse
\l@@belsfalse
\l@@@belsfalse
\r@ggedtrue
%
%% Options declaration part:
%
\DeclareOption{returnlabels}{\l@belstrue\l@@@belstrue}
\DeclareOption{labels}{\l@belstrue\l@@belstrue}
\DeclareOption{blockadjust}{\r@ggedfalse}
\DeclareOption{window}{\setlength{\to@address}{-5.4mm}}
\DeclareOption{nowindow}{\setlength{\to@address}{0mm}}
\DeclareOption{nofoldinglines}{\def\O@nofoldinglines{true}}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{letter}}
%
%% Options execution part:
%
\ExecuteOptions{window}
\ProcessOptions
%
%% Package loading part:
%
\LoadClass{letter}
\RequirePackage{babel}
%
%% Babel part:
%
\addto\extrasswedish{%
  \def\captionO@ref{{\small V{\aa}r ref.:}}%
  \def\captionY@ref{{\small Er ref.:}}%
}
\addto\extrasnynorsk{%
  \def\captionO@ref{{\small V{\aa}r ref.:}}%
  \def\captionY@ref{{\small Dykkar ref.:}}%
}
\addto\extrasnorsk{%
  \def\captionO@ref{{\small V{\aa}r ref.:}}%
  \def\captionY@ref{{\small Deres ref.:}}%
}
\addto\extrasenglish{%
  \def\captionO@ref{{\small Our ref.:}}%
  \def\captionY@ref{{\small Your ref.:}}%
}
\addto\extrasamerican{%
  \def\captionO@ref{{\small Our ref.:}}%
  \def\captionY@ref{{\small Your ref.:}}%
}
\addto\extrasdanish{%
  \def\captionO@ref{{\small Vores ref.:}}%
  \def\captionY@ref{{\small Deres ref.:}}%
}
%
%% Modification part:
%
\addtolength{\textwidth}{\oddsidemargin}
\setlength{\oddsidemargin}{0pt}
\addtolength{\textwidth}{\evensidemargin}
\setlength{\evensidemargin}{0pt}
\setlength{\longindentation}{0pt}
\setlength{\FIRST@textheight}{\textheight}
\addtolength{\FIRST@textheight}{-85mm}
\addtolength{\FIRST@textheight}{1in}
\addtolength{\FIRST@textheight}{\topmargin}
\setlength{\OLD@textheight}{\textheight}
\addtolength{\OLD@textheight}{\headheight}
\addtolength{\OLD@textheight}{\headsep}
\setlength{\OLD@headsep}{\headsep}
\addtolength{\FIRST@textheight}{\topskip}
\addtolength{\FIRST@textheight}{\headsep}
\global\topskip=0pt
\global\headsep=0pt
\global\textheight\FIRST@textheight
\ifr@gged\raggedright\fi
%\def\@texttop{}

%
% Modify the first page layout:
%
\def \ps@firstpage{%
  \setlength\unitlength{1mm}%
  \setlength\topmargin{-1in}   % The 1in space given in the dvi drivers
  \setlength\box@width{\textwidth}%
  \divide\box@width\unitlength % This will be the width of the picture
                               % environment
  \setlength\half@box{\textwidth}%
  \addtolength\half@box{-8cm}  % This is the room left for the
                               % \telephone field without clashing
                               % with the window of the envelope.
  \setlength{\headheight}{85mm}
  \setlength\box@height{\headheight}
  \setlength\window@top{\box@height}
  \divide\box@height\unitlength
  \addtolength{\window@top}{-40mm}
  \divide\window@top\unitlength
%  \setlength{\headsep}{\OLD@headsep}
  \divide\to@address\unitlength
  \def \@evenhead{%
    \begin{picture}(\number\box@width,\number\box@height)%
      \put(\number\to@address,\number\window@top){\makebox(0,0)[tl]{\begin{minipage}[c][20mm][c]{85mm}
            \toname\\
            \toaddress
          \end{minipage}}}%
      \put(0,55){\makebox(0,0)[bl]{\begin{minipage}{\textwidth}
            \ifx\@empty\fromname % In case you don't use \name
            \else %
            \fromname\\
            \fi
            \fromaddress
          \end{minipage}}}%
      \put(\number\box@width,55){\makebox(0,0)[br]{\begin{minipage}{\half@box}
            \raggedleft\ifx\@empty\fromlocation \else \fromlocation,\ \fi%
            % In case you don't use \location
            {\ifx\@empty\Date@Year\else%
              \def\year{\Date@Year}%
              \def\month{\Date@Month}%
              \def\day{\Date@Day}%
             \fi%
             \@date}
          \end{minipage}}}%
      \ifx\@empty\telephonenum\else %
      \put(\number\box@width,15){\makebox(0,0)[br]{\begin{minipage}{\half@box}
            \raggedleft\telephonenum
          \end{minipage}}}%
      \fi%
      \ifx\@empty\Y@ref\else %
      \put(0,5){\makebox(0,0)[cl]{\captionY@ref\ \Y@ref}}%
      \fi%
      \ifx\@empty\O@ref\else %
      \put(70,5){\makebox(0,0)[cl]{\captionO@ref\ \O@ref}}%
      \fi%
%     \put(0,0){\vector(1,0){\number\box@width}}%
%     \put(0,0){\vector(0,1){\number\box@height}}%
      % These two folding lines are placed at 10.4mm from the left
      % edge of the paper, running left way off the edge. 
      \ifx\@empty\O@nofoldinglines
      \put(-15,-20){\makebox(0,0)[cl]{\line(-1,0){20}}}%
% 2005-05-14: I don't want the one for E65 envelopes (Allan Odgaard)
%     \put(-15,-63){\makebox(0,0)[cl]{\line(-1,0){20}}}%
      \fi%
    \end{picture}}%
  \def \@oddhead{\@evenhead}%
  \def \@oddfoot{%
    \global\headheight=0pt%
    \global\headsep=0pt}%
  \def \@evenfoot{}%
}
%
% Modify layout of other pages:
%
\def \ps@plain{%
  \def \@oddhead{}%
  \def \@evenhead{}%
  \def \@evenfoot{\normalfont\rmfamily\normalsize\mdseries\upshape\hfil
        -- \thepage\ --\hfil}
  \def \@oddfoot{\@evenfoot}%
}
%
% Modify \opening:
%
\renewcommand{\opening}[1]{%
  \thispagestyle{firstpage} 
  \global\textheight\OLD@textheight%
  {#1\par\nobreak}}
%
% Modify \closing:
%
\renewcommand{\closing}[1]{\par\nobreak\vspace{5\parskip}%
  \stopbreaks
  \noindent
  \ifx\@empty\fromaddress\else
  \hspace*{\longindentation}\fi
  \raggedright
  \ignorespaces #1\\[6\medskipamount]%
  \ifx\@empty\fromsig
  \fromname
  \else \fromsig \fi\strut
  \par
  \global\textheight\FIRST@textheight}
%
\pagestyle{plain}
%
% Mailing labels:
%
\renewcommand*{\startlabels}{\pagestyle{empty}%
%% 
%% This is file `labels.sty',
%% generated with the docstrip utility.
%% 
%% The original source files were:
%% 
%% labels.dtx  (with options: `package')
%% Copyright (C) 1993-1994-1995 by Sebastian Rahtz 
%% All rights reserved. 
%% 
%% Permission is granted to to customize the declarations in this file to 
%% serve the needs of your installation. However, no permission is 
%% granted to distribute a modified version of this file under its 
%% original name. 
%% 
\def\LabelsFileInfo{1995/06/22\space10}
%% File: labels.dtx  Copyright (C) 1993-1994-1995 by Sebastian Rahtz
%%   and Grant Gustafson
%% All rights reserved.
\newdimen\LeftBorder
\newdimen\RightBorder
\newdimen\TopBorder
\newdimen\BottomBorder
\newcount\numberoflabels
\newdimen\label@width
\newdimen\label@height
\newdimen\half@label
\newdimen\area@width
\newdimen\addr@width
\newdimen\LabTmp
\newsavebox{\this@label}
\newcount\label@number
\newcount\skip@labels
\newcount\l@so@far
\newif\ifLabelGrid
\newif\iffirst@label
\newif\ifLabelInfo
\first@labeltrue
\LabelGridfalse
\LabelInfofalse
\LeftBorder=8mm
\RightBorder=8mm
\TopBorder=9mm
\BottomBorder=2mm
\textwidth=\paperwidth
\textheight=\paperheight
\topmargin=-1in
\headheight=0em
\headsep=0em
\topskip=0em
\footskip=0em
\oddsidemargin=-1in
\evensidemargin=-1in
\pagestyle{empty}
\parindent=0em
\parskip=0pt
\def\@LabelSetup{%
\global\label@width\textwidth%
\global\divide\label@width by\LabelCols%
\global\label@height\textheight%
\global\advance\label@height by-\TopBorder%
\global\advance\label@height by-\BottomBorder%
\global\divide\label@height by\LabelRows%
\global\topmargin=-1in\global\advance\topmargin by\TopBorder%
\global\area@width=\label@width%
\global\advance\area@width by -\LeftBorder%
\global\advance\area@width by -\RightBorder%
\ifLabelGrid%
\global\advance\area@width by-2\fboxsep%
\global\advance\area@width by-2\fboxrule%
\fi%
\ifLabelGrid%
\global\advance\label@height by-2\fboxsep%
\global\advance\label@height by-2\fboxrule%
\fi%
\global\half@label=\label@height\divide\half@label by2\relax
\global\label@number=1\relax
}
\def\LabelSetup{\@LabelSetup}
\numberoflabels=1
\def\sticky@label{\l@so@far=0%
\loop\ifnum\l@so@far<\numberoflabels\advance\l@so@far by 1\make@label%
\repeat}
\def\make@label{%
\ifLabelGrid%
 \let\boxing@type\framebox%
\else%
 \let\boxing@type\makebox%
\fi%
\settowidth{\LabTmp}{\usebox{\this@label}}%
\ifdim\LabTmp=0cm\let\action=\relax\else\let\action=\BuildB@x\fi%
\advance\LabTmp by -\area@width%
\ifdim\LabTmp>0cm\relax\fi%
\settoheight{\LabTmp}%
{\begin{tabular}{l}\usebox{\this@label}\end{tabular}}%
\advance\LabTmp by -\half@label%
\ifdim\LabTmp>0cm\relax%
\LabTmp=2\LabTmp\fi%
\ifnum\skip@labels<\sk@pped\let\action=\BuildB@x\fi%
\action
}
\def\BuildB@x{%
\boxing@type[\label@width][c]{%
\rule{0pt}{\label@height}%
\raisebox{\half@label}[0pt][0pt]{%
\rule{\LeftBorder}{0pt}%
\usebox{\this@label}%
\rule{\RightBorder}{0pt}%
}}%
\ifnum\theskiplabels>0\message{x}\else\message{+}\fi%
\ifnum\label@number=\LabelCols%
\message{|}%
\endgraf\nointerlineskip%
\global\label@number=1\else\global\advance\label@number by 1\fi%
}%
%
\ifnum\theskiplabels>0
\numberoflabels=\theskiplabels
\addresslabel{\rule{0pt}{0pt}}
\setcounter{skiplabels}{0}
\numberoflabels=1
\fi
}
%
\newcount\@Milli
\def\ToMilli#1{\@Milli=#1\advance\@Milli by93225\relax
\divide\@Milli by 186450\relax}
\newcommand{\genericlabel}[1]{%
\iffirst@label\LabelSetup\first@labelfalse\fi%
\savebox{\this@label}{#1}\sticky@label\@gobblecr}
\long\def\L@dblarg#1{\@ifnextchar[{#1}{\L@xdblarg{#1}}}
\long\def\L@xdblarg#1#2{#1[]{#2}}
\long\def\addresslabel{\L@dblarg{\@addresslabel}}
\long\def\@addresslabel[#1]#2{\genericlabel{#1%
\begin{tabular}{@{}p{\area@width}@{}}\raggedright #2\end{tabular}}}
\long\def\boxedaddresslabel{\L@dblarg{\@boxedaddresslabel}}
\long\def\@boxedaddresslabel[#1]#2{\genericlabel{#1%
\addr@width=\area@width\advance\addr@width by-2\fboxsep%
\advance\addr@width by-2\fboxrule\fbox{%
\begin{tabular}{@{}p{\addr@width}@{}}\raggedright #2\end{tabular}}}}
\newcount\sk@pped
\newcounter{skiplabels}
\def\skiplabels#1{\setcounter{skiplabels}{#1}}
%
\newcount\LabelCols
\newcount\LabelRows
\ifdim\paperwidth=210mm\relax%
   \LabelCols=3\relax\LabelRows=8\relax% a4paper
\else
   \LabelCols=3\relax\LabelRows=7\relax% letterpaper
\fi%
\def\l@belsheet(#1x#2){\LabelCols=#1\LabelRows=#2}
\newcommand{\labelsheet}[1]{\l@belsheet(#1)}
%
\renewcommand*{\mlabel}[2]{%
  \ifx#1\@empty\else\addresslabel{#1}\fi
  \ifl@@bels\addresslabel{#2}\fi}
%
\ifl@bels\makelabels\fi
\ifl@@@bels\renewcommand*{\returnaddress}{\fromname\\\fromaddress}\fi
%
% End of brev.cls
