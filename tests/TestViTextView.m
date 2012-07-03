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

#import "TestViTextView.h"

/* Given an input text and location, apply the command keys and check
 * that the result is what we expect.
 */
#define TEST(inText, inLocation, commandKeys, outText, outLocation)          \
	[vi setString:inText];                                               \
	[vi setCaret:inLocation];                                            \
	[vi input:commandKeys];                                              \
	STAssertEqualObjects([[vi textStorage] string], outText, nil);       \
	STAssertEquals([vi caret], (NSUInteger)outLocation, nil);

/* motion commands don't alter the text */
#define MOVE(inText, inLocation, commandKeys, outLocation) \
        TEST(inText, inLocation, commandKeys, inText, outLocation)

#define DUMMY	/* workaround for syntax highlighting */

@implementation TestViTextView

- (void)setUp
{
	vi = [[ViTextView alloc] initWithFrame:NSMakeRect(0, 0, 320, 200)];
	parser = [[ViParser alloc] initWithDefaultMap:[ViMap normalMap]];
	[parser setNviStyleUndo:YES];
	[[vi layoutManager] replaceTextStorage:[[ViTextStorage alloc] init]];
	[vi initWithDocument:nil viParser:parser];
}

- (void)test001_AllocateTextView		{ STAssertNotNil(vi, nil); }
- (void)test002_SetString			{ [vi setString:@"sample"]; STAssertEqualObjects([[vi textStorage] string], @"sample", nil); }

- (void)test010_InsertText			{ TEST(@"abc def", 3, @"i qwerty", @"abc qwerty def\n", 10); }
- (void)test010_InsertTextAndEscape		{ TEST(@"abc def", 3, @"i qwerty\x1b", @"abc qwerty def\n", 9); }
- (void)test011_InsertMovesBackward		{ TEST(@"abc def", 3, @"i\x1b", @"abc def", 2); }
- (void)test012_ChangeWord			{ TEST(@"abc\ndef", 1, @"cwcb\x1b", @"acb\ndef\n", 2); }
- (void)test013_ChangeWordAndPut		{ TEST(@"abc def", 0, @"cwapa\x1b$p", @"apa defabc\n", 7); }
- (void)test014_AppendText			{ TEST(@"abc", 2, @"adef\x1b", @"abcdef\n", 5); }
- (void)test015_RepeatAppendText		{ TEST(@"abc", 1, @"adef\x1b.", @"abdefdefc\n", 7); }
- (void)test016_RepeatInsertText		{ TEST(@"abc", 2, @"idef\x1b.", @"abdedeffc\n", 6); }
- (void)test017_InsertAtBOLAndRepeat		{ TEST(@"abc", 2, @"I+\x1bll.", @"++abc\n", 0); }
- (void)test017_InsertAtBOLAndRepeat2		{ TEST(@"abc", 2, @"I#\x1bll.", @"##abc\n", 0); }
- (void)test018_AppendAtEOLAndRepeat		{ TEST(@"abc", 0, @"A!\x1bhh.", @"abc!!\n", 4); }
- (void)test019_InsertEmptyTextAndRepeat	{ TEST(@"abc", 2, @"i\x1b.i", @"abc", 0); }

- (void)test020_DeleteForward			{ TEST(@"abcdef", 0, @"x", @"bcdef\n", 0); }
- (void)test021_DeleteForwardAtEol		{ TEST(@"abc\ndef", 2, @"x", @"ab\ndef\n", 1); }
- (void)test022_DeleteForewardWithCount		{ TEST(@"abcdef", 1, @"3x", @"aef\n", 1); }
- (void)test023_DeleteForwardWithLargeCount	{ TEST(@"abcdef\nghi", 4, @"33x", @"abcd\nghi\n", 3); }
- (void)test024_DeleteForwardAndPut		{ TEST(@"abc", 0, @"xlp", @"bca\n", 2); }
- (void)test025_RepeatDeleteForward		{ TEST(@"abcdef", 0, @"x..", @"def\n", 0); }
- (void)test026_DeleteRightAtEOL		{ TEST(@"x", 0, @"dl", @"", 0); }

