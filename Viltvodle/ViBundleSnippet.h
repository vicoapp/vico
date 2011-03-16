#import "ViBundleItem.h"

@interface ViBundleSnippet : ViBundleItem
{
	NSString	*content;
}

@property(readonly) NSString *content;

- (ViBundleSnippet *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle;

@end
