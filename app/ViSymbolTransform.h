#import "ViTransformer.h"

@interface ViSymbolTransform : ViTransformer
{
	NSMutableArray *transformations;
}

- (ViSymbolTransform *)initWithTransformationString:(NSString *)aString;
- (NSString *)transformSymbol:(NSString *)aSymbol;

@end
