#import "ViSymbol.h"

@implementation ViSymbol

- (ViSymbol *)initWithSymbol:(NSString *)aSymbol
                    document:(ViDocument *)aDocument
                       range:(NSRange)aRange
                       image:(NSImage *)anImage
{
	self = [super init];
	if (self) {
		symbol = aSymbol;
		document = aDocument;
		range = aRange;
		image = anImage;
	}
	
	return self;
}

@synthesize symbol;
@synthesize document;
@synthesize range;
@synthesize image;

- (int)sortOnLocation:(ViSymbol *)anotherSymbol
{
	if (range.location < [anotherSymbol range].location)
		return -1;
	if (range.location > [anotherSymbol range].location)
		return 1;
	return 0;
}

- (NSString *)displayName
{
	return symbol;
}

- (NSArray *)symbols
{
	return nil;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViSymbol: %@ in %@, range %@>",
	    symbol, [document title], NSStringFromRange(range)];
}

@end

