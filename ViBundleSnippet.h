#import "ViBundleItem.h"

@interface ViBundleSnippet : ViBundleItem
{
	NSString	*content;
	NSString	*tabTrigger;
}

@property(readonly) NSString *content;
@property(readonly) NSString *tabTrigger;

- (ViBundleSnippet *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle;

@end
