@class ViDocument;

@interface ViSymbol : NSObject
{
	NSString *symbol;
	ViDocument *document;
	NSRange range;
	NSImage *image;
}

@property(readonly) NSString *symbol;
@property(readonly) ViDocument *document;
@property(readonly) NSImage *image;
@property(readwrite) NSRange range;

- (ViSymbol *)initWithSymbol:(NSString *)aSymbol
                    document:(ViDocument *)aDocument
                       range:(NSRange)aRange
                       image:(NSImage *)anImage;
- (int)sortOnLocation:(ViSymbol *)anotherSymbol;
- (NSString *)displayName;
- (NSArray *)symbols;

@end
