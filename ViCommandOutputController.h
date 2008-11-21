#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface ViCommandOutputController : NSWindowController
{
	NSString *content;
	IBOutlet WebView *webView;
}

@property(readonly) WebView *webView;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)aString;

@end
