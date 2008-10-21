<?xml version='1.0' encoding='utf-8'?>

<!-- XHTML-to-S5 converted by Fletcher Penney
	specifically designed for use with Markdown created XHTML
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

<!-- to do:
	an option to select what h-level should be slides (for instance, if h2, then each h1 would be a slide, containing list of h2's.  Then h2's converted into slides....
	
	-->
	
<xsl:stylesheet
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	version="1.0">

	<xsl:output method='html' encoding='utf-8' indent="yes"/>

	<xsl:strip-space elements="*" />

	<xsl:variable name="theme">i18n</xsl:variable>

	<xsl:param name="match"/>

	<xsl:template match="/">
		<html>
		<xsl:apply-templates select="node()"/>
		</html>
	</xsl:template>

	<xsl:template match="head">
		<head>
		<xsl:apply-templates select="meta"/>
		<xsl:apply-templates select="node()"/>
		<meta name="version" content="S5 1.1" />
		<link rel="stylesheet" href="ui/{$theme}/slides.css" type="text/css" media="projection" id="slideProj" />
		<link rel="stylesheet" href="ui/default/outline.css" type="text/css" media="screen" id="outlineStyle" />
		<link rel="stylesheet" href="ui/default/print.css" type="text/css" media="print" id="slidePrint" />
		<link rel="stylesheet" href="ui/default/opera.css" type="text/css" media="projection" id="operaFix" />
		<script src="ui/default/slides.js" type="text/javascript"></script>
		</head>
	</xsl:template>

	<xsl:template match="meta" mode="match">
		<xsl:if test="translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
			'abcdefghijklmnopqrstuvwxyz') = $match">
			<xsl:value-of select="@content"/>
		</xsl:if>
	</xsl:template>

	<xsl:template match="title">
		<title><xsl:value-of select="."/></title>
	</xsl:template>

	<xsl:template match="body">
		<body>
		<div class="layout">
			<div id="currentSlide"></div>
			<div id="header"></div>
			<div id="footer">
			<h1><xsl:value-of select="/html/head/title"/></h1>
			<h2>
			<xsl:apply-templates select="/html/head/meta[@name]" mode="match">
				<xsl:with-param name="match" select="'author'"/>
			</xsl:apply-templates>
			</h2>
			</div>
			<div id="controls"></div>
		</div>
		<div class="presentation">
		<div class="slide">
		<h1><xsl:value-of select="/html/head/title"/></h1>
		<h3>
		<xsl:apply-templates select="/html/head/meta[@name]" mode="match">
			<xsl:with-param name="match" select="'author'"/>
		</xsl:apply-templates>
		</h3>
		<xsl:variable name="url">
			<xsl:apply-templates select="/html/head/meta[@name]" mode="match">
				<xsl:with-param name="match" select="'url'"/>
			</xsl:apply-templates>
		</xsl:variable>
		<h4><a href="{$url}">
		<xsl:apply-templates select="/html/head/meta[@name]" mode="match">
			<xsl:with-param name="match" select="'organization'"/>
		</xsl:apply-templates>
		</a></h4>
		<h4>
		<xsl:apply-templates select="/html/head/meta[@name]" mode="match">
			<xsl:with-param name="match" select="'date'"/>
		</xsl:apply-templates>
		</h4>				
		</div>
		
		<xsl:apply-templates select="h1"/>
		</div>
		</body>
	</xsl:template>


	<!-- http://www.biglist.com/lists/xsl-list/archives/200401/msg00696.html -->
	<xsl:template match="h1">
		<div class="slide">
		<h1><xsl:value-of select="."/></h1>
		<xsl:variable name="items" select="count(following-sibling::*) - count(following-sibling::h1/following-sibling::*)"/>
		<xsl:apply-templates select="following-sibling::*[position() &lt; $items]" mode="slide"/>
		</div>
	</xsl:template>

	<xsl:template match="h1[last()]">
		<div class="slide">
		<h1><xsl:value-of select="."/></h1>
		<xsl:variable name="items" select="count(following-sibling::*) - count(following-sibling::h1/following-sibling::*)"/>
		<xsl:apply-templates select="following-sibling::*[position() &lt;= $items]" mode="slide"/>
		</div>
	</xsl:template>

	<xsl:template match="p" mode="slide">
		<div class="handout">
		<xsl:copy-of select="."/>
		</div>
	</xsl:template>

	<xsl:template match="p[1]" mode="slide">
		<xsl:copy-of select="."/>
	</xsl:template>

	<xsl:template match="li" mode="slide">
		<li>
		<xsl:apply-templates select="node()" mode="slide"/>
		</li>
	</xsl:template>

	<xsl:template match="ol" mode="slide">
		<ol class="incremental show-first">
			<xsl:apply-templates select="node()" mode="slide"/>
		</ol>
	</xsl:template>

	<xsl:template match="ul" mode="slide">
		<ul class="incremental show-first">
			<xsl:apply-templates select="node()" mode="slide"/>
		</ul>
	</xsl:template>
</xsl:stylesheet>


