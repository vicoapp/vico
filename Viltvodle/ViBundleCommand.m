#import "ViBundleCommand.h"

@implementation ViBundleCommand

@synthesize input;
@synthesize output;
@synthesize fallbackInput;
@synthesize beforeRunningCommand;
@synthesize command;

- (ViBundleCommand *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle
{
	self = (ViBundleCommand *)[super initFromDictionary:dict inBundle:aBundle];
	if (self) {
		input = [dict objectForKey:@"input"];
		output = [dict objectForKey:@"output"];
		fallbackInput = [dict objectForKey:@"fallbackInput"];
		beforeRunningCommand = [dict objectForKey:@"beforeRunningCommand"];
		command = [dict objectForKey:@"command"];
	}
	return self;
}

@end

