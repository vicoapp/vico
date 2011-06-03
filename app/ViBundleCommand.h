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

@property(readonly) NSString *input;
@property(readonly) NSString *output;
@property(readonly) NSString *fallbackInput;
@property(readonly) NSString *beforeRunningCommand;
@property(readonly) NSString *command;
@property(readonly) NSString *htmlMode;

- (ViBundleCommand *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle;

@end
