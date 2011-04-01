#import <SenTestingKit/SenTestingKit.h>
#import "ViTextStorage.h"

@interface TestViTextStorage : SenTestCase
{
	ViTextStorage *textStorage;

	NSUInteger linesChanged;
	NSUInteger linesRemoved;
	NSUInteger linesAdded;
	NSUInteger lineChangeIndex;
}

@end
