#import "ViTextView.h"
#import "ViDocument.h"
#import "ViDocumentTabController.h"

// XXX: actually a view _controller_
@interface ViDocumentView : NSObject <ViViewController>
{
	IBOutlet NSView *view;
	IBOutlet NSView *innerView;
	IBOutlet NSScrollView *scrollView;
	ViDocument *document;
	ViDocumentTabController *tabController;
}

@property(nonatomic,readonly) id<ViViewDocument> document;
@property(nonatomic,readonly) NSView *view;
@property(nonatomic,readonly) NSView *innerView;
@property(nonatomic,readwrite, assign) ViDocumentTabController *tabController;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument;
- (ViTextView *)textView;
- (void)replaceTextView:(ViTextView *)newTextView;
- (NSString *)title;

@end
