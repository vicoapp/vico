#import "ViTextView.h"
#import "ViThemeStore.h"
#import "ViDocument.h"
#import "ViEventManager.h"
#import "NSObject+SPInvocationGrabbing.h"

#import <objc/runtime.h>

@implementation ViTextView (cursor)

- (void)invalidateCaretRect
{
	NSLayoutManager *lm = [self layoutManager];
	ViTextStorage *ts = [self textStorage];
	NSUInteger length = [ts length];
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

	if (highlightCursorLine && lineHighlightColor && mode != ViVisualMode) {
		NSRange lineRange;
		if (length == 0) {
			lineHighlightRect = NSMakeRect(0, 0, 10000, 16);
		} else {
			NSUInteger glyphIndex = [lm glyphIndexForCharacterAtIndex:IMIN(caret, length - 1)];
			[lm lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineRange];
			if (lineRange.length > 0) {
				NSUInteger eol = [lm characterIndexForGlyphAtIndex:NSMaxRange(lineRange) - 1];
				if ([[ts string] characterAtIndex:eol] == '\n') // XXX: what about other line endings?
					lineRange.length -= 1;
			}

			lineHighlightRect = [lm boundingRectForGlyphRange:lineRange
							  inTextContainer:[self textContainer]];
			lineHighlightRect.size.width = 10000;
		}
	}

	[self setNeedsDisplayInRect:oldCaretRect];
	[self setNeedsDisplayInRect:caretRect];
	[self setNeedsDisplayInRect:oldLineHighlightRect];
	[self setNeedsDisplayInRect:lineHighlightRect];
	oldCaretRect = caretRect;
	oldLineHighlightRect = lineHighlightRect;

	caretBlinkState = YES;
	[caretBlinkTimer invalidate];
	if ([[self window] firstResponder] == self && (caretBlinkMode & mode) != 0)
		caretBlinkTimer = [NSTimer scheduledTimerWithTimeInterval:caretBlinkTime
					target:self
				      selector:@selector(blinkCaret:)
				      userInfo:nil
				       repeats:YES];
}

- (void)updateCaret
{
	[self invalidateCaretRect];

	// update selection in symbol list
	NSNotification *notification = [NSNotification notificationWithName:ViCaretChangedNotification object:self];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
	[[ViEventManager defaultManager] emitDelayed:ViEventCaretDidMove for:self with:self, nil];
}

- (void)blinkCaret:(NSTimer *)aTimer
{
	caretBlinkState = !caretBlinkState;
	[self setNeedsDisplayInRect:caretRect];
}

