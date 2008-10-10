#!/usr/bin/env ruby

require 'English'

svn = ENV['TM_SVN']

verb = ARGV[0]
file = ARGV.last

string = ARGV.inject("") {|string, value| string + ('"' + value + '" ') }

text = %x{#{svn} #{string}}
if $CHILD_STATUS != 0
	puts text
	exit $CHILD_STATUS
end

puts %x{#{svn} status "#{file}"}
