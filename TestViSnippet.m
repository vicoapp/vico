#import "TestViSnippet.h"
#include "logging.h"

@interface MockDelegate : NSObject <ViSnippetDelegate>
{
	NSMutableString *storage;
}
@end

@implementation MockDelegate
- (id)init
{
	if ((self = [super init]) != nil)
		storage = [NSMutableString string];
	return self;
}
- (void)snippet:(ViSnippet *)snippet replaceCharactersInRange:(NSRange)range withString:(NSString *)string
{
	[storage replaceCharactersInRange:range withString:string];
}
- (NSString *)string
{
	return storage;
}
@end

@implementation TestViSnippet

- (void)setUp
{
	env = [NSDictionary dictionaryWithObjectsAndKeys:
	    @"this is the selected text", @"TM_SELECTED_TEXT",
	    @"this selection\nspans\n\nseveral\nlines", @"TM_SELECTED_TEXT2",
	    @"martinh", @"USER",
	    @"TestViSnippet.m", @"TM_FILENAME",
	    nil
	];
	delegate = [[MockDelegate alloc] init];
}

- (void)makeSnippet:(NSString *)snippetString
{
	err = nil;
	snippet = [[ViSnippet alloc] initWithString:snippetString
	                                 atLocation:0
	                                   delegate:delegate
	                                environment:env
	                                      error:&err];
	if (err)
		INFO(@"error: %@", [err localizedDescription]);
	STAssertNotNil(snippet, nil);
	STAssertNil(err, nil);
}

- (void)test001_simpleAbbreviation
{
	[self makeSnippet:@"a long string"];
	STAssertEqualObjects([snippet string], @"a long string", nil);
	STAssertEquals([snippet caret], 13ULL, nil);
}

- (void)test002_escapeReservedCharacters
{
	[self makeSnippet:@"a dollar sign: \\$, \\a bactick: \\`, and a \\\\"];
	STAssertEqualObjects([snippet string], @"a dollar sign: $, \\a bactick: `, and a \\", nil);
	STAssertEquals([snippet caret], 40ULL, nil);
}

- (void)test003_simpleVariable
{
	[self makeSnippet:@"\\textbf{$TM_SELECTED_TEXT}"];
	STAssertEqualObjects([snippet string], @"\\textbf{this is the selected text}", nil);
}

- (void)test004_simpleUndefinedVariable
{
	[self makeSnippet:@"\\textbf{$THIS_VARIABLE_IS_UNDEFINED}"];
	STAssertEqualObjects([snippet string], @"\\textbf{}", nil);
}

- (void)test005_defaultValue
{
	[self makeSnippet:@"\\textbf{${THIS_VARIABLE_IS_UNDEFINED:the variable is undefined}}"];
	STAssertEqualObjects([snippet string], @"\\textbf{the variable is undefined}", nil);
}

- (void)test006_emptyDefaultValue
{
	[self makeSnippet:@"\\textbf{${THIS_VARIABLE_IS_UNDEFINED:}}"];
	STAssertEqualObjects([snippet string], @"\\textbf{}", nil);
}

- (void)test007_missingClosingBrace
{
	snippet = [[ViSnippet alloc] initWithString:@"foo(${THIS_VARIABLE_IS_UNDEFINED:default value)"
	                                 atLocation:0
	                                   delegate:delegate
	                                environment:env
	                                      error:&err];
	STAssertNil(snippet, nil);
	STAssertNotNil(err, nil);
	INFO(@"expected error: %@", [err localizedDescription]);
}

- (void)test008_defaultValueWithEscapedClosingBrace
{
	[self makeSnippet:@"foo(${THIS_VARIABLE_IS_UNDEFINED:\\{braces\\}})"];
	STAssertEqualObjects([snippet string], @"foo(\\{braces})", nil);
}