- (void)test030_DeleteBackward			{ TEST(@"abcdef", 3, @"X", @"abdef\n", 2); }
- (void)test031_DeleteBackwardAtBol		{ TEST(@"abcdef", 0, @"X", @"abcdef", 0); }
- (void)test032_DeleteBackwardWithCount		{ TEST(@"abcdef", 5, @"4X", @"af\n", 1); }
- (void)test033_DeleteBackwardWithLargeCount	{ TEST(@"abcdef", 2, @"7X", @"cdef\n", 0); }
- (void)test034_DeleteBackwardAndPut		{ TEST(@"abc", 1, @"Xlp", @"bca\n", 2); }

- (void)test040_WordForward			{ MOVE(@"abc def", 0, @"w", 4); }
- (void)test041_WordForwardFromBlanks		{ MOVE(@"   abc def", 0, @"w", 3); }
- (void)test042_WordForwardToNonword		{ MOVE(@"abc() def", 0, @"w", 3); }
- (void)test043_WordForwardFromNonword		{ MOVE(@"abc() def", 3, @"w", 6); }
- (void)test044_WordForwardAcrossLines		{ MOVE(@"abc\n def", 2, @"w", 5); }
- (void)test045_WordForwardAtEOL		{ MOVE(@"abc def", 4, @"w", 6); }
- (void)test046_TwoWordsForward			{ MOVE(@"abc def ghi", 0, @"2w", 8); }

- (void)test050_DeleteWordForward		{ TEST(@"abc def", 0, @"dw", @"def\n", 0); }
- (void)test051_DeleteWordForward2		{ TEST(@"abc def", 1, @"dw", @"adef\n", 1); }
- (void)test052_DeleteWordForward3		{ TEST(@"abc def", 4, @"dw", @"abc \n", 3); }
- (void)test053_DeleteWordForwardAtEol		{ TEST(@"abc def\nghi", 4, @"dw", @"abc \nghi\n", 3); }
- (void)test054_DeleteWordForwardAtEmptyLine	{ TEST(@"\nabc", 0, @"dw", @"abc\n", 0); }
- (void)test055_DeleteWordForwardToNonword	{ TEST(@"abc:def", 0, @"dw", @":def\n", 0); }

- (void)test060_GotoColumnZero			{ MOVE(@"abc def", 4, @"0", 0); }
- (void)test061_GotoColumnZeroWthLeadingBlanks	{ MOVE(@"    def", 4, @"0", 0); }
- (void)test062_GotoLastLine			{ MOVE(@"abc\ndef\nghi", 5, @"G", 8); }
- (void)test062_GotoLastLine2			{ MOVE(@"abc\ndef\nghi\n", 5, @"G", 8); }
- (void)test062_GotoLastLine3			{ MOVE(@"abc\ndef\nghi\n\n", 5, @"G", 12); }
- (void)test063_GotoFirstLine			{ MOVE(@"abc\ndef\nghi", 5, @"1G", 0); }
- (void)test064_GotoSecondLine			{ MOVE(@"abc\ndef\nghi", 7, @"2G", 4); }
- (void)test065_GotoBeyondLastLine		{ MOVE(@"abc\ndef\nghi", 2, @"220G", 2); }
- (void)test066_GotoEndOfLine			{ MOVE(@"abc def\nghi\n", 2, @"$", 6); }
- (void)test066_GotoEndOfLine2			{ MOVE(@"abc def\nghi\n", 2, @"2$", 10); }

- (void)test070_DeleteCurrentLine		{ TEST(@"abc\ndef\nghi", 2, @"dd", @"def\nghi\n", 0); }
- (void)test071_DeleteToColumnZero		{ TEST(@"abc def", 4, @"d0", @"def\n", 0); }
- (void)test072_DeleteToEOL			{ TEST(@"abc def", 0, @"d$", @"", 0); } // XXX: shouldn't this be @"\n"?
- (void)test073_DeleteLastLine			{ TEST(@"abc\ndef", 5, @"dd", @"abc\n", 0); }
- (void)test074_DeleteToFirstLine		{ TEST(@"abc\ndef\nghi", 5, @"d1G", @"ghi\n", 0); }
- (void)test075_DeleteToLastLine		{ TEST(@"abc\ndef\nghi\njkl", 5, @"dG", @"abc\n", 0); }
- (void)test076_DeleteAndPut			{ TEST(@"abc def", 0, @"dw$p", @"defabc \n", 3); }
- (void)test077_DeleteToEOL2			{ TEST(@"abc def", 2, @"D", @"ab\n", 1); }
- (void)test078_DeleteTwoLines			{ TEST(@"abc\ndef\nghi", 1, @"2dd", @"ghi\n", 0); }
- (void)test078_DeleteTwoLines2			{ TEST(@"abc\ndef\nghi", 1, @"d2d", @"ghi\n", 0); }

