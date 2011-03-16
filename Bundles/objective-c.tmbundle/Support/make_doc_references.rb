#!/usr/bin/env ruby
#
# This script is used to create the doc_references.txt
#
# find /Developer/ADC\ Reference\ Library/documentation/Cocoa/Reference -path '*/ObjC_classic/*' -name '*.html'|./make_doc_references.rb|sort|gzip - > doc_references.txt.gz

$res = { }

STDIN.each_line do |file|
  File.open(file.chomp).each do |line|
    line.gsub(/<a href="([^"]*)"[^>]*>(NS[A-Z][A-Za-z0-9]*)<\/a>/) do |m|
      key, value = $2, $1
      (path, fragment) = value.split('#')
      ref = File.expand_path(path, File.dirname(file)) + '#' + fragment
      $res[key] = ref.split("/Developer/ADC Reference Library/documentation/Cocoa/Reference/")[1]
    end
  end
end

$res.each { |key,value| puts "#{key}\t#{value}" }
