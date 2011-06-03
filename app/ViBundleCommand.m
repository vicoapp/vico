#import "ViBundleCommand.h"

@implementation ViBundleCommand

@synthesize input;
@synthesize output;
@synthesize fallbackInput;
@synthesize beforeRunningCommand;
@synthesize command;
@synthesize htmlMode;

- (ViBundleCommand *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle
{
	self = (ViBundleCommand *)[super initFromDictionary:dict inBundle:aBundle];
	if (self) {
		input = [dict objectForKey:@"input"];
		output = [dict objectForKey:@"output"];
		fallbackInput = [dict objectForKey:@"fallbackInput"];
		beforeRunningCommand = [dict objectForKey:@"beforeRunningCommand"];
		command = [dict objectForKey:@"command"];
		htmlMode = [dict objectForKey:@"htmlMode"];
	}
	return self;
}

@end

