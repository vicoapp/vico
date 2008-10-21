<?xml version='1.0' encoding='utf-8'?>

<!-- XHTML-to-Latex converter by Fletcher Penney
	specifically designed for use with Markdown created XHTML
	
	Version 2.1.1
-->

<!-- 
# Copyright (C) 2005  Fletcher T. Penney <fletcher@freeshell.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
#    Free Software Foundation, Inc.
#    59 Temple Place, Suite 330
#    Boston, MA 02111-1307 USA
-->

<!-- To Do
-->


<xsl:stylesheet
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	version="1.0">

	<xsl:output method='text' encoding='utf-8'/>

	<xsl:strip-space elements="*" />

	<xsl:variable name="newline">
<xsl:text>
</xsl:text>
	</xsl:variable>

	<xsl:param name="footnoteId"/>

	<xsl:decimal-format name="string" NaN="1"/>


	<xsl:template match="title">
		<xsl:text>\def\mytitle{</xsl:text>
			<xsl:call-template name="clean-text">
				<xsl:with-param name="source">
					<xsl:value-of select="."/>
				</xsl:with-param>
			</xsl:call-template>		
		<xsl:text>}
</xsl:text>
	</xsl:template>


	<xsl:template match="meta">
		<xsl:choose>
			<xsl:when test="translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
			'abcdefghijklmnopqrstuvwxyz') = 'subtitle'">
				<xsl:text>\def\mysubtitle{</xsl:text>
				<xsl:call-template name="clean-text">
					<xsl:with-param name="source">
						<xsl:value-of select="@content"/>
					</xsl:with-param>
				</xsl:call-template>		
				<xsl:text>}
</xsl:text>
			</xsl:when>
			<xsl:when test="translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
			'abcdefghijklmnopqrstuvwxyz') = 'author'">
				<xsl:text>\def\myauthor{</xsl:text>
				<xsl:call-template name="clean-text">
					<xsl:with-param name="source">
						<xsl:value-of select="@content"/>
					</xsl:with-param>
				</xsl:call-template>		
				<xsl:text>}
</xsl:text>
			</xsl:when>
			<xsl:when test="translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
			'abcdefghijklmnopqrstuvwxyz') = 'date'">
				<xsl:text>\date{</xsl:text>
				<xsl:call-template name="clean-text">
					<xsl:with-param name="source">
						<xsl:value-of select="@content"/>
					</xsl:with-param>
				</xsl:call-template>		
				<xsl:text>}
</xsl:text>
			</xsl:when>
			<xsl:when test="translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
			'abcdefghijklmnopqrstuvwxyz') = 'copyright'">
				<xsl:text>\def\mycopyright{</xsl:text>
				<xsl:call-template name="clean-text">
					<xsl:with-param name="source">
						<xsl:value-of select="@content"/>
					</xsl:with-param>
				</xsl:call-template>		
				<xsl:text>}
</xsl:text>
			</xsl:when>
			<xsl:when test="translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
			'abcdefghijklmnopqrstuvwxyz') = 'keywords'">
				<xsl:text>\def\mykeywords{</xsl:text>
				<xsl:call-template name="replace-substring">
					<xsl:with-param name="original">
						<xsl:value-of select="normalize-space(@content)"/>
					</xsl:with-param>
					<xsl:with-param name="substring">
						<xsl:text> </xsl:text>
					</xsl:with-param>
					<xsl:with-param name="replacement">
						<xsl:text>, </xsl:text>
					</xsl:with-param>
				</xsl:call-template>
				<xsl:text>}
</xsl:text>
			</xsl:when>
			<xsl:when test="translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
			'abcdefghijklmnopqrstuvwxyz') = 'xmp'">
				<xsl:text>\includexmp{</xsl:text>
				<xsl:call-template name="clean-text">
					<xsl:with-param name="source">
						<xsl:value-of select="@content"/>
					</xsl:with-param>
				</xsl:call-template>		
				<xsl:text>}