- (void)test080_YankWord			{ TEST(@"abc def ghi", 4, @"yw", @"abc def ghi", 4); }
- (void)test080_YankWordAndPaste		{ TEST(@"abc def ghi", 4, @"ywwP", @"abc def def ghi\n", 8); }
- (void)test081_YankWord2			{ TEST(@"abc def ghi", 8, @"yw0p", @"aghibc def ghi\n", 1); }
- (void)test082_YankBackwards			{ TEST(@"abcdef", 3, @"y0", @"abcdef", 0); }
- (void)test083_YankBackwardsAndPaste		{ TEST(@"abcdef", 3, @"y0p", @"aabcbcdef\n", 1); }
- (void)test084_YankWordAndPasteAtEOL		{ TEST(@"abc def", 4, @"yw$p", @"abc defdef\n", 7); }
- (void)test085_YankLine			{ TEST(@"abc\ndef", 2, @"yy", @"abc\ndef", 2); }
- (void)test086_YankAndPasteLine		{ TEST(@"abc\ndef\nghi", 1, @"yyp", @"abc\nabc\ndef\nghi\n", 4); }
- (void)test086_YankAndPasteLine2		{ TEST(@"abc\ndef\nghi", 1, @"ylYp", @"abc\nabc\ndef\nghi\n", 4); }
- (void)test087_YankAndPasteLineBefore		{ TEST(@"abc\ndef\nghi", 5, @"yyP", @"abc\ndef\ndef\nghi\n", 4); }

- (void)test090_MoveTilChar			{ MOVE(@"abc def ghi", 1, @"tf", 5); }
- (void)test090_MoveTilChar2			{ MOVE(@"abc def abc", 1, @"tc", 1); }
- (void)test091_MoveToChar			{ MOVE(@"abc def ghi", 1, @"ff", 6); }
- (void)test091_MoveToChar2			{ MOVE(@"abc def abc", 1, @"fb", 9); }
- (void)test092_DeleteToChar			{ TEST(@"abc def abc", 1, @"dfe", @"af abc\n", 1); }
- (void)test093_MoveToCharWithCount		{ MOVE(@"abc abc abc", 0, @"2fa", 8); }
- (void)test094_DeleteToCharWithCount		{ TEST(@"abc abc abc", 0, @"d2fa", @"bc\n", 0); }
- (void)test095_DeleteTilCharWithCount		{ TEST(@"abc abc abc", 0, @"d2ta", @"abc\n", 0); }
- (void)test096_RepeatMoveTilChar		{ MOVE(@"abc abc abc", 2, @"ta;", 3); }
- (void)test097_RepeatMoveToChar		{ MOVE(@"abc abc abc", 2, @"fa;", 8); }
- (void)test097_RepeatMoveToChar2		{ MOVE(@"abc abc abc abc", 2, @"fa2;", 12); }
- (void)test097_DeleteToRepeatedMove		{ TEST(@"abc abc abc abc", 2, @"fad2;", @"abc bc\n", 4); }
- (void)test097_DeleteToRepeatedMove2		{ TEST(@"abc abc abc abc", 2, @"fa2d;", @"abc bc\n", 4); }
- (void)test098_ChangeToChar			{ TEST(@"abc abc abc", 0, @"ct ABC\x1bw", @"ABC abc abc\n", 4); }
- (void)test099_RepeatChangeToChar		{ TEST(@"abc abc abc", 0, @"ct ABC\x1bw.", @"ABC ABC abc\n", 6); }
- (void)test099_MoveToCharFail			{ MOVE(@"", 0, @"fo", 0); }
- (void)test099_MoveBackToCharFail		{ MOVE(@"", 0, @"Fo", 0); }

