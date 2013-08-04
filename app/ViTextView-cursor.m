/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViTextView.h"
#import "ViThemeStore.h"
#import "ViDocument.h"
#import "ViEventManager.h"
#import "NSObject+SPInvocationGrabbing.h"

#import <objc/runtime.h>

@implementation ViTextView (cursor)

- (void)updateFont
{
	_characterSize = [@"a" sizeWithAttributes:[NSDictionary dictionaryWithObject:[ViThemeStore font]
									      forKey:NSFontAttributeName]];

	[self invalidateCaretRect];
	[self enclosingFrameDidChange:nil];
}

- (NSRect)invalidateCaretRectAt:(NSUInteger)aCaret
{
	NSLayoutManager *lm = [self layoutManager];
	ViTextStorage *ts = [self textStorage];
	NSUInteger length = [ts length];
	int len = 1;

	if ([self atEOF]) {
		len = 0;
	}

	NSRect aCaretRect = NSMakeRect(0, 0, 0, 0);

	if (length > 0) {
		NSUInteger rectCount = 0;
		NSRectArray rects = [lm rectArrayForCharacterRange:NSMakeRange(aCaret, len)
				      withinSelectedCharacterRange:NSMakeRange(NSNotFound, 0)
						   inTextContainer:[self textContainer]
							 rectCount:&rectCount];
		if (rectCount > 0) {
			aCaretRect = rects[0];
		}
	}

	NSSize inset = [self textContainerInset];
	NSPoint origin = [self textContainerOrigin];
	aCaretRect.origin.x += origin.x;
	aCaretRect.origin.y += origin.y;
	aCaretRect.origin.x += inset.width;
	aCaretRect.origin.y += inset.height;

	if (NSWidth(aCaretRect) == 0) {
		aCaretRect.size = _characterSize;
	}

	if (aCaretRect.origin.x == 0) {
		aCaretRect.origin.x = 5;
	}

	if ([self isFieldEditor]) {
		aCaretRect.size.width = 1;
	} else if (mode == ViInsertMode) {
		aCaretRect.size.width = 2;
	} else if (len > 0) {
		unichar c = [[ts string] characterAtIndex:aCaret];
		if (c == '\t') {
			/* Place cursor at end of tab, like vi does. */
			aCaretRect.origin.x += aCaretRect.size.width - _characterSize.width;
		}
		if (c == '\t' || c == '\n' || c == '\r' || c == 0x0C) {
			aCaretRect.size.width = _characterSize.width;
		}
	}

	if (_highlightCursorLine && _lineHighlightColor && mode != ViVisualMode) {
		_lineHighlightRect = NSMakeRect(0, aCaretRect.origin.y, 10000, aCaretRect.size.height);
	}

	[self setNeedsDisplayInRect:_oldCaretRect];
	[self setNeedsDisplayInRect:aCaretRect];
	[self setNeedsDisplayInRect:_oldLineHighlightRect];
	[self setNeedsDisplayInRect:_lineHighlightRect];
	_oldLineHighlightRect = _lineHighlightRect;

	return aCaretRect;
}

- (void)invalidateCaretRects
{
	[_caretRects removeAllObjects];
	[carets enumerateObjectsUsingBlock:^(id aCaret, NSUInteger i, BOOL *yes) {
		NSUInteger thisCaret = [(NSNumber *)aCaret unsignedIntegerValue];

		NSRect rect = [self invalidateCaretRectAt:thisCaret];
		[_caretRects addObject:[NSValue valueWithRect:rect]];
		if (thisCaret == self.caret) {
			_caretRect = rect;
			_oldCaretRect = _caretRect;
		}
	}];

	_caretBlinkState = YES;
	[_caretBlinkTimer invalidate];
	[_caretBlinkTimer release];
	if ([[self window] firstResponder] == self && (caretBlinkMode & mode) != 0) {
		_caretBlinkTimer = [[NSTimer scheduledTimerWithTimeInterval:caretBlinkTime
								     target:self
								   selector:@selector(blinkCaret:)
								   userInfo:nil
								    repeats:YES] retain];
	} else {
		_caretBlinkTimer = nil;
	}
}

- (void)invalidateCaretRect
{
	[self invalidateCaretRects];
}

- (void)updateCaret
{
	[self invalidateCaretRect];

	/* Update selection in symbol list. */
	NSNotification *notification = [NSNotification notificationWithName:ViCaretChangedNotification object:self];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
	[[ViEventManager defaultManager] emitDelayed:ViEventCaretDidMove for:self with:self, nil];
}

- (void)blinkCaret:(NSTimer *)aTimer
{
	_caretBlinkState = !_caretBlinkState;
	[_caretRects enumerateObjectsUsingBlock:^(id rectValue, NSUInteger i, BOOL *stop) {
		NSRect caretRect = [(NSValue *)rectValue rectValue];

		[self setNeedsDisplayInRect:caretRect];
	}];
}

- (void)updateInsertionPointInRect:(NSRect)aRect
{
	if (_caretBlinkState) {
		NSIndexSet *intersectingRectIndexes = [_caretRects indexesOfObjectsPassingTest:^BOOL(id rectValue, NSUInteger i, BOOL *stop) {
		  NSRect caretRect = [(NSValue *)rectValue rectValue];

		  return NSIntersectsRect(caretRect, aRect);
		}];

		[[_caretRects objectsAtIndexes:intersectingRectIndexes] enumerateObjectsUsingBlock:^(id rectValue, NSUInteger i, BOOL *stop) {
			NSRect intersectingRect = [(NSValue *)rectValue rectValue];

			if ([self isFieldEditor]) {
				[[NSColor blackColor] set];
			} else {
				[_caretColor set];
			}
			[[NSBezierPath bezierPathWithRect:intersectingRect] fill];
		}];
	}
}

- (void)drawViewBackgroundInRect:(NSRect)rect
{
	[super drawViewBackgroundInRect:rect];
	if (NSIntersectsRect(_lineHighlightRect, rect)) {
		if (_highlightCursorLine && _lineHighlightColor && mode != ViVisualMode && ![self isFieldEditor]) {
			[_lineHighlightColor set];
			[[NSBezierPath bezierPathWithRect:_lineHighlightRect] fill];
		}
	}
}

- (void)drawRect:(NSRect)aRect
{
	NSGraphicsContext *context = [NSGraphicsContext currentContext];
	[context setShouldAntialias:antialias];
	[super drawRect:aRect];
	if ([[self window] firstResponder] == self) {
		[self updateInsertionPointInRect:aRect];
	}
	[self drawPageGuideInRect:aRect];
}

- (BOOL)shouldDrawInsertionPoint
{
	return NO;
}

- (BOOL)becomeFirstResponder
{
	[self resetInputSource];
	[self setNeedsDisplayInRect:_oldLineHighlightRect];
	[self setNeedsDisplayInRect:_oldCaretRect];

	/* Force updating of line number view. */
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

	[_caretBlinkTimer invalidate];
	[_caretBlinkTimer release];
	_caretBlinkTimer = nil;

	[self setNeedsDisplayInRect:_oldLineHighlightRect];
	[self setNeedsDisplayInRect:_oldCaretRect];
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
		__invertedIBeamCursor = [[NSCursor alloc] initWithImage:iBeamImg
								hotSpot:[iBeam hotSpot]];
		[iBeamImg release];
	}
	return __invertedIBeamCursor;	
}

@end

