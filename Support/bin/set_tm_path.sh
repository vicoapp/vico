#!/bin/sh

{ APP_PATH=$(ps -xwwp $PPID -o command|grep -o '.*.app')
  osascript -e "tell app \"$(basename "$APP_PATH")\" to quit"

  for (( i = 0; i < 500 && $(echo $(ps -xp $PPID|wc -l))-1; i++ )); do
    sleep .2;
  done

  if [[ $(ps -xp $PPID|wc -l) -ne 2 ]]; then
    exec -c /usr/bin/osascript <<APPLESCRIPT
      tell application "Terminal" to do script "defaults write com.macromates.textmate OakShellVariables -array-add \"{ enabled = 1; variable = PATH; value = '\$PATH'; }\" && open \"$APP_PATH\""
APPLESCRIPT
    
  else
    echo >/dev/console "$(date +%Y-%m-%d\ %H:%M:%S): TextMate is still running. Relaunch aborted."
  fi
} &>/dev/null &