- (void)test100_WordBackward			{ MOVE(@"abcdef", 4, @"b", 0); }
- (void)test100_WordBackward2			{ MOVE(@"abc def", 4, @"b", 0); }
- (void)test100_WordBackward3			{ MOVE(@"abc def ghi", 8, @"b", 4); }
- (void)test100_WordBackward4			{ MOVE(@"<abc>def", 4, @"b", 1); }
- (void)test100_WordBackward5			{ MOVE(@"<abc>def", 5, @"b", 4); }
- (void)test100_WordBackward6			{ MOVE(@"<abc def", 5, @"b", 1); }
- (void)test100_WordBackward7			{ MOVE(@"<abc", 1, @"b", 0); }
- (void)test100_WordBackward8			{ MOVE(@"<abc> def", 6, @"b", 4); }
- (void)test100_WordBackward9			{ MOVE(@"  abc", 2, @"b", 0); }
- (void)test101_TwoWordsBackward		{ MOVE(@"abc def ghi", 8, @"2b", 0); }
- (void)test102_TooManyWordsBackward		{ MOVE(@"abc def ghi", 8, @"3b", 0); }

- (void)test110_MoveDown			{ MOVE(@"abc\ndef", 1, @"j", 5); }
- (void)test111_MoveDownAcrossTab		{ MOVE(@"abcdefghijklmno\n\tabcdef", 10, @"j", 19); }
- (void)test112_MoveToFirstNonspace		{ MOVE(@"   abc", 5, @"_", 3); }
- (void)test112_MoveToFirstNonspace2		{ MOVE(@"   abc", 5, @"^", 3); }
- (void)test113_MoveDownOverRaggedLines		{ MOVE(@"abcdef\nabc\nabcdef", 4, @"jj", 15); }
- (void)test114_MoveDownMultipleLines		{ MOVE(@"abc\ndef\nabc\nabc\ndef", 1, @"3j", 13); }
- (void)test115_MoveUpMultipleLines		{ MOVE(@"abc\ndef\nabc\nabc\ndef", 13, @"3k", 1); }

// The Join command is a mess of special cases...
- (void)test120_JoinLines			{ TEST(@"abc\ndef", 0, @"J", @"abc def\n", 3); }
- (void)test121_JoinLinesWithWhitespace		{ TEST(@"abc\n\t  def", 0, @"J", @"abc def\n", 3); }
- (void)test122_JoinEmptyLine			{ TEST(@"abc\n\ndef", 0, @"J", @"abc\ndef\n", 2); }
- (void)test123_JoinFromEmptyLine		{ TEST(@"\ndef", 0, @"J", @"def\n", 2); }
- (void)test123_JoinFromEmptyLine2		{ TEST(@"\r\ndefghi", 0, @"J", @"defghi\n", 5); }
- (void)test124_JoinFromLineEndingWithSpaces	{ TEST(@"abc   \ndef", 0, @"J", @"abc   def\n", 5); }
- (void)test125_JoinFromFinishedSentence	{ TEST(@"abc.\ndef", 0, @"J", @"abc.  def\n", 4); }
- (void)test125_JoinFromFinishedSentence2	{ TEST(@"abc!\n  def", 0, @"J", @"abc!  def\n", 4); }
- (void)test125_JoinFromFinishedSentence3	{ TEST(@"abc?\n   def", 0, @"J", @"abc?  def\n", 4); }
- (void)test126_JoinLineStartingWithParen	{ TEST(@"abc\n)def", 0, @"J", @"abc)def\n", 2); }

- (void)test130_ReplaceChar			{ TEST(@"abc def", 2, @"rx", @"abx def\n", 2); }

- (void)test140_BigwordForward			{ MOVE(@"abc=def ghi", 0, @"W", 8); }
- (void)test141_BigwordForwardSpace		{ MOVE(@"abc     ghi", 3, @"W", 8); }
- (void)test142_BigwordBackward			{ MOVE(@"abc=def ghi", 8, @"B", 0); }
- (void)test143_DeleteBigwordBackward		{ TEST(@"abc=def ghi", 8, @"dB", @"ghi\n", 0); }
- (void)test144_TwoBigwordsForward		{ MOVE(@"abc=def ghi jkl", 0, @"2W", 12); }
- (void)test145_TwoBigwordsBackward		{ MOVE(@"abc=def ghi jkl", 12, @"2B", 0); }

