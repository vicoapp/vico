#!/usr/bin/env ruby
require ENV["TM_SUPPORT_PATH"] + "/lib/LaTeXUtils.rb"
phrase = STDIN.read.chomp
include LaTeX
items = LaTeX.get_labels
items = items.grep(phrase) if phrase != ""
exit if items.empty?
puts items.join("\n")