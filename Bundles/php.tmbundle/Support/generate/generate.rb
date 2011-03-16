#!/usr/bin/env ruby -wKU

# Extract function summaries from sources of PHP and its extensions
# 
# Example of block looked in .c, .cpp, .h and .ec files
# 
# /* {{{ proto string zend_version(void)
#   Get the version of the Zend Engine */
# 

require 'rubygems'
require ENV['TM_BUNDLE_SUPPORT'] + '/lib/Builder'
require '/Applications/TextMate.app/Contents/SharedSupport/Support/lib/osx/plist'

path = ARGV.join('')
parsefiles = Dir[path + '/**/*.{cpp,c,h,ec}']

unless parsefiles
  puts "No files found"
  exit
end

# =======================
# = Source file parsing =
# =======================

# "\n\n/* {{{ proto string zend_version(void)\n   Get the version of the Zend Engine */"
#
# Example line with trailing garbage (php-5.3.1/ext/standard/array.c:3264)
# "/* {{{ proto array array_uintersect_assoc(array arr1, array arr2 [, array ...], callback data_compare_func) U"
proto_regex  = /^\s*?              # Start of the line
                 \/\*              # Start of the comment
                 \s+?              
                 \{{3}             # 3 Braces
                 \s+?
                 proto
                 \s+?
                 (\S+?)?           # Type
                 \s+?
                 (.+?[)]?)         # Function name
                 (?:[\w ]*(?!\Z))? # Ignore junk at the end of the line
                 $                 # End of the prototype line
                 (.+?)             # Function description
                \*\/               # End of the comment
              /msx
# alias_regex  = /PHP_FALIAS\((\w+),\s*(\w+)/

# Some basic functions aren't documented in the same way as the rest, so we
# have to specify them here
functions = {}
functions_base_text = <<end_of_functions_base
exit%void exit([mixed status])%Output a message and terminate the current script
die%void die([mixed status])%Output a message and terminate the current script
print%int print(string arg)%Output a string
echo%void echo(string arg1 [, string ...])%Output one or more strings
isset%bool isset(mixed var [, mixed var])%Determine whether a variable is set
unset%void unset (mixed var [, mixed var])%Unset a given variable
empty%bool empty( mixed var )%Determine whether a variable is empty
include%bool include(string path)%Includes and evaluates the specified file
include_once%bool include_once(string path)%Includes and evaluates the specified file
require%bool require(string path)%Includes and evaluates the specified file, erroring if the file cannot be included
require_once%bool require_once(string path)%Includes and evaluates the specified file, erroring if the file cannot be included
end_of_functions_base

functions_base_text.split("\n").each do |line|
  name, proto, desc = line.split("%")
  # Not assigning :type or :return since they don't seem to be used anymore
  functions[name] = {:description => desc, :prototype => proto}
end

# aliases = {}
sections = {}

classes = [
  'stdClass',
  'LogicException',
  'BadFunctionCallException',
  'BadMethodCallException',
  'DomainException',
  'InvalidArgumentException',
  'LengthException',
  'OutOfRangeException',
  'RuntimeException',
  'OutOfBoundsException',
  'OverflowException',
  'RangeException',
  'UnderflowException',
  'UnexpectedValueException'  
]

# prototype blocks
parsefiles.sort.each_with_index do |file, key|
  file_contents = File.read(file)
  if file_contents.match(proto_regex)
    section = file.match(/^.+\/(?:zend_)?(.+)\..+$/).captures.first

    file_contents.gsub(proto_regex) do |proto|
      ret, rest, desc = $1, $2, $3
      next unless rest[/(?:(\S+?)::)?(\w+)\s*\(/]
      klass, name = $1, $2
      if klass
        # Class method
        # Ignore the method but add class name to a list
        classes << klass
        next
      end
      desc = desc.strip.gsub(/\s+?/ms, ' ')
      functions[name] = {:type => section, :return => ret, :description => desc, :prototype => ret + ' ' + rest}
      sections[section] ||= []
      sections[section] << name
    end
  end
  # if file_contents.match(alias_regex)
  #   file_contents.gsub(alias_regex) do
  #     aliases[$1] = $2
  #   end
  # end
end

# Workaround for bad docs.
functions['lcfirst'] = {
  :type => 'string',
  :description => "Make a string's first character lowercase",
  :prototype => 'string lcfirst(string str)'
}
sections['string'] << 'lcfirst'

# aliases.each_pair do |func_alias, func|
#   next unless functions[func]
#   functions[func_alias] = functions[func].dup
#   sections[functions[func][:type]] << func_alias
# end

classes.uniq!

# =======================
# = Completions writing =
# =======================

completions = classes + functions.keys
completions.sort!

xml = Builder::XmlMarkup.new(:indent => 2, :target => File.open(File.dirname(__FILE__) + '/../../Preferences/Completions.tmPreferences', 'w'))
xml.instruct!
xml.declare! :DOCTYPE,
             :plist,
             :public,
             "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"
xml.plist :version => '1.0' do
  xml.dict do
    xml.key 'name'
    xml.string 'Completions'
    xml.key 'scope'
    xml.string 'source.php'
    xml.key 'settings'
    xml.dict do
      xml.key 'completions'
      xml.array do
        completions.each do |function_name|
          xml.string function_name
        end
      end
    end
    xml.key 'uuid'
    xml.string '2543E52B-D5CF-4BBE-B792-51F1574EA05F'
  end
end

# ==================
# = Syntax writing =
# ==================
#  process_list
#  Created by Allan Odgaard on 2005-11-28.
#  http://macromates.com/svn/Bundles/trunk/Bundles/Objective-C.tmbundle/Support/list_to_regexp.rb
#
#  Read list and output a compact regexp
#  which will match any of the elements in the list
#  Modified by Ciarån Walsh to accept a plain string array
def process_list(list)
  buckets = { }
  optional = false

  list.map! { |term| term.unpack('C*') }

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
      [key].pack('C') + process_list(value.map{|item| item.pack('C*') }).to_s
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

def pattern_for(name, list, constructors = false)
  return unless list = process_list(list)
  {
    'name'  => name,
    'match' => "(?i)\\b#{ list }(?=\\s*" + (constructors && "[\\(|;]" || "\\(") + ")"
  }
end

GrammarPath = File.dirname(__FILE__) + '/../../Syntaxes/PHP.plist'

grammar = OSX::PropertyList.load(File.read(GrammarPath))

patterns = []

sections.sort.each do |(section, funcs)|
  patterns << pattern_for('support.function.' + section + '.php', funcs)
end
patterns << pattern_for('support.function.alias.php', %w{is_int is_integer})
patterns << pattern_for('support.class.builtin.php', classes, true)

grammar['repository']['support'] = { 'patterns' => patterns }
File.open(GrammarPath, 'w') do |file|
  file << grammar.to_plist
end

# =========================
# = Functions.txt writing =
# =========================
File.open('../functions.txt', 'w') do |file|
  functions.sort.each do |function, data|
    file << function + '%' + data[:prototype] + '%' + data[:description] + "\n"
  end
end

`osascript -e'tell app "TextMate" to reload bundles'`