- (void)test150_EndOfWord			{ MOVE(@"abc def", 0, @"e", 2); }
- (void)test151_EndOfWordFromBlanks		{ MOVE(@"   abc def", 0, @"e", 5); }
- (void)test152_EndOfWordToNonword		{ MOVE(@"a_b() def", 0, @"e", 2); }
- (void)test153_EndOfWordFromNonword		{ MOVE(@"a_b() def", 3, @"e", 4); }
- (void)test154_DeleteToEndOfWordToNonword	{ TEST(@"abc:def", 0, @"de", @":def\n", 0); }
- (void)test155_EndOfBigword			{ MOVE(@"abc:def ghi", 0, @"E", 6); }
- (void)test156_EndOfBigwordFromBlanks		{ MOVE(@"   abc:def ghi", 0, @"E", 9); }
- (void)test156_EndOfBigwordFromNonword		{ MOVE(@"abc:def ghi", 3, @"E", 6); }
- (void)test157_DeleteToEndOfBigwordToNonword	{ TEST(@"abc:def ghi", 0, @"dE", @" ghi\n", 0); }
- (void)test158_DeleteToEndOfWordFromBlanks	{ TEST(@"abc    def", 4, @"de", @"abc \n", 3); }

- (void)test160_DeleteAndUndo			{ TEST(@"abc def", 2, @"xu", @"abc def", 2); }
- (void)test160_DeleteAndUndo2			{ TEST(@"abc def", 2, @"xxu", @"ab def\n", 2); }
- (void)test161_InsertAndUndo			{ TEST(@"abc def", 2, @"i ghi\x1bu", @"abc def", 2); }
// the 'a' command is the only exception to caret location after undo, but actually
// vim differs from nvi here and just places the caret at the beginning of the changed text, like 'i'
- (void)test162_AppendAndUndo			{ TEST(@"abc def\n", 2, @"a ghi\x1bu", @"abc def\n", 3); }
- (void)test162_AppendToEmptyLineAndUndo	{ TEST(@"", 0, @"aabc\x1bu", @"", 0); }
- (void)test162_AppendAtEOLAndUndo		{ TEST(@"abc def\n", 2, @"A ghi\x1bu", @"abc def\n", 6); }
- (void)test162_AppendAtEOToEmptyLineAndUndo	{ TEST(@"", 0, @"Aabc\x1bu", @"", 0); }
- (void)test163_UndoRedo			{ TEST(@"abc def", 0, @"xxxxuu", @"def\n", 0); }
- (void)test164_RepeatUndo			{ TEST(@"abc def", 0, @"xxxxu..", @"bc def\n", 0); }
- (void)test165_RepeatRedo			{ TEST(@"abc def", 0, @"xxxxu..u.", @" def\n", 0); }
- (void)test166_UndoAndRedoEdit			{ TEST(@"ab cd ef gh", 0, @"ix\x1bw.uw.", @"xab cd xef gh\n", 7); }

- (void)test170_ShiftLineRight			{ TEST(@"abc\ndef", 0, @">>", @"\tabc\ndef\n", 1); }
- (void)test171_ShiftTwoLinesRight		{ TEST(@" abc\n\tdef\nghi", 0, @"2>>", @"\t abc\n\t\tdef\nghi\n", 2); }
- (void)test172_ShiftThreeLinesRight		{ TEST(@" abc\n\tdef\nghi\njkl", 0, @"3>>", @"\t abc\n\t\tdef\n\tghi\njkl\n", 2); }
- (void)test173_ShiftLineLeft			{ TEST(@"\t\tabc\ndef", 3, @"<<", @"\tabc\ndef\n", 1); }
- (void)test174_ShiftTwoLinesLeft		{ TEST(@" abc\n\tdef\nghi", 2, @"2<<", @"abc\ndef\nghi\n", 0); }
- (void)test175_ShiftLineLeftAtColumn0		{ TEST(@"abc\n\tdef", 4, @"<<", @"abc\ndef\n", 4); }

