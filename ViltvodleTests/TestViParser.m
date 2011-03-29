#import "TestViParser.h"
#import "ViError.h"
#import "NSString-additions.h"

@implementation TestViParser

- (void)setUp
{
	parser = [[ViParser alloc] initWithDefaultMap:[ViMap normalMap]];
	error = nil;
}

- (void)tearDown
{
	[parser release];
}

- (void)test010_IllegalCommand
{
	command = [parser pushKey:0x0E07 scope:nil timeout:nil error:&error];
	STAssertNil(command, @"an illegal command should return nil");
	STAssertNotNil(error, @"parser should return an error if failed");
	STAssertEquals(error.code, (NSInteger)ViErrorMapNotFound, nil);
}

- (void)test020_SimpleCommands
{
	STAssertNotNil(parser, @"command parser should be created");
	command = [parser pushKey:'i' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, @"'i' should be a complete command");
	STAssertEquals(command.mapping.action, @selector(insert:), @"'i' should be mapped to the 'insert' method");
}

- (void)test021_ResetSimpleCommand
{
	command = [parser pushKey:'i' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, @"'i' should be a complete command");
	command = [parser pushKey:'i' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, @"'i' should be a complete command");
}

- (void)test050_IncompleteCommand
{
	command = [parser pushKey:'c' scope:nil timeout:nil error:&error];
	STAssertNil(command, @"change command requires a movement component");
	STAssertTrue(parser.partial, @"change command requires a movement component");
}

- (void)test051_CommandWithMotion
{
	[parser pushKey:'c' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'w' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, @"(c)hange (w)ord should be a complete command");
	STAssertEquals(command.mapping.action, @selector(change:), nil);
	STAssertEquals(command.motion.action, @selector(word_forward:), nil);
	STAssertEqualObjects(command.mapping.keyString, @"c", nil);
	STAssertFalse(command.isLineMode, nil);
	STAssertFalse(command.isMotion, nil);
	STAssertTrue(command.motion.hasOperator, nil);
}

- (void)test052_CommandWithNonMotion
{
	[parser pushKey:'c' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'x' scope:nil timeout:nil error:&error];
	STAssertNil(command, nil);
	STAssertNotNil(error, nil);
	// 'x' command not found in operator map
	STAssertEquals([error code], (NSInteger)ViErrorMapNotFound, nil);
}

- (void)test053_DoubledCommandImpliesCurrentLine
{
	[parser pushKey:'c' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'c' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(change:), nil);
	STAssertTrue(command.isLineMode, nil);
	STAssertFalse(command.isMotion, nil);
}

