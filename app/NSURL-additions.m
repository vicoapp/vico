#import "NSURL-additions.h"

@implementation NSURL (equality)

static NSCharacterSet *slashSet = nil;

- (BOOL)isEqualToURL:(NSURL *)otherURL
{
	if (slashSet == nil)
		slashSet = [NSCharacterSet characterSetWithCharactersInString:@"/"];
	NSString *s1 = [[self absoluteString] stringByTrimmingCharactersInSet:slashSet];
	NSString *s2 = [[otherURL absoluteString] stringByTrimmingCharactersInSet:slashSet];
	return [s1 isEqualToString:s2];
}

- (BOOL)hasPrefix:(NSURL *)prefixURL
{
	if (slashSet == nil)
		slashSet = [NSCharacterSet characterSetWithCharactersInString:@"/"];
	NSString *s1 = [[self absoluteString] stringByTrimmingCharactersInSet:slashSet];
	NSString *s2 = [[prefixURL absoluteString] stringByTrimmingCharactersInSet:slashSet];
	return [s1 hasPrefix:s2];
}

@end

