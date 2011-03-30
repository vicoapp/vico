#import <WebKit/WebKit.h>

#import "ExEnvironment.h"
#import "ViKeyManager.h"

@interface ViWebView : WebView
{
	ExEnvironment *environment;
	ViKeyManager *keyManager;
}

@property(readwrite, assign) ExEnvironment *environment;

@end

