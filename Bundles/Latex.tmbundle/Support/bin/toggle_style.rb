#!/usr/bin/env ruby -s
$: << ENV['TM_SUPPORT_PATH'] + '/lib'
require 'escape'
def esc(str)
  e_sn(str).gsub(/\}/, '\\}') # escaping inside a placeholder
end

is_math = !ENV['TM_SCOPE'].match(/math/).nil?
style = $style || 'texttt'
# The following line might be problematic if the command is used elsewhere
style = style.sub(/^text/,'math').sub(/^emph$/,'mathit') if is_math
s = STDIN.read
# All the formatting commands except for \verb us {}  \verb can use any delimeter as long as
# the opening delimiter matches the closing.
oc = '{'
cc = '}'
if style == 'verb'
  oc = '!'
  cc = '!'
end
if s.empty? then
  print "\\#{style}"+oc+"$1"+cc
elsif s =~ /^\\#{Regexp.escape style}\{(.*)\}$/ then
  print "${1:#{esc $1}}"
else
  print "\\#{style}"+oc+"#{e_sn s}"+cc
end