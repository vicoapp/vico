#import "ViRulerView.h"
#import "NSTextStorage-additions.h"
#import "logging.h"

#define DEFAULT_THICKNESS   22.0
#define RULER_MARGIN        5.0

@interface ViRulerView (Private)
- (NSDictionary *)textAttributes;
@end

@implementation ViRulerView

- (id)initWithScrollView:(NSScrollView *)aScrollView
{
	if ((self = [super initWithScrollView:aScrollView orientation:NSVerticalRuler]) != nil) {
		[self setClientView:[[self scrollView] documentView]];
		font = [NSFont labelFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
		color = [NSColor colorWithCalibratedWhite:0.42 alpha:1.0];
		backgroundColor = [NSColor colorWithDeviceRed:(float)0xED/0xFF
		                                        green:(float)0xED/0xFF
		                                         blue:(float)0xED/0xFF
		                                        alpha:1.0];
		[self setRuleThickness:[self requiredThickness]];
	}
	return self;
}

- (void)setClientView:(NSView *)aView
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	id oldClientView = [self clientView];

	if (oldClientView != aView &&
	    [oldClientView isKindOfClass:[NSTextView class]])
		[notificationCenter removeObserver:self
                                              name:NSTextStorageDidProcessEditingNotification
                                            object:[(NSTextView *)oldClientView textStorage]];

	[super setClientView:aView];

	if (aView != nil && [aView isKindOfClass:[NSTextView class]])
		[notificationCenter addObserver:self
                                       selector:@selector(textStorageDidProcessEditing:)
                                           name:NSTextStorageDidProcessEditingNotification
                                         object:[(NSTextView *)aView textStorage]];
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
#if 0
	NSTextStorage *textStorage = [notification object];
	NSRange area = [textStorage editedRange];
	NSInteger diff = [textStorage changeInLength];
#endif

	/* FIXME:
	 * Only need to redraw the ruler if changes include newlines.
	 */
	[self setNeedsDisplay:YES];

	CGFloat thickness = [self requiredThickness];
	if (thickness != [self ruleThickness])
		[self setRuleThickness:thickness];
}

- (NSDictionary *)textAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
	    font, NSFontAttributeName, 
	    color, NSForegroundColorAttributeName,
	    nil];
}

- (CGFloat)requiredThickness
{
	NSUInteger	 lineCount, digits;
	NSString	*sampleString;
	NSSize		 stringSize;

	id view = [self clientView];
	if ([view isKindOfClass:[NSTextView class]]) {
		lineCount = [[view textStorage] lineCount];
		digits = (unsigned)log10(lineCount) + 1;
		sampleString = [@"" stringByPaddingToLength:digits
                                                 withString:@"8"
                                            startingAtIndex:0];
		stringSize = [sampleString sizeWithAttributes:[self textAttributes]];
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
	if (![view isKindOfClass:[NSTextView class]])
		return;

	NSLayoutManager         *layoutManager;
	NSTextContainer         *container;
	NSTextStorage		*textStorage;
	NSRect                  visibleRect;
	NSRange                 range, glyphRange, nullRange;
	NSString                *text, *labelText;
	NSUInteger              rectCount;
	NSRectArray             rects;
	CGFloat                 ypos, yinset;
	NSSize                  stringSize;
	
	layoutManager = [view layoutManager];
	container = [view textContainer];
	text = [view string];
	textStorage = [view textStorage];
	nullRange = NSMakeRange(NSNotFound, 0);
	yinset = [view textContainerInset].height;        
	visibleRect = [[[self scrollView] contentView] bounds];

	NSDictionary *textAttributes = [self textAttributes];
	
	// Find the characters that are currently visible
	glyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect
	                                      inTextContainer:container];
	range = [layoutManager characterRangeForGlyphRange:glyphRange
	                                  actualGlyphRange:NULL];

	NSUInteger line = [textStorage lineNumberAtLocation:range.location];
	NSUInteger lastLine = [textStorage lineNumberAtLocation:NSMaxRange(range)];

	for (; line < lastLine; line++) {
		NSUInteger location = [[view textStorage] locationForStartOfLine:line];

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
			rect.origin.y = ypos + (NSHeight(rects[0]) - stringSize.height) / 2.0;
			rect.size.width = NSWidth(bounds) - RULER_MARGIN * 2.0;
			rect.size.height = NSHeight(rects[0]);

			[labelText drawInRect:rect withAttributes:textAttributes];
		}
	}
}

@end
