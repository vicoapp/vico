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
	STAssertEqualObjects(parser.method, @"illegal:", @"0x0E07 should be an illegal command");
}

- (void)test020_SimpleCommands
{
	STAssertNotNil(parser, @"command parser should be created");
	STAssertFalse(parser.complete, @"command shouldn't be complete without any keys");
	[parser pushKey:'i'];
	STAssertTrue(parser.complete, @"'i' should be a complete command");
	STAssertTrue(parser.key == 'i', nil);
	STAssertEqualObjects(parser.method, @"insert:", @"'i' should be mapped to the 'insert' method");
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
	STAssertEqualObjects(parser.method, @"change:", nil);
	STAssertEqualObjects(parser.motion_method, @"word_forward:", nil);
	STAssertTrue(parser.key == 'c', nil);
}

- (void)test052_CommandWithNonMotion
{
	[parser pushKey:'c'];
	[parser pushKey:'x'];
	STAssertTrue(parser.complete, nil);
	STAssertEqualObjects(parser.method, @"nonmotion:", nil);
}

- (void)test053_DoubledCommandImpliesCurrentLine
{
	[parser pushKey:'c'];
	[parser pushKey:'c'];
	STAssertTrue(parser.complete, nil);
	STAssertEqualObjects(parser.method, @"change:", nil);
	STAssertTrue(parser.line_mode, nil);
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
	STAssertEqualObjects(parser.method, @"word_forward:", nil);
	STAssertNil(parser.motion_method, nil);
	STAssertTrue(parser.key == 'w', nil);
}


- (void)test060_CommandWithRepeatCount
{
	[parser pushKey:'3'];
	STAssertFalse(parser.complete, nil);
	[parser pushKey:'w'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.key == 'w', nil);
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
	STAssertTrue(parser.key == 'd', nil);
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

- (void)test064_DualCountIsMultiplicative
{
	/* From nvi:
         * A count may be provided both to the command and to the motion, in
         * which case the count is multiplicative.  For example, "3y4y" is the
         * same as "12yy".  This count is provided to the motion command and 
         * not to the regular function.
         */
	[parser pushKey:'3'];
	[parser pushKey:'y'];
	[parser pushKey:'4'];
	[parser pushKey:'y'];
	STAssertTrue(parser.complete, nil);
	STAssertEquals(parser.count, 0, nil);
	STAssertEquals(parser.motion_count, 12, nil);
	STAssertTrue(parser.line_mode, nil);
	STAssertEqualObjects(parser.method, @"yank:", nil);
}

- (void)test070_NoDotCommand
{
	[parser pushKey:'.'];
	STAssertTrue(parser.complete, nil);
	STAssertEqualObjects(parser.method, @"nodot:", nil);
}

- (void)test071_DotCommand
{
	[parser pushKey:'x'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.key == 'x', nil);
	[parser reset];
	[parser pushKey:'.'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.key == 'x', nil);
	STAssertEqualObjects(parser.method, @"delete_forward:", nil);
}

- (void)test072_MotionDoesntSetDot
{
	[parser pushKey:'w'];
	STAssertTrue(parser.complete, nil);
	[parser reset];
	[parser pushKey:'.'];
	STAssertTrue(parser.complete, nil);
	STAssertEqualObjects(parser.method, @"nodot:", nil);
}

- (void)test073_MotionDoesntResetDot
{
	[parser pushKey:'x'];
	STAssertTrue(parser.complete, nil);
	[parser reset];
	[parser pushKey:'w'];
	STAssertTrue(parser.complete, nil);
	[parser reset];
	[parser pushKey:'.'];
	STAssertTrue(parser.complete, nil);
	STAssertEqualObjects(parser.method, @"delete_forward:", nil);
}

- (void)test074_DotCommandChangesWithCommands
{
	[parser pushKey:'x'];
	[parser reset];
	[parser pushKey:'X'];
	[parser reset];
	[parser pushKey:'.'];
	STAssertTrue(parser.complete, nil);
	STAssertEqualObjects(parser.method, @"delete_backward:", nil);
}

- (void)test075_DotCommandInheritsCount
{
	[parser pushKey:'d'];
	[parser pushKey:'2'];
	[parser pushKey:'w'];
	[parser reset];
	[parser pushKey:'.'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.key == 'd', nil);
	STAssertEqualObjects(parser.motion_method, @"word_forward:", nil);
	STAssertEquals(parser.motion_count, 2, nil);
}

- (void)test076_DotCommandWithCountOverridesOriginal
{
	[parser pushKey:'2'];
	[parser pushKey:'d'];
	[parser pushKey:'w'];
	STAssertTrue(parser.complete, nil);
	STAssertEquals(parser.count, 2, nil);
	[parser reset];
	[parser pushKey:'3'];
	[parser pushKey:'.'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.key == 'd', nil);
	STAssertEqualObjects(parser.motion_method, @"word_forward:", nil);
	STAssertEquals(parser.count, 3, nil);
	STAssertEquals(parser.motion_count, 0, nil);
}

- (void)test077_DotCommandWithMultiplicativeCountOverridesOriginal
{
	[parser pushKey:'2'];
	[parser pushKey:'d'];
	[parser pushKey:'4'];
	[parser pushKey:'w'];
	STAssertTrue(parser.complete, nil);
	STAssertEquals(parser.count, 0, nil);
	STAssertEquals(parser.motion_count, 8, nil);
	[parser reset];
	[parser pushKey:'3'];
	[parser pushKey:'.'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.key == 'd', nil);
	STAssertEqualObjects(parser.motion_method, @"word_forward:", nil);
	STAssertEquals(parser.count, 0, nil);
	STAssertEquals(parser.motion_count, 12, nil);
}

- (void)test078_GCommandSetsLineMode
{
	[parser pushKey:'d'];
	STAssertFalse(parser.line_mode, nil);
	[parser pushKey:'G'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.line_mode, nil);	
}


- (void)test080_tCommandRequiresCharacter
{
	[parser pushKey:'t'];
	STAssertFalse(parser.complete, nil);
	[parser pushKey:'x'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.key == 't', nil);
	STAssertTrue(parser.character == 'x', nil);
}

- (void)test081_tCommandRequiresCharacterWithRepeatCount
{
	[parser pushKey:'3'];
	[parser pushKey:'t'];
	STAssertFalse(parser.complete, nil);
	[parser pushKey:'x'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.key == 't', nil);
	STAssertTrue(parser.character == 'x', nil);
	STAssertEquals(parser.count, 3, nil);
}

- (void)test081_CommandWithCharacterAsMotionComponent
{
	[parser pushKey:'d'];
	[parser pushKey:'t'];
	STAssertFalse(parser.complete, nil);
	[parser pushKey:'x'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.key == 'd', nil);
	STAssertEquals(parser.character, (unichar)'x', nil);
	STAssertEqualObjects(parser.motion_method, @"move_til_char:", nil);
}

- (void)test081_UnicharAsArgument
{
	[parser pushKey:'t'];
	STAssertFalse(parser.complete, nil);
	[parser pushKey:'å'];
	STAssertTrue(parser.complete, nil);
	STAssertTrue(parser.key == 't', nil);
	STAssertTrue(parser.character == 'å', nil);
}

@end
