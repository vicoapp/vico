#!/usr/bin/env ruby
shortcutHash = {
  "<=>" => "\\Leftrightarrow",
  "<->" => "\\leftrightarrow",
  " <-" => "\\leftarrow",
  " <=" => "\\Leftarrow",
  " =>" => "\\Rightarrow",
  " ->" => "\\rightarrow",
  "<--" => "\\longleftarrow",
  "<==" => "\\Longleftarrow",
  "-->" => "\\longrightarrow",
  "==>" => "\\Longrightarrow",
  "|->" => "\\mapsto",
}
  currentWord=ENV["TM_SELECTED_TEXT"].to_s
if (shortcutHash.has_key?(currentWord)) then
  print shortcutHash[currentWord]
else
  print currentWord
end