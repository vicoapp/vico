#import "ViTextView.h"
#import "ViThemeStore.h"
#import "ViDocument.h"

@implementation ViTextView (cursor)

- (void)updateCaret
{
	NSLayoutManager *lm = [self layoutManager];
	NSRange r = [lm glyphRangeForCharacterRange:NSMakeRange(caret, 1) actualCharacterRange:NULL];
	caretRect = [lm boundingRectForGlyphRange:r inTextContainer:[self textContainer]];

	if (NSWidth(caretRect) == 0)
		caretRect.size.width = 7; // XXX
	if (caret + 1 >= [[self textStorage] length])
	{
                // XXX
		caretRect.size.height = 16;
		caretRect.size.width = 7;
	}
        if (caretRect.origin.x == 0)
                caretRect.origin.x = 5;
	[self setNeedsDisplayInRect:oldCaretRect];
	[self setNeedsDisplayInRect:caretRect];
	oldCaretRect = caretRect;

	// update selection in symbol list
	NSNotification *notification = [NSNotification notificationWithName:ViCaretChangedNotification object:self];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
}

- (void)updateInsertionPointInRect:(NSRect)aRect
{
	if (NSIntersectsRect(caretRect, aRect)) 
	{
		if (mode == ViInsertMode)
		{
			caretRect.size.width = 2;
		}
		else if (caret < [[self textStorage] length])
		{
			unichar c = [[[self textStorage] string] characterAtIndex:caret];
			if (c == '\t')
			{
				// place cursor at end of tab, like vi does
				caretRect.origin.x += caretRect.size.width - 7;
			}
			if (c == '\t' || c == '\n' || c == '\r')
				caretRect.size.width = 7; // FIXME: adjust to chosen font, calculated from 'a' for example
		}
		[[[[ViThemeStore defaultStore] defaultTheme] caretColor] set];
		[[NSBezierPath bezierPathWithRect:caretRect] fill];
	}
}

- (void)drawRect:(NSRect)aRect
{
	NSGraphicsContext *context = [NSGraphicsContext currentContext]; 
	[context setShouldAntialias:antialias]; 
	[super drawRect:aRect];
	if ([[self window] firstResponder] == self)
		[self updateInsertionPointInRect:aRect];
	[self drawPageGuideInRect:aRect];
}

- (BOOL)shouldDrawInsertionPoint
{
	return NO;
}

- (BOOL)becomeFirstResponder
{
	[self setNeedsDisplayInRect:oldCaretRect];

	NSNotification *notification = [NSNotification notificationWithName:ViFirstResponderChangedNotification object:self];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];

	return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
	[self setNeedsDisplayInRect:oldCaretRect];
	return [super resignFirstResponder];
}

@end
