@class ViDocument;

@interface ViSymbol : NSObject
{
	NSString *symbol;
	ViDocument *document;
	NSRange range;
	NSImage *image;
}

@property(nonatomic,readonly) NSString *symbol;
@property(nonatomic,readonly) ViDocument *document;
@property(nonatomic,readonly) NSImage *image;
@property(nonatomic,readwrite) NSRange range;

- (ViSymbol *)initWithSymbol:(NSString *)aSymbol
                    document:(ViDocument *)aDocument
                       range:(NSRange)aRange
                       image:(NSImage *)anImage;
- (int)sortOnLocation:(ViSymbol *)anotherSymbol;
- (NSString *)displayName;
- (NSArray *)symbols;

@end
