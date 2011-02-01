#import "ViProject.h"
#import "logging.h"
#import "ProjectDelegate.h"

@implementation ViProject

@synthesize initialURL;

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
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	initialURL = absoluteURL;
	return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	if (outError)
		*outError = [NSError errorWithDomain:@"NSURLErrorDomain" code:NSURLErrorUnsupportedURL userInfo:nil];
	return nil;
}

@end

