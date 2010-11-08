# encoding: utf-8

# This file adds features that were present in Ruby 1.8 but that have been
# removed in 1.9. It should only be used on externally run programs.

# vendor/rcodetools/lib/rcodetools/xmpfilter.rb assumes String
# is enumerable, and that it has grep and friends

if RUBY_VERSION >= "1.9"
  class String
  	def grep(*args)
  		each_line.grep(*args)
  	end                   
	
  	def reject(&block)
  		each_line.reject(&block)
  	end 
  
    def map(&block)
      each_line.map(&block)
    end
  
    def inject(*args, &block)
      each_line.inject(*args, &block)
    end
  end
end

if $0 == __FILE__
	require 'test/unit'
	
	class TestStringExtensions < Test::Unit::TestCase
	 
	  def test_basic_grep
			str = "a\nb\nc\nd"
		  assert_equal(["c\n"], str.grep(/c/))
		  assert_equal([], str.grep(/x/))
		end
		def test_multi_grep
		  assert_equal(["cat\n", "car"], "dog\ncat\nfred\ncar".grep(/a/))
		end
	   
		def test_basic_reject
			str = "a\nb\nc\nd"
			assert_equal(["a\n", "b\n", "d"], str.reject {|l| l =~ /c/})
			assert_equal(["a\n", "b\n", "c\n", "d"], str.reject {|l| l =~ /x/})
		end
		def test_multi_reject
			str = "a\nb\nc\nd"
			assert_equal(["a\n", "d"], str.reject {|l| l =~ /[bc]/})
		end   
		
		def test_map
			str = "a\nb\nc"
			assert_equal(["A\n", "B\n", "C"], str.map {|l| l.upcase })
		end
	end
end