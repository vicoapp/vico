#include "ViJumpList.h"
#include "logging.h"

#define MAX_JUMP_LOCATIONS 100

@implementation ViJump
@synthesize url;
@synthesize line;
@synthesize column;
- (ViJump *)initWithURL:(NSURL *)aURL
                   line:(NSUInteger)aLine
                 column:(NSUInteger)aColumn
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
	return [NSString stringWithFormat:@"<ViJump %p, %@ %u:%u>",
	    self, [url absoluteString], line, column];
}
@end

@implementation ViJumpList

@synthesize delegate;

- (ViJumpList *)init
{
	self = [super init];
	if (self)
		jumps = [[NSMutableArray alloc] init];
	return self;
}

- (BOOL)pushURL:(NSURL *)url
           line:(NSUInteger)line
         column:(NSUInteger)column
{
	if (url == nil)
		return NO;

	if ([jumps count] >= MAX_JUMP_LOCATIONS)
		[jumps removeObjectAtIndex:0];

	BOOL removedDuplicate = NO;
	ViJump *jump = nil;
	for (jump in jumps) {
		if ([[jump url] isEqual:url] && [jump line] == line)
			break;
	}

	if (jump) {
		DEBUG(@"removing duplicate jump %@", jump);
		[jumps removeObject:jump];
		removedDuplicate = YES;
	}

	jump = [[ViJump alloc] initWithURL:url line:line column:column];
	[jumps addObject:jump];
	position = [jumps count];
	DEBUG(@"jumps = %@, position = %u", jumps, position);

	[delegate jumpList:self added:jump];

	return removedDuplicate;
}

- (BOOL)gotoJumpAtPosition:(NSUInteger)aPosition
                       URL:(NSURL **)urlPtr
                      line:(NSUInteger *)linePtr
                    column:(NSUInteger *)columnPtr
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

	[delegate jumpList:self goto:jump];

	return YES;
}

- (BOOL)forwardToURL:(NSURL **)urlPtr
                line:(NSUInteger *)linePtr
              column:(NSUInteger *)columnPtr
{
	DEBUG(@"position = %u, count = %u", position, [jumps count]);
	if (position + 1 >= [jumps count])
		return NO;
	return [self gotoJumpAtPosition:++position
				    URL:urlPtr
				   line:linePtr
				 column:columnPtr];
}

- (BOOL)backwardToURL:(NSURL **)urlPtr
                 line:(NSUInteger *)linePtr
               column:(NSUInteger *)columnPtr
{
	DEBUG(@"position = %u, count = %u", position, [jumps count]);
	if (position <= 0)
		return NO;

	if (position >= [jumps count] && urlPtr && linePtr && columnPtr)
	{
		NSUInteger savedPosition = position;
		BOOL removedDuplicate = [self pushURL:*urlPtr
						 line:*linePtr
					       column:*columnPtr];
		position = savedPosition;
		if (removedDuplicate)
			position--;
	}

	return [self gotoJumpAtPosition:--position
				    URL:urlPtr
				   line:linePtr
				 column:columnPtr];
}

- (BOOL)atBeginning
{
	return (position <= 0);
}

- (BOOL)atEnd
{
	return (position + 1 >= [jumps count]);
}

@end

