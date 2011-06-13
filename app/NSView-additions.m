#import "NSView-additions.h"

@interface NSObject (private)
- (id)delegate;
- (id)document;
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

	if ([[NSApp delegate] respondsToSelector:action])
		return [NSApp delegate];

	return nil;
}

@end

