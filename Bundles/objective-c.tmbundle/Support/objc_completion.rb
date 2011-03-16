#!/usr/bin/env ruby
require ENV['TM_SUPPORT_PATH'] + "/lib/exit_codes"
require "#{ENV['TM_SUPPORT_PATH']}/lib/escape"

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
          files = [[ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaConstants.txt.gz",true,true],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaAnonymousEnums.txt.gz",true,false],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaAnnotatedStrings.txt.gz",false,false],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaFunctions.txt.gz",false,false]]
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
    files.each do |name, pure,noArg|
      zGrepped = %x{zgrep -e ^#{e_sh methodSearch } #{name}}
      candidates += zGrepped.split("\n").map do |elem|
        [elem, pure, noArg]
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
      [prettify(cand[0]), cand[0],cand[1],cand[2]]
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
      require "#{ENV['TM_SUPPORT_PATH']}/lib/osx/plist"
      pl = {'menuItems' => prettyCandidates.map { |pretty, full, pure, noArg | { 'title' => pretty, 'cand' => full, 'pure'=> pure, 'noArg'=> noArg} }}
      open("/dev/console", "w") { |io| io << pl.to_plist }
      io = open('|"$DIALOG" -u', "r+")
      io << pl.to_plist
      io.close_write
      res = OSX::PropertyList::load(io.read)
      if res.has_key? 'selectedMenuItem'
        b = {0 => false , 1 => true}
        snippet_generator( res['selectedMenuItem']['cand'], start, star&& !b[res['selectedMenuItem']['pure']],arg_name && !b[res['selectedMenuItem']['noArg']] )
      else
        "$0"
      end
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

    backContext = line[1+caret_placement..-1].match /^[a-zA-Z0-9_]/

    if backContext
      TextMate.exit_discard
    end

    star = arg_name = false
    if ENV['TM_SCOPE'].include? "meta.protocol-list.objc"
      files = [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaProtocols.txt.gz",false,false]]
    elsif ENV['TM_SCOPE'].include?("meta.scope.implementation.objc") ||  ENV['TM_SCOPE'].include?("meta.interface-or-protocol.objc")
      files = [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaClassesWithFramework.txt.gz",false,false]]
      files += [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaTypes.txt.gz", true, false]] if ENV['TM_SCOPE'].include?("meta.scope.interface.objc")
      userClasses = ["#{ENV['TM_PROJECT_DIRECTORY']}/.classes.TM_Completions.txt.gz", false,false]
      files += [userClasses] if File.exists? userClasses[0]
      if ENV['TM_SCOPE'].include?("meta.function.objc")
        star = true
        files += [[ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaTypes.txt.gz",true,false]]
      elsif ENV['TM_SCOPE'].include? "meta.scope.implementation.objc"
        star = arg_name = true
        files += [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CLib.txt.gz",false,false],
        [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaConstants.txt.gz",true,true],
        [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaTypes.txt.gz",true,false],
        ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaFunctions.txt.gz",false,false]]
        files += [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/C++Lib.txt.gz",false,false]] if ENV['TM_SCOPE'].include? "source.objc++"
      elsif ENV['TM_SCOPE'].include? "meta.scope.interface.objc"
        star = arg_name = true
      end
    else
      star = arg_name = true
      files = [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaClassesWithFramework.txt.gz",false,false],
      [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaConstants.txt.gz",true,true],
      [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaTypes.txt.gz",true,false],
      [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CLib.txt.gz",false,false],
      [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaFunctions.txt.gz",false,false]]
      files += [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/C++Lib.txt.gz",false,false]] if ENV['TM_SCOPE'].include? "source.objc++"
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
          files = [[ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaConstants.txt.gz",false,false],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaAnonymousEnums.txt.gz",false,false],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaAnnotatedStrings.txt.gz",false,false],
          ["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaFunctions.txt.gz",false,false],
          [ "#{e_sh ENV['TM_BUNDLE_SUPPORT']}/CLib.txt.gz",false,false]]
          files += [["#{e_sh ENV['TM_BUNDLE_SUPPORT']}/C++Lib.txt.gz",false,false]] if ENV['TM_SCOPE'].include? "source.objc++"
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

  def prettify(cand, call)
    stuff = cand.split("\t")
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

    return [out.chomp.strip, stuff[0], cand]
  end

  def snippet_generator(cand, start, call)
    start = 0 unless call
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

  def pop_up(candidates, searchTerm, call = true)
    start = searchTerm.size
    prettyCandidates = candidates.map { |candidate| prettify(candidate,call) }.sort
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
      prettyCandidates = prettyCandidates.sort {|x,y| x[1].downcase <=> y[1].downcase }
      show_dialog(prettyCandidates,start) do |c,s|
        snippet_generator(c,s, call)
      end
    else
      snippet_generator( candidates[0], start, call )
    end
  end

  def cfunc_snippet_generator(c,s)
    c = c.split"\t"
    i = 0
    ((c.size < 2 || c.size > 4 || c[1]=="") ? c[0][s..-1]+"$0" : c[0][s..-1]+"("+c[1][1..-2].split(",").collect do |arg| 
      "${"+(i+=1).to_s+":"+ arg.strip + "}" 
    end.join(", ")+")$0")
  end

  def c_snip_gen(c,si,arg_type=nil)
    s = si.size
    prettyCandidates = c.map do |candidate|
      ca = candidate.split("\t")
      [((ca[1].nil? || !ca[4].nil? || c[1]=="") ? ca[0] : ca[0]+ca[1]),ca[0], candidate] 
    end
    unless arg_type.nil?
      tmp = prettyCandidates.reject do |junk1,junk2,b|
        v = b.split("\t")[2]
        v !=nil && !arg_type.include?(v)
      end
      prettyCandidates = tmp unless tmp.empty?
    end
    if prettyCandidates.size > 1
      show_dialog(prettyCandidates,s) do |cand,size|
        cfunc_snippet_generator(cand,size)
      end
    else
      cfunc_snippet_generator(c[0],s)
    end
  end



  def show_dialog(prettyCandidates,start,&snip_gen)
    require "#{ENV['TM_SUPPORT_PATH']}/lib/osx/plist"
    pl = {'menuItems' => prettyCandidates.map { |pretty, junk, full | { 'title' => pretty, 'cand' => full} }}
    io = open('|"$DIALOG" -u', "r+")
    io <<  pl.to_plist
    io.close_write
    res = OSX::PropertyList::load(io.read)
    if res.has_key? 'selectedMenuItem'
      snip_gen.call( res['selectedMenuItem']['cand'], start )
    else
      "$0"
    end
  end

  def candidates_or_exit(methodSearch, list, fileNames)
    x = candidate_list(methodSearch, list, fileNames)
    TextMate.exit_show_tool_tip "No completion available" if x.empty?
    return x
  end

  def candidate_list(methodSearch, list, types)
    unless list.nil?
      obType = list[1]
      list = list[0]
    end

    notif = false
    if types == :classes
      userClasses = "#{ENV['TM_PROJECT_DIRECTORY']}/.classes.TM_Completions.txt.gz"
      fileNames = ["#{ENV['TM_BUNDLE_SUPPORT']}/CocoaClassesWithFramework.txt.gz"]
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

    candidates = []
    if obType && obType == :initObject
      if methodSearch.match /^(i(n(i(t([A-Z]\w*)?)?)?)?)?(\[\[:alpha:\]:\])?$/
        methodSearch = "init[[:space:][:upper:]]" unless methodSearch.match(/^init(\b|[A-Z])/)
      end
    end
    fileNames.each do |fileName|
      zGrepped = %x{ zgrep -e ^#{e_sh methodSearch } #{e_sh fileName }}
      candidates += zGrepped.split("\n")
    end


    return [] if candidates.empty?
    if list.nil?
      return candidates
    else
      n = []
      candidates.each do |cand|
        n << cand if list.include?(cand.split("\t")[0])
      end
      n = (n.empty? ? candidates : n)

      return n
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
      candidates += candidate_list(search, nil, :annotated)
      candidates += candidate_list(search, nil, :anonymous)
      candidates += candidate_list(search, nil, :functions)
      candidates += candidate_list(search, nil, :constants)
      res = c_snip_gen(candidates, search, arg_types)
    else
      candidates = candidate_list(mn, nil, :methods)
      if typeName
        temp = candidates.select do |e|
          c = e.split("\t")[3].match(/[A-Za-z0-9_]+/)[0]
          c == typeName
        end
        candidates = temp unless temp.empty?
      end
      arg_types = candidates.map{|e| e.split("\t")[5+mn.count(":")]} unless candidates.empty?

      if show_arg && !arg_types.nil?
        candidates = arg_types.uniq
      else
        candidates = []
      end
      candidates += candidate_list(search, nil, :annotated)
      candidates += candidate_list(search, nil, :anonymous)
      candidates += candidate_list(search, nil, :functions)
      candidates += candidate_list(search, nil, :constants)
      TextMate.exit_show_tool_tip "No completion available" if candidates.empty?
      res = c_snip_gen(candidates, search, arg_types)
    end
  end


  def method_parse(k)
    k = k.match(/[^;\{]+?(;|\{)/)
    if k
      l = k[0].scan(/(\-|\+)\s*\((([^\(\)]|\([^\)]*\))*)\)|\((([^\(\)]|\([^\)]*\))*)\)\s*([_a-zA-Z][_a-zA-Z0-9]*)|(([a-zA-Z][a-zA-Z0-9]*)?:)/)
      types = l.select {|item| item[3] && item[3].match(/([A-Z]\w*)\s*\*/) &&  item[5] }
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


  def list_from_shell_command(className, type)
    methodTypes = {:initObject => "-i", :classMethod => "-c", :instanceMethod => "-i"}
    framework = %x{ zgrep ^#{e_sh className + "[[:space:]]" } #{e_sh ENV['TM_BUNDLE_SUPPORT']}/CocoaClassesWithFramework.txt.gz }.split("\n")
    unless framework.empty?
      list = %x{#{e_sh ENV['TM_BUNDLE_SUPPORT']}/bin/inspectClass #{methodTypes[type]} -n #{e_sh className} -f #{e_sh framework[0].split("\t")[1]}}.split("\n")

    end
    return list
  end

  def try_find_class(line, start)
    if  m = line[start..-1].match(/^\[\s*(\[|([A-Z][a-zA-Z][a-zA-Z0-9]*)\s|([a-z_][_a-zA-Z0-9]*)\s)/)
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
        h = method_parse(line)
        if h &&  h[m[3]]
          typeName = h[m[3]].match(/[A-Za-z0-1]*/)[0]
          obType = :instanceMethod
          list = list_from_shell_command(typeName, obType)
          if list.nil? && File.exists?(userMethods = "#{ENV['TM_PROJECT_DIRECTORY']}/.methods.TM_Completions.txt.gz") && File.exists?(userClasses = "#{ENV['TM_PROJECT_DIRECTORY']}/.classes.TM_Completions.txt.gz")
            candidates = %x{ zgrep ^#{e_sh h[m[3]] + "[[:space:]]" } #{userClasses} }.split("\n")
            cocoaSet = []
            cocoaSet = %x{gunzip -c #{e_sh userMethods} |cut -f1,4}.split("\n")
            unless candidates.empty? || cocoaSet.empty?
              list = []
              c = candidates[0].split("\t")[1].split(":")
              cocoaSet.each do |element|
                me, cl = element.split("\t")
                c.each do |cand|
                  list << me if cl.match(/\w+/)[0] == cand
                end
              end
              
              l = list_from_shell_command(c[-1], :instanceMethod)
              list += l unless l.nil?
            end
          end
        end
      end
    end
    return list, obType, typeName
  end

  def print

    caret_placement = @car
    line = @line
    bc = line[1+caret_placement..-1].match /\A[a-zA-Z0-9_]+(:)?/
    if bc
      backContext = "[[:alpha:]]*" + bc[0]
      bcL = bc[0].length
    end

    pat = /("(\\.|[^"\\])*"|\[|\]|@selector\([^\)]*\)|[a-zA-Z][a-zA-Z0-9]*:)/

    if caret_placement == -1
      TextMate.exit_discard
    end

    up = 0
    start = [0]
    #Count [
    match_iter(pat , line[0..caret_placement]) do |tok, beg, len|
      t = tok[0].chr
      if t == "["
        start << beg
      elsif t == "]"
        start.pop
      end
    end
    
    

    colon_and_space = /([a-zA-Z][a-zA-Z0-9]*:)\s*$/
    alpha_and_space = /[a-zA-Z0-9"\)\]]\s+$/
    alpha_and_caret = /[a-zA-Z][a-zA-Z0-9]*$/

    mline = line.gsub(/\n/, " ")
    # find Nested method
    list = try_find_class(mline[0..caret_placement], start[-1])
    typeName = list[2]
    mn = methodNames(line[start[-1]..caret_placement])

    if mline[start[-1]..caret_placement].match colon_and_space
      # [obj mess:^]
      [res = return_type_based_c_constructs_suggestions(mn, "", true, typeName) , 0]

    elsif temp =mline[start[-1]..caret_placement].match( alpha_and_space)
      # [obj mess ^]
      candidates = candidates_or_exit( mn + (backContext || "[[:alpha:]:]"), list, :methods ) # the alpha is to prevent satisfaction with just one part
      res = pop_up(candidates, mn)
      [res , (backContext && (res != "$0") ? bcL : 0)]
    elsif k = mline[start[-1]..caret_placement].match( alpha_and_caret)
      # [obj mess^]
      if mline[start[-1]..k.begin(0)-1+start[-1]].match alpha_and_space
        mn += k[0]
        candidates = candidates_or_exit( mn + (backContext || "[[:alpha:]:]"), list, :methods)
        res =pop_up(candidates, mn)
        [res , (backContext && (res != "$0") ? bcL : 0)]
        # [NSOb^]
      elsif mline[start[-1]..k.begin(0)-1+start[-1]].match(/\[\s*$/)
        candidates = candidates_or_exit( k[0] + (backContext || "[[:alpha:]]"), nil, :classes)
        res =pop_up(candidates, k[0])
        [res , (backContext && (res != "$0") ? bcL : 0)]
      elsif mline[start[-1]..k.begin(0)-1+start[-1]].match(colon_and_space)
        #  [obj mess: arg^]
        res = return_type_based_c_constructs_suggestions(mn, k[0], false,typeName)
        [res , (backContext && (res != "$0") ? bcL : 0)]

        # else
        #  TextMate.exit_discard
      end
      #else
      # 
    end

  end
end
