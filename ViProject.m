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
	NSString *localDirectory = nil;
	BOOL isDirectory;
	if ([absoluteURL isFileURL] &&
	    [[NSFileManager defaultManager] fileExistsAtPath:[absoluteURL path]
						 isDirectory:&isDirectory] && isDirectory)
		localDirectory = [absoluteURL path];
	else {
		*outError = [NSError errorWithDomain:@"NSURLErrorDomain" code:NSURLErrorUnsupportedURL userInfo:nil];
		return NO;
	}

	initialURL = absoluteURL;
	return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	*outError = [NSError errorWithDomain:@"NSURLErrorDomain" code:NSURLErrorUnsupportedURL userInfo:nil];
	return nil;
}

- (void)close
{
	[super close];
}

@end

