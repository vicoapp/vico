
class X
  Y = Struct.new(:a)
  def foo(b); b ? Y.new(2) : 2 end
  def bar; raise "No good" end
  def baz; nil end
  def fubar(x); x ** 2.0 + 1 end
  def babar; [1,2] end
  A = 1
  A = 1
end


context "Testing xmpfilter's expectation expansion" do
  setup do
    @o = X.new
  end

  specify "Should expand should_equal expectations" do
    @o.foo(true)   # =>
    @o.foo(true).a # =>
    @o.foo(false)  # =>
  end
  
  specify "Should expand should_raise expectations" do
    @o.bar         # =>
  end

  specify "Should expand should_be_nil expectations" do
    @o.baz         # =>
  end

  specify "Should expand correct expectations for complex values" do
    @o.babar       # =>
  end

  specify "Should expand should_be_close expectations" do
    @o.fubar(10)   # =>
  end
end

context "Testing binding" do
  specify "Should expand should_equal expectations" do
    a = b = c = 1
    d = a
    d                                              # =>
  end
end
