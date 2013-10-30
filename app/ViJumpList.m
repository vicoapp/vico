/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
	DEBUG_INIT();
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
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
	DEBUG(@"jumps = %@, position = %li", _jumps, (unsigned long)_position);

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
	DEBUG(@"position = %li, count = %li", (unsigned long)_position, (unsigned long)[_jumps count]);
	if (_position <= 0)
		return nil;

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

