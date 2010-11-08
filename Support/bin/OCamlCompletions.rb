#!/usr/bin/env ruby

require "#{ENV['TM_SUPPORT_PATH']}/lib/ocamlcompletion"

def parse_records(str)
  str.scan(/^(?:mutable )?([^:]+):/).map { |arr| arr[0].strip }
end


searchtype = ARGV[0].to_sym
searchstring = Regexp.escape(ENV['TM_CURRENT_WORD'].to_s)
answers = OCamlCompletion::cmigrep(searchstring, searchtype)

completions = 
  case searchtype
    when :records then parse_records(answers)
    else []
  end
  
puts completions.sort.uniq.join("\n")