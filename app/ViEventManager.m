#import "ViEventManager.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "Nu.h"
#include "logging.h"

static NSInteger __nextEventId = 0;

@implementation ViEvent

@synthesize expression = _expression;
@synthesize eventId = _eventId;

- (id)initWithExpression:(NuBlock *)anExpression
{
	if ((self = [super init]) != nil) {
		_expression = [anExpression retain];
		_eventId = ++__nextEventId;
	}
	return self;
}

- (void)dealloc
{
	[_expression release];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViEvent %p: %li>", self, _eventId];
}

@end





@implementation ViEventManager

+ (ViEventManager *)defaultManager
{
	static ViEventManager *__defaultManager = nil;
	if (__defaultManager == nil)
		__defaultManager = [[ViEventManager alloc] init];
	return __defaultManager;
}

- (id)init
{
	if ((self = [super init]) != nil) {
		_anonymous_events = [[NSMutableDictionary alloc] init];
		_owned_events = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_anonymous_events release];
	[_owned_events release];
	[super dealloc];
}

- (void)emitCallbacks:(id)callbacks forEvent:(NSString *)event withArglist:(NuCell *)arglist
{
	for (ViEvent *ev in callbacks) {
		DEBUG(@"evaluating expression: %@ with arguments %@",
		    [ev.expression stringValue], arglist);
		@try {
#ifndef NO_DEBUG
			id result =
#endif
			[ev.expression evalWithArguments:arglist
						 context:[ev.expression context]];
			DEBUG(@"expression returned %@", result);
		}
		@catch (NSException *exception) {
			INFO(@"got exception %@ while evaluating expression for event %@:\n%@\n%@",
			    [exception name], event, [exception reason], [exception callStackSymbols]);
		}
	}
}

- (void)emit:(NSString *)event for:(id)owner withArguments:(id)arguments
{
	DEBUG(@"emitting event %@ for %@", event, owner);

	if (event == nil)
		return;

	if (arguments == nil)
		arguments = [NSArray array];

	NuCell *arglist = arguments;
	if ([arguments isKindOfClass:[NSArray class]])
		arglist = [arguments list];
	else if (![arguments isKindOfClass:[NuCell class]]) {
		INFO(@"invalid type of arguments: %@", NSStringFromClass([arguments class]));
		return;
	}

	NSString *key = [event lowercaseString];
	NSMutableArray *callbacks = [_anonymous_events objectForKey:key];
	if (callbacks)
		[self emitCallbacks:callbacks forEvent:event withArglist:arglist];

	if (owner) {
		NSMapTable *owners = [_owned_events objectForKey:key];
		if (owners) {
			NSMutableArray *callbacks = [owners objectForKey:owner];
			if (callbacks)
				[self emitCallbacks:callbacks forEvent:event withArglist:arglist];
		}
	}
}

- (void)emit:(NSString *)event for:(id)owner with:(id)arg1, ...
{
	NSMutableArray *arguments = [NSMutableArray array];
	if (arg1) {
		[arguments addObject:arg1];

		id arg;
		va_list	args;
		va_start(args, arg1);
		while ((arg = va_arg(args, id)) != nil)
			[arguments addObject:arg];
		va_end(args);
	}

	[self emit:event for:owner withArguments:arguments];
}

- (void)emitDelayed:(NSString *)event for:(id)owner withArguments:(id)arguments
{
	[[self nextRunloop] emit:event for:owner withArguments:arguments];
}

- (void)emitDelayed:(NSString *)event for:(id)owner with:(id)arg1, ...
{
	NSMutableArray *arguments = [NSMutableArray array];
	if (arg1) {
		[arguments addObject:arg1];

		id arg;
		va_list	args;
		va_start(args, arg1);
		while ((arg = va_arg(args, id)) != nil)
			[arguments addObject:arg];
		va_end(args);
	}

	[self emitDelayed:event for:owner withArguments:arguments];
}

- (NSInteger)on:(NSString *)event by:(id)owner do:(NuBlock *)expression
{
	DEBUG(@"on %@ by %@ do %@", event, owner, expression);

	if (event == nil || expression == nil)
		return -1;

	NSString *key = [event lowercaseString];
	NSMutableArray *callbacks = nil;
	if (owner == nil) {
		callbacks = [_anonymous_events objectForKey:key];
		if (callbacks == nil) {
			callbacks = [NSMutableArray array];
			[_anonymous_events setObject:callbacks forKey:key];
		}
	} else {
		NSMapTable *owners = [_owned_events objectForKey:key];
		if (owners == nil) {
			owners = [NSMapTable mapTableWithWeakToStrongObjects]; // XXX: owners must explicitly remove themselves in MRC
			[_owned_events setObject:owners forKey:key];
		}

		callbacks = [owners objectForKey:owner];
		if (callbacks == nil) {
			callbacks = [NSMutableArray array];
			[owners setObject:callbacks forKey:owner];
		}
	}

	ViEvent *ev = [[ViEvent alloc] initWithExpression:expression];
	[callbacks addObject:ev];
	[ev release];

	return ev.eventId;
}

- (NSInteger)on:(NSString *)event do:(NuBlock *)callback
{
	return [self on:event by:nil do:callback];
}

- (void)clear:(NSString *)event for:(id)owner
{
	if (event == nil)
		return;

	NSString *key = [event lowercaseString];
	if (owner == nil)
		[_anonymous_events removeObjectForKey:key];
	else
		[[_owned_events objectForKey:key] removeObjectForKey:owner];

}

- (void)clear:(NSString *)event
{
	[self clear:event for:nil];
}

- (void)clearFor:(id)owner
{
	DEBUG(@"clear event for owner %@", owner);
	if (owner == nil) {
		[_anonymous_events removeAllObjects];
		[_owned_events removeAllObjects];
	} else {
		for (NSMapTable *owners in [_owned_events objectEnumerator]) {
			DEBUG(@"remove %@ from %@", owner, owners);
			[owners removeObjectForKey:owner];
		}
	}
}

- (void)clear
{
	[self clearFor:nil];
}

- (void)remove:(NSInteger)eventId
{
	if (eventId < 0)
		return;

	for (NSMutableArray *events in [_anonymous_events allValues]) {
		for (NSUInteger i = 0; i < [events count]; i++) {
			ViEvent *ev = [events objectAtIndex:i];
			if (ev.eventId == eventId) {
				[events removeObjectAtIndex:i];
				return;
			}
		}
	}

	for (NSMapTable *owners in [_owned_events allValues]) {
		for (NSMutableArray *events in [owners objectEnumerator]) {
			for (NSUInteger i = 0; i < [events count]; i++) {
				ViEvent *ev = [events objectAtIndex:i];
				if (ev.eventId == eventId) {
					[events removeObjectAtIndex:i];
					return;
				}
			}
		}
	}
}

@end
