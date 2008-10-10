#!/usr/bin/env ruby
#
# ReIndent v0.1
# By Sune Foldager <cryo at cyanite.org>
#

require 'optparse'

# Defaults.
increase = nil
decrease = nil
line_indent = nil
skip_line = nil
skip_indent = nil
indent = nil
use_tabs = false

opts = OptionParser.new do |o|

  # Increase indent pattern.
  o.on("-i", "--increase [PATTERN]", Regexp,
  "Pattern to increase the indentation level.") { |p|
    increase = p
  }

  # Decrease indent pattern.
  o.on("-d", "--decrease [PATTERN]", Regexp,
  "Pattern to decrease the indentation level.") { |p|
    decrease = p
  }

  # Ignore patterns.
  o.on("--skip-line [PATTERN]", Regexp,
  "Lines matching this pattern will be passed through verbatim, and otherwise ignored.") { |p|
    skip_line = p
  }
  o.on("--skip-indent [PATTERN]", Regexp,
  "Lines matching this pattern will be stripped, not indented, and otherwise ignored.") { |p|
    skip_indent = p
  }

  # Indent size.
  o.on("-I", "--indent-size [SIZE]", Integer,
  "Indentation ammount. Defaults to 2 for spaces, 1 for tabs.") { |i|
    indent = i
  }

  # Use tabs instead of spaces.
  o.on("-t", "--[no-]tabs",
  "Use tabs instead of spaces, for indent. Defaults to using spaces.") { |t|
    use_tabs = t
  }

  # Next-line indent pattern.
  o.on("-n", "--next-line [PATTERN]", Regexp,
  "Regex pattern to increase the indentation level for the next line only.") { |p|
    line_indent = p
  }

  # Help.
  o.on_tail("-h", "--help", "Show this message.") {
    puts o
    exit
  }

  # Parse!
  begin
    o.parse!(ARGV)
  rescue OptionParser::ParseError => e
    puts e.message
    puts o
    exit
  rescue RegexpError => e
    print "ERROR: "
    puts e.message
    exit
  end

end

# Perform re-indentation...
level = 0
extra = 0
indent = (use_tabs ? 1 : 2) unless indent
space = (use_tabs ? "\t" : " ") * indent
while l = gets

  # Ignore lines matching the skip-line pattern.
  if l =~ skip_line
    print l
    next
  end

  # Remove leading whitespace.
  l.lstrip!

  # Ignore empty lines and those matching the skip-indent.
  if l.length == 0 or l =~ skip_indent
    print l
    next
  end

  # Handle de-indentation.
  level -= 1 if level > 0 and l =~ decrease

  # Handle "indent-increase cancels next-line indent".
  extra = 0 if l =~ increase

  # Indent and output. 
  print space * (level+extra) if level+extra > 0
  print l

  # Handle indentation.
  level += 1 if l =~ increase
  extra = (l =~ line_indent) ? 1 : 0

end

