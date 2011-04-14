#import "ViCommandOutputController.h"
#import "ViParser.h"
#import "logging.h"

@implementation ViCommandOutputController

@synthesize tabController;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content
                                      environment:(ExEnvironment *)environment
{
	self = [super init];
	if (self) {
		[NSBundle loadNibNamed:@"CommandOutputWindow" owner:self];
		[webView setEnvironment:environment];
		NSURL *baseURL = [NSURL fileURLWithPath:@"/" isDirectory:YES];
		[[webView mainFrame] loadHTMLString:content
					    baseURL:baseURL];
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

- (void)setContent:(NSString *)content
{
	NSURL *baseURL = [NSURL fileURLWithPath:@"/" isDirectory:YES];
	[[webView mainFrame] loadHTMLString:content
				    baseURL:baseURL];
}

@end
