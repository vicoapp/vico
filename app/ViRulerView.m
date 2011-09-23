#import "ViRulerView.h"
#import "ViTextView.h"
#import "logging.h"

#define DEFAULT_THICKNESS   22.0
#define RULER_MARGIN        5.0

@implementation ViRulerView

- (id)initWithScrollView:(NSScrollView *)aScrollView
{
	if ((self = [super initWithScrollView:aScrollView orientation:NSVerticalRuler]) != nil) {
		[self setClientView:[[self scrollView] documentView]];
		backgroundColor = [NSColor colorWithDeviceRed:(float)0xED/0xFF
		                                        green:(float)0xED/0xFF
		                                         blue:(float)0xED/0xFF
		                                        alpha:1.0];
                [self resetTextAttributes];
	}
	return self;
}

- (void)resetTextAttributes
{
        textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSFont labelFontOfSize:0.8 * [[ViThemeStore font] pointSize]], NSFontAttributeName, 
                [NSColor colorWithCalibratedWhite:0.42 alpha:1.0], NSForegroundColorAttributeName,
                nil];
        [self setRuleThickness:[self requiredThickness]];
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
	if (thickness != [self ruleThickness]) {
		SEL sel = @selector(setRuleThickness:);
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:sel]];
		[invocation setSelector:sel];
		[invocation setArgument:&thickness atIndex:2];
		[invocation performSelector:@selector(invokeWithTarget:) withObject:self afterDelay:0.0];
	}
}

- (CGFloat)requiredThickness
{
	NSUInteger	 lineCount, digits;
	NSString	*sampleString;
	NSSize		 stringSize;

	id view = [self clientView];
	if ([view isKindOfClass:[ViTextView class]]) {
		lineCount = [[(ViTextView *)view textStorage] lineCount];
		digits = (unsigned)log10(lineCount) + 1;
		sampleString = [@"" stringByPaddingToLength:digits
                                                 withString:@"8"
                                            startingAtIndex:0];
		stringSize = [sampleString sizeWithAttributes:textAttributes];
		return ceilf(MAX(DEFAULT_THICKNESS, stringSize.width + RULER_MARGIN * 2));
	}

	return 0;
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{
	NSRect bounds = [self bounds];

	[backgroundColor set];
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
	NSRange                 range, glyphRange, nullRange;
	NSString                *labelText;
	NSUInteger              rectCount;
	NSRectArray             rects;
	CGFloat                 ypos, yinset;
	NSSize                  stringSize;

	layoutManager = [view layoutManager];
	container = [view textContainer];
	textStorage = [(ViTextView *)view textStorage];
	nullRange = NSMakeRange(NSNotFound, 0);
	yinset = [view textContainerInset].height;        
	visibleRect = [[[self scrollView] contentView] bounds];
	
	// Find the characters that are currently visible
	glyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect
	                                      inTextContainer:container];
	range = [layoutManager characterRangeForGlyphRange:glyphRange
	                                  actualGlyphRange:NULL];

	NSUInteger line = [textStorage lineNumberAtLocation:range.location];
	NSUInteger lastLine = [textStorage lineNumberAtLocation:NSMaxRange(range)];

	for (; line <= lastLine; line++) {
		NSUInteger location = [textStorage locationForStartOfLine:line];

		rectCount = 0;
		rects = [layoutManager rectArrayForCharacterRange:NSMakeRange(location, 0)
                                     withinSelectedCharacterRange:nullRange
                                                  inTextContainer:container
                                                        rectCount:&rectCount];

		if (rectCount > 0) {
			// Note that the ruler view is only as tall as the visible
			// portion. Need to compensate for the clipview's coordinates.
			ypos = yinset + NSMinY(rects[0]) - NSMinY(visibleRect);

			labelText = [NSString stringWithFormat:@"%d", line];
			stringSize = [labelText sizeWithAttributes:textAttributes];

			// Draw string flush right, centered vertically within the line
			NSRect rect;
			rect.origin.x = NSWidth(bounds) - stringSize.width - RULER_MARGIN;
			rect.origin.y = ypos + (NSHeight(rects[0]) - stringSize.height) / 2.0 - 1.0;
			rect.size.width = NSWidth(bounds) - RULER_MARGIN * 2.0;
			rect.size.height = NSHeight(rects[0]);

			[labelText drawInRect:rect withAttributes:textAttributes];
		}
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	id view = [self clientView];
	if ([view isKindOfClass:[ViTextView class]]) {
		fromPoint = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		fromPoint.x = 0;
		[(ViTextView *)view rulerView:self selectFromPoint:fromPoint toPoint:fromPoint];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	id view = [self clientView];
	if ([view isKindOfClass:[ViTextView class]]) {
		NSPoint toPoint = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		toPoint.x = 0;
		[(ViTextView *)view rulerView:self selectFromPoint:fromPoint toPoint:toPoint];
	}
}

@end
