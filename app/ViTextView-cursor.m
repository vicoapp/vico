#import "ViTextView.h"
#import "ViThemeStore.h"
#import "ViDocument.h"

@implementation ViTextView (cursor)

- (void)invalidateCaretRect
{
	NSLayoutManager *lm = [self layoutManager];
	NSUInteger length = [[self textStorage] length];
	int len = 1;
	if (caret + 1 >= length)
		len = 0;
	if (length == 0) {
		caretRect.origin = NSMakePoint(0, 0);
	} else {
		NSRange r = [lm glyphRangeForCharacterRange:NSMakeRange(caret, len) actualCharacterRange:NULL];
		caretRect = [lm boundingRectForGlyphRange:r inTextContainer:[self textContainer]];
	}

	if (NSWidth(caretRect) == 0)
		caretRect.size.width = 7; // XXX
	if (len == 0) {
                // XXX: at EOF
		caretRect.size.height = 16;
		caretRect.size.width = 7;
	}
        if (caretRect.origin.x == 0)
                caretRect.origin.x = 5;
	[self setNeedsDisplayInRect:oldCaretRect];
	[self setNeedsDisplayInRect:caretRect];
	oldCaretRect = caretRect;
}

- (void)updateCaret
{
	[self invalidateCaretRect];

	// update selection in symbol list
	NSNotification *notification = [NSNotification notificationWithName:ViCaretChangedNotification object:self];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
}

- (void)updateInsertionPointInRect:(NSRect)aRect
{
	if (NSIntersectsRect(caretRect, aRect)) {
		if ([self isFieldEditor]) {
			caretRect.size.width = 1;
		} else if (mode == ViInsertMode) {
			caretRect.size.width = 2;
		} else if (caret < [[self textStorage] length]) {
			unichar c = [[[self textStorage] string] characterAtIndex:caret];
			if (c == '\t') {
				// place cursor at end of tab, like vi does
				caretRect.origin.x += caretRect.size.width - 7;
			}
			if (c == '\t' || c == '\n' || c == '\r' || c == 0x0C)
				caretRect.size.width = 7; // FIXME: adjust to chosen font, calculated from 'a' for example
		}
		if ([self isFieldEditor])
			[[NSColor blackColor] set];
		else
			[caretColor set];
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

- (void)resetInputSource
{
	if (mode == ViInsertMode)
		[self switchToInsertInputSource];
	else
		[self switchToNormalInputSourceAndRemember:NO];
}

- (BOOL)becomeFirstResponder
{
	INFO(@"%p: became first responder", self);
	[self resetInputSource];

	[self setNeedsDisplayInRect:oldCaretRect];
	return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
	TISInputSourceRef input = TISCopyCurrentKeyboardInputSource();

	if (mode == ViInsertMode) {
		INFO(@"%p: remembering original insert input: %@", self,
		    TISGetInputSourceProperty(input, kTISPropertyLocalizedName));
		original_insert_source = input;
	} else {
		INFO(@"%p: remembering original normal input: %@", self,
		    TISGetInputSourceProperty(input, kTISPropertyLocalizedName));
		original_normal_source = input;
	}

	[self setNeedsDisplayInRect:oldCaretRect];
	return [super resignFirstResponder];
}

@end
