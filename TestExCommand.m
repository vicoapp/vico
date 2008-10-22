#import "TestExCommand.h"
#import "ExCommand.h"

@implementation TestExCommand

- (void)test010_SetCommand
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"w"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.name, @"w", nil);
	STAssertEqualObjects(ex.method, @"ex_write", nil);
}

- (void)test011_NonexistentSimpleCommand
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"foo bar baz"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.name, @"foo", nil);
	STAssertTrue(ex.command == NULL, nil);
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



- (void)test30_WholeFile
{
	struct ex_address addr1, addr2;
	NSScanner *scan = [NSScanner scannerWithString:@"%"];
	STAssertEquals([ExCommand parseRange:scan intoAddress:&addr1 otherAddress:&addr2], 2, nil);
	STAssertEquals(addr1.type, EX_ADDR_ABS, nil);
	STAssertEquals(addr1.addr.abs.line, 1, nil);
	STAssertEquals(addr1.addr.abs.column, 1, nil);
	STAssertEquals(addr1.offset, 0, nil);
	STAssertEquals(addr2.type, EX_ADDR_ABS, nil);
	STAssertEquals(addr2.addr.abs.line, -1, nil);
	STAssertEquals(addr2.addr.abs.column, 1, nil);
	STAssertEquals(addr2.offset, 0, nil);
}

- (void)test30_AbsoluteCommaAbsolute
{
	struct ex_address addr1, addr2;
	NSScanner *scan = [NSScanner scannerWithString:@"1,2"];
	STAssertEquals([ExCommand parseRange:scan intoAddress:&addr1 otherAddress:&addr2], 2, nil);
	STAssertEquals(addr1.type, EX_ADDR_ABS, nil);
	STAssertEquals(addr1.addr.abs.line, 1, nil);
	STAssertEquals(addr1.addr.abs.column, 1, nil);
	STAssertEquals(addr1.offset, 0, nil);
	STAssertEquals(addr2.type, EX_ADDR_ABS, nil);
	STAssertEquals(addr2.addr.abs.line, 2, nil);
	STAssertEquals(addr2.addr.abs.column, 1, nil);
	STAssertEquals(addr2.offset, 0, nil);
}

- (void)test30_AbsoluteCommaSearch
{
	struct ex_address addr1, addr2;
	NSScanner *scan = [NSScanner scannerWithString:@"3,/pattern/"];
	STAssertEquals([ExCommand parseRange:scan intoAddress:&addr1 otherAddress:&addr2], 2, nil);
	STAssertEquals(addr1.type, EX_ADDR_ABS, nil);
	STAssertEquals(addr1.addr.abs.line, 3, nil);
	STAssertEquals(addr1.addr.abs.column, 1, nil);
	STAssertEquals(addr1.offset, 0, nil);
	STAssertEquals(addr2.type, EX_ADDR_SEARCH, nil);
	STAssertEqualObjects(addr2.addr.search.pattern, @"pattern", nil);
	STAssertEquals(addr2.addr.search.backwards, NO, nil);
	STAssertEquals(addr2.offset, 0, nil);
}



- (void)test40_singleComment
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@":\"foo|set"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.name, nil, nil);
	STAssertTrue(ex.command == NULL, nil);
}

- (void)test50_AddressExtraColonCommand
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@":3,5:print"];
	STAssertNotNil(ex, nil);
	STAssertEquals(ex.naddr, (unsigned)2, nil);
	STAssertEquals(ex.addr1->type, EX_ADDR_ABS, nil);
	STAssertEquals(ex.addr2->type, EX_ADDR_ABS, nil);
	STAssertEqualObjects(ex.name, @"print", nil);
	STAssertEqualObjects(ex.method, @"ex_pr", nil);
}

