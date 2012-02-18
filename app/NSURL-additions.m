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
	NSData *bookmarkData = [NSURL bookmarkDataWithContentsOfURL:self error:NULL];
	if (bookmarkData) {
		NSURL *resolvedURL = [NSURL URLByResolvingBookmarkData:bookmarkData
							       options:(NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting)
							 relativeToURL:nil
						   bookmarkDataIsStale:NULL
								 error:NULL];
		if (isAliasPtr) {
			*isAliasPtr = YES;
		}
		return resolvedURL;
	} else if (isAliasPtr) {
		*isAliasPtr = NO;
	}
	return [self URLByResolvingSymlinksInPath];
}

@end

