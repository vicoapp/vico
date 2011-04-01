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
	NSArray *keys = [@"c" keyCodes];
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

