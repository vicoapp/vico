#!/usr/bin/env ruby

# find /System/Library/Frameworks/{AppKit,Foundation}.framework -name \*.h -exec awk '/\}/ { if(pr) print $0; pr = 0; } { if(pr) print $0; } /^(typedef )enum .*\{[^}]*$/ { print $0 ;pr = 1}' '{}' \;|expand

# NSStringEncodings are not defined as typedefed enum, add by hand

str = open("typedefs.txt").read
list = str.split(/\n/)
out = []
typename = constantname = ""
list.reverse_each do |x| 
	if x =~ /\}\s*([A-Z][A-Z][a-zA-Z0-9*]*)/
		typename = $1
	elsif x =~ /^\s*([A-Z][A-Z][A-Za-z0-9]*)/
		constantname = $1
		out << "#{constantname}\t\t#{typename}"
	end
end

f = open("outConstants.txt","w")
out.reverse_each do |x| f.write(x+"\n") end
f.close

	
	 
