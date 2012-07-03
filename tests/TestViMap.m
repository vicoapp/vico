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

#import "TestViMap.h"
#import "ViMap.h"
#import "NSString-additions.h"

@implementation TestViMap

- (void)setUp
{
//	[ViMap clearAll];
}

- (void)test001_getStandardMaps
{
	STAssertNotNil([ViMap normalMap], nil);
	STAssertNotNil([ViMap insertMap], nil);
	STAssertNotNil([ViMap visualMap], nil);
	STAssertNotNil([ViMap operatorMap], nil);
	STAssertNotNil([ViMap explorerMap], nil);
}

- (void)test002_createPrivateMaps
{
	ViMap *map = [ViMap mapWithName:@"baconMap"];
	STAssertNotNil(map, nil);
	STAssertEqualObjects([map name], @"baconMap", nil);
}

- (void)test010_simpleAction
{
	ViMap *map = [ViMap normalMap];
//	[map setKey:@"i" toEditAction:@selector(insert:)];
	NSArray *keys = [@"i" keyCodes];
	STAssertEquals([keys count], 1ULL, nil);
	STAssertEquals([[keys objectAtIndex:0] integerValue], 0x69LL, nil);
	ViMapping *m = [map lookupKeySequence:keys withScope:nil allowMacros:YES excessKeys:nil timeout:nil error:nil];
	STAssertNotNil(m, nil);
	STAssertEquals(m.isAction, YES, nil);
	STAssertEquals(m.isMacro, NO, nil);
	STAssertEquals(m.isMotion, NO, nil);
	STAssertEquals(m.isOperator, NO, nil); STAssertEquals(m.flags, ViMapSetsDot, nil);
	STAssertEqualObjects(m.keyString, @"i", nil);
	STAssertEquals(m.action, @selector(insert:), nil);
}

- (void)test011_simpleMotion
{
	ViMap *map = [ViMap normalMap];
//	[map setKey:@"w" toMotion:@selector(word_forward:)];
	NSArray *keys = [@"w" keyCodes];
	ViMapping *m = [map lookupKeySequence:keys withScope:nil allowMacros:YES excessKeys:nil timeout:nil error:nil];
	STAssertNotNil(m, nil);
	STAssertEquals(m.isMotion, YES, nil);
	STAssertEquals(m.isOperator, NO, nil);
	STAssertEquals(m.flags, ViMapIsMotion, nil);
}

- (void)test012_simpleOperator
{
	ViMap *map = [ViMap normalMap];
//	[map setKey:@"w" toMotion:@selector(word_forward:)];
//	[map setKey:@"c" toOperator:@selector(change:)];
	NSArray *keys = [@"d" keyCodes];
	ViMapping *m = [map lookupKeySequence:keys withScope:nil allowMacros:YES excessKeys:nil timeout:nil error:nil];
	STAssertNotNil(m, nil);
	STAssertEquals(m.isMotion, NO, nil);
	STAssertEquals(m.isOperator, YES, nil);
	STAssertEquals(m.flags, ViMapNeedMotion | ViMapSetsDot, nil);
}

- (void)test013_simpleArgument
{
	ViMap *map = [ViMap normalMap];
//	[map setKey:@"f" toMotion:@selector(move_to_char:) flags:ViMapNeedArgument parameter:nil scope:nil];
	NSArray *keys = [@"f" keyCodes];
	ViMapping *m = [map lookupKeySequence:keys withScope:nil allowMacros:YES excessKeys:nil timeout:nil error:nil];
	STAssertNotNil(m, nil);
	STAssertEquals(m.isMotion, YES, nil);
	STAssertEquals(m.isOperator, NO, nil);
	STAssertEquals(m.isLineMode, NO, nil);
	STAssertEquals(m.flags, ViMapIsMotion|ViMapNeedArgument, nil);
}

@end

