#import "TestViTextStorage.h"
#include "logging.h"

@implementation TestViTextStorage

- (void)setUp
{
	textStorage = [[ViTextStorage alloc] init];
}

- (void)test001_AllocateTextStorage
{
	STAssertNotNil(textStorage, nil);
}

- (void)test002_InitialString
{
	STAssertEqualObjects([textStorage string], @"", nil);
}

- (void)test003_SetString
{
	[[textStorage mutableString] setString:@"bacon"];
	STAssertEqualObjects([textStorage string], @"bacon", nil);
}

- (void)test004_GetAttributes
{
	[[textStorage mutableString] setString:@"bacon"];
	NSRange range;
	NSDictionary *attrs = [textStorage attributesAtIndex:2 effectiveRange:&range];
	STAssertNotNil(attrs, nil);
	STAssertNotNil([attrs objectForKey:NSFontAttributeName], nil);
	STAssertTrue(range.location == 0, nil);
	STAssertTrue(range.length == [textStorage length], nil);
}

@end