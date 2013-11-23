@class ViTextView;

/**
 * A view that presents line numbers in a ViRulerView.
 */
@interface ViLineNumberView : NSView
{
	NSDictionary	*_textAttributes;
	NSPoint			 _fromPoint;
	NSImage			*_digits[10];
	NSSize			 _digitSize;

    NSImage         *_closedFoldIndicator;
    NSImage         *_openFoldStartIndicator;
    NSImage         *_openFoldBodyIndicator;

	BOOL			_relative;

	ViTextView 		*_textView;
}

@property (nonatomic,readwrite) NSColor *backgroundColor;

- (ViLineNumberView *)initWithTextView:(ViTextView *)aTextView backgroundColor:(NSColor *)aColor;

- (void)setRelative:(BOOL)flag;
- (void)setTextView:(ViTextView *)aTextView;

- (void)updateViewFrame;
- (CGFloat)requiredThickness;

- (void)resetTextAttributes;

- (void)drawLineNumbersInRect:(NSRect)aRect visibleRect:(NSRect)visibleRect;

@end
