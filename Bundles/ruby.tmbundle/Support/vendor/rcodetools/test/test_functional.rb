require 'test/unit'

class TestFunctional < Test::Unit::TestCase
  tests = {:simple_annotation => [], :unit_test => ["-u"], :rspec => ["-s"],
           :no_warnings => ["--no-warnings"], :bindings => ["--poetry", "-u"],
           :add_markers => ["-m"]
  }
  tests.each_pair do |test, opts|
    define_method("test_#{test}") do
      dir = File.expand_path(File.dirname(__FILE__))
      libdir = File.expand_path(dir + '/../lib')
      exec = File.expand_path(dir + '/../bin/xmpfilter')
      output = `ruby -I#{libdir} #{exec} #{opts.join(" ")} #{dir}/data/#{test}-input.rb`
      outputfile = "#{dir}/data/#{test}-output.rb"
      assert_equal(File.read(outputfile), output)
    end
  end 
end
