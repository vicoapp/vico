#import "ViBundleItem.h"

@interface ViBundleCommand : ViBundleItem
{
	NSString	*input;
	NSString	*output;
	NSString	*fallbackInput;
	NSString	*beforeRunningCommand;
	NSString	*command;
}

@property(readonly) NSString *input;
@property(readonly) NSString *output;
@property(readonly) NSString *fallbackInput;
@property(readonly) NSString *beforeRunningCommand;
@property(readonly) NSString *command;

- (ViBundleCommand *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle;

@end