- (void)test180_OpenLineAbove			{ TEST(@"abc\ndef", 4, @"Oxxx\x1b", @"abc\nxxx\ndef\n", 6); }
- (void)test181_DeleteToChar			{ TEST(@"abc def ghi", 0, @"df ", @"def ghi\n", 0); }
- (void)test182_DeleteToCharAndRepeat		{ TEST(@"abc def ghi", 0, @"df .", @"ghi\n", 0); }

- (void)test190_SubstLine			{ TEST(@"abc\ndef\nghi", 5, @"Sapa\x1b", @"abc\napa\nghi\n", 6); }
- (void)test191_SubstLastLine			{ TEST(@"abc\ndef\nghi", 8, @"Sapa\x1b", @"abc\ndef\napa\n", 10); }

- (void)test200_MoveBackwardTilChar		{ MOVE(@"abc def ghi", 8, @"Tf", 7); }
- (void)test200_MoveBackwardTilChar2		{ MOVE(@"abc def abc", 3, @"Tc", 3); }
- (void)test201_MoveBackwardToChar		{ MOVE(@"abc def ghi", 8, @"Ff", 6); }
- (void)test201_MoveBackwardToChar2		{ MOVE(@"abc def abc", 9, @"Fb", 1); }
- (void)test202_DeleteBackwardToChar		{ TEST(@"abc def abc", 9, @"dFe", @"abc dbc\n", 5); }
- (void)test203_MoveBackwardToCharWithCount	{ MOVE(@"abc abc abc", 10, @"2Fa", 4); }
- (void)test204_DeleteBackwardToCharWithCount	{ TEST(@"abc abc abc", 10, @"d2Fa", @"abc c\n", 4); }
- (void)test205_DeleteBackwardTilCharWithCount	{ TEST(@"abc abc abc", 10, @"d2Ta", @"abc ac\n", 5); }
- (void)test206_RepeatMoveBackwardTilChar	{ MOVE(@"abc abc abc", 7, @"Ta;", 5); }
- (void)test207_RepeatMoveBackwardToChar	{ MOVE(@"abc abc abc", 7, @"Fa;", 0); }
- (void)test208_RepeatOtherDirection		{ MOVE(@"abc abc abc", 0, @"fa;,", 4); }

- (void)test210_FindForward			{ MOVE(@"abc def ghi", 0, @"/g<cr>", 8); }

- (void)test220_ChangeWordAtEnd			{ TEST(@"apa", 0, @"cwb<esc>", @"b\n", 0); }
- (void)test220_ChangeWordAndRepeatNearEnd	{ TEST(@"apa\napa", 0, @"cwb<esc>j.", @"b\nb\n", 2); }

- (void)test230_UpperCaseWord			{ TEST(@"abc def ghi", 0, @"gUw", @"ABC def ghi\n", 0); }
- (void)test231_UpperCaseTwoWords		{ TEST(@"abc def ghi", 0, @"2gUw", @"ABC DEF ghi\n", 0); }
- (void)test232_LowerCaseWord			{ TEST(@"ABC DEF GHI", 0, @"guw", @"abc DEF GHI\n", 0); }
- (void)test233_LowerCaseTwoWords		{ TEST(@"ABC DEF GHI", 0, @"2guw", @"abc def GHI\n", 0); }
- (void)test234_UpperCaseUnicode		{ TEST(@"ÅäöéÉ", 0, @"gUU", @"ÅÄÖÉÉ\n", 0); }

- (void)test240_InsertMultipliedText		{ TEST(@"", 0, @"5ix<esc>", @"xxxxx\n", 4); }
- (void)test241_InsertMultipliedText2		{ TEST(@"", 0, @"5iabc<esc>", @"abcabcabcabcabc\n", 14); }
- (void)test242_InsertMultipliedText3		{ TEST(@"", 0, @"ix<esc>""4.", @"xxxxx\n", 3); }
- (void)test243_RepeatInsertMultipliedText	{ TEST(@"x", 0, @"5ab<esc>.", @"xbbbbbbbbbb\n", 10); }
- (void)test244_RepeatTwiceInsertMultipliedText	{ TEST(@"x", 0, @"5ab<esc>..", @"xbbbbbbbbbbbbbbb\n", 15); }
//- (void)test245_OpenWithMultipliedText		{ TEST(@"abc\n", 1, @"3Odef\x1b", @"def\ndef\ndef\nabc\n", 10); }

@end

