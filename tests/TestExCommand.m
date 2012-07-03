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

#import "TestExCommand.h"

@implementation TestExCommand

- (void)setUp
{
	ex = nil;
}

- (void)parse:(NSString *)string
{
	NSError *error = nil;
	ex = [[ExParser sharedParser] parse:string error:&error];
	STAssertNotNil(ex, nil);
	STAssertNil(error, nil);
}

- (void)test010_SetCommand
{
	[self parse:@"w"];
	STAssertEqualObjects(ex.mapping.name, @"write", nil);
	STAssertEquals(ex.mapping.action, @selector(ex_write:), nil);
}

- (void)test011_NonexistentSimpleCommand
{
	NSError *error = nil;
	ex = [[ExParser sharedParser] parse:@"foo bar baz" error:&error];
	STAssertNil(ex, nil);
	STAssertNotNil(error, nil);
}

- (void)test20_AbsoluteAddress
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"17"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressAbsolute, nil);
	STAssertEquals(addr.line, 17LL, nil);
	STAssertEquals(addr.offset, 0LL, nil);
}

- (void)test20_LastLineAddress
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"$"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressAbsolute, nil);
	STAssertEquals(addr.line, -1LL, nil);
	STAssertEquals(addr.offset, 0LL, nil);
}

- (void)test20_MarkAddress
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"'x"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressMark, nil);
	STAssertEquals(addr.mark, (unichar)'x', nil);
	STAssertEquals(addr.offset, 0LL, nil);
}

- (void)test20_Search
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"/pattern/"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressSearch, nil);
	STAssertEqualObjects(addr.pattern, @"pattern", nil);
	STAssertEquals(addr.backwards, NO, nil);
	STAssertEquals(addr.offset, 0LL, nil);
}

- (void)test20_SearchNoTerminator
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"/pattern"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressSearch, nil);
	STAssertEqualObjects(addr.pattern, @"pattern", nil);
	STAssertEquals(addr.backwards, NO, nil);
	STAssertEquals(addr.offset, 0LL, nil);
}

- (void)test20_BackwardsSearch
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"?pattern?"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressSearch, nil);
	STAssertEqualObjects(addr.pattern, @"pattern", nil);
	STAssertEquals(addr.backwards, YES, nil);
	STAssertEquals(addr.offset, 0LL, nil);
}

- (void)test20_BackwardsSearchNoTerminator
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"?pattern"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressSearch, nil);
	STAssertEqualObjects(addr.pattern, @"pattern", nil);
	STAssertEquals(addr.backwards, YES, nil);
	STAssertEquals(addr.offset, 0LL, nil);
}

- (void)test20_CurrentPosition
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"."];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressCurrent, nil);
	STAssertEquals(addr.offset, 0LL, nil);
}

- (void)test20_CurrentPositionPlusOffset
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@".+7"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressCurrent, nil);
	STAssertEquals(addr.offset, 7LL, nil);
}

- (void)test20_ImplicitCurrentPostionPlusOffset
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"+7"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressRelative, nil);
	STAssertEquals(addr.offset, 7LL, nil);
}

- (void)test20_ImplicitCurrentPostionMinusOffset
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"-7"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressRelative, nil);
	STAssertEquals(addr.offset, -7LL, nil);
}

- (void)test20_ImplicitCurrentPostionMinusOffset2
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"^7"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressRelative, nil);
	STAssertEquals(addr.offset, -7LL, nil);
}

- (void)test20_AdditiveOffsets
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"2 2 3p"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressAbsolute, nil);
	STAssertEquals(addr.line, 2LL, nil);
	STAssertEquals(addr.offset, 5LL, nil);
}

- (void)test20_OffsetsWithOnlySigns
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"3 - 2"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressAbsolute, nil);
	STAssertEquals(addr.line, 3LL, nil);
	STAssertEquals(addr.offset, 1LL, nil);
}

