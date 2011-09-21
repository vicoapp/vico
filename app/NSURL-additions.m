#import "NSURL-additions.h"

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

@end

