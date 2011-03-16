#import "ViScriptProxy.h"
#import "NSObject+SPInvocationGrabbing.h"
#include "logging.h"

@implementation ViScriptProxy

@synthesize __obj = _object;

- (ViScriptProxy *)initWithObject:(id)object
{
	self = [super init];
	if (self) {
		_object = object;
		_listeners = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)emit:(NSString *)event withArguments:(NSArray *)arguments
{
	if (event == nil)
		return;

	NSMutableArray *callbacks = [_listeners objectForKey:event];
	if (callbacks == nil)
		return;

	if (arguments == nil)
		arguments = [NSArray array];

	// FIXME: catch exceptions
	for (NSDictionary *d in callbacks) {
		JSValueRef callback = [[d objectForKey:@"callback"] pointerValue];
		id jsc = [d objectForKey:@"controller"];
		[jsc callJSFunction:callback withArguments:arguments];   
	}
}

- (void)emit:(NSString *)event with:(id)arg1, ...
{
	NSMutableArray *arguments = [NSMutableArray array];
	if (arg1)
		[arguments addObject:arg1];

	if (arg1) {
		id arg;
		va_list	args;
		va_start(args, arg1);
		while ((arg = va_arg(args, id)))	
			[arguments addObject:arg];
		va_end(args);
	}
	
	[self emit:event withArguments:arguments];
}

- (void)emitDelayed:(NSString *)event withArguments:(NSArray *)arguments
{
	[[self nextRunloop] emit:event withArguments:arguments];
}

- (void)emitDelayed:(NSString *)event with:(id)arg1, ...
{
	NSMutableArray *arguments = [NSMutableArray array];
	if (arg1)
		[arguments addObject:arg1];

	if (arg1) {
		id arg;
		va_list	args;
		va_start(args, arg1);
		while ((arg = va_arg(args, id)))	
			[arguments addObject:arg];
		va_end(args);
	}
	
	[self emitDelayed:event withArguments:arguments];
}

- (void)onEvent:(NSString *)event runCallback:(JSValueRefAndContextRef)callback
{
	if (event == nil)
		return;

	NSMutableArray *callbacks = [_listeners objectForKey:event];
	if (callbacks == nil) {
		callbacks = [NSMutableArray array];
		[_listeners setObject:callbacks forKey:event];
	}

	id jsc = [JSCocoa controllerFromContext:callback.ctx];
	if (jsc) {
		JSValueProtect([jsc ctx], callback.value); 
		NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
		    [NSValue valueWithPointer:callback.value], @"callback",
		    jsc, @"controller",
		    nil];
		[callbacks addObject:d];
	}
}


- (void)removeAllListeners:(NSString *)event
{
	if (event == nil)
		return;

	NSMutableArray *callbacks = [_listeners objectForKey:event];
	if (callbacks) {
		callbacks = [NSMutableArray array];
		[_listeners setObject:callbacks forKey:event];
	}
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	SEL aSelector = [invocation selector];
	if ([_object respondsToSelector:aSelector])
		[invocation invokeWithTarget:_object];
	else
		[self doesNotRecognizeSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)inSelector
{
	NSMethodSignature *signature = [super methodSignatureForSelector:inSelector];
	if (signature == NULL)
		signature = [_object methodSignatureForSelector:inSelector];
	return signature;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	return [super respondsToSelector:aSelector] || [_object respondsToSelector:aSelector];
}

@end