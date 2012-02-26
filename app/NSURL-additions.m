#import "NSURL-additions.h"
#import "ViURLManager.h"
#include "logging.h"

@implementation NSURL (equality)

static NSCharacterSet *__slashSet = nil;

- (BOOL)isEqualToURL:(NSURL *)otherURL
{
	if (__slashSet == nil)
		__slashSet = [[NSCharacterSet characterSetWithCharactersInString:@"/"] retain];

	NSString *s1 = [[self absoluteString] stringByTrimmingCharactersInSet:__slashSet];
	NSString *s2 = [[otherURL absoluteString] stringByTrimmingCharactersInSet:__slashSet];
	return [s1 isEqualToString:s2];
}

- (BOOL)hasPrefix:(NSURL *)prefixURL
{
	if (__slashSet == nil)
		__slashSet = [[NSCharacterSet characterSetWithCharactersInString:@"/"] retain];

	NSString *s1 = [[self absoluteString] stringByTrimmingCharactersInSet:__slashSet];
	NSString *s2 = [[prefixURL absoluteString] stringByTrimmingCharactersInSet:__slashSet];
	return [s1 hasPrefix:s2];
}

- (NSURL *)URLWithRelativeString:(NSString *)string
{
	return [[NSURL URLWithString:[string stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
		       relativeToURL:self] absoluteURL];
}

- (NSString *)displayString
{
	return [[ViURLManager defaultManager] stringByAbbreviatingWithTildeInPath:self];
}

/*
 * Copied from a post by Sean McBride.
 * http://www.cocoabuilder.com/archive/cocoa/301899-dealing-with-alias-files-finding-url-to-target-file.html
 */
- (NSURL *)URLByResolvingSymlinksAndAliases:(BOOL *)isAliasPtr
{
	NSURL *url = self;

	if ([self isFileURL]) {
		url = [self URLByResolvingSymlinksInPath];

		NSNumber *isAliasFile = nil;
		BOOL success = [url getResourceValue:&isAliasFile
					       forKey:NSURLIsAliasFileKey
						error:NULL];
		if (success && [isAliasFile boolValue]) {
			NSData *bookmarkData = [NSURL bookmarkDataWithContentsOfURL:url error:NULL];
			if (bookmarkData) {
				NSURL *resolvedURL = [NSURL URLByResolvingBookmarkData:bookmarkData
									       options:(NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting)
									 relativeToURL:nil
								   bookmarkDataIsStale:NULL
										 error:NULL];
				if (isAliasPtr) {
					*isAliasPtr = YES;
				}

				/* Don't return file reference URLs, make it a plain file URL. */
				return [[[NSURL fileURLWithPath:[resolvedURL path]] URLByStandardizingPath] absoluteURL];
			}
		}
	}
	if (isAliasPtr) {
		*isAliasPtr = NO;
	}
	return url;
}

@end