- (void)test20_SearchWithAdditiveOffsets
{
	ExAddress *addr;
	NSScanner *scan = [NSScanner scannerWithString:@"/pattern/2 2 2"];
	STAssertTrue([ExParser parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, ExAddressSearch, nil);
	STAssertEqualObjects(addr.pattern, @"pattern", nil);
	STAssertEquals(addr.backwards, NO, nil);
	STAssertEquals(addr.offset, 6LL, nil);
}



- (void)test30_WholeFile
{
	ExAddress *addr1, *addr2;
	NSScanner *scan = [NSScanner scannerWithString:@"%"];
	STAssertEquals([ExParser parseRange:scan intoAddress:&addr1 otherAddress:&addr2], 2, nil);
	STAssertEquals(addr1.type, ExAddressAbsolute, nil);
	STAssertEquals(addr1.line, 1LL, nil);
	STAssertEquals(addr1.offset, 0LL, nil);
	STAssertEquals(addr2.type, ExAddressAbsolute, nil);
	STAssertEquals(addr2.line, -1LL, nil);
	STAssertEquals(addr2.offset, 0LL, nil);
}

- (void)test30_AbsoluteCommaAbsolute
{
	ExAddress *addr1, *addr2;
	NSScanner *scan = [NSScanner scannerWithString:@"1,2"];
	STAssertEquals([ExParser parseRange:scan intoAddress:&addr1 otherAddress:&addr2], 2, nil);
	STAssertEquals(addr1.type, ExAddressAbsolute, nil);
	STAssertEquals(addr1.line, 1LL, nil);
	STAssertEquals(addr1.offset, 0LL, nil);
	STAssertEquals(addr2.type, ExAddressAbsolute, nil);
	STAssertEquals(addr2.line, 2LL, nil);
	STAssertEquals(addr2.offset, 0LL, nil);
}

- (void)test30_AbsoluteCommaSearch
{
	ExAddress *addr1, *addr2;
	NSScanner *scan = [NSScanner scannerWithString:@"3,/pattern/"];
	STAssertEquals([ExParser parseRange:scan intoAddress:&addr1 otherAddress:&addr2], 2, nil);
	STAssertEquals(addr1.type, ExAddressAbsolute, nil);
	STAssertEquals(addr1.line, 3LL, nil);
	STAssertEquals(addr1.offset, 0LL, nil);
	STAssertEquals(addr2.type, ExAddressSearch, nil);
	STAssertEqualObjects(addr2.pattern, @"pattern", nil);
	STAssertEquals(addr2.backwards, NO, nil);
	STAssertEquals(addr2.offset, 0LL, nil);
}



- (void)test40_singleComment
{
	[self parse:@":\"foo|set"];
	STAssertEqualObjects(ex.mapping.name, @"#", nil);
	STAssertTrue(ex.mapping.action == @selector(ex_goto:), nil);
}

- (void)test50_AddressExtraColonCommand
{
	[self parse:@":3,5:eval"];
	STAssertEquals(ex.naddr, 2ULL, nil);
	STAssertNotNil(ex.addr1, nil);
	STAssertNotNil(ex.addr2, nil);
	STAssertEquals(ex.addr1.type, ExAddressAbsolute, nil);
	STAssertEquals(ex.addr2.type, ExAddressAbsolute, nil);
	STAssertEqualObjects(ex.mapping.name, @"eval", nil);
	STAssertEquals(ex.mapping.action, @selector(ex_eval:), nil);
}

- (void)test60_semicolonDelimitedRange
{
	[self parse:@"  :3;/pattern/d"];
	STAssertEqualObjects(ex.mapping.name, @"delete", nil);
	STAssertEquals(ex.mapping.action, @selector(ex_delete:), nil);

	STAssertEquals(ex.naddr, 2ULL, nil);
	STAssertEquals(ex.addr1.type, ExAddressAbsolute, nil);
	STAssertEquals(ex.addr1.line, 3LL, nil);
	STAssertEquals(ex.addr1.offset, 0LL, nil);
	STAssertEquals(ex.addr2.type, ExAddressSearch, nil);
	STAssertEqualObjects(ex.addr2.pattern, @"pattern", nil);
	STAssertEquals(ex.addr2.backwards, NO, nil);
	STAssertEquals(ex.addr2.offset, 0LL, nil);
}

#if 0
- (void)test60_OneAddressCommandWithTwoAddresses
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"'a,5pu"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.method, @"ex_put", nil);
	STAssertEquals(ex.naddr, 1ULL, nil);
	STAssertEquals([ex addr1].type, ExAddressAbsolute, nil);
	STAssertEquals([ex addr1].line, 5LL, nil);
}

