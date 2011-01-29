#import "ViCommandOutputController.h"
#import "logging.h"

@implementation ViCommandOutputController

@synthesize webView;

- (ViCommandOutputController *)initWithHTMLString:(NSString *)aString
{
	self = [super initWithWindowNibName:@"CommandOutputWindow"];
	if (self)
	{
		content = aString;
		DEBUG(@"content = [%@]", content);
	}
	return self;
}

- (void)windowDidLoad
{
	DEBUG(@"content = [%@]", content);
	[[webView mainFrame] loadHTMLString:content baseURL:[NSURL fileURLWithPath:@"/" isDirectory:YES]];
}

@end
