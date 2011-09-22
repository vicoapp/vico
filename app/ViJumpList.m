#import "ViJumpList.h"
#import "ViCommon.h"
#include "logging.h"

#define MAX_JUMP_LOCATIONS 100

@implementation ViJump

@synthesize url = _url;
@synthesize line = _line;
@synthesize column = _column;
@synthesize view = _view;

- (ViJump *)initWithURL:(NSURL *)aURL
                   line:(NSUInteger)aLine
                 column:(NSUInteger)aColumn
                   view:(NSView *)aView
{
	if ((self = [super init]) != nil) {
		_url = [aURL retain];
		_line = aLine;
		_column = aColumn;

		_view = aView; // XXX: not retained!
		if (_view)
			[[NSNotificationCenter defaultCenter] addObserver:self
								 selector:@selector(viewClosed:)
								     name:ViViewClosedNotification
								   object:_view];
	}
	return self;
}

- (void)viewClosed:(NSNotification *)notification
{
	INFO(@"view %@ closed", [notification object]);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_view = nil;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_url release];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViJump %p, %@ %u:%u>",
	    self, [_url absoluteString], _line, _column];
}

@end




@implementation ViJumpList

@synthesize delegate = _delegate;

- (ViJumpList *)init
{
	if ((self = [super init]) != nil)
		_jumps = [[NSMutableArray alloc] init];
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_jumps release];
	[super dealloc];
}

- (BOOL)pushURL:(NSURL *)url
           line:(NSUInteger)line
         column:(NSUInteger)column
           view:(NSView *)aView
{
	if (url == nil)
		return NO;

	if ([_jumps count] >= MAX_JUMP_LOCATIONS)
		[_jumps removeObjectAtIndex:0];

	DEBUG(@"pushing %@ %lu:%lu", url, line, column);

	BOOL removedDuplicate = NO;
	ViJump *jump = nil;
	for (jump in _jumps)
		if ([[jump url] isEqual:url] && IMAX(1, [jump line]) == IMAX(1, line))
			break;

	if (jump) {
		DEBUG(@"removing duplicate jump %@", jump);
		[_jumps removeObject:jump];
		removedDuplicate = YES;
	}

	jump = [[[ViJump alloc] initWithURL:url line:line column:column view:aView] autorelease];
	[_jumps addObject:jump];
	_position = [_jumps count];
	DEBUG(@"jumps = %@, position = %u", _jumps, _position);

	[_delegate jumpList:self added:jump];

	return removedDuplicate;
}

- (BOOL)gotoJumpAtPosition:(NSInteger)aPosition
                       URL:(NSURL **)urlPtr
                      line:(NSUInteger *)linePtr
                    column:(NSUInteger *)columnPtr
                      view:(NSView **)viewPtr
{
	DEBUG(@"goto jump at position %li", aPosition);
	if (aPosition < 0 || aPosition >= [_jumps count])
		return NO;
	ViJump *jump = [_jumps objectAtIndex:aPosition];
	DEBUG(@"using jump %@", jump);
	if (urlPtr)
		*urlPtr = jump.url;
	if (linePtr)
		*linePtr = jump.line;
	if (columnPtr)
		*columnPtr = jump.column;
	if (viewPtr)
		*viewPtr = jump.view;
	DEBUG(@"jumps = %@, position = %u", _jumps, _position);

	[_delegate jumpList:self goto:jump];

	return YES;
}

- (BOOL)forwardToURL:(NSURL **)urlPtr
                line:(NSUInteger *)linePtr
              column:(NSUInteger *)columnPtr
                view:(NSView **)viewPtr
{
	DEBUG(@"position = %u, count = %u", _position, [_jumps count]);
	if (_position + 1 >= [_jumps count])
		return NO;
	return [self gotoJumpAtPosition:++_position
				    URL:urlPtr
				   line:linePtr
				 column:columnPtr
				   view:viewPtr];
}

- (BOOL)backwardToURL:(NSURL **)urlPtr
                 line:(NSUInteger *)linePtr
               column:(NSUInteger *)columnPtr
                 view:(NSView **)viewPtr
{
	DEBUG(@"position = %li, count = %u", _position, [_jumps count]);
	if (_position <= 0)
		return NO;

	if (_position >= [_jumps count] && urlPtr && linePtr && columnPtr && viewPtr) {
		NSInteger savedPosition = _position;
		BOOL removedDuplicate = [self pushURL:*urlPtr
						 line:*linePtr
					       column:*columnPtr
						 view:*viewPtr];
		_position = savedPosition;
		if (removedDuplicate)
			_position--;
	}

	return [self gotoJumpAtPosition:--_position
				    URL:urlPtr
				   line:linePtr
				 column:columnPtr
				   view:viewPtr];
}

- (BOOL)atBeginning
{
	return (_position <= 0);
}

- (BOOL)atEnd
{
	return (_position + 1 >= [_jumps count]);
}

- (void)enumerateJumpsBackwardsUsingBlock:(void (^)(ViJump *jump, BOOL *stop))block
{
	NSInteger pos = _position - 1;
	DEBUG(@"navigating jumplist %@ backwards from %li", _jumps, pos);
	BOOL stop = NO;
	while (!stop && pos >= 0) {
		block([_jumps objectAtIndex:pos], &stop);
		--pos;
	}
}

@end

