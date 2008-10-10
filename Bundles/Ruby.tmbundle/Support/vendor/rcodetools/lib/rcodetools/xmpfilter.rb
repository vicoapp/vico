#!/usr/bin/env ruby
# Copyright (c) 2005-2007 Mauricio Fernandez <mfp@acm.org> http://eigenclass.org
#                         rubikitch <rubikitch@ruby-lang.org>
# Use and distribution subject to the terms of the Ruby license.

class XMPFilter
  VERSION = "0.5.0"

  MARKER = "!XMP#{Time.new.to_i}_#{Process.pid}_#{rand(1000000)}!"
  XMP_RE = Regexp.new("^" + Regexp.escape(MARKER) + '\[([0-9]+)\] (=>|~>|==>) (.*)')
  VAR = "_xmp_#{Time.new.to_i}_#{Process.pid}_#{rand(1000000)}"
  WARNING_RE = /.*:([0-9]+): warning: (.*)/

  RuntimeData = Struct.new(:results, :exceptions, :bindings)

  INITIALIZE_OPTS = {:interpreter => "ruby", :options => [], :libs => [],
                     :include_paths => [], :warnings => true, 
                     :use_parentheses => true}

  # The processor (overridable)
  def self.run(code, opts)
    new(opts).annotate(code)
  end

  def initialize(opts = {})
    options = INITIALIZE_OPTS.merge opts
    @interpreter = options[:interpreter]
    @options = options[:options]
    @libs = options[:libs]
    @evals = options[:evals] || []
    @include_paths = options[:include_paths]
    @output_stdout = options[:output_stdout]
    @dump = options[:dump]
    @warnings = options[:warnings]
    @parentheses = options[:use_parentheses]
    @ignore_NoMethodError = options[:ignore_NoMethodError]

    @postfix = ""
  end

  def add_markers(code, min_codeline_size = 50)
    maxlen = code.map{|x| x.size}.max
    maxlen = [min_codeline_size, maxlen + 2].max
    ret = ""
    code.each do |l|
      l = l.chomp.gsub(/ # (=>|!>).*/, "").gsub(/\s*$/, "")
      ret << (l + " " * (maxlen - l.size) + " # =>\n")
    end
    ret
  end

  def annotate(code)
    idx = 0
    newcode = code.gsub(/^(.*) # =>.*/){|l| prepare_line($1, idx += 1) }
    if @dump
      File.open(@dump, "w"){|f| f.puts newcode}
    end
    stdout, stderr = execute(newcode)
    output = stderr.readlines
    runtime_data = extract_data(output)
    idx = 0
    annotated = code.gsub(/^(.*) # =>.*/) do |l|
      expr = $1
      if /^\s*#/ =~ l
        l 
      else
        annotated_line(l, expr, runtime_data, idx += 1)
      end
    end.gsub(/ # !>.*/, '').gsub(/# (>>|~>)[^\n]*\n/m, "");
    ret = final_decoration(annotated, output)
    if @output_stdout and (s = stdout.read) != ""
      ret << s.inject(""){|s,line| s + "# >> #{line}".chomp + "\n" }
    end
    ret
  end

  def annotated_line(line, expression, runtime_data, idx)
    "#{expression} # => " + (runtime_data.results[idx].map{|x| x[1]} || []).join(", ")
  end
  
  def prepare_line_annotation(expr, idx)
    v = "#{VAR}"
    blocal = "__#{VAR}"
    blocal2 = "___#{VAR}"
    # rubikitch: oneline-ized
# <<EOF.chomp
# ((#{v} = (#{expr}); $stderr.puts("#{MARKER}[#{idx}] => " + #{v}.class.to_s + " " + #{v}.inspect) || begin; $stderr.puts local_variables; local_variables.each{|#{blocal}| #{blocal2} = eval(#{blocal}); if #{v} == #{blocal2} && #{blocal} != %#{expr}.strip; $stderr.puts("#{MARKER}[#{idx}] ==> " + #{blocal}); elsif [#{blocal2}] == #{v}; $stderr.puts("#{MARKER}[#{idx}] ==> [" + #{blocal} + "]") end }; nil rescue Exception; nil end || #{v}))
# EOF
    oneline_ize(<<-EOF).chomp
#{v} = (#{expr})
$stderr.puts("#{MARKER}[#{idx}] => " + #{v}.class.to_s + " " + #{v}.inspect) || begin
  $stderr.puts local_variables
  local_variables.each{|#{blocal}|
    #{blocal2} = eval(#{blocal})
    if #{v} == #{blocal2} && #{blocal} != %#{expr}.strip
      $stderr.puts("#{MARKER}[#{idx}] ==> " + #{blocal})
    elsif [#{blocal2}] == #{v}
      $stderr.puts("#{MARKER}[#{idx}] ==> [" + #{blocal} + "]")
    end
  }
  nil
rescue Exception
  nil
end || #{v}
    EOF

  end
  alias_method :prepare_line, :prepare_line_annotation

  def execute_tmpfile(code)
    stdin, stdout, stderr = (1..3).map do |i|
      fname = "xmpfilter.tmpfile_#{Process.pid}-#{i}.rb"
      f = File.open(fname, "w+")
      at_exit { f.close unless f.closed?; File.unlink fname }
      f
    end
    stdin.puts code
    stdin.close
    exe_line = <<-EOF.map{|l| l.strip}.join(";")
      $stdout.reopen('#{stdout.path}', 'w')
      $stderr.reopen('#{stderr.path}', 'w')
      $0.replace '#{stdin.path}'
      ARGV.replace(#{@options.inspect})
      load #{stdin.path.inspect}
      #{@evals.join(";")}
    EOF
    system(*(interpreter_command << "-e" << exe_line))
    [stdout, stderr]
  end

  def execute_popen(code)
    require 'open3'
    stdin, stdout, stderr = Open3::popen3(*interpreter_command)
    stdin.puts code
    @evals.each{|x| stdin.puts x } unless @evals.empty?
    stdin.close
    [stdout, stderr]
  end

  if /win|mingw/ =~ RUBY_PLATFORM && /darwin/ !~ RUBY_PLATFORM
    alias_method :execute, :execute_tmpfile
  else
    alias_method :execute, :execute_popen
  end

  def interpreter_command
    r = [@interpreter, "-wKu"]
    r << "-d" if $DEBUG
    r << "-I#{@include_paths.join(":")}" unless @include_paths.empty?
    @libs.each{|x| r << "-r#{x}" } unless @libs.empty?
    (r << "-").concat @options unless @options.empty?
    r
  end

  def extract_data(output)
    results = Hash.new{|h,k| h[k] = []}
    exceptions = Hash.new{|h,k| h[k] = []}
    bindings = Hash.new{|h,k| h[k] = []}
    output.grep(XMP_RE).each do |line|
      result_id, op, result = XMP_RE.match(line).captures
      case op
      when "=>"
        klass, value = /(\S+)\s+(.*)/.match(result).captures
        results[result_id.to_i] << [klass, value]
      when "~>"
        exceptions[result_id.to_i] << result
      when "==>"
        bindings[result_id.to_i] << result unless result.index(VAR) 
      end
    end
    RuntimeData.new(results, exceptions, bindings)
  end

  def final_decoration(code, output)
    warnings = {}
    output.join.grep(WARNING_RE).map do |x|
      md = WARNING_RE.match(x)
      warnings[md[1].to_i] = md[2]
    end
    idx = 0
    ret = code.map do |line|
      w = warnings[idx+=1]
      if @warnings
        w ? (line.chomp + " # !> #{w}") : line
      else
        line
      end
    end
    output = output.reject{|x| /^-:[0-9]+: warning/.match(x)}
    if exception = /^-:[0-9]+:.*/m.match(output.join)
      ret << exception[0].map{|line| "# ~> " + line }
    end
    ret
  end

  def oneline_ize(code)
    "((" + code.gsub(/\r?\n|\r/, ';') + "))#{@postfix}\n"
  end

  def debugprint(*args)
    $stderr.puts(*args) if $DEBUG
  end
end # clas XMPFilter

class XMPAddMarkers < XMPFilter
  def self.run(code, opts)
    new(opts).add_markers(code, opts[:min_codeline_size])
  end
end
