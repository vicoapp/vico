#!/bin/bash
#
# This file contains support functions for generating HTML, to be used with TextMate's
# HTML output window.  Please don't put functions in here without coordinating with me
# or Allan.
#
# Only some basic stuff is included, as well as stuff designed to work with the default
# stylesheet and javascript.
#
# Version 2 (2005-05-23).
# By Sune Foldager.
#

# Initialization.
_toggleID=1
declare -a _tagStack

# Types back the arguments if given, or stdin (internal use).
_doArg() {
   [ -n "$1" ] && echo -n "$@" || cat
}

# Generate JavaScript code (i.e. wrap arguments in script tags). A final ; is added.
# USAGE: javaScript <code...>
javaScript() {
	echo '<script type="text/javascript">'
	_doArg "$1"
	echo '</script>'
}

# Import JavaScript code.
# USAGE: importJS <local filename>
importJS() {
   echo '<script type="text/javascript">'
   cat "$1"
   echo '</script>'
}

# Execute JavaScript code after a delay (in milliseconds).
# USAGE: delayedExec <delay in ms> <code...>
delayedJS() {
   echo -n "<script type=\"text/javascript\">setTimeout('"
   _doArg "$2"
   echo "', $1);</script>"
}

# Redirect to a given URL.
# USAGE: redirect <url>
redirect() {
	javaScript "window.location='$1'"
}

# Generate CSS (i.e. wrap arguments in style tags).
# USAGE: css <styles...>
css() {
   echo '<style type="text/css">'
   _doArg "$1"
   echo '</style>'
}

# Import a CSS script.
# USAGE: importCSS <local filename>
importCSS() {
   echo '<style type="text/css">'
   cat "$1"
   echo '</style>'
}

# Generate HTML header up to and including the body tag. Also includes the default
# stylesheet and javascript.
# USAGE: htmlHeader [page title] [optional <head> stuff]
htmlHeader() {
   echo '<?xml version="1.0" encoding="utf-8"?>'
   echo '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"'
   echo '	"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">'
   echo '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en"><head>'
   echo '<meta http-equiv="content-type" content="text/html; charset=utf-8" />'
   [ -n "$1" ] && echo "<title>$1</title>"
   importCSS "${TM_SUPPORT_PATH}/css/default.css"
   importJS "${TM_SUPPORT_PATH}/script/default.js"
   [ -n "$2" ] && echo "$2"
   echo '</head><body>'
}

# Generate HTML footer.
# USAGE: htmlFooter
htmlFooter() {
   echo '</body></html>'
}

# Close the HTML window, after a delay (in milliseconds). Defaults to 1 second.
# USAGE: closeWindow [delay in ms]
closeWindow() {
   local to=$1
   [ ${to:=1000} ]
	delayedJS $to 'window.close();'
}

# Typesets the arguments in <em> tags.
# USAGE: emph <text...>
emph() {
   echo -n '<em>'
   _doArg "$1"
   echo '</em>'
}

# Typesets the arguments in <strong> tags.
# USAGE: strong <text...>
strong() {
   echo -n '<strong>'
   _doArg "$1"
   echo '</strong>'
}

# Creates a link (HTML anchor tag)
# USAGE: link <url> <text...>
link() {
   echo -n "<a href=\"$1\">"
   _doArg "$2"
   echo '</a>'
}

# Generate a tag, with optional class, id and other attributes.
# USAGE: beginTag <name> [class] [id] [extra]
#        endTag <name>
#        tag <name> <contents...> [class] [id] [extra]
beginTag() {
   echo -n "<$1"
   [ -n "$2" ] && echo -n " class=\"$2\""
   [ -n "$3" ] && echo -n " id=\"$3\""
   [ -n "$4" ] && echo -n " $4"
   echo '>'
   _tagStack[${#_tagStack[*]}]="$1"
}
endTag() {
   if ((${#_tagStack[*]} > 0)); then
      local index=$((${#_tagStack[*]} - 1))
      echo -n '</'
      echo -n ${_tagStack[$index]}
      echo '>'
      unset _tagStack[$index]
   fi
}
tag() {
   beginTag "$1" "$3" "$4" "$5"
   _doArg "$2"
   endTag
}

# Creates a toggle tag, and bumps the global ID. Used by the functions below.
# Mainly an internal function; USAGE: makeToggle
makeToggle() {
   beginTag div toggle
   beginTag span '' "toggle${_toggleID}_s" 'style="display: inline;"'
   link "javascript:showElement('toggle${_toggleID}');" 'Show details'
   endTag
   beginTag span '' "toggle${_toggleID}_h" 'style="display: none;"'
   link "javascript:hideElement('toggle${_toggleID}');" 'Hide details'
   endTag
   endTag
   _toggleID=$((_toggleID + 1))
}

# Creates a toggle box, which consists of the following:
#  - The main box.
#  - A show/hide button.
#  - A part that is always displayed (called 'brief').
#  - A part initially hidden, but toggleable with the button (called 'details').
# The box will be left open at the 'details' part. Use toggleBoxE to close it.
# USAGE: beginToggleBox <class name> <brief matter...>
#        endToggleBox
#        toggleBox <class name> <brief matter> <detailed matter...>
beginToggleBox() {
   local id=$_toggleID
   beginTag div "$1"
   makeToggle
   beginTag div brief
   _doArg "$2"
   endTag
   beginTag div details "toggle${id}_b" 'style="display: none;"'
}
endToggleBox() {
   endTag
   endTag
}
toggleBox() {
   beginToggleBox "$1" "$2"
   _doArg "$3"
   endToggleBox
}

# Quick way to create sideBars and boxes (see the default stylesheet).
# Leaves the box open at the 'details' part.
# USAGE: beginSideBar/box <brief matter...>
#        sideBar/box <brief matter> <detailed matter...>
beginSideBar() {
   beginToggleBox sideBar "$1"
}
endSideBar() {
   endToggleBox
}
sideBar() {
   toggleBox sideBar "$1" "$2"
}
beginBox() {
   beginToggleBox box "$1"
}
endBox() {
   endToggleBox
}
box() {
   toggleBox box "$1" "$2"
}

