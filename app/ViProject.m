#import "ViProject.h"
#import "logging.h"
#import "ViFileExplorer.h"
#import "ViDocumentController.h"
#import "ViDocument.h"

@implementation ViProject

@synthesize initialURL = _initialURL;
@synthesize windowController = _windowController;

- (NSString *)title
{
	return [[_initialURL path] lastPathComponent];
}

- (void)makeWindowControllers
{
	_windowController = [[ViWindowController alloc] init];
	[self addWindowController:_windowController];
	[_windowController setProject:self];
	[_windowController browseURL:_initialURL];
	ViDocument *doc = [[ViDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:nil];
	[doc setIsTemporary:YES];
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_windowController release];
	[_initialURL release];
	[super dealloc];
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	_initialURL = [url retain];
	return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	if (outError)
		*outError = [NSError errorWithDomain:@"NSURLErrorDomain" code:NSURLErrorUnsupportedURL userInfo:nil];
	return nil;
}

@end

