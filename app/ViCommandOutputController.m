#import "ViCommandOutputController.h"
#import "ViParser.h"
#import "logging.h"

@implementation ViCommandOutputController

@synthesize tabController = _tabController;
@synthesize title = _title;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content
{
	if ((self = [super init]) != nil) {
		if (![NSBundle loadNibNamed:@"CommandOutputWindow" owner:self]) {
			[self release];
			return NO;
		}
		[self setContent:content];
		_title = [@"command output" retain];
	}
	return self;
}

- (void)dealloc
{
	[_title release];
	[webView release]; // Top-level nib object
	[super dealloc];
}

- (NSView *)view
{
	return webView;
}

- (NSView *)innerView
{
	return webView;
}

- (void)setContent:(NSString *)content
{
	NSURL *baseURL = [NSURL fileURLWithPath:@"/" isDirectory:YES];
	[[webView mainFrame] loadHTMLString:content
				    baseURL:baseURL];
}

@end
