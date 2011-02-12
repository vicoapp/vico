#import "ViBundleSnippet.h"

@implementation ViBundleSnippet

@synthesize content;
@synthesize tabTrigger;

- (ViBundleSnippet *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle
{
	self = (ViBundleSnippet *)[super initFromDictionary:dict inBundle:aBundle];
	if (self) {
		content = [dict objectForKey:@"content"];
		tabTrigger = [dict objectForKey:@"tabTrigger"];
	}
	return self;
}

@end

