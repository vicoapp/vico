#import <SenTestingKit/SenTestingKit.h>
#import "ViParser.h"

@interface TestViParser : SenTestCase
{
	ViParser *parser;
	ViCommand *command;
	NSError *error;
}

@end
