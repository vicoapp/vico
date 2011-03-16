@interface ViSyntaxContext : NSObject
{
	unichar *characters;
	NSRange range;
	NSUInteger offset;
	NSUInteger lineOffset;
	BOOL restarting;
	BOOL cancelled;
}

@property(readwrite, assign) unichar *characters;
@property(readwrite) NSRange range;
@property(readwrite) NSUInteger lineOffset;
@property(readwrite) BOOL restarting;
@property(readwrite) BOOL cancelled;

- (ViSyntaxContext *)initWithLine:(NSUInteger)line;
- (ViSyntaxContext *)initWithCharacters:(unichar *)chars
				  range:(NSRange)aRange
				   line:(NSUInteger)line
			     restarting:(BOOL)flag;

@end
