#import "TestViSnippet.h"

@implementation TestViSnippet

- (void)setUp
{
	env = [NSDictionary dictionaryWithObjectsAndKeys:
	    nil
	];
}

- (void)test001_simpleAbbreviation
{
	snippet = [[ViSnippet alloc] initWithString:@"a long string" atLocation:0 environment:env];
	STAssertNotNil(snippet, nil);
	STAssertEqualObjects([snippet string], @"a long string", nil);
	STAssertTrue([snippet activeInRange:NSMakeRange(0, 1)], nil);
	STAssertTrue([snippet activeInRange:NSMakeRange(12, 1)], nil);
	STAssertTrue([snippet activeInRange:NSMakeRange(13, 0)], nil);	// appending
	STAssertTrue([snippet done], nil);
}

- (void)test002_escapeReservedCharacters
{
	snippet = [[ViSnippet alloc] initWithString:@"a dollar sign: \\$, \\a bactick: \\`, and a \\\\" atLocation:0 environment:env];
	STAssertNotNil(snippet, nil);
	STAssertEqualObjects([snippet string], @"a dollar sign: $, \\a bactick: `, and a \\\\", nil);
}

@end

