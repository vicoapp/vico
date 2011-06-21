#import "ViDocumentTabController.h"
#import "ViTextView.h"
#import "ViWebView.h"

@interface ViCommandOutputController : NSObject <ViViewController>
{
	IBOutlet ViWebView *webView;
	ViDocumentTabController *tabController;
	NSString *title;
}

@property(nonatomic,readwrite, assign) ViDocumentTabController *tabController;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content;
- (NSView *)view;
- (NSView *)innerView;
- (void)setTitle:(NSString *)aTitle;

- (void)setContent:(NSString *)content;

@end
