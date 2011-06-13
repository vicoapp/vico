#import <WebKit/WebKit.h>

#import "ViKeyManager.h"

@interface ViWebView : WebView
{
	ViKeyManager *keyManager;
}

@end

