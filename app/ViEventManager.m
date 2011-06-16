#import "ViEventManager.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "Nu/Nu.h"
#include "logging.h"

static NSInteger nextEventId = 0;

@implementation ViEvent
@synthesize owner, expression, eventId;
- (id)initWithExpression:(NuBlock *)anExpression owner:(id)anOwner
{
	if ((self = [super init]) != nil) {
		expression = anExpression;
		owner = anOwner;
		eventId = nextEventId++;
	}
	return self;
}
@end

@implementation ViEventManager

+ (ViEventManager *)defaultManager
{
	static ViEventManager *defaultManager = nil;
	if (defaultManager == nil)
		defaultManager = [[ViEventManager alloc] init];
	return defaultManager;
}

- (id)init
{
	if ((self = [super init]) != nil) {
		_events = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)emit:(NSString *)event for:(id)owner withArguments:(id)arguments
{
	DEBUG(@"emitting event %@ for %@", event, owner);

	if (event == nil)
		return;

	NSMutableArray *callbacks = [_events objectForKey:[event lowercaseString]];
	if (callbacks == nil)
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

	for (ViEvent *ev in callbacks) {
		if (ev.owner == nil || [owner isEqual:ev.owner]) {
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
				INFO(@"got exception %@ while evaluating expression:\n%@",
				    [exception name], [exception reason]);
			}
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
	NSMutableArray *callbacks = [_events objectForKey:key];
	if (callbacks == nil) {
		callbacks = [NSMutableArray array];
		[_events setObject:callbacks forKey:key];
	}

	ViEvent *ev = [[ViEvent alloc] initWithExpression:expression owner:owner];
	[callbacks addObject:ev];
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

	NSMutableArray *callbacks = [_events objectForKey:[event lowercaseString]];
	for (NSUInteger i = 0; i < [callbacks count];) {
		ViEvent *ev = [callbacks objectAtIndex:i];
		if (owner == nil || [owner isEqual:ev.owner])
			[callbacks removeObjectAtIndex:i];
		else
			++i;
	}
}

- (void)clear:(NSString *)event
{
	[self clear:event for:nil];
}

- (void)clearFor:(id)owner
{
	for (NSString *event in [_events allKeys])
		[self clear:event for:owner];
}

- (void)clear
{
	[self clearFor:nil];
}

- (void)remove:(NSInteger)eventId
{
	if (eventId < 0)
		return;

	for (NSString *event in [_events allKeys]) {
		NSMutableArray *events = [_events objectForKey:event];
		for (NSUInteger i = 0; i < [events count]; i++) {
			ViEvent *ev = [events objectAtIndex:i];
			if (ev.eventId == eventId) {
				[events removeObjectAtIndex:i];
				break;
			}
		}
	}
}

@end
