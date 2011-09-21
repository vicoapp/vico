#import "ViBundleSnippet.h"
#include "logging.h"

@implementation ViBundleSnippet

@synthesize content = _content;

- (ViBundleSnippet *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle
{
	if ((self = (ViBundleSnippet *)[super initFromDictionary:dict inBundle:aBundle]) != nil) {
		_content = [[dict objectForKey:@"content"] retain];
		if (_content == nil) {
			INFO(@"missing snippet content in bundle item %@", self.name);
			[self release];
			return nil;
		}
	}
	return self;
}

- (void)dealloc
{
	[_content release];
	[super dealloc];
}

@end

