#import "ViRulerView.h"
#import "ViTextView.h"
#import "ViThemeStore.h"
#import "NSObject+SPInvocationGrabbing.h"
#include "logging.h"

#define DEFAULT_THICKNESS   22.0
#define RULER_MARGIN        5.0

@implementation ViRulerView

- (id)initWithScrollView:(NSScrollView *)aScrollView
{
	if ((self = [super initWithScrollView:aScrollView orientation:NSVerticalRuler]) != nil) {
		[self setClientView:[[self scrollView] documentView]];
		_backgroundColor = [NSColor colorWithDeviceRed:(float)0xED/0xFF
							 green:(float)0xED/0xFF
							  blue:(float)0xED/0xFF
							 alpha:1.0];
		[_backgroundColor retain];
		[self resetTextAttributes];
	}
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_textAttributes release];
	[_backgroundColor release];
	for (int i = 0; i < 10; i++)
		[_digits[i] release];
	[super dealloc];
}

- (void)resetTextAttributes
{
	[_textAttributes release];
	_textAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSFont labelFontOfSize:0.8 * [[ViThemeStore font] pointSize]], NSFontAttributeName, 
		[NSColor colorWithCalibratedWhite:0.42 alpha:1.0], NSForegroundColorAttributeName,
		nil];

	_digitSize = [@"8" sizeWithAttributes:_textAttributes];
	_digitSize.width += 1.0;
	_digitSize.height += 1.0;

	[self setRuleThickness:[self requiredThickness]];

	for (int i = 0; i < 10; i++) {
		NSString *s = [NSString stringWithFormat:@"%i", i];
		NSImage *img = [[NSImage alloc] initWithSize:_digitSize];
		[img lockFocusFlipped:NO];
		[_backgroundColor set];
		NSRectFill(NSMakeRect(0, 0, _digitSize.width, _digitSize.height));
		[s drawAtPoint:NSMakePoint(0.5,0.5) withAttributes:_textAttributes];
		[img unlockFocus];
		[_digits[i] release];
		_digits[i] = img;
	}

	[self setNeedsDisplay:YES];
}

- (void)setClientView:(NSView *)aView
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	id oldClientView = [self clientView];

	if (oldClientView != aView &&
	    [oldClientView isKindOfClass:[NSTextView class]])
		[notificationCenter removeObserver:self
					      name:ViTextStorageChangedLinesNotification
					    object:[(NSTextView *)oldClientView textStorage]];

	[super setClientView:aView];

	if (aView != nil && [aView isKindOfClass:[NSTextView class]])
		[notificationCenter addObserver:self
				       selector:@selector(textStorageDidChangeLines:)
					   name:ViTextStorageChangedLinesNotification
					 object:[(NSTextView *)aView textStorage]];
}

- (void)textStorageDidChangeLines:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];

	NSUInteger linesRemoved = [[userInfo objectForKey:@"linesRemoved"] unsignedIntegerValue];
	NSUInteger linesAdded = [[userInfo objectForKey:@"linesAdded"] unsignedIntegerValue];

	NSInteger diff = linesAdded - linesRemoved;
	if (diff == 0)
		return;

	[self setNeedsDisplay:YES];

	CGFloat thickness;
	thickness = [self requiredThickness];
	if (thickness != [self ruleThickness])
		[[self nextRunloop] setRuleThickness:thickness];
}

- (CGFloat)requiredThickness
{
	NSUInteger	 lineCount, digits;

	id view = [self clientView];
	if ([view isKindOfClass:[ViTextView class]]) {
		lineCount = [[(ViTextView *)view textStorage] lineCount];
		digits = (unsigned)log10(lineCount) + 1;
		return ceilf(MAX(DEFAULT_THICKNESS, _digitSize.width * digits + RULER_MARGIN * 2));
	}

	return 0;
}

- (void)drawLineNumber:(NSUInteger)line inRect:(NSRect)rect
{
	do {
		NSUInteger rem = line % 10;
		line = line / 10;

		rect.origin.x -= _digitSize.width;

		[_digits[rem] drawInRect:rect
				fromRect:NSZeroRect
			       operation:NSCompositeSourceOver
				fraction:1.0
			  respectFlipped:YES
				   hints:nil];
	} while (line > 0);
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{
	NSRect bounds = [self bounds];

	[_backgroundColor set];
	NSRectFill(bounds);

	[[NSColor colorWithCalibratedWhite:0.58 alpha:1.0] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMinY(bounds))
				  toPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMaxY(bounds))];

	id view = [self clientView];
	if (![view isKindOfClass:[ViTextView class]])
		return;

	NSLayoutManager         *layoutManager;
	NSTextContainer         *container;
	ViTextStorage		*textStorage;
	NSRect                  visibleRect;
	NSRange                 range, glyphRange;
	CGFloat                 ypos, yinset;

	layoutManager = [view layoutManager];
	container = [view textContainer];
	textStorage = [(ViTextView *)view textStorage];
	yinset = [view textContainerInset].height;
	visibleRect = [[[self scrollView] contentView] bounds];

	if (layoutManager == nil)
		return;

	// Find the characters that are currently visible
	glyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect
					      inTextContainer:container];
	range = [layoutManager characterRangeForGlyphRange:glyphRange
					  actualGlyphRange:NULL];

	NSUInteger line = [textStorage lineNumberAtLocation:range.location];
	NSUInteger location = range.location;

	if (location >= NSMaxRange(range)) {
		// Draw line number "0" in empty documents

		ypos = yinset - NSMinY(visibleRect);
		// Draw digits flush right, centered vertically within the line
		NSRect r;
		r.origin.x = NSWidth(bounds) - RULER_MARGIN;
		r.origin.y = ypos + 2.0;
		r.size = _digitSize;

		[self drawLineNumber:0 inRect:r];
		return;
	}

	for (; location < NSMaxRange(range); line++) {
		NSUInteger glyphIndex = [layoutManager glyphIndexForCharacterAtIndex:location];
		NSRect rect = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];

		// Note that the ruler view is only as tall as the visible
		// portion. Need to compensate for the clipview's coordinates.
		ypos = yinset + NSMinY(rect) - NSMinY(visibleRect);

		// Draw digits flush right, centered vertically within the line
		NSRect r;
		r.origin.x = floor(NSWidth(bounds) - RULER_MARGIN);
		r.origin.y = floor(ypos + (NSHeight(rect) - _digitSize.height) / 2.0 + 1.0);
		r.size = _digitSize;

		[self drawLineNumber:line inRect:r];

		[[textStorage string] getLineStart:NULL
					       end:&location
				       contentsEnd:NULL
					  forRange:NSMakeRange(location, 0)];
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	id view = [self clientView];
	if ([view isKindOfClass:[ViTextView class]]) {
		_fromPoint = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		_fromPoint.x = 0;
		[(ViTextView *)view rulerView:self selectFromPoint:_fromPoint toPoint:_fromPoint];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	id view = [self clientView];
	if ([view isKindOfClass:[ViTextView class]]) {
		NSPoint toPoint = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		toPoint.x = 0;
		[(ViTextView *)view rulerView:self selectFromPoint:_fromPoint toPoint:toPoint];
	}
}

@end
