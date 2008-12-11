#import <Cocoa/Cocoa.h>

@interface ViSyntaxContext : NSObject
{
	unichar *characters;
	NSRange range;
	NSUInteger offset;
	unsigned lineOffset;
	BOOL restarting;
	BOOL cancelled;
}

@property(readwrite, assign) unichar *characters;
@property(readwrite) NSRange range;
@property(readwrite) unsigned lineOffset;
@property(readwrite) BOOL restarting;
@property(readwrite) BOOL cancelled;

- (ViSyntaxContext *)initWithLine:(unsigned)line;
- (ViSyntaxContext *)initWithCharacters:(unichar *)chars range:(NSRange)aRange line:(unsigned)line restarting:(BOOL)flag;

@end
