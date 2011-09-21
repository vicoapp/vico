#import "ExCommand.h"
#import "NSString-additions.h"
#include "logging.h"

@implementation ExCommand

@synthesize mapping = _mapping;
@synthesize nextCommand = _nextCommand;
@synthesize naddr = _naddr;
@synthesize count = _count;
@synthesize force = _force;
@synthesize append = _append;
@synthesize filter = _filter;
@synthesize arg = _arg;
@synthesize plus_command = _plus_command;
@synthesize pattern = _pattern;
@synthesize replacement = _replacement;
@synthesize options = _options;
@synthesize reg = _reg;
@synthesize addr1 = _addr1;
@synthesize addr2 = _addr2;
@synthesize lineAddress = _lineAddress;
@synthesize caret = _caret;
@synthesize messages = _messages;
@synthesize lineRange = _lineRange;
@synthesize range = _range;
@synthesize line = _line;

+ (ExCommand *)commandWithMapping:(ExMapping *)aMapping
{
	return [[[ExCommand alloc] initWithMapping:aMapping] autorelease];
}

- (ExCommand *)initWithMapping:(ExMapping *)aMapping
{
	if ((self = [super init]) != nil) {
		_mapping = [aMapping retain];
	}
	return self;
}

- (void)dealloc
{
	[_cmdline release];
	[_mapping release];
	[_nextCommand release];
	[_addr1 release];
	[_addr2 release];
	[_lineAddress release];
	[_arg release];
	[_plus_command release];
	[_pattern release];
	[_replacement release];
	[_options release];
	[_messages release];
	[super dealloc];
}

- (NSArray *)args
{
	// XXX: doesn't handle escaped spaces
	return [self.arg componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (void)message:(NSString *)message
{
	DEBUG(@"got message %@", message);
	if (message == nil)
		return;
	if (_messages == nil)
		_messages = [[NSMutableArray alloc] init];
	[_messages addObject:message];
}

- (NSString *)rangeDescription
{
	if ([_mapping.syntax occurrencesOfCharacter:'r'] == 0)
		return @"";
	if (_naddr == 0)
		return [NSString stringWithFormat:@"default range %@ - %@", _addr1, _addr2];
	if (_naddr == 1)
		return [NSString stringWithFormat:@"%@ (%@)", _addr1, _addr2];
	return [NSString stringWithFormat:@"range %@ - %@", _addr1, _addr2];
}

- (NSString *)description
{
	if (_pattern)
		return [NSString stringWithFormat:@"<ExCommand %@%s /%@/%@/%@ %@ count %li>",
		       _mapping.name, _force ? "!" : "", _pattern, _replacement ?: @"", _options, [self rangeDescription], _count];
	else
		return [NSString stringWithFormat:@"<ExCommand %@%s %@ %@ %@ count %li>",
		       _mapping.name, _force ? "!" : "", _plus_command, _arg, [self rangeDescription], _count];
}

@end