/* The default value can itself contain variables or shell code. */
- (void)test009_defaultValueContainingSimpleVariable
{
	[self makeSnippet:@"User is ${THIS_VARIABLE_IS_UNDEFINED:$USER}"];
	STAssertEqualObjects([snippet string], @"User is martinh", nil);
}

- (void)test010_defaultValueContainingUndefinedVariable
{
	[self makeSnippet:@"User is ${THIS_VARIABLE_IS_UNDEFINED:$ALSO_UNDEFINED}"];
	STAssertEqualObjects([snippet string], @"User is ", nil);
}

- (void)test011_defaultValueContainingDefaultValue
{
	[self makeSnippet:@"User is ${THIS_VARIABLE_IS_UNDEFINED:${ALSO_UNDEFINED:nobody}}"];
	STAssertEqualObjects([snippet string], @"User is nobody", nil);
}

- (void)test012_regexpReplacement
{
	[self makeSnippet:@"{'user': '${USER/mar/tin/}'}"];
	STAssertEqualObjects([snippet string], @"{'user': 'tintinh'}", nil);
}

- (void)test013_multipleRegexpReplacements
{
	[self makeSnippet:@"{'text': '${TM_SELECTED_TEXT/s/ESS/g}'}"];
	STAssertEqualObjects([snippet string], @"{'text': 'thiESS iESS the ESSelected text'}", nil);
}

- (void)test014_regexpMissingSlash
{
	snippet = [[ViSnippet alloc] initWithString:@"{'user': '${USER/mar/tin}'}"
	                                 atLocation:0
	                                   delegate:delegate
	                                environment:env
	                                      error:&err];
	STAssertNil(snippet, nil);
	STAssertNotNil(err, nil);
	INFO(@"expected error: %@", [err localizedDescription]);
}

- (void)test015_regexpNoMatch
{
	[self makeSnippet:@"{'user': '${USER/foo/bar/}'}"];
	STAssertEqualObjects([snippet string], @"{'user': 'martinh'}", nil);
}

- (void)test016_regexpEmptyFormat
{
	[self makeSnippet:@"{'user': '${USER/h$//}'}"];
	STAssertEqualObjects([snippet string], @"{'user': 'martin'}", nil);
}

- (void)test017_defaultValueContainingRegexp
{
	[self makeSnippet:@"User is ${THIS_VARIABLE_IS_UNDEFINED:${USER/tin/mor/}}"];
	STAssertEqualObjects([snippet string], @"User is marmorh", nil);
}

- (void)test018_invalidRegexp
{
	snippet = [[ViSnippet alloc] initWithString:@"${USER/[x/bar/}"
	                                 atLocation:0
	                                   delegate:delegate
	                                environment:env
	                                      error:&err];
	STAssertNil(snippet, nil);
	STAssertNotNil(err, nil);
	INFO(@"expected error: %@", [err localizedDescription]);
}

- (void)test019_regexpPrepend
{
	[self makeSnippet:@"${TM_SELECTED_TEXT/^.+$/* $0/}"];
	STAssertEqualObjects([snippet string], @"* this is the selected text", nil);
}

- (void)test020_regexpPrependMultipleLines
{
	[self makeSnippet:@"${TM_SELECTED_TEXT2/^.+$/* $0/g}"];
	STAssertEqualObjects([snippet string], @"* this selection\n* spans\n\n* several\n* lines", nil);
}

- (void)test021_regexpCaptures
{
	[self makeSnippet:@"${TM_SELECTED_TEXT/^this (.*) the (.*)$/$1 $2/}"];
	STAssertEqualObjects([snippet string], @"is selected text", nil);
}

- (void)test022_simpleShellCodeInterpolation
{
	[self makeSnippet:@"<a href=\"`echo \"bacon\"`.html\">what's chunky?</a>"];
	STAssertEqualObjects([snippet string], @"<a href=\"bacon.html\">what's chunky?</a>", nil);
}