- (void)test054_ResetCommandWithMotion
{
	[parser pushKey:'c' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'w' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	command = [parser pushKey:'w' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(word_forward:), nil);
	STAssertNil(command.motion, nil);
	STAssertTrue(command.isMotion, nil);
}

- (void)test060_CommandWithRepeatCount
{
	command = [parser pushKey:'3' scope:nil timeout:nil error:&error];
	STAssertNil(command, nil);
	STAssertNil(error, nil);
	command = [parser pushKey:'w' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertNil(error, nil);
	STAssertEquals(command.count, 3, nil);
}

- (void)test061_CommandWithMotionRepeatCount
{
	command = [parser pushKey:'d' scope:nil timeout:nil error:&error];
	STAssertNil(command, nil);
	STAssertNil(error, nil);
	command = [parser pushKey:'3' scope:nil timeout:nil error:&error];
	STAssertNil(command, nil);
	STAssertNil(error, nil);
	command = [parser pushKey:'w' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertNotNil(command.motion, nil);
	STAssertNil(error, nil);
	STAssertEquals(command.count, 0, nil);
	STAssertEquals(command.motion.count, 3, nil);
}

- (void)test062_InitialZeroIsCommandNotRepeatCount
{
	command = [parser pushKey:'0' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertNil(error, nil);
	STAssertEquals(command.mapping.action, @selector(move_bol:), nil);
}

- (void)test063_MultiDigitRepeatCount
{
	[parser pushKey:'9' scope:nil timeout:nil error:&error];
	[parser pushKey:'8' scope:nil timeout:nil error:&error];
	[parser pushKey:'7' scope:nil timeout:nil error:&error];
	[parser pushKey:'6' scope:nil timeout:nil error:&error];
	[parser pushKey:'5' scope:nil timeout:nil error:&error];
	[parser pushKey:'0' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'x' scope:nil timeout:nil error:&error];
	STAssertEquals(command.count, 987650, nil);
}

- (void)test064_DualCountIsMultiplicative
{
	/* From nvi:
         * A count may be provided both to the command and to the motion, in
         * which case the count is multiplicative.  For example, "3y4y" is the
         * same as "12yy".  This count is provided to the motion command and 
         * not to the regular function.
         */
	[parser pushKey:'3' scope:nil timeout:nil error:&error];
	[parser pushKey:'y' scope:nil timeout:nil error:&error];
	[parser pushKey:'4' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'w' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.count, 0, nil);
	STAssertEquals(command.motion.count, 12, nil);
}

- (void)test070_NoDotCommand
{
	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertNil(command, nil);
	STAssertNotNil(error, nil);
	STAssertEquals(error.code, (NSInteger)ViErrorParserNoDot, nil);
}

- (void)test071_DotCommand
{
	[parser pushKey:'x' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(delete_forward:), nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test072_MotionDoesntSetDot
{
	command = [parser pushKey:'w' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertNil(command, nil);
	STAssertNotNil(error, nil);
	STAssertEquals(error.code, (NSInteger)ViErrorParserNoDot, nil);
}

- (void)test073_MotionDoesntResetDot
{
	[parser pushKey:'c' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'w' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertFalse(command.fromDot, nil);
	STAssertTrue(command.motion.hasOperator, nil);
	command = [parser pushKey:'j' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertFalse(command.fromDot, nil);
	STAssertFalse(command.hasOperator, nil);
	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(change:), nil);
	STAssertEquals(command.motion.mapping.action, @selector(word_forward:), nil);
	STAssertTrue(command.fromDot, nil);
	STAssertTrue(command.motion.hasOperator, nil);
}

- (void)test074_DotCommandChangesWithCommands
{
	[parser pushKey:'x' scope:nil timeout:nil error:&error];
	[parser pushKey:'X' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertEquals(command.mapping.action, @selector(delete_backward:), nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test075_DotCommandInheritsCount
{
	[parser pushKey:'3' scope:nil timeout:nil error:&error];
	[parser pushKey:'x' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertEquals(command.mapping.action, @selector(delete_forward:), nil);
	STAssertEquals(command.count, 3, nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test075_DotCommandInheritsMotionCount
{
	[parser pushKey:'d' scope:nil timeout:nil error:&error];
	[parser pushKey:'2' scope:nil timeout:nil error:&error];
	[parser pushKey:'w' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertEquals(command.mapping.action, @selector(delete:), nil);
	STAssertEquals(command.motion.mapping.action, @selector(word_forward:), nil);
	STAssertEquals(command.motion.count, 2, nil);
	STAssertEquals(command.count, 0, nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test076_DotCommandWithCountOverridesOriginal
{
	[parser pushKey:'2' scope:nil timeout:nil error:&error];
	[parser pushKey:'d' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'w' scope:nil timeout:nil error:&error];
	STAssertEquals(command.motion.count, 2, nil);
	STAssertEquals(command.count, 0, nil);
	[parser pushKey:'3' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertEqualObjects(command.mapping.keyString, @"d", nil);
	STAssertEquals(command.motion.mapping.action, @selector(word_forward:), nil);
	STAssertEquals(command.motion.count, 3, nil);
	STAssertEquals(command.count, 0, nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test077_DotCommandWithMultiplicativeCountOverridesOriginal
{
	[parser pushKey:'2' scope:nil timeout:nil error:&error];
	[parser pushKey:'d' scope:nil timeout:nil error:&error];
	[parser pushKey:'4' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'w' scope:nil timeout:nil error:&error];
	STAssertEquals(command.count, 0, nil);
	STAssertEquals(command.motion.count, 8, nil);
	STAssertFalse(command.fromDot, nil);
	[parser pushKey:'3' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertEquals(command.count, 0, nil);
	STAssertEquals(command.motion.count, 3, nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test078_GCommandSetsLineMode
{
	command = [parser pushKey:'d' scope:nil timeout:nil error:&error];
	STAssertFalse(command.isLineMode, nil);
	command = [parser pushKey:'G' scope:nil timeout:nil error:&error];
	STAssertTrue(command.isLineMode, nil);	
	STAssertEquals(command.count, 0, nil);
	STAssertEquals(command.motion.count, 0, nil);
}

- (void)test078_gUUCommandSetsLineMode
{
	command = [parser pushKey:'g' scope:nil timeout:nil error:&error];
	STAssertFalse(command.isLineMode, nil);
	command = [parser pushKey:'U' scope:nil timeout:nil error:&error];
	STAssertFalse(command.isLineMode, nil);
	command = [parser pushKey:'U' scope:nil timeout:nil error:&error];
	STAssertTrue(command.isLineMode, nil);
	STAssertEquals(command.mapping.action, @selector(uppercase:), nil);
}

- (void)test080_tCommandRequiresArgument
{
	command = [parser pushKey:'t' scope:nil timeout:nil error:&error];
	STAssertNil(command, nil);
	STAssertNil(error, nil);
	command = [parser pushKey:'x' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.argument, (unichar)'x', nil);
}

- (void)test081_tCommandRequiresCharacterWithRepeatCount
{
	[parser pushKey:'3' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'t' scope:nil timeout:nil error:&error];
	STAssertNil(command, nil);
	command = [parser pushKey:'x' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.argument, (unichar)'x', nil);
	STAssertEquals(command.count, 3, nil);
}

- (void)test081_CommandWithArgumentAsMotionComponent
{
	[parser pushKey:'d' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'t' scope:nil timeout:nil error:&error];
	STAssertNil(command, nil);
	command = [parser pushKey:'x' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.argument, (unichar)0, nil);
	STAssertEquals(command.motion.argument, (unichar)'x', nil);
	STAssertEquals(command.motion.mapping.action, @selector(move_til_char:), nil);
}

- (void)test081_UnicharAsArgument
{
	[parser pushKey:'t' scope:nil timeout:nil error:&error];
	NSString *euro = @"€";
	unichar ch = [euro characterAtIndex:0];
	command = [parser pushKey:ch scope:nil timeout:nil error:&error];
	STAssertEquals(command.argument, ch, nil);
}

- (void)test090_DotCommandWithInsertedText
{
	command = [parser pushKey:'a' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	// input text
	[command setText:[@"apa" keyCodes]];

	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(append:), nil);
	STAssertEqualObjects(command.text, [@"apa" keyCodes], nil);

	command = [parser pushKey:'x' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertNil(command.text, nil);
}

- (void)test091_MotionCommandsDontResetRepeatText
{
	command = [parser pushKey:'i' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	// input text
	[command setText:[@"apa" keyCodes]];

	command = [parser pushKey:'j' scope:nil timeout:nil error:&error];
	STAssertNil(command.text, nil);

	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertEqualObjects(command.text, [@"apa" keyCodes], nil);
}

- (void)test092_CommandsWithArgumentRememberArgument
{
	[parser pushKey:'d' scope:nil timeout:nil error:&error];
	[parser pushKey:'f' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'a' scope:nil timeout:nil error:&error];
	STAssertEquals(command.argument, (unichar)0, nil);
	STAssertEquals(command.motion.argument, (unichar)'a', nil);

	command = [parser pushKey:'j' scope:nil timeout:nil error:&error];
	STAssertEquals(command.argument, (unichar)0, nil);

	command = [parser pushKey:'.' scope:nil timeout:nil error:&error];
	STAssertEquals(command.argument, (unichar)0, nil);
	STAssertEquals(command.motion.argument, (unichar)'a', nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test093_PrefixKeys
{
	command = [parser pushKey:0x17 scope:nil timeout:nil error:&error];	// C-w
	STAssertNil(command, nil);
	STAssertNil(error, nil);
	command = [parser pushKey:'l' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(window_right:), nil);
}

/* d10gg should be the same as d10G
 */
- (void)test094_MotionComponentInChainedMaps
{
	[parser pushKey:'d' scope:nil timeout:nil error:&error];
	[parser pushKey:'1' scope:nil timeout:nil error:&error];
	[parser pushKey:'0' scope:nil timeout:nil error:&error];
	command = [parser pushKey:'g' scope:nil timeout:nil error:&error];
	STAssertNil(command, @"g is not a complete motion command");
	STAssertNil(error, nil);
	command = [parser pushKey:'g' scope:nil timeout:nil error:&error];
	STAssertNotNil(command, @"g is a complete motion command");
	STAssertNil(error, nil);
	STAssertEquals(command.motion.count, 10, nil);
	STAssertEquals(command.action, @selector(delete:), nil);
	STAssertEquals(command.motion.mapping.action, @selector(goto_line:), nil);
}

@end

