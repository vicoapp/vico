#import <Cocoa/Cocoa.h>

#import "ViSyntaxContext.h"
#import "ViSyntaxMatch.h"
#import "MHSysTree.h"
#import "ViLanguage.h"

@interface ViSyntaxParser : NSObject
{
	// configuration
	id delegate;
	ViLanguage *language;

	// persistent state
	NSMutableArray *continuations;
	MHSysTree *scopeTree;
	NSMutableArray *uglyHack;

	// per-request state
	const unichar *chars;
	NSUInteger offset;
	unsigned lineOffset;

	// statistics
	unsigned regexps_tried;
	unsigned regexps_overlapped;
	unsigned regexps_matched;
	unsigned regexps_cached;
}

- (ViSyntaxParser *)initWithLanguage:(ViLanguage *)aLanguage delegate:(id)aDelegate;
- (void)parseContext:(ViSyntaxContext *)aContext;

- (void)setContinuation:(NSArray *)continuationMatches forLine:(unsigned)lineno;
- (void)setScopes:(NSArray *)aScopeArray inRange:(NSRange)aRange;

- (NSArray *)scopesFromMatches:(NSArray *)matches withoutContentForMatch:(ViSyntaxMatch *)skipContentMatch;
- (NSArray *)scopesFromMatches:(NSArray *)matches;

- (void)pushContinuations:(NSValue *)rangeValue;

@end
