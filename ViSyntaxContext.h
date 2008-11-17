#import <Cocoa/Cocoa.h>

@interface ViSyntaxContext : NSObject
{
	unichar *characters;
	NSRange range;
	NSUInteger offset;
	unsigned lineOffset;
	BOOL restarting;
	NSArray *scopes;
}

@property(readonly) unichar *characters;
@property(readwrite) NSRange range;
@property(readwrite) unsigned lineOffset;
@property(readonly) BOOL restarting;
@property(readwrite, copy) NSArray *scopes;

- (ViSyntaxContext *)initWithCharacters:(unichar *)chars range:(NSRange)aRange line:(unsigned)line restarting:(BOOL)flag;

@end
