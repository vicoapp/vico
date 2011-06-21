#import "ViCommandOutputController.h"
#import "ViParser.h"
#import "logging.h"

@implementation ViCommandOutputController

@synthesize tabController;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content
{
	self = [super init];
	if (self) {
		[NSBundle loadNibNamed:@"CommandOutputWindow" owner:self];
		[self setContent:content];
		[self setTitle:@"command output"];
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

- (void)setTitle:(NSString *)aTitle
{
	title = aTitle;
}

- (NSString *)title
{
	return title;
}

- (void)setContent:(NSString *)content
{
	NSURL *baseURL = [NSURL fileURLWithPath:@"/" isDirectory:YES];
	[[webView mainFrame] loadHTMLString:content
				    baseURL:baseURL];
}

@end
