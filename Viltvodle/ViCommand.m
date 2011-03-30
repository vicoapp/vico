#import "ViCommand.h"

@implementation ViCommand

@synthesize mapping;
@synthesize count;
@synthesize fromDot;
@synthesize argument;
@synthesize reg;
@synthesize motion;
@synthesize text;
@synthesize isLineMode;
@synthesize operator;

+ (ViCommand *)commandWithMapping:(ViMapping *)aMapping count:(int)aCount
{
	return [[ViCommand alloc] initWithMapping:aMapping count:aCount];
}

- (ViCommand *)initWithMapping:(ViMapping *)aMapping count:(int)aCount
{
	if ((self = [super init]) != nil) {
		mapping = aMapping;
		count = saved_count = aCount;
	}
	return self;
}

- (SEL)action
{
	return mapping.action;
}

- (BOOL)isLineMode
{
	return isLineMode || mapping.isLineMode;
}

- (BOOL)isMotion
{
	return [mapping isMotion];
}

- (BOOL)hasOperator
{
	return operator != nil;
}

- (BOOL)isUndo
{
	return mapping.action == @selector(vi_undo:);
}

- (BOOL)isDot
{
	return mapping.action == @selector(dot:);
}

- (ViCommand *)dotCopy
{
	ViCommand *copy = [ViCommand commandWithMapping:mapping count:saved_count];
	copy.fromDot = YES;
	copy.argument = argument;
	copy.reg = reg;
	copy.motion = [motion dotCopy];
	copy.operator = operator;
	copy.text = [text copy];

	return copy;
}

- (NSString *)description
{
	if (motion)
		return [NSString stringWithFormat:@"<ViCommand %@: %@ * %i, motion = %@>",
		    mapping.keyString, NSStringFromSelector(mapping.action), count, motion];
	else
		return [NSString stringWithFormat:@"<ViCommand %@: %@ * %i>",
		    mapping.keyString, NSStringFromSelector(mapping.action), count];
}

@end

