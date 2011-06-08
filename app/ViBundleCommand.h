#import "ViBundleItem.h"

@interface ViBundleCommand : ViBundleItem
{
	NSString	*input;
	NSString	*output;
	NSString	*fallbackInput;
	NSString	*beforeRunningCommand;
	NSString	*command;
	NSString	*htmlMode;
}

@property(nonatomic,readonly) NSString *input;
@property(nonatomic,readonly) NSString *output;
@property(nonatomic,readonly) NSString *fallbackInput;
@property(nonatomic,readonly) NSString *beforeRunningCommand;
@property(nonatomic,readonly) NSString *command;
@property(nonatomic,readonly) NSString *htmlMode;

- (ViBundleCommand *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle;

@end