- (void)test60_semicolonDelimitedRange
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"  :3;/pattern/d"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.name, @"d", nil);
	STAssertEqualObjects(ex.method, @"ex_delete", nil);

	STAssertEquals(ex.naddr, (unsigned)2, nil);
	STAssertEquals(ex.addr1->type, EX_ADDR_ABS, nil);
	STAssertEquals(ex.addr1->addr.abs.line, 3, nil);
	STAssertEquals(ex.addr1->addr.abs.column, 1, nil);
	STAssertEquals(ex.addr1->offset, 0, nil);
	STAssertEquals(ex.addr2->type, EX_ADDR_SEARCH, nil);
	STAssertEqualObjects(ex.addr2->addr.search.pattern, @"pattern", nil);
	STAssertEquals(ex.addr2->addr.search.backwards, NO, nil);
	STAssertEquals(ex.addr2->offset, 0, nil);
	
}

- (void)test60_OneAddressCommandWithTwoAddresses
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"'a,5pu"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.method, @"ex_put", nil);
	STAssertEquals(ex.naddr, (unsigned)1, nil);
	STAssertEquals(ex.addr1->type, EX_ADDR_ABS, nil);
	STAssertEquals(ex.addr1->addr.abs.line, 5, nil);
	STAssertEquals(ex.addr1->addr.abs.column, 1, nil);
}

- (void)test60_OneAddressCommandWithZeroAddresses
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"put"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.method, @"ex_put", nil);
	STAssertEquals(ex.naddr, (unsigned)1, nil);
	STAssertEquals(ex.addr1->type, EX_ADDR_CURRENT, nil);
}



- (void)test70_GlobalCommandWithColonBeforeFlags
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@":g/pattern/:p"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.name, @"g", nil);
	STAssertEqualObjects(ex.method, @"ex_global", nil);
	STAssertEqualObjects(ex.regexp, @"pattern", nil);
	STAssertEquals(ex.flags, (unsigned)E_C_PRINT, nil);
}

- (void)test70_CopyToLineZero
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"-,+t0"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.name, @"t", nil);
	STAssertEqualObjects(ex.method, @"ex_copy", nil);
	STAssertEquals(ex.naddr, (unsigned)2, nil);
	STAssertEquals(ex.line->type, EX_ADDR_ABS, nil);
	STAssertEquals(ex.line->addr.abs.line, 0, nil);
	STAssertEquals(ex.line->offset, 0, nil);
}

- (void)test70_MoveCommandWithDestinationAddress
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"20,.m$"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.name, @"m", nil);
	STAssertEqualObjects(ex.method, @"ex_move", nil);
	STAssertEquals(ex.naddr, (unsigned)2, nil);
	STAssertEquals(ex.addr1->type, EX_ADDR_ABS, nil);
	STAssertEquals(ex.addr2->type, EX_ADDR_CURRENT, nil);
	STAssertEquals(ex.line->type, EX_ADDR_ABS, nil);
	STAssertEquals(ex.line->addr.abs.line, -1, nil);
	STAssertEquals(ex.line->addr.abs.column, 1, nil);
	STAssertEquals(ex.line->offset, 0, nil);
}

- (void)test70_MoveCommandWithDestinationAddressAndOffset
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"226,$m.-2"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.name, @"m", nil);
	STAssertEqualObjects(ex.method, @"ex_move", nil);
	STAssertEquals(ex.naddr, (unsigned)2, nil);
	STAssertEquals(ex.addr1->type, EX_ADDR_ABS, nil);
	STAssertEquals(ex.addr2->type, EX_ADDR_ABS, nil);
	STAssertEquals(ex.line->type, EX_ADDR_CURRENT, nil);
	STAssertEquals(ex.line->offset, -2, nil);
}

- (void)test70_EditCommandWithPlusCommand
{
	ExCommand *ex = [[ExCommand alloc] initWithString:@"edit +25|s/abc/ABC/ file.c"];
	STAssertNotNil(ex, nil);
	STAssertEqualObjects(ex.name, @"edit", nil);
	STAssertEqualObjects(ex.method, @"ex_edit", nil);
	STAssertEqualObjects(ex.plus_command, @"25|s/abc/ABC/", nil);
	STAssertEqualObjects(ex.filename, @"file.c", nil);
}

@end
