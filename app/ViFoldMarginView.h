@class ViTextView;

/**
 * A view that presents fold margin indicators in a ViRulerView.
 *
 * A given fold indicator can be clicked to close or open that fold.
 */
@interface ViFoldMarginView : NSView
{
	ViTextView 		*_textView;
}

- (ViFoldMarginView *)initWithTextView:(ViTextView *)aTextView;

- (void)setTextView:(ViTextView *)aTextView;

- (void)updateViewFrame;

- (void)drawFoldsInRect:(NSRect)aRect visibleRect:(NSRect)visibleRect;

@end
