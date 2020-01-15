\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{aaltoslides}
%Pass your school to aaltologo with 
%\PassOptionsToPackage{ELEC}{aaltologo} in your master slides

\RequirePackage{aaltologo}
\RequirePackage{graphicx,color}
%\RequirePackage{enumitem}


\LoadClass{beamer}

\logo{}
\newcommand{\smalllogo}{}
\newcommand{\largelogo}{}

\newcommand\aaltofootertext[3]{\def\footfrow{#1}\def\footsrow{#2}\def\foottrow{#3}}
\aaltofootertext{}{}{}

\newif\iffooter\footertrue
\newif\ifnormaltitle\normaltitlefalse

%Itemize environment
%\setlist[itemize]{leftmargini=1ex}

\setlength\leftmargini {0ex}
\setlength\leftmarginii {1.5ex}
\setlength\leftmarginiii {1.5ex}

% AALTO COLORS DEFINED IN AALTOLOGO

% LENGTHS
\newlength\aaltofooterplace \setlength\aaltofooterplace{8.5cm}
\newlength\aaltofooterruleheight \setlength\aaltofooterruleheight{2.5pt}
\newlength\aaltofooterrulewidth \setlength\aaltofooterrulewidth{12cm}
\newlength\aaltotitleboxplace \setlength\aaltotitleboxplace{0cm}
\newlength\aaltotitleboxheight \setlength\aaltotitleboxheight{5cm}
\newlength\aaltotitleboxwidth \setlength\aaltotitleboxwidth{12cm}
\newlength\aaltotitlesep \setlength\aaltotitlesep{0.3cm}
\newlength\aaltotitleentrysep \setlength\aaltotitleentrysep{0.2cm}
\newlength\largelogoheight \setlength\largelogoheight{1.5cm}
\newlength\smalllogoheight \setlength\smalllogoheight{0.5cm}
\newcommand\largelogoscale{0.3}
\newcommand\smalllogoscale{0.3}

% OPTIONS
% Primary color
\DeclareOption{first=yellow}{\definecolor{primarycolor}{named}{aaltoYellow}}
\DeclareOption{first=red}{\definecolor{primarycolor}{named}{aaltoRed}}
\DeclareOption{first=blue}{\definecolor{primarycolor}{named}{aaltoBlue}}
\DeclareOption{first=gray}{\definecolor{primarycolor}{named}{aaltoGray}}
\DeclareOption{first=lgreen}{\definecolor{primarycolor}{named}{aaltoLightGreen}}
\DeclareOption{first=dgreen}{\definecolor{primarycolor}{named}{aaltoGreen}}
\DeclareOption{first=purple}{\definecolor{primarycolor}{named}{aaltoPurple}}
\DeclareOption{first=magenta}{\definecolor{primarycolor}{named}{aaltoMagenta}}
\DeclareOption{first=orange}{\definecolor{primarycolor}{named}{aaltoOrange}}
\DeclareOption{first=lorange}{\definecolor{primarycolor}{named}{aaltoLightOrange}}
% Secondary color
\DeclareOption{second=yellow}{\definecolor{secondarycolor}{named}{aaltoYellow}}
\DeclareOption{second=red}{\definecolor{secondarycolor}{named}{aaltoRed}}
\DeclareOption{second=blue}{\definecolor{secondarycolor}{named}{aaltoBlue}}
\DeclareOption{second=gray}{\definecolor{secondarycolor}{named}{aaltoGray}}
\DeclareOption{second=lgreen}{\definecolor{secondarycolor}{named}{aaltoLightGreen}}
\DeclareOption{second=dgreen}{\definecolor{secondarycolor}{named}{aaltoGreen}}
\DeclareOption{second=purple}{\definecolor{secondarycolor}{named}{aaltoPurple}}
\DeclareOption{second=magenta}{\definecolor{secondarycolor}{named}{aaltoMagenta}}
\DeclareOption{second=orange}{\definecolor{secondarycolor}{named}{aaltoOrange}}
\DeclareOption{second=lorange}{\definecolor{secondarycolor}{named}{aaltoLightOrange}}

% Logo
\DeclareOption{logo=yellowexc}{%
   \renewcommand{\largelogo}{\AaltoLogoLarge{\largelogoscale}{!}{aaltoYellow}}
   \renewcommand{\smalllogo}{\AaltoLogoSmall{\smalllogoscale}{!}{aaltoYellow}}
}
\DeclareOption{logo=yellowquo}{%
   \renewcommand{\largelogo}{\AaltoLogoLarge{\largelogoscale}{''}{aaltoYellow}}
   \renewcommand{\smalllogo}{\AaltoLogoSmall{\smalllogoscale}{''}{aaltoYellow}}
}
\DeclareOption{logo=yellowque}{%
   \renewcommand{\largelogo}{\AaltoLogoLarge{\largelogoscale}{?}{aaltoYellow}}
   \renewcommand{\smalllogo}{\AaltoLogoSmall{\smalllogoscale}{?}{aaltoYellow}}
}
\DeclareOption{logo=redexc}{%
   \renewcommand{\largelogo}{\AaltoLogoLarge{\largelogoscale}{!}{aaltoRed}}
   \renewcommand{\smalllogo}{\AaltoLogoSmall{\smalllogoscale}{!}{aaltoRed}}
}
\DeclareOption{logo=redquo}{%
   \renewcommand{\largelogo}{\AaltoLogoLarge{\largelogoscale}{''}{aaltoRed}}
   \renewcommand{\smalllogo}{\AaltoLogoSmall{\smalllogoscale}{''}{aaltoRed}}
}
\DeclareOption{logo=redque}{%
   \renewcommand{\largelogo}{\AaltoLogoLarge{\largelogoscale}{?}{aaltoRed}}
   \renewcommand{\smalllogo}{\AaltoLogoSmall{\smalllogoscale}{?}{aaltoRed}}
}
\DeclareOption{logo=blueexc}{%
   \renewcommand{\largelogo}{\AaltoLogoLarge{\largelogoscale}{!}{aaltoBlue}}
   \renewcommand{\smalllogo}{\AaltoLogoSmall{\smalllogoscale}{!}{aaltoBlue}}
}
\DeclareOption{logo=bluequo}{%
   \renewcommand{\largelogo}{\AaltoLogoLarge{\largelogoscale}{''}{aaltoBlue}}
   \renewcommand{\smalllogo}{\AaltoLogoSmall{\smalllogoscale}{''}{aaltoBlue}}
}
\DeclareOption{logo=blueque}{%
   \renewcommand{\largelogo}{\AaltoLogoLarge{\largelogoscale}{?}{aaltoBlue}}
   \renewcommand{\smalllogo}{\AaltoLogoSmall{\smalllogoscale}{?}{aaltoBlue}}
}
\DeclareOption{logo=random}{%
  \renewcommand{\largelogo}{\AaltoLogoRandomLarge{\largelogoscale}}
  \renewcommand{\smalllogo}{\AaltoLogoRandomSmall{\smalllogoscale}}
}

% Other options
\DeclareOption{nofoot}{\footerfalse}
\DeclareOption{nologo}{\renewcommand{\largelogo}{\vspace{\largelogoheight}}\renewcommand{\smalllogo}{}}
\DeclareOption{normaltitle}{\normaltitletrue}

\ExecuteOptions{first=purple,second=blue,logo=redexc}
\ProcessOptions

\newcommand{\aaltosl@name}{aaltoslides}
\newcommand{\aaltosl@date}{Feb 21, 2016}
\newcommand{\aaltosl@version}{Version 2.0}
\newcommand{\aaltosl@id}{\aaltosl@version\space (\aaltosl@date)}
\typeout{********************************************************^^J%
'\aaltosl@name'\space Document Class\space\aaltosl@id^^J%
Author: Kimmo Jarvinen (kimmo.jarvinen@tkk.fi)^^J%
^^J%
Last modified by Marko Kosunen (marko.kosunen@aalto.fi)^^J%
********************************************************^^J%
}

% SOME CUSTOMIZATION
\useinnertheme[shadow]{rounded} % Rounded blocks
\setbeamertemplate{navigation symbols}{} % Remove navigation symbols
\setbeamertemplate{frametitle continuation}[from second] 
\setbeamersize{text margin left=1cm, text margin right=1cm}
\iffooter\setbeamertemplate{footline}{\vspace{1.1cm}}\fi % B. Brumley's fix to the "text too low problem"

% Set fonts
\renewcommand{\rmdefault}{phv} % Helvetica (resembles Arial)
\renewcommand{\sfdefault}{phv} % Helvetica (resembles Arial)
\setbeamerfont{title}{size=\Large, series=\bfseries}
\setbeamerfont{frametitle}{size=\Large, series=\bfseries}

% Set colors
\setbeamercolor{structure}{fg=primarycolor}
\setbeamercolor{alerted text}{fg=secondarycolor}
\setbeamercolor{example text}{fg=secondarycolor}

%%BLOCK
\setbeamercolor{block title}{fg=white,bg=secondarycolor!75}
\setbeamercolor{block body}{fg=black,bg=secondarycolor!10}

% FOOTER
\usebackgroundtemplate{
  \iffooter
  \begin{minipage}{\paperwidth}
    \begin{center}
      \vspace{\aaltofooterplace}
      {\color{primarycolor}\rule{\aaltofooterrulewidth}{\aaltofooterruleheight}}
    \end{center}
    \vspace{-0.65cm}
    \flushleft\hspace{0.40cm}\mbox{\smalllogo}
    \vspace{-0.9cm}
    \begin{flushright}
    \Tiny \bfseries
    \footfrow \qquad \ \, \phantom{0} \\
    {\color{gray} \footsrow \qquad \ \, \phantom{0} \\
    \foottrow \qquad \ \, \phantom{0} \\}
    \end{flushright}
  \end{minipage}
  \fi
}

% TITLEPAGE
\ifnormaltitle
  % More traditional title page
  \newcommand{\aaltotitleframe}{
  {\usebackgroundtemplate{}
  \frame{
  \vspace{0.6cm}
  \largelogo
  \vspace{0.3cm}
  \titlepage
  }}}
\else
  % Aalto-style title page
  \newcommand{\aaltotitleframe}{
  {\usebackgroundtemplate{
    \begin{minipage}{\paperwidth}
      \vspace{0.8cm}
      \hspace{0.5cm}
      \mbox{\largelogo}
      \vspace{\aaltotitleboxplace}
      \begin{center}
        {\color{primarycolor}\rule{\aaltotitleboxwidth}{\aaltotitleboxheight}}
      \end{center}
    \end{minipage} 
  }
  \frame[t]{
  \vspace{1.2cm}
  \vspace{\largelogoheight}
  {\color{white} 
  {\bfseries \Large \inserttitle}  \\[\aaltotitlesep]
  \insertauthor \\[\aaltotitleentrysep]
  \footnotesize \insertinstitute \\[\aaltotitleentrysep]
  \insertdate
  }}
  }}
\fi

