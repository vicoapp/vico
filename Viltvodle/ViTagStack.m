#import "ViTagStack.h"

@implementation ViTagStack

- (id)init
{
	self = [super init];
	if (self) {
		stack = [NSMutableArray array];
	}
	return self;
}

- (void)pushURL:(NSURL *)url
           line:(NSUInteger)line
         column:(NSUInteger)column
{
	NSDictionary *location = [[NSDictionary alloc] initWithObjectsAndKeys:url, @"url",
				  [NSNumber numberWithUnsignedInteger:line], @"line",
				  [NSNumber numberWithUnsignedInteger:column], @"column",
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
