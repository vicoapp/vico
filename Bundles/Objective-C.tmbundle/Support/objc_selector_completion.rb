#!/usr/bin/env ruby
require ENV['TM_SUPPORT_PATH'] + "/lib/exit_codes"
require "#{ENV['TM_SUPPORT_PATH']}/lib/escape"

class ObjcSelectorCompletion
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
  
  def prettify(cand, call)
    stuff = cand.split("\t")
    out = stuff[0]
    return [out.chomp.strip, stuff[0], cand]
  end

  def snippet_generator(cand, start, call)
    stuff = cand[start..-1].split("\t") 
    out = stuff[0]
    out = out.chomp.strip + "$0"
    return out
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
    prettyCandidates = prettyCandidates.sort {|x,y| x[1].downcase <=> y[1].downcase }
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

      show_dialog(prettyCandidates,start) do |c,s|
        snippet_generator(c,s, call)
      end
    else
      snippet_generator( candidates[0], start, call )
    end
  end

  def show_dialog(prettyCandidates,start,&snip_gen)
    require "#{ENV['TM_SUPPORT_PATH']}/lib/osx/plist"
    pl = {'menuItems' => prettyCandidates.map { |pretty,junk, full | { 'title' => pretty, 'cand' => full} }}
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

  def candidates_or_exit(methodSearch, list, fileNames, notif = false)
    x = candidate_list(methodSearch, list, fileNames, notif)
    TextMate.exit_show_tool_tip "No completion available" if x.empty?
    return x
  end

  def candidate_list(methodSearch, list, fileNames, notif = false)
    candidates = []
    fileNames.each do |fileName|
      zGrepped = %x{ zgrep ^#{e_sh methodSearch } #{e_sh ENV['TM_BUNDLE_SUPPORT']}/#{fileName} }
      candidates += zGrepped.split("\n")
    end
    # strip notifications
    if notif
      candidates = candidates.select {|cand| cand.match(/\tno\t/) }
    else
      candidates = candidates.reject {|cand| cand.match(/\tno\t/) }
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

  def print
    line = @line
    caret_placement = @car
    methodDeclaration = /^(?:@selector\()([_a-zA-Z][a-zA-Z0-9:]*)$/

    if k = line[0..caret_placement].match(methodDeclaration)
      candidates = candidates_or_exit( k[1], nil, "cocoa.txt.gz")
      res =pop_up(candidates, k[1])
      TextMate.exit_discard if res == "$0"
      e_sn(line[0..caret_placement]) + res + e_sn(line[caret_placement + 1 ..  -1])
    else
      TextMate.exit_discard
    end
  end
end