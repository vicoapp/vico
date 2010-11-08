unset BASH_ENV # avoid recursively running this script
export LC_CTYPE="en_US.UTF-8"

set +u # avoid warning when we use unset variables (if user had ‘set -u’ in his profile)

if [[ -d "$TM_SUPPORT_PATH/bin" ]]; then
	PATH="$PATH:$TM_SUPPORT_PATH/bin"
	if [[ -d "$TM_SUPPORT_PATH/bin/CocoaDialog.app/Contents/MacOS" ]]; then
		PATH="$TM_SUPPORT_PATH/bin/CocoaDialog.app/Contents/MacOS:$PATH"
	fi
fi

if [[ -d "$TM_BUNDLE_SUPPORT" && -d "$TM_BUNDLE_SUPPORT/bin" ]]; then
   PATH="$TM_BUNDLE_SUPPORT/bin:$PATH"
fi

export PATH

: ${TM_BASH_INIT:=$HOME/Library/Application Support/TextMate/bash_init.sh}
if [[ -f "$TM_BASH_INIT" ]]; then
	. "$TM_BASH_INIT"
fi

export RUBYLIB="${RUBYLIB:+$RUBYLIB:}$TM_SUPPORT_PATH/lib"

textmate_init () {
	[[ "$1" != / && "$1" != ~ ]] && textmate_init "$(dirname "$1")"
	[[ -f "$1/.textmate_init" ]] && . "$1/.textmate_init"
	[[ "$1" == / && -f ~/.textmate_init ]] && . ~/.textmate_init
}
textmate_init "${TM_DIRECTORY:-$HOME}"

# an abstract way to change the output option of the running command
exit_discard ()					{ echo -n "$1"; exit 200; }
exit_replace_text ()				{ echo -n "$1"; exit 201; }
exit_replace_document ()		{ echo -n "$1"; exit 202; }
exit_insert_text ()				{ echo -n "$1"; exit 203; }
exit_insert_snippet ()			{ echo -n "$1"; exit 204; }
exit_show_html ()					{ echo -n "$1"; exit 205; }
exit_show_tool_tip ()			{ echo -n "$1"; exit 206; }
exit_create_new_document ()	{ echo -n "$1"; exit 207; }

# force TM to refresh current file and project drawer
rescan_project () {
	osascript &>/dev/null \
	   -e 'tell app "SystemUIServer" to activate' \
	   -e 'tell app "TextMate" to activate' &
}

# use this as a filter (|pre) when you want 
# raw output to show as such in the HTML output
pre () {
	echo -n '<pre style="word-wrap: break-word;">'
	perl -pe '$| = 1; s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g; s/$\\n/<br>/'
	echo '</pre>'
}

# this will check for the presence of a command and
# prints an (HTML) error + exists if it's not there
require_cmd () {
	if ! type -p "$1" >/dev/null; then
		cat <<HTML
<h3 class="error">Couldn't find $1</h3>
${2:+<p>$2</p>}
<p>Locations searched:</p>
<p><pre>
${PATH//:/
}
</pre></p>
HTML
		exit_show_html;
	fi
}
