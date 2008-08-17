#import "TestViCommandParser.h"

@implementation TestViCommandParser

- (void)setUp
{
	parser = [[ViCommand alloc] init];
}

- (void)tearDown
{
	[parser release];
}

- (void)test010_IllegalCommand
{
	[parser pushKey:0x0E07];
	STAssertTrue(parser.complete, @"an illegal command should be complete");
	STAssertEqualObjects(parser.method, @"illegal", @"0x0E07 should be an illegal command");
}

- (void)test020_SimpleCommands
{
	STAssertNotNil(parser, @"command parser should be created");
	STAssertFalse(parser.complete, @"command shouldn't be complete without any keys");
	[parser pushKey:'i'];
	STAssertTrue(parser.complete, @"'i' should be a complete command");
	STAssertEquals(parser.key, 'i', nil);
	STAssertEqualObjects(parser.method, @"insert", @"'i' should be mapped to the 'insert' method");
}

- (void)test021_ResetSimpleCommand
{
	[parser pushKey:'i'];
	STAssertTrue(parser.complete, @"'i' should be a complete command");
	[parser reset];
	STAssertFalse(parser.complete, @"reset should set complete to false");
	[parser pushKey:'i'];
	STAssertTrue(parser.complete, @"'i' should be a complete command");
}

- (void)test050_IncompleteCommand
{
	[parser pushKey:'c'];
	STAssertFalse(parser.complete, @"change command requires a movement component");
}

- (void)test051_CommandWithMotion
{
	[parser pushKey:'c'];
	[parser pushKey:'w'];
	STAssertTrue(parser.complete, @"(c)hange (w)ord should be a complete command");
	STAssertEqualObjects(parser.method, @"change", nil);
	STAssertEqualObjects(parser.motion_method, @"word_forward", nil);
	STAssertEquals(parser.key, 'c', nil);
}

- (void)test052_CommandWithNonMotion
{
	[parser pushKey:'c'];
	[parser pushKey:'x'];
	STAssertTrue(parser.complete, nil);
	STAssertEqualObjects(parser.method, @"nonmotion", nil);
}

- (void)test053_DoubledCommandImpliesCurrentLine
{
	[parser pushKey:'c'];
	[parser pushKey:'c'];
	STAssertTrue(parser.complete, nil);
	STAssertEqualObjects(parser.method, @"change", nil);
	STAssertEqualObjects(parser.motion_method, @"current_line", nil);
}

- (void)test054_ResetCommandWithMotion
{
	[parser pushKey:'c'];
	[parser pushKey:'w'];
	STAssertTrue(parser.complete, nil);
	[parser reset];
	STAssertFalse(parser.complete, nil);
	[parser pushKey:'w'];
	STAssertTrue(parser.complete, nil);
	STAssertEqualObjects(parser.method, @"word_forward", nil);
	STAssertNil(parser.motion_method, nil);
	STAssertEquals(parser.key, 'w', nil);
}


- (void)test060_CommandWithRepeatCount
{
	[parser pushKey:'3'];
	STAssertFalse(parser.complete, nil);
	[parser pushKey:'w'];
	STAssertTrue(parser.complete, nil);
	STAssertEquals(parser.key, 'w', nil);
	STAssertEquals(parser.count, 3, nil);
}

- (void)test061_CommandWithMotionRepeatCount
{
	[parser pushKey:'d'];
	STAssertFalse(parser.complete, nil);
	[parser pushKey:'3'];
	STAssertFalse(parser.complete, nil);
	[parser pushKey:'w'];
	STAssertTrue(parser.complete, nil);
	STAssertEquals(parser.key, 'd', nil);
	STAssertEquals(parser.count, 0, nil);
	STAssertEquals(parser.motion_count, 3, nil);
}

- (void)test062_InitialZeroIsCommandNotRepeatCount
{
	[parser pushKey:'0'];
	STAssertTrue(parser.complete, nil);
	STAssertEquals(parser.count, 0, nil);
}

- (void)test063_ResetCommandWithRepeatCount
{
	[parser pushKey:'3'];
	[parser pushKey:'x'];
	[parser reset];
	STAssertEquals(parser.count, 0, nil);
	STAssertEquals(parser.motion_count, 0, nil);
}

- (void)test063_MultiDigitRepeatCount
{
	[parser pushKey:'9'];
	[parser pushKey:'8'];
	[parser pushKey:'7'];
	[parser pushKey:'6'];
	[parser pushKey:'5'];
	[parser pushKey:'0'];
	[parser pushKey:'x'];
	STAssertEquals(parser.count, 987650, nil);
}

- (void)test064_OverrideRepeatCount
{
}

@end
