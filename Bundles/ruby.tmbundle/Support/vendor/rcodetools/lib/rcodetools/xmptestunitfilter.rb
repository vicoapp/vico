require 'rcodetools/xmpfilter'
class XMPTestUnitFilter < XMPFilter
  def initialize(opts = {})
    super
    @output_stdout = false
    mod = @parentheses ? :WithParentheses : :Poetry
    extend self.class.const_get(mod) 
  end

  private
  def annotated_line(line, expression, runtime_data, idx)
    indent =  /^\s*/.match(line)[0]
    assertions(expression.strip, runtime_data, idx).map{|x| indent + x}.join("\n")
  end

  def prepare_line(expr, idx)
    basic_eval = prepare_line_annotation(expr, idx)
    %|begin; #{basic_eval}; rescue Exception; $stderr.puts("#{MARKER}[#{idx}] ~> " + $!.class.to_s); end|
  end

  def assertions(expression, runtime_data, index)
    exceptions = runtime_data.exceptions
    ret = []

    unless (vars = runtime_data.bindings[index]).empty?
      vars.each{|var| ret << equal_assertion(var, expression) }
    end
    if !(wanted = runtime_data.results[index]).empty? || !exceptions[index]
      case (wanted[0][1] rescue 1)
      when "nil"
        ret.concat nil_assertion(expression)
      else
        case wanted.size
        when 1
          ret.concat _value_assertions(wanted[0], expression)
        else
          # discard values from multiple runs
          ret.concat(["#xmpfilter: WARNING!! extra values ignored"] + 
                     _value_assertions(wanted[0], expression))
        end
      end
    else
      ret.concat raise_assertion(expression, exceptions, index)
    end

    ret
  end

  OTHER = Class.new
  def _value_assertions(klass_value_txt_pair, expression)
    klass_txt, value_txt = klass_value_txt_pair
    value = eval(value_txt) || OTHER.new
    # special cases
    value = nil if value_txt.strip == "nil"
    value = false if value_txt.strip == "false"
    value_assertions klass_txt, value_txt, value, expression
  rescue Exception
    return object_assertions(klass_txt, value_txt, expression)
  end

  def raise_assertion(expression, exceptions, index)
    ["assert_raise(#{exceptions[index][0]}){#{expression}}"]
  end

  module WithParentheses
    def nil_assertion(expression)
      ["assert_nil(#{expression})"]
    end

    def value_assertions(klass_txt, value_txt, value, expression)
      case value
      when Float
        ["assert_in_delta(#{value.inspect}, #{expression}, 0.0001)"]
      when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
        ["assert_equal(#{value_txt}, #{expression})"]
      else
        object_assertions(klass_txt, value_txt, expression)
      end
    end

    def object_assertions(klass_txt, value_txt, expression)
      [ "assert_kind_of(#{klass_txt}, #{expression})",
        "assert_equal(#{value_txt.inspect}, #{expression}.inspect)" ]
    end

    def equal_assertion(expected, actual)
      "assert_equal(#{expected}, #{actual})"
    end
  end

  module Poetry
    def nil_assertion(expression)
      ["assert_nil #{expression}"]
    end

    def value_assertions(klass_txt, value_txt, value, expression)
      case value
      when Float
        ["assert_in_delta #{value.inspect}, #{expression}, 0.0001"]
      when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
        ["assert_equal #{value_txt}, #{expression}"]
      else
        object_assertions klass_txt, value_txt, expression
      end
    end

    def object_assertions(klass_txt, value_txt, expression)
      [ "assert_kind_of #{klass_txt}, #{expression} ",
        "assert_equal #{value_txt.inspect}, #{expression}.inspect" ] 
    end

    def equal_assertion(expected, actual)
      "assert_equal #{expected}, #{actual}"
    end
  end
end

class XMPRSpecFilter < XMPTestUnitFilter
  private
  def execute(code)
    codefile = "xmpfilter.rspec_tmpfile_#{Process.pid}.rb"
    File.open(codefile, "w"){|f| f.puts code}
    path = File.expand_path(codefile)
    at_exit { File.unlink path if File.exist? path}
    stdout, stderr = (1..2).map do |i|
      fname = "xmpfilter.rspec_tmpfile_#{Process.pid}-#{i}.rb"
      fullname = File.expand_path(fname)
      at_exit { File.unlink fullname if File.exist? fullname}
      File.open(fname, "w+")
    end
    args = *(interpreter_command << %["#{codefile}"] << "2>" << 
             %["#{stderr.path}"] << ">" << %["#{stdout.path}"])
    system(args.join(" "))
    [stdout, stderr]
  end

  def interpreter_command
    [@interpreter] + @libs.map{|x| "-r#{x}"}
  end

  def raise_assertion(expression, exceptions, index)
    ["lambda{#{expression}}.should_raise #{exceptions[index][0]}"]
  end

  module WithParentheses
    def nil_assertion(expression)
      ["(#{expression}).should_be_nil"]
    end
    
    def value_assertions(klass_txt, value_txt, value, expression)
      case value
      when Float
        ["(#{expression}).should_be_close #{value.inspect}, 0.0001"]
      when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
        ["(#{expression}).should_equal #{value_txt}"]
      else
        object_assertions klass_txt, value_txt, expression
      end
    end

    def object_assertions(klass_txt, value_txt, expression)
      [ "(#{expression}).should_be_a_kind_of #{klass_txt}",
        "(#{expression}.inspect).should_equal #{value_txt.inspect}" ]
    end

    def equal_assertion(expected, actual)
      "(#{actual}).should_equal #{expected}"
    end
  end

  module Poetry
    def nil_assertion(expression)
      ["#{expression}.should_be_nil"]
    end

    def value_assertions(klass_txt, value_txt, value, expression)
      case value
      when Float
        ["#{expression}.should_be_close #{value.inspect}, 0.0001"]
      when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
        ["#{expression}.should_equal #{value_txt}"]
      else
        object_assertions klass_txt, value_txt, expression
      end
    end

    def object_assertions(klass_txt, value_txt, expression)
      [ "#{expression}.should_be_a_kind_of #{klass_txt}",
        "#{expression}.inspect.should_equal #{value_txt.inspect}" ]
    end

    def equal_assertion(expected, actual)
      "#{actual}.should_equal #{expected}"
    end
  end
end

