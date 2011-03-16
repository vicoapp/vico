require 'optparse'

# Domain specific OptionParser extensions
module OptionHandler
  def set_banner
    self.banner = "Usage: #{$0} [options] [inputfile] [-- cmdline args]"
  end

  def handle_position(options)
    separator ""
    separator "Position options:"
    on("--line=LINE", "Current line number.") do |n|
      options[:lineno] = n.to_i
    end
    on("--column=COLUMN", "Current column number.") do |n|
      options[:column] = n.to_i
    end
  end

  def handle_interpreter(options)
    separator ""
    separator "Interpreter options:"
    on("-S FILE", "--interpreter FILE", "Use interpreter FILE.") do |interpreter|
      options[:interpreter] = interpreter
    end
    on("-I PATH", "Add PATH to $LOAD_PATH") do |path|
      options[:include_paths] << path
    end
    on("--dev", "Add this project's bin/ and lib/ to $LOAD_PATH.",
       "A directory with a Rakefile is considered a project base directory.") do
      auto_include_paths(options[:include_paths], Dir.pwd)
    end
    on("-r LIB", "Require LIB before execution.") do |lib|
      options[:libs] << lib
    end
    on("-e EXPR", "--eval=EXPR", "--stub=EXPR", "Evaluate EXPR after execution.") do |expr|
      options[:evals] << expr
    end

  end

  def handle_misc(options)
    separator ""
    separator "Misc options:"
    on("--cd DIR", "Change working directory to DIR.") do |dir|
      options[:wd] = dir
    end
    on("--debug", "Write transformed source code to xmp-tmp.PID.rb.") do
      options[:dump] = "xmp-tmp.#{Process.pid}.rb"
    end
    separator ""
    on("-h", "--help", "Show this message") do
      puts self
      exit
    end
    on("-v", "--version", "Show version information") do
      puts "#{File.basename($0)} #{XMPFilter::VERSION}"
      exit
    end
  end

  def auto_include_paths(include_paths, pwd)
    if pwd =~ %r!^(.+)/(lib|bin)!
      include_paths.unshift("#$1/lib").unshift("#$1/bin")
    elsif File.file? "#{pwd}/Rakefile" or File.file? "#{pwd}/rakefile"
      include_paths.unshift("#{pwd}/lib").unshift("#{pwd}/bin")
    end
  end
  module_function :auto_include_paths

end

def set_extra_opts(options)
  if idx = ARGV.index("--")
    options[:options] = ARGV[idx+1..-1]
    ARGV.replace ARGV[0...idx]
  else
    options[:options] = []
  end
end

DEFAULT_OPTIONS = {
  :interpreter       => "ruby",
  :options => ["hoge"],
  :min_codeline_size => 50,
  :libs              => [],
  :evals             => [],
  :include_paths     => [],
  :dump              => nil,
  :wd                => nil,
  :warnings          => true,
  :use_parentheses   => true,
  :column            => nil,
  :output_stdout     => true,
  }
