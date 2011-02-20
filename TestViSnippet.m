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
	STAssertTrue([snippet done], nil);
}

@end

