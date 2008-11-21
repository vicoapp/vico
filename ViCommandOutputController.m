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
		INFO(@"content = [%@]", content);
	}
	return self;
}

- (void)windowDidLoad
{
	INFO(@"content = [%@]", content);
	[[webView mainFrame] loadHTMLString:content baseURL:[NSURL fileURLWithPath:@"/" isDirectory:YES]];
}

@end
