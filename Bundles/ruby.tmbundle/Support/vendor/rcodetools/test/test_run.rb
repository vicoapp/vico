require 'test/unit'
require 'rcodetools/xmpfilter'
require 'rcodetools/xmptestunitfilter'
require 'rcodetools/completion'
require 'rcodetools/doc'
require 'rcodetools/options'
require 'stringio'

class TestRun < Test::Unit::TestCase
  tests = {
    :simple_annotation => {:klass => XMPFilter},
    :unit_test         => {:klass => XMPTestUnitFilter},
    :rspec             => {:klass => XMPRSpecFilter,    :interpreter     => "spec"},
    :rspec_poetry      => {:klass => XMPRSpecFilter,    :interpreter     => "spec", :use_parentheses => false},
    :no_warnings       => {:klass => XMPFilter,         :warnings        => false},
    :bindings          => {:klass => XMPTestUnitFilter, :use_parentheses => false},
    :unit_test_poetry  => {:klass => XMPTestUnitFilter, :use_parentheses => false},
    :add_markers       => {:klass => XMPAddMarkers},
    
    :completion       => {:klass => XMPCompletionFilter,      :lineno => 1},
    :completion_emacs => {:klass => XMPCompletionEmacsFilter, :lineno => 1},
    :completion_emacs_icicles => {:klass => XMPCompletionEmacsIciclesFilter, :lineno => 1},
    
    :doc      => {:klass => XMPDocFilter,     :lineno => 1},
    :refe     => {:klass => XMPReFeFilter,    :lineno => 1},
    :ri       => {:klass => XMPRiFilter,      :lineno => 1},
    :ri_emacs => {:klass => XMPRiEmacsFilter, :lineno => 1},
    :ri_vim   => {:klass => XMPRiVimFilter,   :lineno => 1},
    
  }
  tests.each_pair do |test, opts|
    define_method("test_#{test}") do
      dir = File.expand_path(File.dirname(__FILE__))
      inputfile = "#{dir}/data/#{test}-input.rb"
      outputfile = "#{dir}/data/#{test}-output.rb"
      sio = StringIO.new
      sio.puts opts[:klass].run(File.read(inputfile), DEFAULT_OPTIONS.merge(opts))
      assert_equal(File.read(outputfile), sio.string)
    end
  end 
end
