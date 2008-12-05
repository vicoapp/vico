#import "ViTextView.h"
#import "ViThemeStore.h"
#import "ViDocument.h"

@implementation ViTextView (cursor)

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
			if (c == '\t' || c == '\n')
				caretRect.size.width = 7; // FIXME: adjust to chosen font, calculated from 'a' for example
		}
		[[[[ViThemeStore defaultStore] defaultTheme] caretColor] set];
		[[NSBezierPath bezierPathWithRect:caretRect] fill];
	}
}

- (void)drawRect:(NSRect)aRect
{
	[super drawRect:aRect];
	if ([[self window] firstResponder] == self)
		[self updateInsertionPointInRect:aRect];
	[self drawPageGuideInRect:aRect];
}

- (BOOL)shouldDrawInsertionPoint;
{
	return NO;
}

- (BOOL)becomeFirstResponder
{
	[self setNeedsDisplayInRect:oldCaretRect];
	[[self delegate] setMostRecentDocumentView:documentView];
	return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
	[self setNeedsDisplayInRect:oldCaretRect];
	return [super resignFirstResponder];
}

@end
