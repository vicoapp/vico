#import "ViTagStack.h"

@implementation ViTagStack

- (id)init
{
	self = [super init];
	if (self)
	{
		stack = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)pushFile:(NSString*)aFile
            line:(NSUInteger)aLine
          column:(NSUInteger)aColumn
{
	NSDictionary *location = [[NSDictionary alloc] initWithObjectsAndKeys:aFile, @"file",
				  [NSNumber numberWithUnsignedInteger:aLine], @"line",
				  [NSNumber numberWithUnsignedInteger:aColumn], @"column",
				  nil];
	[stack addObject:location];
}

- (NSDictionary *)pop
{
	NSDictionary *location = [stack lastObject];
	if (location)
		[stack removeLastObject];
	return location;
}

@end
