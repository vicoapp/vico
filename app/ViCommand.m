#import "ViCommand.h"
#include "logging.h"

@implementation ViCommand

@synthesize mapping = _mapping;
@synthesize count = _count;
@synthesize saved_count = _saved_count;
@synthesize fromDot = _fromDot;
@synthesize argument = _argument;
@synthesize reg = _reg;
@synthesize motion = _motion;
@synthesize text = _text;
@synthesize isLineMode = _isLineMode;
@synthesize operator = _operator;
@synthesize range = _range;
@synthesize caret = _caret;
@synthesize macro = _macro;
@synthesize messages = _messages;
@synthesize keySequence = _keySequence;

+ (ViCommand *)commandWithMapping:(ViMapping *)aMapping count:(int)aCount
{
	return [[[ViCommand alloc] initWithMapping:aMapping count:aCount] autorelease];
}

- (ViCommand *)initWithMapping:(ViMapping *)aMapping count:(int)aCount
{
	if ((self = [super init]) != nil) {
		_mapping = [aMapping retain];
		_isLineMode = _mapping.isLineMode;
		_count = _saved_count = aCount;
	}
	return self;
}

- (void)dealloc
{
	[_mapping release];
	[_motion setOperator:nil];
	[_motion release];
	[_macro release];
	[_text release];
	[_messages release];
	[_keySequence release];
	[super dealloc];
}

- (BOOL)performWithTarget:(id)target
{
	if (target == nil)
		return NO;
        return (BOOL)[target performSelector:_mapping.action withObject:self];
}

- (SEL)action
{
	return _mapping.action;
}

- (BOOL)isLineMode
{
	return _isLineMode;
}

- (BOOL)isMotion
{
	return [_mapping isMotion];
}

- (BOOL)hasOperator
{
	return _operator != nil;
}

- (BOOL)isUndo
{
	return _mapping.action == @selector(vi_undo:);
}

- (BOOL)isDot
{
	return _mapping.action == @selector(dot:);
}

- (id)copyWithZone:(NSZone *)zone
{
	ViCommand *copy = [[ViCommand allocWithZone:zone] initWithMapping:_mapping count:_saved_count];

	/* Set the fromDot flag. 
	 * We copy commands mainly for the dot command. This flag is necessary for
	 * the nvi undo style as it needs to know if a command is a dot repeat or not.
	 */
	[copy setFromDot:YES];

	[copy setIsLineMode:_isLineMode];
	[copy setArgument:_argument];
	[copy setReg:_reg];
	if (_motion) {
		ViCommand *motionCopy = [[_motion copy] autorelease];
		[motionCopy setOperator:copy];
		[copy setMotion:motionCopy];
	} else
		[copy setOperator:_operator];
	[copy setText:_text];

	return copy;
}

- (NSString *)description
{
	if (_motion)
		return [NSString stringWithFormat:@"<ViCommand %@: %@ * %i, motion = %@>",
		    _mapping.keyString, NSStringFromSelector(_mapping.action), _count, _motion];
	else
		return [NSString stringWithFormat:@"<ViCommand %@: %@ * %i>",
		    _mapping.keyString, NSStringFromSelector(_mapping.action), _count];
}

- (void)message:(NSString *)message
{
	DEBUG(@"got message %@", message);
	if (message == nil)
		return;
	if (_messages == nil)
		_messages = [[NSMutableArray alloc] init];
	[_messages addObject:message];
}

@end

