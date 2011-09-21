#import "ViSyntaxContext.h"
#import "logging.h"

@implementation ViSyntaxContext

@synthesize characters = _characters;
@synthesize range = _range;
@synthesize lineOffset = _lineOffset;
@synthesize restarting = _restarting;
@synthesize cancelled = _cancelled;

+ (ViSyntaxContext *)syntaxContextWithLine:(NSUInteger)line
{
	return [[[ViSyntaxContext alloc] initWithLine:line] autorelease];
}

- (ViSyntaxContext *)initWithLine:(NSUInteger)line
{
	if ((self = [super init]) != nil) {
		_lineOffset = line;
		_restarting = YES;
	}
	return self;
}

- (ViSyntaxContext *)initWithCharacters:(unichar *)chars
				  range:(NSRange)aRange
				   line:(NSUInteger)line
			     restarting:(BOOL)flag
{
	if ((self = [super init]) != nil) {
		_characters = chars;
		_range = aRange;
		_lineOffset = line;
		_restarting = flag;
	}
	return self;
}

- (void)finalize
{
	free(_characters);
	[super finalize];
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	free(_characters);
	[super dealloc];
}

@end
