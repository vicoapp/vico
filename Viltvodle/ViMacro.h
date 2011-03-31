#import "ViMap.h"

@interface ViMacro : NSObject
{
	NSArray		*keys;
	NSUInteger	 ip;
	ViMapping	*mapping;
}

@property (readonly) ViMapping *mapping;

+ (id)macroWithMapping:(ViMapping *)aMapping prefix:(NSArray *)prefixKeys;
- (id)initWithMapping:(ViMapping *)aMapping prefix:(NSArray *)prefixKeys;

- (NSInteger)pop;

@end
