#!/bin/bash
# 
# Version 3 (2006-08-14) - by Soryu
# 
# This file contains support functions for generating HTML, to be used with TextMate's HTML output window. Please don't put functions in here without coordinating the core Bundle developers on IRC.
# 
# Further Notes:
# This is in flux right (see http://macromates.com/wiki/Suggestions/StylingHTMLOutput) now as I'm updating the Web Preview (HTML output). `html.sh` is the old version. To make for a smooth transition I threw out all the old (now partly incompatible and as I see it hardly used) functions and kind of started from scratch.

# Generate HTML header up to and including the body tag. Also includes the default stylesheet and javascript.
# USAGE: html_header [page title] [page info, like Bundle Name, shown at the top right]
html_header() {
	case ${#@} in
		1)	export WINDOW_TITLE="$1"; export PAGE_TITLE="$1";                      ;;
		2)	export WINDOW_TITLE="$1"; export PAGE_TITLE="$1"; export SUB_TITLE="$2";;
		3)	export WINDOW_TITLE="$1"; export PAGE_TITLE="$2"; export SUB_TITLE="$3";;
	esac

	"${TM_RUBY:-ruby}" -r"$TM_SUPPORT_PATH/lib/web_preview.rb" <<-'RUBY'
		puts html_head(
			:window_title	=> ENV['WINDOW_TITLE'],
			:page_title		=> ENV['PAGE_TITLE'],
			:sub_title		=> ENV['SUB_TITLE']
		)
	RUBY
}

# Generate HTML footer.
# USAGE: html_footer
html_footer() {
	echo $'	</div>\n</body>\n</html>'
}

