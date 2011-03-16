
require 'test/unit'
$: << ".." << "../lib[s]"
require "rcodetools/xmpfilter"

class TestXMPFilter < Test::Unit::TestCase
  def setup
    @xmp = XMPFilter.new
    @marker = XMPFilter::MARKER
  end

  def test_extract_data
    str = <<-EOF
#{@marker}[1] => Fixnum 42
#{@marker}[1] => Fixnum 0
#{@marker}[1] ==> var
#{@marker}[1] ==> var2
#{@marker}[4] ==> var3
#{@marker}[2] ~> some exception
#{@marker}[10] => Fixnum 42
    EOF
    data = @xmp.extract_data(str)
    assert_kind_of(XMPFilter::RuntimeData, data)
    assert_equal([[1, [["Fixnum", "42"], ["Fixnum", "0"]]], [10, [["Fixnum", "42"]]]], data.results.sort)
    assert_equal([[2, ["some exception"]]], data.exceptions.sort)
    assert_equal([[1, ["var", "var2"]], [4, ["var3"]]], data.bindings.sort)
  end
end

class TestXMPAddMarkers < Test::Unit::TestCase
  

  def test_

  end
end
