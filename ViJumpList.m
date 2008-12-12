#include "ViJumpList.h"
#include "logging.h"

#define MAX_JUMP_LOCATIONS 100

@implementation ViJump
@synthesize url;
@synthesize line;
@synthesize column;
- (ViJump *)initWithURL:(NSURL *)aURL line:(NSUInteger)aLine column:(NSUInteger)aColumn
{
	self = [super init];
	if (self)
	{
		url = aURL;
		line = aLine;
		column = aColumn;
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViJump %p, %@ %u:%u>", self, [url absoluteString], line, column];
}
@end

@implementation ViJumpList

static ViJumpList *defaultJumpList = nil;

+ (ViJumpList *)defaultJumpList
{
	if (defaultJumpList == nil)
	{
		defaultJumpList = [[ViJumpList alloc] init];
	}
	return defaultJumpList;
}

- (ViJumpList *)init
{
	self = [super init];
	if (self)
	{
		jumps = [[NSMutableArray alloc] init];
	}
	return self;
}

- (BOOL)pushURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column
{
	if ([jumps count] >= MAX_JUMP_LOCATIONS)
	{
		[jumps removeObjectAtIndex:0];
	}

	BOOL removedDuplicate = NO;
	ViJump *jump = nil;
	for (jump in jumps)
	{
		if ([[jump url] isEqual:url] && [jump line] == line)
		{
			break;
		}
	}
	if (jump)
	{
		DEBUG(@"removing duplicate jump %@", jump);
		[jumps removeObject:jump];
		removedDuplicate = YES;
	}

	[jumps addObject:[[ViJump alloc] initWithURL:url line:line column:column]];
	position = [jumps count];
	DEBUG(@"jumps = %@, position = %u", jumps, position);
	return removedDuplicate;
}

- (BOOL)gotoJumpAtPosition:(NSUInteger)aPosition URL:(NSURL **)urlPtr line:(NSUInteger *)linePtr column:(NSUInteger *)columnPtr
{
	ViJump *jump = [jumps objectAtIndex:aPosition];
	DEBUG(@"using jump %@", jump);
	if (urlPtr)
		*urlPtr = [jump url];
	if (linePtr)
		*linePtr = [jump line];
	if (columnPtr)
		*columnPtr = [jump column];
	DEBUG(@"jumps = %@, position = %u", jumps, position);
	return YES;
}

- (BOOL)forwardToURL:(NSURL **)urlPtr line:(NSUInteger *)linePtr column:(NSUInteger *)columnPtr
{
	DEBUG(@"position = %u, count = %u", position, [jumps count]);
	if (position + 1 >= [jumps count])
		return NO;
	return [self gotoJumpAtPosition:++position URL:urlPtr line:linePtr column:columnPtr];
}

- (BOOL)backwardToURL:(NSURL **)urlPtr line:(NSUInteger *)linePtr column:(NSUInteger *)columnPtr
{
	DEBUG(@"position = %u, count = %u", position, [jumps count]);
	if (position == 0)
		return NO;

	if (position >= [jumps count])
	{
		NSUInteger savedPosition = position;
		BOOL removedDuplicate = [self pushURL:*urlPtr line:*linePtr column:*columnPtr];
		position = savedPosition;
		if (removedDuplicate)
			position--;
	}

	return [self gotoJumpAtPosition:--position URL:urlPtr line:linePtr column:columnPtr];
}

@end

