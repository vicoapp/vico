#import "ViTextView.h"
#import "ViDocument.h"
#import "ViDocumentTabController.h"

// XXX: actually a view _controller_
@interface ViDocumentView : NSObject
{
	IBOutlet NSView *view;
	IBOutlet ViTextView *textView;
	ViDocument *document;
	ViDocumentTabController *tabController;
}

@property(readonly) ViDocument *document;
@property(readonly) NSView *view;
@property(readonly) ViTextView *textView;
@property(readwrite, assign) ViDocumentTabController *tabController;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument;
- (void)close;

@end
