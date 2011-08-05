#import "ViTabController.h"
#import "ViTextView.h"
#import "ViWebView.h"

@interface ViCommandOutputController : NSObject <ViViewController>
{
	IBOutlet ViWebView *webView;
	ViTabController *tabController;
	NSString *title;
}

@property(nonatomic,readwrite, assign) ViTabController *tabController;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content;
- (NSView *)view;
- (NSView *)innerView;
- (void)setTitle:(NSString *)aTitle;

- (void)setContent:(NSString *)content;

@end
