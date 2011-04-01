#import "ViBundleSnippet.h"

@implementation ViBundleSnippet

@synthesize content;

- (ViBundleSnippet *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle
{
	self = (ViBundleSnippet *)[super initFromDictionary:dict inBundle:aBundle];
	if (self) {
		content = [dict objectForKey:@"content"];
	}
	return self;
}

@end

