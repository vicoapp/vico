#!/usr/bin/env bash

source "$TM_SUPPORT_PATH/lib/bash_init.sh"

export TM_JAVA=${TM_JAVA:-java}
export TM_JAVAC=${TM_JAVAC:-javac}

require_cmd "$TM_JAVA" "If you have installed java, then you need to either <a href=\"help:anchor='search_path'%20bookID='TextMate%20Help'\">update your <tt>PATH</tt></a> or set the <tt>TM_JAVA</tt> shell variable (e.g. in Preferences / Advanced)"

require_cmd "$TM_JAVAC" "If you have installed javac, then you need to either <a href=\"help:anchor='search_path'%20bookID='TextMate%20Help'\">update your <tt>PATH</tt></a> or set the <tt>TM_JAVAC</tt> shell variable (e.g. in Preferences / Advanced)"

javamate.rb