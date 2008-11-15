#import <Cocoa/Cocoa.h>

@interface ViSyntaxContext : NSObject
{
	unichar *characters;
	NSRange range;
	NSUInteger offset;
	unsigned lineOffset;
	BOOL restarting;
}

@property(readonly) unichar *characters;
@property(readonly) NSRange range;
@property(readonly) unsigned lineOffset;
@property(readonly) BOOL restarting;

- (ViSyntaxContext *)initWithCharacters:(unichar *)chars range:(NSRange)aRange line:(unsigned)line restarting:(BOOL)flag;

@end
