#import <WebKit/WebKit.h>

#import "ViKeyManager.h"

@interface ViWebView : WebView <ViKeyManagerTarget>
{
	ViKeyManager *_keyManager;
}

@property (nonatomic,readwrite,retain) ViKeyManager *keyManager;

@end