</xsl:text>
			</xsl:when>
			<xsl:when test="translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
			'abcdefghijklmnopqrstuvwxyz') = 'bibtex'">
				<xsl:text>\def\mybibliocommand{\bibliography{</xsl:text>
				<xsl:call-template name="clean-text">
					<xsl:with-param name="source">
						<xsl:value-of select="@content"/>
					</xsl:with-param>
				</xsl:call-template>		
				<xsl:text>}}
</xsl:text>
			</xsl:when>
			<xsl:when test="translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
			'abcdefghijklmnopqrstuvwxyz') = 'bibliographystyle'">
				<xsl:text>\def\mybibliostyle{</xsl:text>
				<xsl:call-template name="clean-text">
					<xsl:with-param name="source">
						<xsl:value-of select="@content"/>
					</xsl:with-param>
				</xsl:call-template>		
				<xsl:text>}
</xsl:text>
			</xsl:when>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="body">
		<xsl:apply-templates select="*"/>
	</xsl:template>

	<xsl:template match="text()">
		<xsl:call-template name="clean-text">
			<xsl:with-param name="source">
				<xsl:value-of select="."/>
			</xsl:with-param>
		</xsl:call-template>		
	</xsl:template>
	
	<!-- Clean Up Special characters-->
	<xsl:template name="clean-text">
		<xsl:param name="source" />
      <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
      <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
      <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
      <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
      <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
      <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
      <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
       <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
        <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
        <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
         <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
        <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
         <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
         <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
         <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
         <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
         <xsl:call-template name="replace-substring">
         <xsl:with-param name="original">
           <xsl:value-of select="$source"/>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>\</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>$\backslash$</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
          </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>&#8212;</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>---</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>&#8211;</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>--</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>&#8216;</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>`</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>&#8230;</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>\ldots</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>&#8221;</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>''</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
        </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>&#8220;</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>``</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>&#8217;</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>'</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
        </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>%</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>\%</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>&amp;</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>\&amp;</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>}</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>\}</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>{</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>\{</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>_</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>\_</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>$</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>\$</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>&#xA9;</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>\textcopyright{}</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>#</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>\#</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
         </xsl:with-param>
         <xsl:with-param name="substring">
            <xsl:text>\$\backslash\$</xsl:text>
         </xsl:with-param>
         <xsl:with-param name="replacement">
            <xsl:text>$\backslash$</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
	</xsl:template>
 

	<!-- paragraphs -->
	
	<xsl:template match="p">
		<xsl:apply-templates select="node()"/>
		<xsl:value-of select="$newline"/>
		<xsl:value-of select="$newline"/>
	</xsl:template>

	<!-- footnote div -->
	<!-- print contents of the matching footnote -->
	<xsl:template match="div" mode="footnote">
		<xsl:if test="parent::div/@class = 'footnotes'">
			<xsl:if test="concat('#',@id) = $footnoteId">
				<xsl:apply-templates select="node()"/>
			</xsl:if>
		</xsl:if>
	</xsl:template>


	<!-- anchors -->
	<xsl:template match="a[@href]">
		<xsl:choose>
			<!-- footnote (my addition)-->
			<xsl:when test="@class = 'footnote'">
				<xsl:text>\footnote{</xsl:text>
				<xsl:apply-templates select="/html/body/div[@class]/div[@id]" mode="footnote">
					<xsl:with-param name="footnoteId" select="@href"/>
				</xsl:apply-templates>
				<xsl:text>}</xsl:text>
			</xsl:when>

			<xsl:when test="@class = 'reversefootnote'">
			</xsl:when>

			<!-- if href is same as the anchor text, then use \url{} -->
			<xsl:when test="@href = .">
				<xsl:text>\url{</xsl:text>
				<xsl:value-of select="@href"/>
				<xsl:text>}</xsl:text>
			</xsl:when>

			<!-- if href is mailto, use \href{} -->
			<xsl:when test="starts-with(@href,'mailto:')">
				<xsl:text>\href{</xsl:text>
				<xsl:value-of select="@href"/>
				<xsl:text>}{</xsl:text>
				<xsl:value-of select="substring-after(@href,'mailto:')"/>
				<xsl:text>}</xsl:text>
			</xsl:when>
			
			<!-- if href is local anchor, use autoref -->
			<xsl:when test="starts-with(@href,'#')">
				<xsl:value-of select="."/>
				<xsl:text> (\autoref{</xsl:text>
				<xsl:value-of select="substring-after(@href,'#')"/>
				<xsl:text>})</xsl:text>
			</xsl:when>
			
			<!-- otherwise, implement an href and put href in footnote
				for printed version -->
			<xsl:otherwise>
				<xsl:text>\href{</xsl:text>
				<xsl:value-of select="@href"/>
				<xsl:text>}{</xsl:text>
				<xsl:call-template name="clean-text">
					<xsl:with-param name="source">
						<xsl:value-of select="."/>
					</xsl:with-param>
				</xsl:call-template>		
				<xsl:text>}\footnote{\href{</xsl:text>
				<xsl:value-of select="@href"/>
				<xsl:text>}{</xsl:text>
				<xsl:call-template name="clean-text">
					<xsl:with-param name="source">
						<xsl:value-of select="@href"/>
					</xsl:with-param>
				</xsl:call-template>		
				<xsl:text>}}</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- ordered list -->
	<xsl:template match="ol">
		<xsl:text>\begin{enumerate}</xsl:text>
		<xsl:value-of select="$newline"/>
		<xsl:value-of select="$newline"/>
		<xsl:apply-templates select="*"/>
		<xsl:text>\end{enumerate}</xsl:text>
		<xsl:value-of select="$newline"/>
		<xsl:value-of select="$newline"/>
	</xsl:template>

	<!-- unordered list -->
	<xsl:template match="ul">
		<xsl:text>\begin{itemize}</xsl:text>
		<xsl:value-of select="$newline"/>
		<xsl:value-of select="$newline"/>
		<xsl:apply-templates select="*"/>
		<xsl:text>\end{itemize}</xsl:text>
		<xsl:value-of select="$newline"/>
		<xsl:value-of select="$newline"/>
	</xsl:template>
	
	<!-- list item -->
	<xsl:template match="li">
		<xsl:text>\item </xsl:text>
		<xsl:apply-templates select="node()"/>
		<xsl:value-of select="$newline"/>
	</xsl:template>
		
	<!-- code span -->
	<xsl:template match="code">
		<xsl:text>\texttt{</xsl:text>
		<xsl:apply-templates select="node()"/>
		<xsl:text>}</xsl:text>
	</xsl:template>

	<!-- line ending -->
	<xsl:template match="br">
		<xsl:text>\\
</xsl:text>
	</xsl:template>

	<!-- blockquote -->
	<xsl:template match="blockquote">
		<xsl:text>\begin{quotation}
</xsl:text>
		<xsl:apply-templates select="node()"/>
		<xsl:text>\end{quotation}

</xsl:text>
	</xsl:template>

	<!-- emphasis -->
	<xsl:template match="em">
		<xsl:text>{\itshape </xsl:text>
			<xsl:call-template name="clean-text">
				<xsl:with-param name="source">
					<xsl:value-of select="."/>
				</xsl:with-param>
			</xsl:call-template>		
		<xsl:text>}</xsl:text>
	</xsl:template>

	<!-- strong -->
	<xsl:template match="strong">
		<xsl:text>\textbf{</xsl:text>
			<xsl:call-template name="clean-text">
				<xsl:with-param name="source">
					<xsl:value-of select="."/>
				</xsl:with-param>
			</xsl:call-template>		
		<xsl:text>}</xsl:text>
	</xsl:template>
	
	<!-- horizontal rule -->
	<xsl:template match="hr">
		<xsl:text>\vskip 2em
\hrule height 0.4pt
\vskip 2em

</xsl:text>
	</xsl:template>

	<!-- image -->
	<xsl:template match="img">
		<xsl:text>\begin{figure}
</xsl:text>
		<xsl:if test="@title">
			<xsl:text>\caption{</xsl:text>
			<xsl:call-template name="clean-text">
				<xsl:with-param name="source">
					<xsl:value-of select="@title"/>
				</xsl:with-param>
			</xsl:call-template>		
			<xsl:text>}
</xsl:text>
		</xsl:if>
		<xsl:if test="@id">
			<xsl:text>\label{</xsl:text>
			<xsl:value-of select="@id"/>
			<xsl:text>}
</xsl:text>
		</xsl:if>
		<xsl:text>\begin{center}
\includegraphics{</xsl:text>
		<xsl:value-of select="@src"/>
		<xsl:text>}
\end{center}
\end{figure}
</xsl:text>
	</xsl:template>
	
	<!-- footnotes -->
	<xsl:template match="div">
		<xsl:if test="not(@class = 'footnotes')">
			<xsl:apply-templates select="node()"/>
		</xsl:if>
	</xsl:template>

	<!-- tables -->
	<xsl:template match="table">
		<xsl:text>\begin{table}[htbp]
\centering
</xsl:text>
		<xsl:apply-templates select="caption"/>
		<xsl:text>\begin{tabular}{@{}</xsl:text>
		<xsl:apply-templates select="col"/>		
		<xsl:text>@{}} \\ \toprule</xsl:text>
		<xsl:apply-templates select="thead"/>
		<xsl:apply-templates select="tbody"/>
		<xsl:apply-templates select="tr"/>
		<xsl:text>\end{tabular}
\end{table}

</xsl:text>
	</xsl:template>
	
	<xsl:template match="tbody">
		<xsl:apply-templates select="tr"/>
	</xsl:template>

	<xsl:template match="col">
		<xsl:choose>
			<xsl:when test="@align='center'">
				<xsl:text>c</xsl:text>
			</xsl:when>
			<xsl:when test="@align='right'">
				<xsl:text>r</xsl:text>
			</xsl:when>
			<xsl:otherwise>
				<xsl:text>l</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="thead">
		<xsl:apply-templates select="tr" mode="header"/>
		<xsl:text> \midrule
</xsl:text>
	</xsl:template>
	
	<xsl:template match="caption">
		<xsl:text>\caption{</xsl:text>
			<xsl:call-template name="clean-text">
				<xsl:with-param name="source">
					<xsl:value-of select="."/>
				</xsl:with-param>
			</xsl:call-template>		
		<xsl:text>}
</xsl:text>
	</xsl:template>
	
	<xsl:template match="tr" mode="header">
		<xsl:text>
</xsl:text>
		<xsl:apply-templates select="td|th"/>
		<xsl:text> \\ </xsl:text>
		<!-- figure out a way to count columns for \cmidrule{x-y} -->
		<xsl:apply-templates select="td[1]|th[1]" mode="cmidrule">
			<xsl:with-param name="col" select="1"/>
		</xsl:apply-templates>
	</xsl:template>

	<xsl:template match="td|th" mode="cmidrule">
		<xsl:param name="col"/>
		<xsl:param name="end" select="$col+format-number(@colspan,'#','string')-1"/>
		<xsl:if test="not(. = '')">
			<xsl:text> \cmidrule{</xsl:text>
			<xsl:value-of select="$col"/>
			<xsl:text>-</xsl:text>
			<xsl:value-of select="$end"/>
			<xsl:text>}</xsl:text>
		</xsl:if>
		<xsl:apply-templates select="following-sibling::*[1]" mode="cmidrule">
			<xsl:with-param name="col" select="$end+1"/>
		</xsl:apply-templates>
	</xsl:template>
	
	<xsl:template match="tr[last()]" mode="header">
		<xsl:text>
</xsl:text>
		<xsl:apply-templates select="td|th"/>
		<xsl:text> \\</xsl:text>
	</xsl:template>

	<xsl:template match="tr">
		<xsl:apply-templates select="td|th"/>
		<xsl:text> \\
</xsl:text>
	</xsl:template>

	<xsl:template match="tr[last()]">
		<xsl:apply-templates select="td|th"/>
		<xsl:text> \\ \bottomrule
</xsl:text>
	</xsl:template>

	<xsl:template match="tr/*[last()]">
		<xsl:if test="@colspan">
			<xsl:text>\multicolumn{</xsl:text>
			<xsl:value-of select="@colspan"/>
		</xsl:if>
		<xsl:if test="@colspan">
			<xsl:text>}{c}{</xsl:text>
		</xsl:if>
		<xsl:apply-templates select="node()"/>
		<xsl:text> </xsl:text>
		<xsl:if test="@colspan">
			<xsl:text>}</xsl:text>
		</xsl:if>
	</xsl:template>

	<xsl:template match="th|td">
		<xsl:if test="@colspan">
			<xsl:text>\multicolumn{</xsl:text>
			<xsl:value-of select="@colspan"/>
		</xsl:if>
		<xsl:if test="@colspan">
			<xsl:text>}{c}{</xsl:text>
		</xsl:if>
		<xsl:apply-templates select="node()"/>
		<xsl:if test="@colspan">
			<xsl:text>}</xsl:text>
		</xsl:if>
		<xsl:text>&amp;</xsl:text>
	</xsl:template>
	
	<!-- Default LaTeX code to add -->
	
	<xsl:template name="latex-header">
		<xsl:text>\usepackage{geometry}			% See geometry.pdf to learn the layout options.
								% There are lots.
								
\geometry{letterpaper}			% ... or a4paper or a5paper or ... 
%\geometry{landscape}			% Activate for rotated page geometry
%\usepackage[parfill]{parskip}	% Activate to begin paragraphs with an empty
								% line rather than an indent

\usepackage{ifpdf}
\usepackage{graphicx}
\usepackage{booktabs}
\usepackage[utf8]{inputenc}

% Definitions
\def\myauthor{Author}
\def\mytitle{Title}
\def\mycopyright{\myauthor}
\def\mykeywords{}
\def\mybibliostyle{plain}
\def\mybibliocommand{}
\def\mysubtitle{}

</xsl:text>
	</xsl:template>
	
	<xsl:template name="latex-intro">
				<xsl:text>

%
%	PDF Stuff
%

\ifpdf
  \pdfoutput=1
  \usepackage[
  	plainpages=false,
  	pdfpagelabels,
  	bookmarksnumbered,
  	pdftitle={\mytitle},
  	pagebackref,
  	pdfauthor={\myauthor},
  	pdfkeywords={\mykeywords}
  	]{hyperref}
  \usepackage{memhfixc}
\fi


% Title Information
\title{\mytitle \\ \mysubtitle}
\author{\myauthor}

\begin{document}
</xsl:text>
	</xsl:template>
	
	<xsl:template name="latex-footer">
		<xsl:text>% Bibliography
\bibliographystyle{\mybibliostyle}
\mybibliocommand

\end{document}
</xsl:text>
	</xsl:template>
	
	<!-- replace-substring routine by Doug Tidwell - XSLT, O'Reilly Media -->
	<xsl:template name="replace-substring">
		<xsl:param name="original" />
		<xsl:param name="substring" />
		<xsl:param name="replacement" select="''"/>
		<xsl:variable name="first">
			<xsl:choose>
				<xsl:when test="contains($original, $substring)" >
					<xsl:value-of select="substring-before($original, $substring)"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="$original"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="middle">
			<xsl:choose>
				<xsl:when test="contains($original, $substring)" >
					<xsl:value-of select="$replacement"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text></xsl:text>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="last">
			<xsl:choose>
				<xsl:when test="contains($original, $substring)">
					<xsl:choose>
						<xsl:when test="contains(substring-after($original, $substring), $substring)">
							<xsl:call-template name="replace-substring">
								<xsl:with-param name="original">
									<xsl:value-of select="substring-after($original, $substring)" />
								</xsl:with-param>
								<xsl:with-param name="substring">
									<xsl:value-of select="$substring" />
								</xsl:with-param>
								<xsl:with-param name="replacement">
									<xsl:value-of select="$replacement" />
								</xsl:with-param>
							</xsl:call-template>
						</xsl:when>	
						<xsl:otherwise>
							<xsl:value-of select="substring-after($original, $substring)"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text></xsl:text>
				</xsl:otherwise>		
			</xsl:choose>				
		</xsl:variable>		
		<xsl:value-of select="concat($first, $middle, $last)"/>
	</xsl:template>
	
</xsl:stylesheet>
