#import "ViMark.h"

@implementation ViMark

- (ViMark *)initWithLine:(NSUInteger)aLine column:(NSUInteger)aColumn
{
	if ((self = [super init]) != nil)
	{
		line = aLine;
		column = aColumn;
	}
	
	return self;
}

@synthesize line;
@synthesize column;

@end
