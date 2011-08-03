#import <WebKit/WebKit.h>

#import "ViKeyManager.h"

@interface ViWebView : WebView <ViKeyManagerTarget>
{
	ViKeyManager *keyManager;
}

@end

