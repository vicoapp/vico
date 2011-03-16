
# find /System/Library/Frameworks/*.framework -name \*.h -exec awk '/\}/ { if(pr) print $0; pr = 0;} { if(pr) print $0; } /^enum .*\{[^}]*$/ { pr = 1; print $0; }' '{}' \; > anonut.txt
s = STDIN.read
def stripComments(line)
  line.gsub(/((['"])(?:\\.|.)*?\2)|\/\*.*?\*\/|\/\/[^\n\r]*/m) do |s| 
    if $1
      s
    else
      ' ' * s.length()
    end
  end
end


def presuff(items)min_len = items.min{ |i,j| i.length <=> j.length }.length
  common_prefix = ""
  (0...min_len).each do |i|
  col = items.inject(""){ |sum,elem|  sum << elem[i] }.squeeze
  if col.length > 1
    break
  end
  common_prefix << col
  end

  min_len = items.min{ |i,j| i.length <=> j.length }.length
  common_suffix = ""
  (0...min_len).each do |i|
  col = items.inject(""){ |sum,elem| sum << elem[-i-1] }.squeeze
  if col.length > 1
    break
  end
  common_suffix = col + common_suffix
  end
  common_prefix = "" unless common_prefix.length > 2
  common_suffix = "" unless common_suffix.length > 2
  r = common_prefix + common_suffix
  r = "NO_GUESS" if r == ""  
  return r
end

require 'set'
nameSet = Set.new
s = stripComments(s).gsub(/(\w)\s*,\s*(\w)/, '\1,
\2')
l = s.scan(/enum\s*(?:\w+\s*)?\{.*?\}\;/m)
l = l.sort.uniq
list = []
l.each do |elem|
  if elemName = elem.match(/enum\s+(\w+)/)
    guess = elemName[1]
  end
  ms = elem.split("\n").select{|a| a.match(/^\s*[a-zA-Z0-9_]+\s*(=|,)/)}.collect{|b| b.match(/[a-zA-Z0-9_]+/)[0]}
  if ms && !ms.empty?
    unless elemName
      guess = presuff(ms) 
      guess = ms[0] if ms.size == 1
      if guess == "StringEncoding" #special case
        guess = "NO_GUESS" 
        noGo = true
      end
    end
    if nameSet.include?(guess)
      unless nameSet.include?(ms[0]) && ms.size > 1
        guess = ms[0]
      else
        puts "------" #these will have to be solved by hand
      end 
    else
      nameSet.add(guess)
    end
    guess = "kException" if guess == "Exception"
    unless noGo
      ms.each do |k|
        puts k + "\t\t#"+ guess
      end
    end
  end
end

"NSAlertOtherReturn NSAlertReturn
typedef unsigned int NSWorkspaceLaunchOptions;
enum {
     NSWorkspaceLaunchAndPrint
typedef unsigned int NSGlyph;
enum {
  NSControlGlyph
typedef unsigned int NSDragOperation;
enum {
    NSDragOperationNone
             
                
typedef unsigned int NSDatePickerElementFlags;
enum {
    /* Time Elements */
    NSHourMinuteDatePickerElementFlag       = 0x000c,
    enum {
        NSKeyValueObservingOptionNew = 0x01,
        NSKeyValueObservingOptionOld = 0x02
    };
typedef unsigned int NSKeyValueObservingOptions;"