- (void)test60_OneAddressCommandWithZeroAddresses
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"put"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.method, @"ex_put", nil);
	STAssertEquals(ex.naddr, 1ULL, nil);
	STAssertEquals([ex addr1].type, ExAddressCurrent, nil);
}



- (void)test70_GlobalCommandWithStringArgument
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@":g/pattern/:p"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.name, @"g", nil);
	STAssertEqualObjects(ex.method, @"ex_global", nil);
	STAssertEqualObjects(ex.string, @"/pattern/:p", nil);
}
#endif

- (void)test70_CopyToLineZero
{
	[self parse:@"-,+t0"];
	STAssertEqualObjects(ex.mapping.name, @"copy", nil); // 'copy' is aliased as 't'
	STAssertEquals(ex.mapping.action, @selector(ex_copy:), nil);
	STAssertEquals(ex.naddr, 2ULL, nil);
	STAssertEquals(ex.lineAddress.type, ExAddressAbsolute, nil);
	STAssertEquals(ex.lineAddress.line, 0LL, nil);
	STAssertEquals(ex.lineAddress.offset, 0LL, nil);
}

- (void)test70_MoveCommandWithDestinationAddress
{
	[self parse:@"20,.m$"];
	STAssertEqualObjects(ex.mapping.name, @"move", nil);
	STAssertEquals(ex.mapping.action, @selector(ex_move:), nil);
	STAssertEquals(ex.naddr, 2ULL, nil);
	STAssertEquals(ex.addr1.type, ExAddressAbsolute, nil);
	STAssertEquals(ex.addr2.type, ExAddressCurrent, nil);
	STAssertEquals(ex.lineAddress.type, ExAddressAbsolute, nil);
	STAssertEquals(ex.lineAddress.line, -1LL, nil);
	STAssertEquals(ex.lineAddress.offset, 0LL, nil);
}

- (void)test70_MoveCommandWithDestinationAddressAndOffset
{
	[self parse:@"226,$m.-2"];
	STAssertEqualObjects(ex.mapping.name, @"move", nil);
	STAssertEquals(ex.mapping.action, @selector(ex_move:), nil);
	STAssertEquals(ex.naddr, 2ULL, nil);
	STAssertEquals(ex.addr1.type, ExAddressAbsolute, nil);
	STAssertEquals(ex.addr2.type, ExAddressAbsolute, nil);
	STAssertEquals(ex.lineAddress.type, ExAddressCurrent, nil);
	STAssertEquals(ex.lineAddress.offset, -2LL, nil);
}

- (void)test70_EditCommandWithPlusCommand
{
	[self parse:@"edit +25|s/abc/ABC/ file.c"];
	STAssertEqualObjects(ex.mapping.name, @"edit", nil);
	STAssertEquals(ex.mapping.action, @selector(ex_edit:), nil);
	STAssertEqualObjects(ex.plus_command, @"25|s/abc/ABC/", nil);
	STAssertEqualObjects(ex.arg, @"file.c", nil);
}

- (void)test80_BangCommand
{
	[self parse:@"!ls"];
	STAssertEqualObjects(ex.mapping.name, @"!", nil);
	STAssertEquals(ex.mapping.action, @selector(ex_bang:), nil);
	STAssertEqualObjects(ex.arg, @"ls", nil);
}

- (void)test80_BangCommandWithShellPipe
{
	[self parse:@"!ls -1 | grep .m"];
	STAssertEqualObjects(ex.mapping.name, @"!", nil);
	STAssertEquals(ex.mapping.action, @selector(ex_bang:), nil);
	STAssertEqualObjects(ex.arg, @"ls -1 | grep .m", nil);
}

@end
