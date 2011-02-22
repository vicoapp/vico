#import <SenTestingKit/SenTestingKit.h>
#import "ViSnippet.h"

@interface TestViSnippet : SenTestCase
{
	NSDictionary *env;
	NSError *err;
	ViSnippet *snippet;
}

@end
