#import "ViCommandOutputController.h"
#import "ViParser.h"
#import "logging.h"

@implementation ViCommandOutputController

- (ViCommandOutputController *)initWithHTMLString:(NSString *)content
{
	if ((self = [super initWithNibName:@"CommandOutputWindow" bundle:nil]) != nil) {
		[self loadView];
		[self setContent:content];
		[self setTitle:@"command output"];
	}
	return self;
}

- (void)setContent:(NSString *)content
{
	NSURL *baseURL = [NSURL fileURLWithPath:@"/" isDirectory:YES];
	[[(ViWebView *)[self view] mainFrame] loadHTMLString:content
						     baseURL:baseURL];
}

@end
