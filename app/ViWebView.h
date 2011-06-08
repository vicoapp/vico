#import <WebKit/WebKit.h>

#import "ExEnvironment.h"
#import "ViKeyManager.h"

@interface ViWebView : WebView
{
	ExEnvironment *environment;
	ViKeyManager *keyManager;
}

@property(nonatomic,readwrite, assign) ExEnvironment *environment;

@end

