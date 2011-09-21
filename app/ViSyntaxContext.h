@interface ViSyntaxContext : NSObject
{
	unichar		*_characters;
	NSRange		 _range;
	NSUInteger	 _offset;
	NSUInteger	 _lineOffset;
	BOOL		 _restarting;
	BOOL		 _cancelled;
}

@property(nonatomic,readwrite) unichar *characters;
@property(nonatomic,readwrite) NSRange range;
@property(nonatomic,readwrite) NSUInteger lineOffset;
@property(nonatomic,readwrite) BOOL restarting;
@property(nonatomic,readwrite) BOOL cancelled;

+ (ViSyntaxContext *)syntaxContextWithLine:(NSUInteger)line;

- (ViSyntaxContext *)initWithLine:(NSUInteger)line;
- (ViSyntaxContext *)initWithCharacters:(unichar *)chars
				  range:(NSRange)aRange
				   line:(NSUInteger)line
			     restarting:(BOOL)flag;

@end
