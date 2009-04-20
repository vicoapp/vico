#!/usr/bin/env ruby
require ENV['TM_SUPPORT_PATH'] + "/lib/exit_codes"
require "#{ENV['TM_SUPPORT_PATH']}/lib/escape"
require "zlib"
require "set"
require "#{ENV['TM_SUPPORT_PATH']}/lib/ui"


class ExternalSnippetizer
  
  def initialize(options = {})
    @star = options[:star] || nil
    @arg_name = options[:arg_name] || nil
    @tm_C_pointer = options[:tm_C_pointer] || nil
  end
  
def snippet_generator(cand, start)

  cand = cand.strip
  oldstuff = cand[0..-1].split("\t")
  stuff = cand[start..-1].split("\t")
  stuffSize = stuff[0].size
  if oldstuff[0].count(":") == 1
    out = "${0:#{stuff[6]}}"
  elsif oldstuff[0].count(":") > 1

    name_array = stuff[0].split(":")
    out = "${1:#{stuff[-name_array.size - 1]}} "
    unless name_array.empty?
    begin      
      stuff[-(name_array.size)..-1].each_with_index do |arg,i|
          out << name_array[i] + ":${"+(i+2).to_s + ":"+ arg + "} "
      end
    rescue NoMethodError
      out = "$0"
    end
  end
  else
    out = "$0"
  end
  return out.chomp.strip
end

def construct_arg_name(arg)
  a = arg.match(/(NS|AB|CI|CD)?(Mutable)?(([AEIOQUYi])?[A-Za-z_0-9]+)/)
  unless a.nil?
    (a[4].nil? ? "a": "an") + a[3].sub!(/\b\w/) { $&.upcase }
  else
    ""
  end
end

def type_declaration_snippet_generator(dict)

  arg_name = @arg_name && dict['noArg']
  star = @star && dict['pure']
  pointer = @tm_C_pointer
  pointer = " *" unless pointer

  if arg_name
    name = "${2:#{construct_arg_name dict['match']}}"
    if star
      name = ("${1:#{pointer}#{name}}")
    else
      name = " " + name
    end

  else
    name = pointer.rstrip if star
  end
  #  name = name[0..-2].rstrip unless arg_name
  name + "$0"
end

def cfunction_snippet_generator(c)
  c = c.split"\t"
  i = 0
  "("+c[1][1..-2].split(",").collect do |arg| 
    "${"+(i+=1).to_s+":"+ arg.strip + "}" 
  end.join(", ")+")$0"
end

def run(res)
  if res['type'] == "methods"
    r = snippet_generator(res['cand'], res['match'].size)
  elsif res['type'] == "functions"
    r = cfunction_snippet_generator(res['cand'])
  elsif res['pure'] && res['noArg']
    r = type_declaration_snippet_generator res
  else 
    r = "$0"
  end
  return r
end
end

