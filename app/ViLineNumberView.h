@class ViTextView;

/**
 * A view that presents line numbers in a ViRulerView.
 *
 * The line numbers can be clicked and dragged to select one or more lines
 * in the text view.
 *
@interface ViLineNumberView : NSView
{
	NSDictionary	*_textAttributes;
	NSPoint			 _fromPoint;
	NSImage			*_digits[10];
	NSSize			 _digitSize;

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

- (void)lineNumberMouseDown:(NSEvent *)theEvent;
- (void)lineNumberMouseDragged:(NSEvent *)theEvent;

@end
*/