#import "ViDocumentTabController.h"
#import "ViTextView.h"
#import "ViWebView.h"

@interface ViCommandOutputController : NSObject <ViViewController>
{
	IBOutlet ViWebView *webView;
	ViDocumentTabController *tabController;
}

@property(readwrite, assign) ViDocumentTabController *tabController;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content
                                      environment:(ExEnvironment *)environment;
- (NSView *)view;
- (NSView *)innerView;

- (void)setContent:(NSString *)content;

@end
