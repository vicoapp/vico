#import "ViProject.h"
#import "logging.h"
#import "ProjectDelegate.h"
#import "SFTPConnectionPool.h"
#import "ViDocumentController.h"

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
	if ([[url scheme] isEqualToString:@"sftp"] && ([url path] == nil || [[url path] isEqualToString:@""])) {
		SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:outError];
		initialURL = [NSURL URLWithString:[conn home] relativeToURL:url];
	} else
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

