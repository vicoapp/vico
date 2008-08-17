#import "TestViTextView.h"

/* Given an input text and location, apply the command keys and check
 * that the result is what we expect.
 */
#define TEST(inText, inLocation, commandKeys, outText, outLocation)          \
	[vi setString:inText];                                               \
	[vi setSelectedRange:NSMakeRange(inLocation, 0)];                    \
	[vi input:commandKeys];                                              \
	STAssertEqualObjects([[vi textStorage] string], outText, nil);       \
	STAssertEquals([vi selectedRange].location, (NSUInteger)outLocation, nil);

/* motion commands don't alter the text */
#define MOVE(inText, inLocation, commandKeys, outLocation) \
	TEST(inText, inLocation, commandKeys, inText, outLocation)

@implementation TestViTextView

- (void)setUp
{
	vi = [[ViTextView alloc] initWithFrame:NSMakeRect(0, 0, 320, 200)];
	[vi initEditor];
}

- (void)test001_AllocateTextView		{ STAssertNotNil(vi, nil); }

#if 0
// FIXME: input keys passed through to the super NSTextView doesn't work yet
- (void)test010_InsertText			{ TEST(@"abc def", 3, @"i qwerty", @"abc qwerty def", 9); }
#endif

- (void)test020_DeleteForward			{ TEST(@"abcdef", 0, @"x", @"bcdef", 0); }
- (void)test021_DeleteForwardAtEol		{ TEST(@"abc\ndef", 2, @"x", @"ab\ndef", 1); }
- (void)test022_DeleteForewardWithCount		{ TEST(@"abcdef", 1, @"3x", @"aef", 1); }
- (void)test022_DeleteForwardWithLargeCount	{ TEST(@"abcdef\nghi", 4, @"33x", @"abcd\nghi", 4); }

- (void)test030_DeleteBackward			{ TEST(@"abcdef", 3, @"X", @"abdef", 2); }
- (void)test030_DeleteBackwardAtBol		{ TEST(@"abcdef", 0, @"X", @"abcdef", 0); }
- (void)test030_DeleteBackwardWithCount		{ TEST(@"abcdef", 5, @"4X", @"af", 1); }
- (void)test030_DeleteBackwordWithLargeCount	{ TEST(@"abcdef", 2, @"7X", @"cdef", 0); }

- (void)test040_WordForward			{ MOVE(@"abc def", 0, @"w", 4); }
- (void)test041_WordForwardFromBlanks		{ MOVE(@"   abc def", 0, @"w", 3); }
- (void)test041_WordForwardToNonword		{ MOVE(@"abc() def", 0, @"w", 3); }
- (void)test041_WordForwardFromNonword		{ MOVE(@"abc() def", 3, @"w", 6); }
- (void)test041_WordForwardAcrossLines		{ MOVE(@"abc\n def", 2, @"w", 5); }

- (void)test050_DeleteWordForward		{ TEST(@"abc def", 0, @"dw", @"def", 0); }
- (void)test051_DeleteWordForward2		{ TEST(@"abc def", 1, @"dw", @"adef", 1); }
- (void)test052_DeleteWordForward3		{ TEST(@"abc def", 4, @"dw", @"abc ", 3); }
- (void)test053_DeleteWordForwardAtEol		{ TEST(@"abc def\nghi", 4, @"dw", @"abc \nghi", 3); }

- (void)test060_GotoColumnZero			{ MOVE(@"abc def", 4, @"0", 0); }
- (void)test060_GotoColumnZeroWthLeadingBlanks	{ MOVE(@"    def", 4, @"0", 0); }

- (void)test070_DeleteCurrentLine		{ TEST(@"abc\ndef\nghi", 2, @"dd", @"def\nghi", 0); }

- (void)test080_YankWord			{ TEST(@"abc def ghi", 4, @"ywwP", @"abc def def ghi", 8); }
- (void)test081_YankWord2			{ TEST(@"abc def ghi", 8, @"yw0p", @"aghibc def ghi", 1); }

@end
