#import <WebKit/WebKit.h>

#import "ExEnvironment.h"
#import "ViParser.h"

@interface ViWebView : WebView
{
	ExEnvironment *environment;
	ViParser *parser;
}

@property(readwrite, assign) ExEnvironment *environment;
@property(readwrite, assign) ViParser *parser;

@end

