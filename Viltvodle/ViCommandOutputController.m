#import "ViCommandOutputController.h"
#import "logging.h"

@implementation ViCommandOutputController

@synthesize tabController;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content environment:(ExEnvironment *)environment parser:(ViCommand *)parser
{
	self = [super init];
	if (self)
	{
		[NSBundle loadNibNamed:@"CommandOutputWindow" owner:self];
		[webView setEnvironment:environment];
		[webView setParser:parser];
		[[webView mainFrame] loadHTMLString:content baseURL:[NSURL fileURLWithPath:@"/" isDirectory:YES]];
	}
	return self;
}

- (NSView *)view
{
	return webView;
}

- (NSView *)innerView
{
	return webView;
}

- (NSString *)title
{
	return @"command output";
}

@end
