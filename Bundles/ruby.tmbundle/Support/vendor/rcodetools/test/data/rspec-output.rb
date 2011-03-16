
class X
  Y = Struct.new(:a)
  def foo(b); b ? Y.new(2) : 2 end
  def bar; raise "No good" end
  def baz; nil end
  def fubar(x); x ** 2.0 + 1 end
  def babar; [1,2] end
  A = 1
  A = 1 # !> already initialized constant A
end


context "Testing xmpfilter's expectation expansion" do
  setup do
    @o = X.new
  end

  specify "Should expand should_equal expectations" do
    (@o.foo(true)).should_be_a_kind_of X::Y
    (@o.foo(true).inspect).should_equal "#<struct X::Y a=2>"
    (@o.foo(true).a).should_equal 2
    (@o.foo(false)).should_equal 2
  end
  
  specify "Should expand should_raise expectations" do
    lambda{@o.bar}.should_raise RuntimeError
  end

  specify "Should expand should_be_nil expectations" do
    (@o.baz).should_be_nil
  end

  specify "Should expand correct expectations for complex values" do
    (@o.babar).should_equal [1, 2]
  end

  specify "Should expand should_be_close expectations" do
    (@o.fubar(10)).should_be_close 101.0, 0.0001
  end
end

context "Testing binding" do
  specify "Should expand should_equal expectations" do
    a = b = c = 1
    d = a
    (d).should_equal a
    (d).should_equal b
    (d).should_equal c
    (d).should_equal 1
  end
end