# Zlib::GzipReader.new(ARGF).each { |l| f = l.split("\t"); puts l if f[0] =~ /\S/ and f[3] =~ /\S/ }
class ObjCFallbackCompletion
      A = Struct.new(:tt, :text, :beg)
  
  def initialize(line, caret_placement)
    @full = line
    if ENV['TM_INPUT_START_LINE']
      tmp = ENV['TM_LINE_NUMBER'].to_i - ENV['TM_INPUT_START_LINE'].to_i
    else
      tmp = 0
    end
    l = line.split("\n")
    if l.empty?
      @line = ""
    else
      @line = l[tmp] 
    end
    @car = caret_placement
  end
  
  def method_parse(k)
    k = k.match(/[^;\{]+?(;|\{)/)
    if k
      l = k[0].scan(/(\-|\+)\s*\((([^\(\)]|\([^\)]*\))*)\)|\((([^\(\)]|\([^\)]*\))*)\)\s*([_a-zA-Z][_a-zA-Z0-9]*)|(([a-zA-Z][a-zA-Z0-9]*)?:)/)
      types = l.select {|item| item[3] && item[3].match(/([A-Z]\w|unichar)\s*(?!\*)/) &&  item[5] }
      h = {}
      types.each{|item| h[item[5]] = item[3] }
      l = k.post_match.scan(/([A-Z]\w+|unichar)\s+([a-z_]\w*(?!\s*(?::|\]))(?:\s*\,\s*[a-z_]\w*)*)/)
      l.each do |e|
        e[1].split(/\s*,\s*/).each do |item|
          h[item] = e[0]
        end
      end
      return h
    end
  end

  def match_iter(rgxp,str)
    offset = 0
    while m = str.match(rgxp)
      yield [m[0], m.begin(0) + offset, m[0].length]
      str = m.post_match
      offset += m.end(0)
    end
  end

  def methodNames(line )
    up =-1
    list = ""
    pat = /("(\\.|[^"\\])*"|\[|\]|@selector\([^\)]*\)|[a-zA-Z][a-zA-Z0-9]*:)/
    match_iter(pat , line) do |tok, beg, len|
      t = tok[0].chr
      if t == "["
        up +=1
      elsif t == "]"
        up -=1
        break if up < 0
      elsif t !='"' and t !='@' and up == 0
        list << tok
      end
    end
    if list.empty?
      m = line.match(/([a-zA-Z][a-zA-Z0-9]*)\s*\]\s*$/)
      list = m[1] unless m.nil?
    end
    return list
  end

  def caseSensitive(line)
    require "stringio"
    require "#{ENV['TM_BUNDLE_SUPPORT']}/objcParser"
    to_parse = StringIO.new(line)
    lexer = Lexer.new do |l|
      l.add_token(:return,  /\breturn\b/)
      l.add_token(:nil, /\bnil\b/)
      l.add_token(:control, /\b(?:if|while|for|do)(?:\s*)\(/)# /\bif|while|for|do(?:\s*)\(/)
      l.add_token(:at_string, /"(?:\\.|[^"\\])*"/)
      l.add_token(:selector, /\b[A-Za-z_0-9]+:/)
      l.add_token(:identifier, /\b[A-Za-z_0-9]+(?:\b|$)/)
      l.add_token(:bind, /(?:->)|\./)
      l.add_token(:post_op, /\+\+|\-\-/)
      l.add_token(:at, /@/)
      l.add_token(:star, /\*/)
      l.add_token(:close, /\)|\]|\}/)
      l.add_token(:open, /\(|\[|\{/)
      l.add_token(:operator,   /[&-+\/=%:\,\?;<>\|\~\^]/)
      l.add_token(:terminator, /;\n|\n/)
      l.add_token(:whitespace, /\s+/)
      l.add_token(:unknown,    /./) 
      l.input { to_parse.gets }
        #l.input {STDIN.read}
    end

    offset = 0
    tokenList = []

    lexer.each do |token| 
      tokenList << A.new(*(token<<offset)) unless [:whitespace,:terminator].include? token[0]
      offset +=token[1].length
    end
    if tokenList.empty?
      return nil
    end
    r = nil
    par = ObjcParser.new(tokenList)
    b, has_message = par.find_object_start

    unless b.nil?
      if k = line[b..-1].match(/^((?:const\s+)?(?:([_a-z])|([A-Z]))[a-zA-Z0-9_]*)|(\[)/)
        if k[2] #lowercase
          h = method_parse(@full[0..@car])
          unless h.nil?
            type = h[k[1]]
            r = [type]
            r = ["#Character","#FunctionKey"] if type == "unichar"
          end
        elsif k[3] #uppercase
          files = [[ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaConstants.txt.gz",true,true, :constant],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaAnonymousEnums.txt.gz",true,false,:anonymous],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaAnnotatedStrings.txt.gz",false,false,:annotated],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaFunctions.txt.gz",false,false,:functions]]
          candidates = candidates_or_exit(k[1]+ "[[:space:]]", files)
          r = [candidates[0][0].split("\t")[2]] unless candidates.empty?

          #get constant or function return type
        elsif k[4]
          mn = methodNames(line[b..-1])
          unless mn.empty?
            candidates = %x{ zgrep ^#{e_sh mn + "[[:space:]]" } #{e_sh ENV['TM_BUNDLE_SUPPORT']}/cocoa.txt.gz }.split("\n")
          end
          r = candidates.map{|e| e.split("\t")[5]} unless candidates.empty?
        end
      end
    end
    return r
  end
  
  def candidates_or_exit(methodSearch,files)
    candidates = []
    files.each do |name, pure,noArg, type|
      zGrepped = %x{zgrep -e ^#{e_sh methodSearch } #{name}}
      candidates += zGrepped.split("\n").map do |elem|
        [elem, pure, noArg, type]
      end
    end
    TextMate.exit_show_tool_tip "No completion available" if candidates.empty?
    return candidates
  end

  def prettify(candidate)
    ca = candidate.split("\t")
    if ca[1] && ca[1][0] && ca[1][0].chr == "("
      ca[0]+ca[1]
    else
      ca[0]
    end
  end

  def construct_arg_name(arg)
    a = arg.match(/(NS|AB|CI|CD)?(Mutable)?(([AEIOQUYi])?[A-Za-z_0-9]+)/)
    unless a.nil?
      (a[4].nil? ? "a": "an") + a[3].sub!(/\b\w/) { $&.upcase }
    else
      ""
    end
  end

  def snippet_generator(cand,s,star,arg_name)
    c = cand.split"\t"
    if c[1] && c[1][0] && c[1][0].chr == "("
      i = 0
      middle = c[1][1..-2].split(",").collect do |arg|
        "${"+(i+=1).to_s+":"+ arg.strip + "}" 
      end.join(", ")
      c[0][s..-1]+"("+middle+")$0"
    else
      name = ""
      if arg_name
        name = "${2:#{construct_arg_name(c[0])}}"
        if star
          name = ("${1:${TM_C_POINTER: *}#{name}}") if star
        else
          name = " " + name
        end

      else
        name = (ENV['TM_C_POINTER'] || " *").rstrip if star
      end
      #  name = name[0..-2].rstrip unless arg_name
      e_sn(c[0][s..-1]) + name + "$0"
    end
  end


  def pop_up(candidates, searchTerm,star,arg_name)
    start = searchTerm.size

    prettyCandidates = candidates.map do |cand|
      [prettify(cand[0]), cand[0],cand[1],cand[2],cand[3]]
    end.sort {|x,y| x[1].downcase <=> y[1].downcase }

    
    if prettyCandidates.size > 1

      require "enumerator"
      pruneList = []  

      prettyCandidates.each_cons(2) do |a| 
        pruneList << (a[0][0] != a[1][0]) # check if prettified versions are the same
      end
      pruneList << true
      ind = -1
      prettyCandidates = prettyCandidates.select do |a| #remove duplicates
        pruneList[ind+=1]  
      end
    end

    if prettyCandidates.size > 1
      #index = start
      #test = false
      #while !test
      #  candidates.each_cons(2) do |a,b|
      #    break if test = (a[index].chr != b[index].chr || a[index].chr == "\t")
      #  end
      #  break if test
      #  searchTerm << candidates[0][index].chr
      #  index +=1
      #end
     pl = prettyCandidates.map do |pretty, full, pure, noArg, type |
        { 'display' => pretty,
          'cand' => full,
          'pure'=> pure, 
          'noArg'=> noArg,
          'type'=> type.to_s,
          'match'=> full.split("\t")[0]
        }
      end

      flags = {}
      flags[:extra_chars]= '_'
      flags[:initial_filter]= searchTerm
      begin
        TextMate::UI.complete(pl, flags)  do |hash| 
          es = ExternalSnippetizer.new({:star => star,
               :arg_name => arg_name,
               :tm_C_pointer => ENV['TM_C_POINTER']})
          es.run(hash)
        end
        
      rescue NoMethodError
        TextMate.exit_show_tool_tip "you have Dialog2 installed but not the ui.rb in review"
      end
     TextMate.exit_discard # create_new_document
    else
      snippet_generator( candidates[0][0], start, star && !candidates[0][1], arg_name && !candidates[0][2] )
    end
  end

  def print

    line = @line

    if ENV['TM_INPUT_START_LINE_INDEX']
      caret_placement = ENV['TM_LINE_INDEX'].to_i - 1
      caret_placement += ENV['TM_INPUT_START_LINE_INDEX'].to_i if ENV['TM_INPUT_START_LINE'] == ENV['TM_LINE_NUMBER'] 
    else
      caret_placement = ENV['TM_LINE_INDEX'].to_i - 1
    end

    if line[1+caret_placement..-1].nil?
       TextMate.exit_discard
    end

    backContext = line[1+caret_placement..-1].match(/^[a-zA-Z0-9_]/)

    if backContext
      TextMate.exit_discard
    end

    star = arg_name = false
    if ENV['TM_SCOPE'].include? "meta.protocol-list.objc"
      files = [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaProtocols.txt.gz",false,false, :constant]]
    elsif ENV['TM_SCOPE'].include?("meta.scope.implementation.objc") ||  ENV['TM_SCOPE'].include?("meta.interface-or-protocol.objc")
      files = [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaClassesWithAncestry.txt.gz",false,false, :classes]]
      files += [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaTypes.txt.gz", true, false, :constant]] if ENV['TM_SCOPE'].include?("meta.scope.interface.objc")
      userClasses = ["#{ENV['TM_PROJECT_DIRECTORY']}/.classes.TM_Completions.txt.gz", false,false,:constant]
      files += [userClasses] if File.exists? userClasses[0]
      if ENV['TM_SCOPE'].include?("meta.function.objc")
        star = true
        files += [[ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaTypes.txt.gz",true,false, :constant]]
      elsif ENV['TM_SCOPE'].include? "meta.scope.implementation.objc"
        star = arg_name = true
        files += [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CLib.txt.gz",false,false, :functions],
        [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaConstants.txt.gz",true,true, :constant],
        [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaTypes.txt.gz",true,false, :constant],
        ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaFunctions.txt.gz",false,false, :functions]]
        files += [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/C++Lib.txt.gz",false,false, :functions]] if ENV['TM_SCOPE'].include? "source.objc++"
      elsif ENV['TM_SCOPE'].include? "meta.scope.interface.objc"
        star = arg_name = true
      end
    else
      star = arg_name = true
      files = [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaClassesWithAncestry.txt.gz",false,false, :classes],
      [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaConstants.txt.gz",true,true, :constant],
      [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaTypes.txt.gz",true,false, :constant],
      [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CLib.txt.gz",false,false, :functions],
      [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaFunctions.txt.gz",false,false, :functions]]
      files += [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/C++Lib.txt.gz",false,false, :functions]] if ENV['TM_SCOPE'].include? "source.objc++"
    end
    dot_alpha_and_caret = /\.([a-zA-Z][a-zA-Z0-9]*)?$/
    if temp =line[0..caret_placement].match( dot_alpha_and_caret)
      obc = ObjCMethodCompletion.new(line, caret_placement)
      list = obc.try_find_class(@full, 0)
      candidates = obc.candidates_or_exit( temp[0][1..-1] + "[a-zA-Z0-9]+\\s", list, :methods )
      res = obc.pop_up(candidates, temp[0][1..-1], "")
      return res
    end
    
    
    alpha_and_caret = /(==|!=|(?:\+|\-|\*|\/)?=)?\s*([a-zA-Z_][_a-zA-Z0-9]*)\(?$/
    if k = line[0..caret_placement].match(alpha_and_caret)
      if k[1]
        star = arg_name = false
        r = caseSensitive(k.pre_match)
        if r.nil? || (!r.empty? && r[0].nil? )
          candidates = candidates_or_exit(k[2], files)
          res = pop_up(candidates, k[2],star,arg_name)
        else
          files = [[ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaConstants.txt.gz",false,false, :constant],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaAnonymousEnums.txt.gz",false,false, :constant],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaAnnotatedStrings.txt.gz",false,false, :constant],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaFunctions.txt.gz",false,false, :functions],
          [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CLib.txt.gz",false,false, :functions]]
          files += [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/C++Lib.txt.gz",false,false, :functions]] if ENV['TM_SCOPE'].include? "source.objc++"
          candidates = candidates_or_exit(k[2], files)
          temp = []
          unless candidates.empty?
 
            temp = candidates.select do |e|
              s = e[0].match(/\#?\w+$/)
              r.include?(s[0]) unless s.nil?
            end
          end
          candidates = temp unless temp.empty?
          res = pop_up(candidates, k[2],star,arg_name)
        end
          
      else
        candidates = candidates_or_exit(k[2], files)
        res = pop_up(candidates, k[2],star,arg_name)
      end
    else
      res = "$0"
    end
    return res

  end
end

class ObjCMethodCompletion
  def initialize(line, caret_placement)
    @line = line
    @car = caret_placement
  end

  def construct_arg_name(arg)
    a = arg.match(/(NS|AB|CI|CD)?(Mutable)?(([AEIOQUYi])?[A-Za-z_0-9]+)/)
    unless a.nil?
      (a[4].nil? ? "a": "an") + a[3].sub!(/\b\w/) { $&.upcase }
    else
      ""
    end
  end

  def prettify(cand, call, type, staticPrefix, word)
    stuff = cand.chomp.split("\t")
    ind = staticPrefix.size + word.size
    k = stuff[0][ind..-1].index(":")
    if k
      filterOn = stuff[0][0..k+ind]
    else
      filterOn = stuff[0]
    end
    if stuff[0].count(":") > 0
      name_array = stuff[0].split(":")
      out = ""
      begin
        stuff[-(name_array.size)..-1].each_with_index do |arg,i|
          out << name_array[i] +  ":("+ arg.gsub(/ \*/,(ENV['TM_C_POINTER'] || " *").rstrip)+") "
        end
      rescue NoMethodError
        out << stuff[0]
      end
    else
      out = stuff[0]
    end
    out = "(#{stuff[5].gsub(/ \*/,(ENV['TM_C_POINTER'] || " *").rstrip)})#{out}" unless call || (stuff.size < 4)
    
    return [out, filterOn, cand, type]
  end

  def snippet_generator(cand, start, call)
    start = 0 unless call
    cand = cand.strip
    stuff = cand[start..-1].split("\t")
    if stuff[0].count(":") > 0

      name_array = stuff[0].split(":")
      name_array = [""] if name_array.empty? 
      out = ""
      begin
        stuff[-(name_array.size)..-1].each_with_index do |arg,i|
          if (name_array.size == (i+1))
            if arg == "SEL"
              out << name_array[i] + ":${0:SEL} "
            else
              out << name_array[i] + ":${"+(i+1).to_s + ":"+ arg+"}$0"
            end
          else
            out << name_array[i] +  ":${"+(i+1).to_s + ":"+ arg+"} "
          end
        end
      rescue NoMethodError
        out << stuff[0]
      end
    else
      out = stuff[0] + "$0"
    end
    out = "(#{stuff[5]})#{out}" unless call || (stuff.size < 4)
    return out.chomp.strip
  end

  def pop_up(candidates, staticPrefix, word, call = true)
    start = staticPrefix.size + word.size
    prettyCandidates = candidates.map { |candidate,type| prettify(candidate, call, type, staticPrefix, word) }
    prettyCandidates = prettyCandidates.sort{|x,y| x[1] <=> y[1] }
    if prettyCandidates.size > 1
      require "enumerator"
      pruneList = []  

      prettyCandidates.each_cons(2) do |a,b| 
        pruneList << (a[0] != b[0]) # check if prettified versions are the same
      end
      pruneList << true
      ind = -1
      prettyCandidates = prettyCandidates.select do |a| #remove duplicates
        pruneList[ind+=1]  
      end
    end

    if prettyCandidates.size > 1
      #index = start
      #test = false
      #while !test
      #  candidates.each_cons(2) do |a,b|
      #    break if test = (a[index].chr != b[index].chr || a[index].chr == "\t")
      #  end
      #  break if test
      #  searchTerm << candidates[0][index].chr
      #  index +=1
      #end
      prettyCandidates = prettyCandidates.sort {|x,y| x[1].downcase <=> y[1].downcase }
      show_dialog(prettyCandidates,start,staticPrefix,word) do |c,s|
        snippet_generator(c,s, call)
      end
    else
      snippet_generator( candidates[0][0], start, call )
    end
  end

  def cfunc_snippet_generator(c,s)
    c , type = c
    c = c.split("\t")
    i = 0
    if type == :functions
      tmp = c[1][1..-2].split(",").collect do |arg| 
        "${"+(i+=1).to_s+":"+ arg.strip + "}" 
      end
      tmp = tmp.join(", ")+")$0"
      tmp = c[0][s..-1]+"(" + tmp
    else
      c[0][s..-1]+"$0"
    end
  end

  def c_popup_gen(c,si,arg_type=nil)
    s = si.size
    #puts c.inspect.gsub("],", "],\n")
    #c.each {|e| puts e unless e.class == Array}
    prettyCandidates = c.map do |candidate, type|
      ca = candidate.split("\t")
      if type == :functions
        [ca[0]+ca[1], ca[0], candidate,type]
      else
        [ca[0], ca[0], candidate,type]
      end
        
      #[((ca[1].nil? || !ca[4].nil? || c[1]=="") ? ca[0] : ca[0]+ca[1]),ca[0], candidate] 
    end

    if prettyCandidates.size > 1
      show_dialog(prettyCandidates,s,"",si) 
    else
      cfunc_snippet_generator(c[0],s)
    end
  end



  def show_dialog(prettyCandidates,start,static,word)
    pl = prettyCandidates.map do |pretty, filter, full, type | 
            { 'display' => pretty, 'cand' => full, 'match'=> filter, 'type'=> type.to_s}
    end
        
    flags = {}
    flags[:static_prefix] =static
    flags[:extra_chars]= '_:'
    flags[:initial_filter]= word
    begin
      TextMate::UI.complete(pl, flags) do |hash|
        ExternalSnippetizer.new.run(hash)
      end
    rescue NoMethodError
        TextMate.exit_show_tool_tip "you have Dialog2 installed but not the ui.rb in review"
    end
    TextMate.exit_discard
  end

  def candidates_or_exit(methodSearch, list, fileNames)
    x = candidate_list(methodSearch, list, fileNames)
    TextMate.exit_show_tool_tip "No completion available" if x.empty?
    return x
  end

  def file_names(types)
    if types == :classes
      userClasses = "#{ENV['TM_PROJECT_DIRECTORY']}/.classes.TM_Completions.txt.gz"
      fileNames = ["#{ENV['TM_BUNDLE_SUPPORT']}/CocoaClassesWithAncestry.txt.gz"]
      fileNames += [userClasses] if File.exists? userClasses
    elsif types == :functions
      fileNames = "#{ENV['TM_BUNDLE_SUPPORT']}/CocoaFunctions.txt.gz"
    elsif types == :methods
      fileNames = ["#{ENV['TM_BUNDLE_SUPPORT']}/cocoa.txt.gz"]
      userMethods = "#{ENV['TM_PROJECT_DIRECTORY']}/.methods.TM_Completions.txt.gz"

      fileNames += [userMethods] if File.exists? userMethods
    elsif types == :constants
      fileNames = "#{ENV['TM_BUNDLE_SUPPORT']}/CocoaConstants.txt.gz"
    elsif types == :anonymous
      fileNames = "#{ENV['TM_BUNDLE_SUPPORT']}/CocoaAnonymousEnums.txt.gz"
    elsif types == :annotated
      fileNames = "#{ENV['TM_BUNDLE_SUPPORT']}/CocoaAnnotatedStrings.txt.gz"
    end
    return fileNames
  end

  def candidate_list(methodSearch, list, types)
    unless list.nil?
      obType = list[1]
      list = list[0]
    end

    

    candidates = []
    if obType && obType == :initObject
      if methodSearch.match /^(i(n(i(t([A-Z]\w*)?)?)?)?)?(\[\[:alpha:\]:\])?$/
        methodSearch = "init(\b|[A-Z])" unless methodSearch.match(/^init(\b|[A-Z])/)
      end
    end
    
    fileNames = file_names(types)
    
    n = []
    k = (/^#{methodSearch}/)
    fileNames.each do |fileName|
      z = Zlib::GzipReader.open(fileName).each do |l|
        if l =~k

          f = l.split("\t")
          if types == :methods
            n << [l,:methods] if list && list.include?(f[3].split(";")[0])
          else
            n << [l.strip,types] if list && list.include?(f[2].split("\n"))
          end
          candidates << [l.strip, types]
        end
      end
      z.close
        # zGrepped = %x{ zgrep -e ^#{e_sh methodSearch } #{e_sh fileName }}
        #candidates += zGrepped.split("\n")
    end

    n = (n.empty? ? candidates : n)
    return n  
  end


  def match_iter(rgxp,str)
    offset = 0
    while m = str.match(rgxp)
      yield [m[0], m.begin(0) + offset, m[0].length]
      str = m.post_match
      offset += m.end(0)
    end
  end

  def methodNames(line )
    up =-1
    list = ""
    pat = /("(\\.|[^"\\])*"|\[|\]|@selector\([^\)]*\)|[a-zA-Z][a-zA-Z0-9]*:)/
    match_iter(pat , line) do |tok, beg, len|
      t = tok[0].chr
      if t == "["
        up +=1
      elsif t == "]"
        up -=1
      elsif t !='"' and t !='@' and up == 0
        list << tok
      end
    end
    return list
  end

  def return_type_based_c_constructs_suggestions(mn, search, show_arg, typeName)
    rules = open("#{ENV['TM_BUNDLE_SUPPORT']}/SpecialRules.txt","r").read.split("\n")
    arg_types = nil
    rules.each do |rule|
      sMn, sCn, sIMn, sTy = rule.split("!")
 #     sCn = nil if sCn.empty?
      if(mn == sMn && (sCn == "" || (sCn != "" && sCn.split("|").include?(typeName))))
        arg_types = sTy.split("|")
        break
      end
    end
    if arg_types
      candidates = []
      types = [arg_types.to_set]
      candidates += candidate_list(search, types, :annotated)
      candidates += candidate_list(search, types, :anonymous)
      candidates += candidate_list(search, types, :functions)
      candidates += candidate_list(search, types, :constants)
      #puts candidates.inspect.gsub(",","\n")
      res = c_popup_gen(candidates, search, arg_types)
    else
      candidates = candidate_list(mn, nil, :methods)
      if typeName
        temp = candidates.select do |e|
          c = e[0].split("\t")[3].match(/[A-Za-z0-9_]+/)[0]
          c == typeName
        end
        candidates = temp unless temp.empty?
      end
      arg_types = candidates.map{|e| e[0].split("\t")[5+mn.count(":")]} unless candidates.empty?

      if show_arg && !arg_types.nil?
        candidates = arg_types.uniq
      else
        candidates = []
      end
      types = [candidates.to_set]
      candidates += candidate_list(search, types, :annotated)
      candidates += candidate_list(search, types, :anonymous)
      candidates += candidate_list(search, types, :functions)
      candidates += candidate_list(search, types, :constants)
#      puts candidates.inspect.gsub(",","\n")
      TextMate.exit_show_tool_tip "No completion available" if candidates.empty?

      res = c_popup_gen(candidates, search, arg_types)
    end
  end


  def method_parse(k)
    k = k.match(/[^;\{]+?(;|\{)/)
    if k
      l = k[0].scan(/(\-|\+)\s*\((([^\(\)]|\([^\)]*\))*)\)|\((([^\(\)]|\([^\)]*\))*)\)\s*([_a-zA-Z][_a-zA-Z0-9]*)|(([a-zA-Z][a-zA-Z0-9]*)?:)/)
      types = l.select {|item| item[3] && item[3].match(/([A-Z]\w)\s*\*/) &&  item[5] }
      h = {}
      types.each{|item| h[item[5]] = item[3].gsub(/(\w)\s*\*/,'\1 *') }
      l = k.post_match.scan(/([A-Z]\w+)\s*\*\s*(\w+(?:\s*\,\s*\*\s*\w+)*)/)
      l.each do |e|
        e[1].split(/\s*,\s*\*\s*/).each do |item|
          if e[0].match /\*/
            h[item] = e[0] + ' *'
          else
            h[item] = e[0]
          end
        end
      end
      return h
    end
  end

  def instance_methods_for_variable(var,line)
    h = method_parse(line)
    if h &&  h[var]
      typeName = h[var].match(/[A-Za-z0-1]*/)[0]
      obType = :instanceMethod
      list = list_from_shell_command(typeName, obType)
      if list.nil? && File.exists?(userClasses = "#{ENV['TM_PROJECT_DIRECTORY']}/.classes.TM_Completions.txt.gz")
        candidates = %x{ zgrep ^#{e_sh h[var] + "[[:space:]]" } #{e_sh userClasses} }.split("\n")
        unless candidates.empty?
          list = Set.new
          c = candidates[0].split("\t")[1].split(":")
          list = c.to_set
          l = list_from_shell_command(c[-1], :instanceMethod)
          list += l unless l.nil?
        end
      end
    end
    return list
  end

  def list_from_shell_command(className, type)
    framework = %x{ zgrep ^#{e_sh className + "[[:space:]]" } #{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaClassesWithAncestry.txt.gz }.split("\n")
    list = framework[0].split("\t")[1].split(":").to_set unless framework.empty?

    return list
  end

  def try_find_class(line, start)
    if  m = line[start..-1].match(/^\[\s*(\[|([A-Z][a-zA-Z][a-zA-Z0-9]*)\s|([a-z_][_a-zA-Z0-9]*)\s)|((\b[a-z_][_a-zA-Z0-9]*)\.([a-z_][_a-zA-Z0-9]*)?$)/)
      if m[1] == "["
        pat = /("(\\.|[^"\\])*"|\[|\]|@selector\([^\)]*\)|[a-zA-Z][a-zA-Z0-9]*:)/
        up = -2
        last = -1
        match_iter(pat , line) do |tok, beg, len|
          t = tok[0].chr
          if t == "["
            up +=1
          elsif t == "]"
            if up == 0
              last = beg
              break
            end
            up -=1
          end
        end
        mn = methodNames(line[m.begin(1)..last])
        if mn.empty?
          m = line[m.begin(1)..last].match(/([a-zA-Z][a-zA-Z0-9]*)\s*\]$/)
          mn = m[1] unless m.nil?
        end
        if mn && (mn == "alloc" || mn == "allocWithZone:")
          obType = :initObject
          if  m = line.match(/^\[\s*\[\s*([A-Z][a-zA-Z][a-zA-Z0-9]*)\s/)
            typeName = m[1]
            list = list_from_shell_command(typeName, obType)
            if list
              list = list.select do |e|
                e.match(/^(init(\b|[A-Z]))/)
              end
            end
          end

        else
          candidates = %x{ zgrep ^#{e_sh mn + "[[:space:]]" } #{e_sh ENV['TM_BUNDLE_SUPPORT']}/cocoa.txt.gz }.split("\n")
          obType = :instanceMethod

          unless candidates.empty?
            if (type = candidates[0].split("\t")[5].match(/[A-Za-z]+/))
              typeName = type[0]
              list = list_from_shell_command(typeName, obType)
            end      
          end
        end
      elsif m[2]
        obType = :classMethod
        typeName = m[2]
        list = list_from_shell_command(typeName, obType)

      elsif m[3] && ENV['TM_SCOPE'].include?("meta.function-with-body.objc") && ENV['TM_SCOPE'].include?("meta.block.c")
        list = instance_methods_for_variable(m[3], line)

      elsif m[4] && ENV['TM_SCOPE'].include?("meta.function-with-body.objc") && ENV['TM_SCOPE'].include?("meta.block.c")
        list = instance_methods_for_variable(m[5], line)
      end
    end
    return list, obType, typeName
  end

  def print

    caret_placement = @car
    line = @line
    secondhalf = line.scan(/./mu)[1+caret_placement..-1].join
    bc = secondhalf.match /\A[a-zA-Z0-9_]+(:)?/
    if bc
      backContext = "[[:alnum:]]*" + bc[0]
      bcL = bc[0].length
    end

    pat = /("(\\.|[^"\\])*"|\[|\]|@selector\([^\)]*\)|[a-zA-Z][a-zA-Z0-9]*:)/u

    if caret_placement == -1
      TextMate.exit_discard
    end


    
    

    colon_and_space = /([a-zA-Z][a-zA-Z0-9]*:)\s*$/
    alpha_and_space = /[a-zA-Z0-9"\)\]]\s+$/
    alpha_and_caret = /[a-zA-Z][a-zA-Z0-9]*$/
    dot_alpha_and_caret = /\.([a-zA-Z][a-zA-Z0-9]*)?$/

    mline = line.gsub(/\n/, " ")
    # find Nested method
    up = 0
    start = [0]
    #Count [
    fromstart = mline.scan(/./u)[0..caret_placement].join
    match_iter(pat , fromstart) do |tok, beg, len|
      t = tok[0].chr
      if t == "["
        start << beg
      elsif t == "]"
        start.pop
      end
    end
    list = try_find_class(fromstart, start[-1])
    typeName = list[2]
    precaret = fromstart[start[-1]..-1]
    mn = methodNames(precaret)

    if precaret.match colon_and_space
      # [obj mess:^]
      [res = return_type_based_c_constructs_suggestions(mn, "", true, typeName) , 0]

    elsif temp =precaret.match( dot_alpha_and_caret)
      candidates = candidates_or_exit( temp[0][1..-1] + "[a-zA-Z0-9]+\\s", list, :methods )
      res = pop_up(candidates, temp[0][1..-1], "")
      [res , 0]
    elsif temp =precaret.match( alpha_and_space)
      # [obj mess ^]
      candidates = candidates_or_exit( mn + (backContext || "[[:alnum:]:]"), list, :methods ) # the alpha is to prevent satisfaction with just one part
      res = pop_up(candidates, mn, "")
      [res , (backContext && (res != "$0") ? bcL : 0)]
    elsif k = precaret.match( alpha_and_caret)
      # [obj mess^]
      t = mline[start[-1]..k.begin(0)-1+start[-1]]
      if t.match alpha_and_space
        candidates = candidates_or_exit( mn +k[0] + (backContext || "[[:alnum:]:]"), list, :methods)
        res =pop_up(candidates, mn, k[0])
        [res , (backContext && (res != "$0") ? bcL : 0)]
        # [NSOb^]
      elsif t.match(/\[\s*$/)
        candidates = candidates_or_exit( k[0] + (backContext || "[[:alnum:]]"), nil, :classes)
        res =pop_up(candidates, "",k[0])
        [res , (backContext && (res != "$0") ? bcL : 0)]
      elsif t.match(colon_and_space)
        #  [obj mess: arg^]
        res = return_type_based_c_constructs_suggestions(mn, k[0], false,typeName)
        [res , (backContext && (res != "$0") ? bcL : 0)]
      end
    end

  end
end

