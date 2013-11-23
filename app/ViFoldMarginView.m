#import "ViFoldMarginView.h"

#import "ViFold.h"
#import "ViTextView.h"

#define FOLD_MARGIN_WIDTH 10

@implementation ViFoldMarginView

- (ViFoldMarginView *)initWithTextView:(ViTextView *)aTextView
{
	if (self = [super init]) {
		[self setTextView:aTextView];

		self.autoresizingMask = NSViewMinXMargin;
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setTextView:(ViTextView *)aTextView
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	if (_textView != aTextView) {
		[notificationCenter removeObserver:self
									  name:ViTextStorageChangedLinesNotification
									object:_textView.textStorage];
	}

	if (aTextView != nil) {
		[notificationCenter addObserver:self
							   selector:@selector(textStorageDidChangeLines:)
								   name:ViTextStorageChangedLinesNotification
								 object:_textView.textStorage];
	}

	_textView = aTextView;
}

- (void)textStorageDidChangeLines:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];

	NSUInteger linesRemoved = [[userInfo objectForKey:@"linesRemoved"] unsignedIntegerValue];
	NSUInteger linesAdded = [[userInfo objectForKey:@"linesAdded"] unsignedIntegerValue];

	NSInteger diff = linesAdded - linesRemoved;
	if (diff == 0)
		return;

	[self updateViewFrame];

	[self setNeedsDisplay:YES];
}

// We override this because due to how we do drawing here, simply
// saying the line numbers need display isn't enough; we need to
// tell the ruler view it needs display as well.
- (void)setNeedsDisplay:(BOOL)needsDisplay
{
	[super setNeedsDisplay:needsDisplay];

	[[self superview] setNeedsDisplay:needsDisplay];
}

- (void)updateViewFrame
{
	[self setFrameSize:NSMakeSize(FOLD_MARGIN_WIDTH, _textView.bounds.size.height)];
}

- (void)drawFoldsInRect:(NSRect)aRect visibleRect:(NSRect)visibleRect
{
	NSLayoutManager         *layoutManager;
	NSTextContainer         *container;
	ViTextStorage			*textStorage;
	ViDocument				*document;
	NSRange                 range, glyphRange;
	CGFloat                 ypos, yinset;

	layoutManager = _textView.layoutManager;
	container = _textView.textContainer;
	textStorage = _textView.textStorage;
	document = _textView.document;
	yinset = _textView.textContainerInset.height;

	if (layoutManager == nil)
		return;

	// Find the characters that are currently visible
	glyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect
										  inTextContainer:container];
	range = [layoutManager characterRangeForGlyphRange:glyphRange
									  actualGlyphRange:NULL];

	NSUInteger line = [textStorage lineNumberAtLocation:range.location];
	NSUInteger location = range.location;

	for (; location < NSMaxRange(range); line++) {
		NSUInteger glyphIndex = [layoutManager glyphIndexForCharacterAtIndex:location];
		NSRect rect = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];

		ViFold *fold = [document foldAtLocation:location];
		if (fold) {
			// Note that the ruler view is only as tall as the visible
			// portion. Need to compensate for the clipview's coordinates.
			ypos = yinset + NSMinY(rect) - NSMinY(visibleRect);

			// Draw digits flush right, centered vertically within the line
			NSRect r;
			r.origin.x = NSMaxX(self.superview.bounds) - FOLD_MARGIN_WIDTH;
			r.origin.y = ypos;
			r.size = NSMakeSize(FOLD_MARGIN_WIDTH, rect.size.height);

			CGFloat alpha = 0.1 * (fold.depth + 1);
			NSColor *foldColor = [NSColor colorWithCalibratedWhite:0.42 alpha:alpha];
			[foldColor set];
			NSRectFillUsingOperation(r, NSCompositeSourceOver);
		}

		/* Protect against an improbable (but possible due to
		 * preceeding exceptions in undo manager) out-of-bounds
		 * reference here.
		 */
		if (location >= [textStorage length]) {
			break;
		}
		[[textStorage string] getLineStart:NULL
					       end:&location
				       contentsEnd:NULL
					  forRange:NSMakeRange(location, 0)];
	}
}

@end
