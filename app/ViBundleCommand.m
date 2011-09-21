#import "ViBundleCommand.h"
#include "logging.h"

@implementation ViBundleCommand

@synthesize input = _input;
@synthesize output = _output;
@synthesize fallbackInput = _fallbackInput;
@synthesize beforeRunningCommand = _beforeRunningCommand;
@synthesize command = _command;
@synthesize htmlMode = _htmlMode;

- (ViBundleCommand *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle
{
	if ((self = (ViBundleCommand *)[super initFromDictionary:dict inBundle:aBundle]) != nil) {
		_input = [[dict objectForKey:@"input"] retain];
		_output = [[dict objectForKey:@"output"] retain];
		_fallbackInput = [[dict objectForKey:@"fallbackInput"] retain];
		_beforeRunningCommand = [[dict objectForKey:@"beforeRunningCommand"] retain];
		_command = [[dict objectForKey:@"command"] retain];
		if (_command == nil) {
			INFO(@"missing command in bundle item %@", self.name);
			[self release];
			return nil;
		}
		_htmlMode = [[dict objectForKey:@"htmlMode"] retain];
	}
	return self;
}

- (void)dealloc
{
	[_input release];
	[_output release];
	[_fallbackInput release];
	[_beforeRunningCommand release];
	[_command release];
	[_htmlMode release];
	[super dealloc];
}

@end

