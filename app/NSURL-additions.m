#import "NSURL-additions.h"
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
	if ([self isFileURL])
		return [[self path] stringByAbbreviatingWithTildeInPath];
	return [self absoluteString];
}

/*
 * Copied from a post by Sean McBride.
 * http://www.cocoabuilder.com/archive/cocoa/301899-dealing-with-alias-files-finding-url-to-target-file.html
 */
- (NSURL *)URLByResolvingSymlinksAndAliases:(BOOL *)isAliasPtr
{
	NSURL *resultURL = [self URLByResolvingSymlinksInPath];

	NSError *error = nil;
	NSNumber *isAliasFile = nil;
	BOOL success = [resultURL getResourceValue:&isAliasFile
					    forKey:NSURLIsAliasFileKey
					     error:&error];
	if (success && [isAliasFile boolValue]) {
		if (isAliasPtr)
			*isAliasPtr = YES;
		NSData *bookmarkData = [NSURL bookmarkDataWithContentsOfURL:resultURL
								      error:&error];
		if (bookmarkData) {
			BOOL isStale = NO;
			NSURLBookmarkResolutionOptions options =
			    (NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting);

			NSURL *resolvedURL = [NSURL URLByResolvingBookmarkData:bookmarkData
								       options:options
								 relativeToURL:nil
							   bookmarkDataIsStale:&isStale
									 error:&error];
			if (resolvedURL) {
				resultURL = resolvedURL;
				DEBUG(@"resolved %@ -> %@", self, resultURL);
			}
		}
	} else if (isAliasPtr)
		*isAliasPtr = NO;

	return resultURL;
}

@end

