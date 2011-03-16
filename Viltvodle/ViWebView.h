#import <WebKit/WebKit.h>

#import "ExEnvironment.h"
#import "ViCommand.h"

@interface ViWebView : WebView
{
	ExEnvironment *environment;
	ViCommand *parser;
}

@property(readwrite, assign) ExEnvironment *environment;
@property(readwrite, assign) ViCommand *parser;

@end

