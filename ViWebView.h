#import "ViTextView.h"
#import <WebKit/WebKit.h>

@interface ViWebView : WebView
{
}

@property(readwrite, assign) id<ViTextViewDelegate> delegate;

@end

