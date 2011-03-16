import com.foo.*;
import com.bar.*;  // comment
import com.baz.*;

  /** class foo */

public class Foo
{
	void bar(Object baz)
	{
		throw new RuntimeException(baz.toString() + "; void");
	}
}

public class Hello
{
	void method(Integer integer) {}
	void method(INTEGER integer) {}
	
	private static final int ID = 0;
    ID id = new ID();
    Id id = new Id();
    
}

class Foo // bar
{
}

class Foo /* bar */
{
}

interface Foo // bar
{
}

interface Foo /* bar */
{
}

class Foo
{
}

class Foo extends Bar // bar
{
}

class Foo extends Bar /* bar */
{
}

class Foo extends Bar implements Bat // bar
{
}

class Foo extends Bar implements Bat /* bar */
{
}

class Foo implements Bar // bar
{
}

class Foo implements Bar /* bar */
{
}

interface Foo extends Bar // bar
{
}

interface Foo extends Bar /* bar */
{
    Value<?> get();
}

class Assertion 
{
    assert 1 = 1 : "Failure message";
    assert 1 = 1;
}

class AnonymousClassExample {
    public Object m() {
        return new Object() { /* meta.anon-class.java */ };
    }  
	public class Inner {
		void method() throws  {
			
		}
		
	}
}

public class Ticket3D1E429A 
{ 
    public static void main(String[] args) 
    { 
        System.out.println("      Java: " + profiler.profileJava(new ArrayList<Int>(), new Random(seed)));
    } 
}

public class Foo
{
   public void bar() {
       Int[] int1 = new Int[10] {1,2,3};
       Int[] int2 = new Int[10];
   }
   
   void method( ) 
   {
       method(new Integer[334]);
   }
   
   void method2() {
       // make sure this is shown as method2 in the symbol list
   }
   
}

public class ImplementsOverMultipleLines
   implements Bar,
              Baz
{
}

class Foo {
	private java.util.List<double[]> bar;
}

class Foo
{
   void bar()
   {
       System.out.println("class name");
   }
}

class Ta {
	/**
	 * 
	 */
	private native void setInitValues(long modelPtr, double n1,
	                                                       double n2,
	                                                       double p2,
	                                                       double p26,
	                                                       double p3,
	                                                       double wf,
	                                                       double t44);
}

class NativeAndAbstractMethods {
   private abstract long InitModel();
   private native void Step(long modelPtr, int iterationsPerStep);
   private native void Term(long modelPtr);
   private native void setValue(long modelPtr, String Key, double  
Value);
   private native double getValue(long modelPtr, String Key);
   private native void setInitValues(long modelPtr, double n1, double  
											n2, double
												p2, double p26, double p3, double wf, double t44);
}