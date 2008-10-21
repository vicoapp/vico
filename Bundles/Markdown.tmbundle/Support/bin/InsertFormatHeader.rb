#!/usr/bin/env ruby -wKU
#
# This wrapper will insert a ‘Format: Complete’-header 
# if the document (as read from stdin) does not have a 
# format header already.
#
# This header is sort of necessary when we conver the
# users document to RTF or similar where the document
# encoding is specified in the header.

doc = STDIN.read

def parse_headers(doc)
  return {} unless doc =~ /\A(\w+:.+?)\n\n/m
  tmp = $1.scan(/^(\w+):\s+(.*)$/).collect { |pair| [pair[0].downcase, pair[1].strip] }
  Hash[*tmp.flatten]
end

headers = parse_headers(doc)
unless headers.has_key?('format')
  puts "Format: complete" 
  puts if headers.empty?
end
print doc
