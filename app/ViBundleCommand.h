#import "ViBundleItem.h"

@interface ViBundleCommand : ViBundleItem
{
	NSString	*_input;
	NSString	*_output;
	NSString	*_fallbackInput;
	NSString	*_beforeRunningCommand;
	NSString	*_command;
	NSString	*_htmlMode;
}

@property(nonatomic,readonly) NSString *input;
@property(nonatomic,readonly) NSString *output;
@property(nonatomic,readonly) NSString *fallbackInput;
@property(nonatomic,readonly) NSString *beforeRunningCommand;
@property(nonatomic,readonly) NSString *command;
@property(nonatomic,readonly) NSString *htmlMode;

- (ViBundleCommand *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle;

@end
