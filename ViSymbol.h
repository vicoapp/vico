#import <Cocoa/Cocoa.h>

@interface ViSymbol : NSObject
{
	NSString *symbol;
	NSRange range;
}

@property(readonly) NSString *symbol;
@property(readwrite) NSRange range;

- (ViSymbol *)initWithSymbol:(NSString *)aSymbol range:(NSRange)aRange;
- (int)sortOnLocation:(ViSymbol *)anotherSymbol;
- (NSString *)displayName;
- (NSArray *)symbols;

@end
