#import "ViSyntaxContext.h"
#import "logging.h"

@implementation ViSyntaxContext

@synthesize characters;
@synthesize range;
@synthesize lineOffset;
@synthesize restarting;
@synthesize scopes;

- (ViSyntaxContext *)initWithCharacters:(unichar *)chars range:(NSRange)aRange line:(unsigned)line restarting:(BOOL)flag
{
	self = [super init];
	if (self)
	{
		characters = chars;
		range = aRange;
		lineOffset = line;
		restarting = flag;
	}
	return self;
}

- (void)finalize
{
	free(characters);
	[super finalize];
}

@end
