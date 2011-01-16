#import "ViProject.h"
#import "logging.h"
#import "ProjectDelegate.h"

@implementation ViProject

@synthesize initialURL;

- (void)makeWindowControllers
{
	windowController = [[ViWindowController alloc] init];
	[self addWindowController:windowController];
	[windowController setProject:self];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	initialURL = absoluteURL;
	return YES;
#if 0
	BOOL isDirectory;
	if ([absoluteURL isFileURL] &&
	    [[NSFileManager defaultManager] fileExistsAtPath:[absoluteURL path] isDirectory:&isDirectory] && isDirectory) {
		initialURL = absoluteURL;
		return YES;
	}

	if (outError)
		*outError = [NSError errorWithDomain:@"NSURLErrorDomain" code:NSURLErrorUnsupportedURL userInfo:nil];
	return NO;
#endif
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	if (outError)
		*outError = [NSError errorWithDomain:@"NSURLErrorDomain" code:NSURLErrorUnsupportedURL userInfo:nil];
	return nil;
}

- (void)close
{
	[super close];
}

@end

