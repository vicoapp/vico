#import "ViMacro.h"
#import "NSString-additions.h"
#include "logging.h"

@implementation ViMacro

@synthesize mapping = _mapping;

+ (id)macroWithMapping:(ViMapping *)aMapping prefix:(NSArray *)prefixKeys
{
	return [[[ViMacro alloc] initWithMapping:aMapping prefix:prefixKeys] autorelease];
}

- (id)initWithMapping:(ViMapping *)aMapping prefix:(NSArray *)prefixKeys
{
	if ((self = [super init])) {
		_mapping = [aMapping retain];
		_ip = 0;
		_keys = [[aMapping.macro keyCodes] mutableCopy];
		if ([prefixKeys count] > 0)
			[_keys replaceObjectsInRange:NSMakeRange(0, 0) withObjectsFromArray:prefixKeys];
	}

	DEBUG_INIT();
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_mapping release];
	[_keys release];
	[super dealloc];
}

- (void)push:(NSNumber *)keyCode
{
	[_keys insertObject:keyCode atIndex:_ip];
}

- (NSInteger)pop
{
	if (_ip >= [_keys count])
		return -1LL;
	return [[_keys objectAtIndex:_ip++] integerValue];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViMacro %p: %@>",
	    self, [NSString stringWithKeySequence:_keys]];
}

@end
