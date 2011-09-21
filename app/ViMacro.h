#import "ViMap.h"

@interface ViMacro : NSObject
{
	NSMutableArray	*_keys;
	NSUInteger	 _ip;
	ViMapping	*_mapping;
}

@property(nonatomic,readonly) ViMapping *mapping;

+ (id)macroWithMapping:(ViMapping *)aMapping prefix:(NSArray *)prefixKeys;
- (id)initWithMapping:(ViMapping *)aMapping prefix:(NSArray *)prefixKeys;

- (void)push:(NSNumber *)keyCode;
- (NSInteger)pop;

@end