- (void)test023_nonexistantShellCommand
{
	[self makeSnippet:@"`doesntexist`"];
	STAssertEqualObjects([snippet string], @"/bin/bash: doesntexist: command not found", nil);
}

- (void)test024_shebangShellCommand
{
	[self makeSnippet:@"`#!/usr/bin/env perl\nprint(\"\\`hej\\`\");\n`"];
	STAssertEqualObjects([snippet string], @"`hej`", nil);
}

/* Shell commands have access to the environment variables. */
- (void)test024_shellCommandWithEnvironment
{
	[self makeSnippet:@"filename is `echo \"${TM_FILENAME}\"`"];
	STAssertEqualObjects([snippet string], @"filename is TestViSnippet.m", nil);
}

- (void)test025_simpleTabStop
{
	[self makeSnippet:@"<div>\n    $0\n</div>"];
	STAssertEqualObjects([snippet string], @"<div>\n    \n</div>", nil);
	STAssertEquals([snippet caret], 10ULL, nil);
}

- (void)test026_tabStopWithDefaultValue
{
	[self makeSnippet:@"#include \"${1:${TM_FILENAME/\\..+$/.h/}}\""];
	STAssertEqualObjects([snippet string], @"#include \"TestViSnippet.h\"", nil);
	STAssertEquals([snippet range].location, 0ULL, nil);
	STAssertEquals([snippet range].length, 26ULL, nil);
	NSRange r = [snippet tabRange];
	STAssertEquals(r.location, 10ULL, nil);
	STAssertEquals(r.length, 15ULL, nil);
}

- (void)test027_multipleTabStops
{
	[self makeSnippet:@"<div$1>\n    $0\n</div>"];
	STAssertEqualObjects([snippet string], @"<div>\n    \n</div>", nil);
	STAssertEquals([snippet tabRange].location, 4ULL, nil);
	STAssertEquals([snippet tabRange].length, 0ULL, nil);
	STAssertTrue([snippet advance], nil);
	STAssertEquals([snippet tabRange].location, 10ULL, nil);
	STAssertEquals([snippet tabRange].length, 0ULL, nil);
}

- (void)test028_updatePlaceHolders
{
	[self makeSnippet:@"if (${1:/* condition */})\n{\n    ${0:/* code */}\n}"];
	STAssertEqualObjects([snippet string], @"if (/* condition */)\n{\n    /* code */\n}", nil);
	STAssertEquals([snippet tabRange].location, 4ULL, nil);
	STAssertEquals([snippet tabRange].length, 15ULL, nil);

	STAssertEquals(snippet.selectedRange.location, 4ULL, nil);
	STAssertEquals(snippet.selectedRange.length, 15ULL, nil);
	[snippet deselect];
	STAssertEquals(snippet.selectedRange.location, NSNotFound, nil);
	STAssertEquals(snippet.selectedRange.length, 0ULL, nil);

	STAssertTrue([snippet replaceRange:NSMakeRange(4, 15) withString:@"p"], nil);
	STAssertEqualObjects([snippet string], @"if (p)\n{\n    /* code */\n}", nil);
	STAssertEquals([snippet tabRange].location, 4ULL, nil);
	STAssertEquals([snippet tabRange].length, 1ULL, nil);
	STAssertTrue([snippet advance], nil);

	STAssertEquals([snippet tabRange].location, 13ULL, nil);
	STAssertEquals([snippet tabRange].length, 10ULL, nil);
	STAssertTrue([snippet replaceRange:NSMakeRange(13, 10) withString:@""], nil);

	STAssertEquals([snippet tabRange].location, 13ULL, nil);
	STAssertEquals([snippet tabRange].length, 0ULL, nil);
	STAssertTrue([snippet replaceRange:NSMakeRange(13, 0) withString:@"return;"], nil);
	STAssertEquals([snippet tabRange].location, 13ULL, nil);
	STAssertEquals([snippet tabRange].length, 7ULL, nil);
}

