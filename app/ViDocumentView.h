#import "ViTextView.h"
#import "ViDocument.h"
#import "ViViewController.h"

/** A ViViewController that manages a split view for a ViDocument.
 * @see ViDocumentView.
 */
@interface ViDocumentView : ViViewController
{
	IBOutlet NSView		*_innerView;
	IBOutlet NSScrollView	*_scrollView;
}

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument;
- (ViTextView *)textView;
- (void)replaceTextView:(ViTextView *)newTextView;

- (ViDocument *)document;
- (void)setDocument:(ViDocument *)document;

@end