- (void)updateInsertionPointInRect:(NSRect)aRect
{
	if (caretBlinkState && NSIntersectsRect(caretRect, aRect)) {
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

- (void)drawViewBackgroundInRect:(NSRect)rect
{
	[super drawViewBackgroundInRect:rect];
	if (NSIntersectsRect(lineHighlightRect, rect)) {
		if (highlightCursorLine && lineHighlightColor && mode != ViVisualMode && ![self isFieldEditor]) {
			[lineHighlightColor set];
			[[NSBezierPath bezierPathWithRect:lineHighlightRect] fill];
		}
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
	[self resetInputSource];
	[self setNeedsDisplayInRect:oldLineHighlightRect];
	[self setNeedsDisplayInRect:oldCaretRect];

	// force updating of line number view
	[[[self enclosingScrollView] verticalRulerView] setNeedsDisplay:YES];

	[self updateCaret];
	[[self nextRunloop] setCursorColor];
	return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
	TISInputSourceRef input = TISCopyCurrentKeyboardInputSource();

	if (mode == ViInsertMode) {
		DEBUG(@"%p: remembering original insert input: %@", self,
		    TISGetInputSourceProperty(input, kTISPropertyLocalizedName));
		original_insert_source = input;
	} else {
		DEBUG(@"%p: remembering original normal input: %@", self,
		    TISGetInputSourceProperty(input, kTISPropertyLocalizedName));
		original_normal_source = input;
	}

	[caretBlinkTimer invalidate];
	[self setNeedsDisplayInRect:oldLineHighlightRect];
	[self setNeedsDisplayInRect:oldCaretRect];
	[self forceCursorColor:NO];
	return [super resignFirstResponder];
}

- (void)forceCursorColor:(BOOL)state
{
	/*
	 * Change the IBeamCursor method implementation.
	 */

	if (![self isFieldEditor]) {
		Class class = [NSCursor class];
		IMP whiteIBeamCursorIMP = method_getImplementation(class_getClassMethod([NSCursor class],
			@selector(whiteIBeamCursor)));

		DEBUG(@"setting %s cursor", state ? "WHITE" : "NORMAL");

		Method defaultIBeamCursorMethod = class_getClassMethod(class, @selector(IBeamCursor));
		method_setImplementation(defaultIBeamCursorMethod,
			state ? whiteIBeamCursorIMP : [NSCursor defaultIBeamCursorImplementation]);

		/*
		 * We always set the i-beam cursor.
		 */
		[[NSCursor IBeamCursor] set];
	}
}

- (void)setCursorColor
{
	if (![self isFieldEditor]) {
		BOOL mouseInside = [self mouse:[self convertPoint:[[self window] mouseLocationOutsideOfEventStream]
							 fromView:nil]
					inRect:[self bounds]];

		BOOL shouldBeWhite = mouseInside && backgroundIsDark && ![self isHidden] && [[self window] isKeyWindow];

		DEBUG(@"caret %s be white (bg is %s, mouse is %s, %shidden)",
			shouldBeWhite ? "SHOULD" : "should NOT",
			backgroundIsDark ? "dark" : "light",
			mouseInside ? "inside" : "outside",
			[self isHidden] ? "" : "not ");

		[self forceCursorColor:shouldBeWhite];
	}
}

- (void)mouseEntered:(NSEvent *)anEvent
{
	[self setCursorColor];
}

- (void)mouseExited:(NSEvent *)anEvent
{
	[self forceCursorColor:NO];
}

/* Hiding or showing the view does not always produce mouseEntered/Exited events. */
- (void)viewDidUnhide
{
	[[self nextRunloop] setCursorColor];
	[super viewDidUnhide];
}

- (void)viewDidHide
{
	[self forceCursorColor:NO];
	[super viewDidHide];
}

- (void)windowBecameKey:(NSNotification *)notification
{
	[self setCursorColor];
}

- (void)windowResignedKey:(NSNotification *)notification
{
	[self forceCursorColor:NO];
}

@end

@implementation NSCursor (CursorColor)

+ (IMP)defaultIBeamCursorImplementation
{
	static IMP __defaultIBeamCursorIMP = NULL;
	if (__defaultIBeamCursorIMP == nil)
		__defaultIBeamCursorIMP = method_getImplementation(class_getClassMethod([NSCursor class], @selector(IBeamCursor)));
	return __defaultIBeamCursorIMP;
}

+ (NSCursor *)defaultIBeamCursor
{
	return [self defaultIBeamCursorImplementation]([NSCursor class], @selector(IBeamCursor));
}

+ (NSCursor *)whiteIBeamCursor
{
	static NSCursor *__invertedIBeamCursor = nil;
	if (!__invertedIBeamCursor) {
		NSCursor *iBeam = [NSCursor defaultIBeamCursor];
		NSImage *iBeamImg = [[iBeam image] copy];
		NSRect imgRect = {NSZeroPoint, [iBeamImg size]};
		[iBeamImg lockFocus];
		[[NSColor whiteColor] set];
		NSRectFillUsingOperation(imgRect, NSCompositeSourceAtop);
		[iBeamImg unlockFocus];
		__invertedIBeamCursor = [[NSCursor alloc] initWithImage:iBeamImg hotSpot:[iBeam hotSpot]];
		[iBeamImg release];
	}
	return __invertedIBeamCursor;	
}

@end

