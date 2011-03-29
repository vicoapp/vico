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
@synthesize isMotion;
@synthesize operator;

+ (ViCommand *)commandWithMapping:(ViMapping *)aMapping
{
	return [[ViCommand alloc] initWithMapping:aMapping];
}

- (ViCommand *)initWithMapping:(ViMapping *)aMapping
{
	if ((self = [super init]) != nil) {
		mapping = aMapping;
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
	ViCommand *copy = [ViCommand commandWithMapping:mapping];
	copy.count = count;
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

