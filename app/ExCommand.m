#import "ExCommand.h"
#import "NSString-additions.h"
#include "logging.h"

@implementation ExCommand

@synthesize mapping;
@synthesize nextCommand;
@synthesize naddr;
@synthesize count;
@synthesize force;
@synthesize append;
@synthesize filter;
@synthesize arg;
@synthesize plus_command;
@synthesize pattern, replacement, options;
@synthesize reg;
@synthesize addr1, addr2, lineAddress;
@synthesize caret;
@synthesize messages;
@synthesize lineRange, range, line;

- (ExCommand *)initWithMapping:(ExMapping *)aMapping
{
	if ((self = [super init]) != nil) {
		mapping = aMapping;
	}
	return self;
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
	if (messages == nil)
		messages = [NSMutableArray array];
	[messages addObject:message];
}

- (NSString *)rangeDescription
{
	if ([mapping.syntax occurrencesOfCharacter:'r'] == 0)
		return @"";
	if (naddr == 0)
		return [NSString stringWithFormat:@"default range %@ - %@", addr1, addr2];
	if (naddr == 1)
		return [NSString stringWithFormat:@"%@ (%@)", addr1, addr2];
	return [NSString stringWithFormat:@"range %@ - %@", addr1, addr2];
}

- (NSString *)description
{
	if (pattern)
		return [NSString stringWithFormat:@"<ExCommand %@%s /%@/%@/%@ %@ count %li>",
		       mapping.name, force ? "!" : "", pattern, replacement ?: @"", options, [self rangeDescription], count];
	else
		return [NSString stringWithFormat:@"<ExCommand %@%s %@ %@ %@ count %li>",
		       mapping.name, force ? "!" : "", plus_command, arg, [self rangeDescription], count];
}

@end