- (void)test029_mirror
{
	[self makeSnippet:@"\\begin{${1:enumerate}}$0\\end{$1}"];
	STAssertEqualObjects([snippet string], @"\\begin{enumerate}\\end{enumerate}", nil);
	STAssertEquals([snippet tabRange].location, 7ULL, nil);
	STAssertEquals([snippet tabRange].length, 9ULL, nil);
	STAssertEquals(snippet.range.location, 0ULL, nil);
	STAssertEquals(snippet.range.length, 32ULL, nil);
	STAssertTrue([snippet replaceRange:NSMakeRange(7, 9) withString:@"itemize"], nil);
	STAssertEqualObjects([snippet string], @"\\begin{itemize}\\end{itemize}", nil);
	STAssertEquals([snippet tabRange].location, 7ULL, nil);
	STAssertEquals([snippet tabRange].length, 7ULL, nil);
	STAssertEquals(snippet.range.location, 0ULL, nil);
	STAssertEquals(snippet.range.length, 28ULL, nil);
}

/* If there are mirrors, the first tabstop with a default value
 * (placeholder) is where the caret is placed.
 */
- (void)test030_reverseMirror
{
	[self makeSnippet:@"\\begin{$1}$0\\end{${1:enumerate}}"];
	STAssertEqualObjects([snippet string], @"\\begin{enumerate}\\end{enumerate}", nil);
	STAssertEquals([snippet tabRange].location, 22ULL, nil);
	STAssertEquals([snippet tabRange].length, 9ULL, nil);
}

- (void)test031_tabstopOrdering
{
	[self makeSnippet:@"2:$2 0:$0 1:$1 3:$3 2.2:$2 2.3:$2"];
	STAssertEqualObjects([snippet string], @"2: 0: 1: 3: 2.2: 2.3:", nil);
	STAssertEquals(snippet.caret, 8ULL, nil);
	STAssertTrue([snippet advance], nil);
	STAssertEquals(snippet.caret, 2ULL, nil);
	STAssertTrue([snippet advance], nil);
	STAssertEquals(snippet.caret, 11ULL, nil);
	STAssertTrue([snippet advance], nil);
	STAssertEquals(snippet.caret, 5ULL, nil);
}

/* A tabstop can't be placed inside a default value for a shell variable. */
- (void)test032_invalidTabstopInVariable
{
	snippet = [[ViSnippet alloc] initWithString:@"hello ${USER:$1}"
	                                 atLocation:0
	                                   delegate:delegate
	                                environment:env
	                                      error:&err];
	STAssertNil(snippet, nil);
	STAssertNotNil(err, nil);
	INFO(@"expected error: %@", [err localizedDescription]);
}

/* A mirror can be transformed by a regular expression. */
- (void)test033_mirrorWithTransformation
{
	[self makeSnippet:@"tabstop:${1:bacon}\nmirror:${1/[aouåeiyäö]/$0$0/g}"];
	STAssertEqualObjects([snippet string], @"tabstop:bacon\nmirror:baacoon", nil);
	STAssertEquals(snippet.caret, 8ULL, nil);
	STAssertTrue([snippet replaceRange:snippet.selectedRange withString:@"chunky"], nil);
	STAssertEqualObjects([snippet string], @"tabstop:chunky\nmirror:chuunkyy", nil);
}

/* Tabstops can be nested. */
- (void)test037_nestedTabstops
{
	[self makeSnippet:@"x: ${1:nested ${2:tabstop}}"];
	STAssertEqualObjects([snippet string], @"x: nested tabstop", nil);
	STAssertEquals(snippet.caret, 3ULL, nil);
	STAssertEquals(snippet.selectedRange.location, 3ULL, nil);
	STAssertEquals(snippet.selectedRange.length, 14ULL, nil);
	STAssertTrue([snippet advance], nil);
	STAssertEquals(snippet.caret, 10ULL, nil);
	STAssertEquals(snippet.selectedRange.location, 10ULL, nil);
	STAssertEquals(snippet.selectedRange.length, 7ULL, nil);
	STAssertTrue([snippet replaceRange:snippet.selectedRange withString:@"placeholder"], nil);
	STAssertEqualObjects([snippet string], @"x: nested placeholder", nil);
}

