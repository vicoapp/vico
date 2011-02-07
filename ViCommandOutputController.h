#import "ViDocumentTabController.h"
#import "ViTextView.h"
#import "ViWebView.h"

@interface ViCommandOutputController : NSObject <ViViewController>
{
	IBOutlet ViWebView *webView;
	ViDocumentTabController *tabController;
}

@property(readwrite, assign) ViDocumentTabController *tabController;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content environment:(ExEnvironment *)environment parser:(ViCommand *)parser;
- (NSView *)view;
- (NSView *)innerView;

@end
