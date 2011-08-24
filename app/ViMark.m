#import "ViMark.h"

@implementation ViMark

- (ViMark *)initWithLocation:(NSUInteger)aLocation line:(NSUInteger)aLine column:(NSUInteger)aColumn
{
	if ((self = [super init]) != nil) {
		location = aLocation;
		line = aLine;
		column = aColumn;
	}
	
	return self;
}

@synthesize line;
@synthesize column;
@synthesize location;

@end
