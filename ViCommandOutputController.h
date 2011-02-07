#import "ViDocumentTabController.h"
#import "ViTextView.h"
#import "ViWebView.h"

@interface ViCommandOutputController : NSObject <ViViewController>
{
	IBOutlet ViWebView *webView;
	ViDocumentTabController *tabController;
}

@property(readwrite, assign) ViDocumentTabController *tabController;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content delegate:(id<ViTextViewDelegate>)delegate;
- (NSView *)view;
- (NSView *)innerView;

@end
