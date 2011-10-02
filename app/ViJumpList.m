#import "ViJumpList.h"
#import "ViCommon.h"
#import "ViMark.h"
#include "logging.h"

#define MAX_JUMP_LOCATIONS 100


@implementation ViJumpList

@synthesize delegate = _delegate;

- (ViJumpList *)init
{
	if ((self = [super init]) != nil)
		_jumps = [[NSMutableArray alloc] init];
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_jumps release];
	[super dealloc];
}

- (BOOL)push:(ViMark *)newJump
{
	if ([_jumps count] >= MAX_JUMP_LOCATIONS)
		[_jumps removeObjectAtIndex:0];

	newJump.title = @"jump";
	DEBUG(@"pushing %@", newJump);
	DEBUG(@"called from %@", [NSThread callStackSymbols]);

	BOOL removedDuplicate = NO;
	ViMark *jump = nil;
	if (newJump)
		for (jump in _jumps)
			if ([jump.url isEqual:newJump.url] && IMAX(1, jump.line) == IMAX(1, newJump.line))
				break;

	/* XXX: ugly hack. Jumps in untitled files that have closed have a nil url.
	 * Replace the initial jump in the first untitled file.
	 * Should probably be automatically removed (by [ViMark remove]) if using a ViMarkList instead of a ViJumpList.
	 */
	if (newJump && jump == nil)
		for (jump in _jumps)
			if (jump.url == nil && IMAX(1, jump.line) == IMAX(1, newJump.line))
				break;

	if (jump) {
		DEBUG(@"removing duplicate jump %@", jump);
		[_jumps removeObject:jump];
		removedDuplicate = YES;
	}

	if (newJump)
		[_jumps addObject:newJump];
	_position = [_jumps count];
	DEBUG(@"jumps = %@, position = %u", _jumps, _position);

	[_delegate jumpList:self added:newJump];

	return removedDuplicate;
}

- (ViMark *)forward
{
	DEBUG(@"position = %u, count = %u", _position, [_jumps count]);
	if (_position + 1 >= [_jumps count])
		return nil;
	return [_jumps objectAtIndex:++_position];
}

- (ViMark *)backwardFrom:(ViMark *)fromJump
{
	DEBUG(@"position = %li, count = %u", _position, [_jumps count]);
	if (_position <= 0)
		return NO;

	if (_position >= [_jumps count] && fromJump) {
		NSInteger savedPosition = _position;
		BOOL removedDuplicate = [self push:fromJump];
		_position = savedPosition;
		if (removedDuplicate)
			_position--;
	}

	return [_jumps objectAtIndex:--_position];
}

- (BOOL)atBeginning
{
	return (_position <= 0);
}

- (BOOL)atEnd
{
	return (_position + 1 >= [_jumps count]);
}

- (void)enumerateJumpsBackwardsUsingBlock:(void (^)(ViMark *jump, BOOL *stop))block
{
	NSInteger pos = _position - 1;
	DEBUG(@"navigating jumplist %@ backwards from %li", _jumps, pos);
	BOOL stop = NO;
	while (!stop && pos >= 0) {
		block([_jumps objectAtIndex:pos], &stop);
		--pos;
	}
}

@end

