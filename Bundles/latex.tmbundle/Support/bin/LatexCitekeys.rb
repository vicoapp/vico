#!/usr/bin/env ruby
require ENV["TM_BUNDLE_SUPPORT"] + "/lib/LaTeXUtils.rb"
phrase = STDIN.read.chomp
include LaTeX
items = LaTeX.get_citekeys
items = items.grep(/#{phrase}/) if phrase != ""
exit if items.empty?
puts items.join("\n")
