@interface ViTextStorage : NSTextStorage
{
	NSMutableString *string;
	NSDictionary *typingAttributes;
}

- (id)init;

- (void)setTypingAttributes:(NSDictionary *)attributes;

- (NSString *)string;
- (NSDictionary *)attributesAtIndex:(unsigned)anIndex effectiveRange:(NSRangePointer)aRange;
- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)str;
- (void)insertString:(NSString *)aString atIndex:(NSUInteger)anIndex;
- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange;

- (NSInteger)locationForStartOfLine:(NSUInteger)aLineNumber;
- (NSUInteger)lineNumberAtLocation:(NSUInteger)aLocation;
- (NSUInteger)lineCount;

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet from:(NSUInteger)startLocation to:(NSUInteger)toLocation backward:(BOOL)backwardFlag;
- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet fromLocation:(NSUInteger)startLocation backward:(BOOL)backwardFlag;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation toLocation:(NSUInteger)toLocation;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation;

- (NSString *)wordAtLocation:(NSUInteger)aLocation range:(NSRange *)returnRange;
- (NSString *)wordAtLocation:(NSUInteger)aLocation;

- (NSUInteger)lineIndexAtLocation:(NSUInteger)aLocation;
- (NSUInteger)columnAtLocation:(NSUInteger)aLocation;
- (NSUInteger)locationForColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation acceptEOL:(BOOL)acceptEOL;

- (NSString *)lineForLocation:(NSUInteger)aLocation;
- (BOOL)isBlankLineAtLocation:(NSUInteger)aLocation;

@end
