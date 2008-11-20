#import <Cocoa/Cocoa.h>

@interface ViSymbolTransform : NSObject
{
	NSMutableArray *transformations;
}

- (ViSymbolTransform *)initWithTransformationString:(NSString *)aString;
- (NSString *)transformSymbol:(NSString *)aSymbol;

@end
