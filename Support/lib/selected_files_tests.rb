# cheat a bit to let textmate.rb not fail its require
ENV['TM_SUPPORT_PATH'] = '..'
require 'textmate.rb'
require 'test/unit'


# some tests to verify TextMate.selected_files is working
class SelectedFilesTestCase < Test::Unit::TestCase
  
  def test_empty
    assert_nil( TextMate.selected_files(nil) )
    assert_nil( TextMate.selected_files('') )
  end
  
  def test_single_file
    assert_equal( ["test'me"], TextMate.selected_files("'test'\\''me'") )
    
    assert_equal(
      ["test'me'again'and  ''again  '  and again."],
      TextMate.selected_files("'test'\\''me'\\''again'\\''and  '\\'\\''"+
                              "again  '\\''  and again.'")
    )
  end
  
  def test_multiple_files
    assert_equal(
      [ "test'me", "  and me", "/and  /  also ' mmh me/.rb"],
      TextMate.selected_files(
        "'test'\\''me' " + "'  and me' " + "'/and  /  also '\\'' mmh me/.rb'")
    )
  end
  
end
