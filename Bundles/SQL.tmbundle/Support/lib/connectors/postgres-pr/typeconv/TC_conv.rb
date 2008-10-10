require 'test/unit'
require 'conv'
require 'array'
require 'bytea'

class TC_Conversion < Test::Unit::TestCase
  def test_decode_array
    assert_equal ["abcdef ", "hallo", ["1", "2"]], decode_array("{   abcdef ,    hallo, {   1, 2} }")
    assert_equal [""], decode_array("{ }") # TODO: Correct?
    assert_equal [], decode_array("{}")
    assert_equal ["hallo", ""], decode_array("{hallo,}")
  end

  def test_bytea
  end

  include Postgres::Conversion
end
