@interface ViSyntaxContext : NSObject
{
	unichar *characters;
	NSRange range;
	NSUInteger offset;
	NSUInteger lineOffset;
	BOOL restarting;
	BOOL cancelled;
}

@property(nonatomic,readwrite, assign) unichar *characters;
@property(nonatomic,readwrite) NSRange range;
@property(nonatomic,readwrite) NSUInteger lineOffset;
@property(nonatomic,readwrite) BOOL restarting;
@property(nonatomic,readwrite) BOOL cancelled;

- (ViSyntaxContext *)initWithLine:(NSUInteger)line;
- (ViSyntaxContext *)initWithCharacters:(unichar *)chars
				  range:(NSRange)aRange
				   line:(NSUInteger)line
			     restarting:(BOOL)flag;

@end
