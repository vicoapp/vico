#import "ViTransformer.h"

@interface ViSymbolTransform : ViTransformer
{
	NSMutableArray *_transformations;
}

- (ViSymbolTransform *)initWithTransformationString:(NSString *)aString;
- (NSString *)transformSymbol:(NSString *)aSymbol;

@end
