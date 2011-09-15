#import "ViProject.h"
#import "logging.h"
#import "ViFileExplorer.h"
#import "ViDocumentController.h"
#import "ViDocument.h"

@implementation ViProject

@synthesize initialURL;
@synthesize windowController;

- (NSString *)title
{
	return [[initialURL path] lastPathComponent];
}

- (void)makeWindowControllers
{
	windowController = [[ViWindowController alloc] init];
	[self addWindowController:windowController];
	[windowController setProject:self];
	[windowController browseURL:initialURL];
	ViDocument *doc = [[ViDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:nil];
	[doc setIsTemporary:YES];
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	initialURL = url;
	return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	if (outError)
		*outError = [NSError errorWithDomain:@"NSURLErrorDomain" code:NSURLErrorUnsupportedURL userInfo:nil];
	return nil;
}

@end

