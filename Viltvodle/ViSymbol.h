@interface ViSymbol : NSObject
{
	NSString *symbol;
	NSRange range;
	NSImage *image;
}

@property(readonly) NSString *symbol;
@property(readonly) NSImage *image;
@property(readwrite) NSRange range;

- (ViSymbol *)initWithSymbol:(NSString *)aSymbol range:(NSRange)aRange image:(NSImage *)anImage;
- (int)sortOnLocation:(ViSymbol *)anotherSymbol;
- (NSString *)displayName;
- (NSArray *)symbols;

@end
