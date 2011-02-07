#import "ViTextView.h"
#import "ViDocument.h"
#import "ViDocumentTabController.h"

// XXX: actually a view _controller_
@interface ViDocumentView : NSObject <ViViewController>
{
	IBOutlet NSView *view;
	IBOutlet NSView *innerView;
	ViDocument *document;
	ViDocumentTabController *tabController;
}

@property(readonly) ViDocument *document;
@property(readonly) NSView *view;
@property(readonly) NSView *innerView;
@property(readwrite, assign) ViDocumentTabController *tabController;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument;
- (ViTextView *)textView;
- (NSString *)title;

@end