/* Nested tabstops can have mirrors outside of the containing tabstop. */
- (void)test038_nestedTabstopWithMirros
{
	[self makeSnippet:@"foo: ${1:nested ${2:tabstop}}, ${2/^.*$/mirror: $0/}"];
	STAssertEqualObjects([snippet string], @"foo: nested tabstop, mirror: tabstop", nil);
}

- (void)test039_updateNestedBaseLocation
{
	[self makeSnippet:@"for(size_t ${2:i} = 0; $2 < ${1:count}; ${3:++$2})"];
	STAssertEqualObjects([snippet string], @"for(size_t i = 0; i < count; ++i)", nil);
}

- (void)test040_nestedTabstopCancelledIfParentEdited
{
	[self makeSnippet:@"${1:hello ${2:world}}"];
	STAssertEqualObjects([snippet string], @"hello world", nil);
	STAssertEquals(snippet.selectedRange.location, 0ULL, nil);
	STAssertEquals(snippet.selectedRange.length, 11ULL, nil);
	STAssertTrue([snippet replaceRange:snippet.selectedRange withString:@"goodbye"], nil);
	STAssertFalse([snippet advance], nil);
}

- (void)test041_nestedTabstopCancelledIfParentEdited_2
{
	[self makeSnippet:@"${2:hello ${1:world}}$0"];
	STAssertEqualObjects([snippet string], @"hello world", nil);
	STAssertEquals(snippet.selectedRange.location, 6ULL, nil);
	STAssertEquals(snippet.selectedRange.length, 5ULL, nil);
	STAssertTrue([snippet replaceRange:snippet.selectedRange withString:@"chunky bacon"], nil);
	STAssertEqualObjects([snippet string], @"hello chunky bacon", nil);
	STAssertTrue([snippet advance], nil);
	STAssertEquals(snippet.selectedRange.location, 0ULL, nil);
	STAssertEquals(snippet.selectedRange.length, 18ULL, nil);
	STAssertTrue([snippet replaceRange:snippet.selectedRange withString:@"goodbye"], nil);
	STAssertEqualObjects([snippet string], @"goodbye", nil);
	STAssertTrue([snippet advance], nil);
	STAssertEquals(snippet.caret, 7ULL, nil);
	STAssertFalse([snippet advance], nil);
}

- (void)test042_nestedTabstopWithMultipleLocations
{
	[self makeSnippet:@"${3:Send $2 to $1, if $1 supports it}\n[${1:self} respondsToSelector:@selector(${2:someSelector:})]"];
	STAssertEqualObjects([snippet string], @"Send someSelector: to self, if self supports it\n[self respondsToSelector:@selector(someSelector:)]", nil);
	STAssertEquals(snippet.selectedRange.location, 49ULL, nil);
	STAssertEquals(snippet.selectedRange.length, 4ULL, nil);
	STAssertTrue([snippet replaceRange:snippet.selectedRange withString:@"bacon"], nil);
	STAssertEqualObjects([snippet string], @"Send someSelector: to bacon, if bacon supports it\n[bacon respondsToSelector:@selector(someSelector:)]", nil);
	STAssertEquals([snippet tabRange].location, 51ULL, nil);
	STAssertEquals([snippet tabRange].length, 5ULL, nil);
}

- (void)test043_weirdTransformation
{
	[self makeSnippet:@"${2:someSelector:} ${2/((:\\s*$)|(:\\s*))/:<>(?3: )/g}"];
	STAssertEqualObjects([snippet string], @"someSelector: someSelector:<>", nil);
}

@end
