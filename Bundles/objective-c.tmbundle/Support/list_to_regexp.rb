#!/usr/bin/env ruby
#
#  list_to_regexp.rb
#  Created by Allan Odgaard on 2005-11-28.
#
#  Read list from stdin and output a compact regexp
#  which will match any of the elements in the list
#

def process_list (list)

  buckets = { }
  optional = false

  list.each do |str|
    if str.empty? then
      optional = true
    else
      ch = str.shift
      buckets[ch] = (buckets[ch] or []).push(str)
    end
  end

  unless buckets.empty? then
    ptrns = buckets.collect do |key, value|
      [key].pack('C') + process_list(value).to_s
    end

    if optional == true then
      "(" + ptrns.join("|") + ")?"
    elsif ptrns.length > 1 then
      "(" + ptrns.join("|") + ")"
    else
      ptrns
    end
  end

end

print process_list(STDIN.collect { |line| line.chomp.unpack('C*') })
