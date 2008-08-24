//
//  TestExCommand.m
//  vizard
//
//  Created by Martin Hedenfalk on 2008-03-29.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import "TestExCommand.h"
#import "ExCommand.h"


@implementation TestExCommand

- (void)test010_SetCommand
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"w"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects([ex command], @"write", nil);
	STAssertEqualObjects([ex method], @"ex_write", nil);
}

- (void)test011_NonexistentSimpleCommand
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"foo bar baz"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.command, @"foo", nil);
	STAssertNil(ex.method, nil);
}

- (void)test012_SimpleCommandWithSimpleParameter
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"edit /path/to/file.txt"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.command, @"edit", nil);
	STAssertEqualObjects(ex.method, @"ex_edit", nil);
	STAssertNotNil(ex.arguments, nil);
	STAssertTrue([ex.arguments count] == 1, nil);
	STAssertEqualObjects([ex.arguments objectAtIndex:0], @"/path/to/file.txt", nil);
}


- (void)test20_AbsoluteAddress
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"17"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_ABS, nil);
	STAssertEquals(addr.addr.abs.line, 17, nil);
	STAssertEquals(addr.addr.abs.column, 1, nil);
	STAssertEquals(addr.offset, 0, nil);
}

- (void)test20_LastLineAddress
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"$"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_ABS, nil);
	STAssertEquals(addr.addr.abs.line, -1, nil);
	STAssertEquals(addr.addr.abs.column, 1, nil);
	STAssertEquals(addr.offset, 0, nil);
}

- (void)test20_MarkAddress
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"'x"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_MARK, nil);
	STAssertEquals(addr.addr.mark, 'x', nil);
	STAssertEquals(addr.offset, 0, nil);
}

- (void)test20_Search
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"/pattern/"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_SEARCH, nil);
	STAssertEqualObjects(addr.addr.search.pattern, @"pattern", nil);
	STAssertEquals(addr.addr.search.backwards, NO, nil);
	STAssertEquals(addr.offset, 0, nil);
}

- (void)test20_SearchNoTerminator
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"/pattern"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_SEARCH, nil);
	STAssertEqualObjects(addr.addr.search.pattern, @"pattern", nil);
	STAssertEquals(addr.addr.search.backwards, NO, nil);
	STAssertEquals(addr.offset, 0, nil);
}

- (void)test20_BackwardsSearch
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"?pattern?"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_SEARCH, nil);
	STAssertEqualObjects(addr.addr.search.pattern, @"pattern", nil);
	STAssertEquals(addr.addr.search.backwards, YES, nil);
	STAssertEquals(addr.offset, 0, nil);
}

- (void)test20_BackwardsSearchNoTerminator
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"?pattern"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_SEARCH, nil);
	STAssertEqualObjects(addr.addr.search.pattern, @"pattern", nil);
	STAssertEquals(addr.addr.search.backwards, YES, nil);
	STAssertEquals(addr.offset, 0, nil);
}

- (void)test20_CurrentPosition
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"."];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_CURRENT, nil);
	STAssertEquals(addr.offset, 0, nil);
}

- (void)test20_CurrentPositionPlusOffset
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@".+7"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_CURRENT, nil);
	STAssertEquals(addr.offset, 7, nil);
}

- (void)test20_ImplicitCurrentPostionPlusOffset
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"+7"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_CURRENT, nil);
	STAssertEquals(addr.offset, 7, nil);
}

- (void)test20_ImplicitCurrentPostionMinusOffset
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"-7"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_CURRENT, nil);
	STAssertEquals(addr.offset, -7, nil);
}

- (void)test20_ImplicitCurrentPostionMinusOffset2
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"^7"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_CURRENT, nil);
	STAssertEquals(addr.offset, -7, nil);
}

- (void)test20_AdditiveOffsets
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"2 2 3p"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_ABS, nil);
	STAssertEquals(addr.addr.abs.line, 2, nil);
	STAssertEquals(addr.addr.abs.column, 1, nil);
	STAssertEquals(addr.offset, 5, nil);
}

- (void)test20_OffsetsWithOnlySigns
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"3 - 2"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_ABS, nil);
	STAssertEquals(addr.addr.abs.line, 3, nil);
	STAssertEquals(addr.addr.abs.column, 1, nil);
	STAssertEquals(addr.offset, 1, nil);
}

- (void)test20_SearchWithAdditiveOffsets
{
	struct ex_address addr;
	NSScanner *scan = [NSScanner scannerWithString:@"/pattern/2 2 2"];
	STAssertTrue([ExCommand parseRange:scan intoAddress:&addr], nil);
	STAssertEquals(addr.type, EX_ADDR_SEARCH, nil);
	STAssertEqualObjects(addr.addr.search.pattern, @"pattern", nil);
	STAssertEquals(addr.addr.search.backwards, NO, nil);
	STAssertEquals(addr.offset, 6, nil);
}



- (void)test40_singleComment
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@":\"foo|set"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.command, nil, nil);
	STAssertEqualObjects(ex.method, nil, nil);
}

- (void)test50_precedingColon
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@":g/pattern/:p"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.command, @"g", nil);
	STAssertEqualObjects(ex.method, @"ex_global", nil);
	STAssertEquals(ex.flags, (unsigned)E_C_PRINT, nil);
}

- (void)test60_semicolonDelimitedRange
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"  :3;/pattern/d"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.command, @"d", nil);
	STAssertEqualObjects(ex.method, @"ex_delete", nil);
	// FIXME: check addresses
}

@end
