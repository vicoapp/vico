#import "NSView-additions.h"
#import "ViWindowController.h"
#import "ViAppController.h"
#import "ExParser.h"

@interface NSObject (private)
- (id)delegate;
- (id)document;
- (id)keyManager;
@end

@implementation NSView (additions)

- (id)targetForSelector:(SEL)action
{
	NSView *view = self;

	do {
		if ([view respondsToSelector:action])
			return view;
	} while ((view = [view superview]) != nil);

	if ([[self window] respondsToSelector:action])
		return [self window];

	if ([[[self window] windowController] respondsToSelector:action])
		return [[self window] windowController];

	if ([self respondsToSelector:@selector(delegate)]) {
		id delegate = [self delegate];
		if ([delegate respondsToSelector:action])
			return delegate;
	}

	if ([self respondsToSelector:@selector(document)]) {
		id document = [self document];
		if ([document respondsToSelector:action])
			return document;
	}

	if ([self respondsToSelector:@selector(keyManager)]) {
		id keyManager = [self keyManager];
		if ([keyManager respondsToSelector:@selector(target)]) {
			id target = [keyManager target];
			if ([target respondsToSelector:action])
				return target;
		}
	}

	if ([[NSApp delegate] respondsToSelector:action])
		return [NSApp delegate];

	return nil;
}

- (BOOL)performCommand:(ViCommand *)command
{
	return [command performWithTarget:[self targetForSelector:[command action]]];
}

- (NSString *)getExStringForCommand:(ViCommand *)command prefix:(NSString *)prefix
{
	NSString *exString = nil;
	if ([[[self window] windowController] isKindOfClass:[ViWindowController class]])
		exString = [[[self window] windowController] getExStringInteractivelyForCommand:command prefix:prefix];
	else
		exString = [[NSApp delegate] getExStringForCommand:command prefix:prefix];
	return exString;
}

- (NSString *)getExStringForCommand:(ViCommand *)command
{
	return [self getExStringForCommand:command prefix:nil];
}

- (BOOL)evalExCommand:(ExCommand *)ex
{
	id result = nil;

	if (ex == nil)
		return YES;

	DEBUG(@"eval ex command %@", ex);

	if (ex.mapping.expression) {
		NuBlock *expression = ex.mapping.expression;
		NSUInteger requiredArgs = [[expression parameters] count];
		NuCell *arglist = nil;
		if (requiredArgs > 0)
			arglist = [[NSArray arrayWithObject:ex] list];
		DEBUG(@"evaling with calling context %@ and arguments %@", [expression context], arglist);
		@try {
			result = [expression evalWithArguments:arglist
						       context:[expression context]];
		}
		@catch (NSException *exception) {
			INFO(@"got exception %@ while evaluating expression:\n%@", [exception name], [exception reason]);
			INFO(@"context was: %@", [expression context]);
			[ex message:[NSString stringWithFormat:@"Got exception %@: %@", [exception name], [exception reason]]];
			return NO;
		}
	} else {
		id target = [self targetForSelector:ex.mapping.action];
		if (target == nil) {
			[ex message:[NSString stringWithFormat:@"The %@ command is not implemented.", ex.mapping.name]];
			return NO;
		} else {
			@try {
				result = [target performSelector:ex.mapping.action withObject:ex];
			}
			@catch (NSException *exception) {
				INFO(@"got exception %@ while evaluating ex command %@:\n%@",
					[exception name], ex.mapping.name, [exception reason]);
				[ex message:[NSString stringWithFormat:@"Got exception %@: %@", [exception name], [exception reason]]];
				return NO;
			}
		}
	}

	DEBUG(@"got result %@, class %@", result, NSStringFromClass([result class]));
	if (result == nil || [result isKindOfClass:[NSNull class]]) {
		return YES;
	} else if ([result isKindOfClass:[NSError class]]) {
		DEBUG(@"got error: %@", [result localizedDescription]);
		[ex message:[result localizedDescription]];
		return NO;
	} else if ([result isKindOfClass:[NSString class]]) {
		/* FIXME: I'm not sure we should handle returned strings this way... */
		[ex message:result];
		return YES;
	} else if ([result respondsToSelector:@selector(boolValue)] && [result boolValue])
		return YES;
	return NO;
}

@end

