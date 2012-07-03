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
	command = [parser pushKey:0x0E07 allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, @"an illegal command should return nil");
	STAssertNotNil(error, @"parser should return an error if failed");
	STAssertEquals(error.code, (NSInteger)ViErrorMapNotFound, nil);
}

- (void)test020_SimpleCommands
{
	STAssertNotNil(parser, @"command parser should be created");
	command = [parser pushKey:'i' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, @"'i' should be a complete command");
	STAssertEquals(command.mapping.action, @selector(insert:), @"'i' should be mapped to the 'insert' method");
}

- (void)test021_ResetSimpleCommand
{
	command = [parser pushKey:'i' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, @"'i' should be a complete command");
	command = [parser pushKey:'i' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, @"'i' should be a complete command");
}

- (void)test050_IncompleteCommand
{
	command = [parser pushKey:'c' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, @"change command requires a movement component");
	STAssertTrue(parser.partial, @"change command requires a movement component");
}

- (void)test051_CommandWithMotion
{
	[parser pushKey:'c' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
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
	[parser pushKey:'c' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'x' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, nil);
	STAssertNotNil(error, nil);
	// 'x' command not found in operator map
	STAssertEquals([error code], (NSInteger)ViErrorMapNotFound, nil);
}

- (void)test053_DoubledCommandImpliesCurrentLine
{
	[parser pushKey:'d' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'d' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(delete:), nil);
	STAssertTrue(command.isLineMode, nil);
	STAssertFalse(command.isMotion, nil);
}

- (void)test054_ResetCommandWithMotion
{
	[parser pushKey:'c' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	command = [parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(word_forward:), nil);
	STAssertNil(command.motion, nil);
	STAssertTrue(command.isMotion, nil);
}

- (void)test060_CommandWithRepeatCount
{
	command = [parser pushKey:'3' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, nil);
	STAssertNil(error, nil);
	command = [parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertNil(error, nil);
	STAssertEquals(command.count, 3, nil);
}

- (void)test061_CommandWithMotionRepeatCount
{
	command = [parser pushKey:'d' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, nil);
	STAssertNil(error, nil);
	command = [parser pushKey:'3' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, nil);
	STAssertNil(error, nil);
	command = [parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertNotNil(command.motion, nil);
	STAssertNil(error, nil);
	STAssertEquals(command.count, 0, nil);
	STAssertEquals(command.motion.count, 3, nil);
}

- (void)test062_InitialZeroIsCommandNotRepeatCount
{
	command = [parser pushKey:'0' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertNil(error, nil);
	STAssertEquals(command.mapping.action, @selector(move_bol:), nil);
}

- (void)test063_MultiDigitRepeatCount
{
	[parser pushKey:'9' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'8' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'7' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'6' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'5' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'0' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'x' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
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
	[parser pushKey:'3' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'y' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'4' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.count, 0, nil);
	STAssertEquals(command.motion.count, 12, nil);
}

- (void)test070_NoDotCommand
{
	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, nil);
	STAssertNotNil(error, nil);
	STAssertEquals(error.code, (NSInteger)ViErrorParserNoDot, nil);
}

- (void)test071_DotCommand
{
	[parser pushKey:'x' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(delete_forward:), nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test072_MotionDoesntSetDot
{
	command = [parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, nil);
	STAssertNotNil(error, nil);
	STAssertEquals(error.code, (NSInteger)ViErrorParserNoDot, nil);
}

- (void)test073_MotionDoesntResetDot
{
	[parser pushKey:'c' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertFalse(command.fromDot, nil);
	STAssertTrue(command.motion.hasOperator, nil);
	command = [parser pushKey:'j' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertFalse(command.fromDot, nil);
	STAssertFalse(command.hasOperator, nil);
	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(change:), nil);
	STAssertEquals(command.motion.mapping.action, @selector(word_forward:), nil);
	STAssertTrue(command.fromDot, nil);
	STAssertTrue(command.motion.hasOperator, nil);
}

- (void)test074_DotCommandChangesWithCommands
{
	[parser pushKey:'x' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'X' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEquals(command.mapping.action, @selector(delete_backward:), nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test075_DotCommandInheritsCount
{
	[parser pushKey:'3' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'x' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEquals(command.mapping.action, @selector(delete_forward:), nil);
	STAssertEquals(command.count, 3, nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test075_DotCommandInheritsMotionCount
{
	[parser pushKey:'d' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'2' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEquals(command.mapping.action, @selector(delete:), nil);
	STAssertEquals(command.motion.mapping.action, @selector(word_forward:), nil);
	STAssertEquals(command.motion.count, 2, nil);
	STAssertEquals(command.count, 0, nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test076_DotCommandWithCountOverridesOriginal
{
	[parser pushKey:'2' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'d' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEquals(command.motion.count, 2, nil);
	STAssertEquals(command.count, 0, nil);
	[parser pushKey:'3' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEqualObjects(command.mapping.keyString, @"d", nil);
	STAssertEquals(command.motion.mapping.action, @selector(word_forward:), nil);
	STAssertEquals(command.motion.count, 3, nil);
	STAssertEquals(command.count, 0, nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test077_DotCommandWithMultiplicativeCountOverridesOriginal
{
	[parser pushKey:'2' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'d' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'4' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'w' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEquals(command.count, 0, nil);
	STAssertEquals(command.motion.count, 8, nil);
	STAssertFalse(command.fromDot, nil);
	[parser pushKey:'3' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEquals(command.count, 0, nil);
	STAssertEquals(command.motion.count, 3, nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test078_GCommandSetsLineMode
{
	command = [parser pushKey:'d' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertFalse(command.isLineMode, nil);
	command = [parser pushKey:'G' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertTrue(command.isLineMode, nil);
	STAssertEquals(command.count, 0, nil);
	STAssertEquals(command.motion.count, 0, nil);
}

- (void)test078_gUUCommandSetsLineMode
{
	command = [parser pushKey:'g' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertFalse(command.isLineMode, nil);
	command = [parser pushKey:'U' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertFalse(command.isLineMode, nil);
	command = [parser pushKey:'U' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertTrue(command.isLineMode, nil);
	STAssertEquals(command.mapping.action, @selector(uppercase:), nil);
}

- (void)test080_tCommandRequiresArgument
{
	command = [parser pushKey:'t' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, nil);
	STAssertNil(error, nil);
	command = [parser pushKey:'x' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.argument, (unichar)'x', nil);
}

- (void)test081_tCommandRequiresCharacterWithRepeatCount
{
	[parser pushKey:'3' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'t' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, nil);
	command = [parser pushKey:'x' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.argument, (unichar)'x', nil);
	STAssertEquals(command.count, 3, nil);
}

- (void)test081_CommandWithArgumentAsMotionComponent
{
	[parser pushKey:'d' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'t' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, nil);
	command = [parser pushKey:'x' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.argument, (unichar)0, nil);
	STAssertEquals(command.motion.argument, (unichar)'x', nil);
	STAssertEquals(command.motion.mapping.action, @selector(move_til_char:), nil);
}

- (void)test081_UnicharAsArgument
{
	[parser pushKey:'t' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	NSString *euro = @"€";
	unichar ch = [euro characterAtIndex:0];
	command = [parser pushKey:ch allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEquals(command.argument, ch, nil);
}

- (void)test090_DotCommandWithInsertedText
{
	command = [parser pushKey:'a' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	// input text
	[command setText:[@"apa" keyCodes]];

	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(append:), nil);
	STAssertEqualObjects(command.text, [@"apa" keyCodes], nil);

	command = [parser pushKey:'x' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertNil(command.text, nil);
}

- (void)test091_MotionCommandsDontResetRepeatText
{
	command = [parser pushKey:'i' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	// input text
	[command setText:[@"apa" keyCodes]];

	command = [parser pushKey:'j' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command.text, nil);

	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEqualObjects(command.text, [@"apa" keyCodes], nil);
}

- (void)test092_CommandsWithArgumentRememberArgument
{
	[parser pushKey:'d' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'f' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'a' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEquals(command.argument, (unichar)0, nil);
	STAssertEquals(command.motion.argument, (unichar)'a', nil);

	command = [parser pushKey:'j' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEquals(command.argument, (unichar)0, nil);

	command = [parser pushKey:'.' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertEquals(command.argument, (unichar)0, nil);
	STAssertEquals(command.motion.argument, (unichar)'a', nil);
	STAssertTrue(command.fromDot, nil);
}

- (void)test093_PrefixKeys
{
	command = [parser pushKey:0x17 allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];	// C-w
	STAssertNil(command, nil);
	STAssertNil(error, nil);
	command = [parser pushKey:'l' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, nil);
	STAssertEquals(command.mapping.action, @selector(window_right:), nil);
}

/* d10gg should be the same as d10G
 */
- (void)test094_MotionComponentInChainedMaps
{
	[parser pushKey:'d' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'1' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	[parser pushKey:'0' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	command = [parser pushKey:'g' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNil(command, @"g is not a complete motion command");
	STAssertNil(error, nil);
	command = [parser pushKey:'g' allowMacros:YES scope:nil timeout:nil excessKeys:nil error:&error];
	STAssertNotNil(command, @"g is a complete motion command");
	STAssertNil(error, nil);
	STAssertEquals(command.motion.count, 10, nil);
	STAssertEquals(command.action, @selector(delete:), nil);
	STAssertEquals(command.motion.mapping.action, @selector(goto_line:), nil);
}

@end

