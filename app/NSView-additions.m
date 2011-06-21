#import "NSView-additions.h"
#import "ViWindowController.h"
#import "ViAppController.h"

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

- (NSString *)getExStringForCommand:(ViCommand *)command
{
	NSString *exString = nil;
	if ([self window])
		exString = [[[self window] windowController] getExStringInteractivelyForCommand:command];
	else
		exString = [[NSApp delegate] getExStringForCommand:command];
	return exString;
}

@end

