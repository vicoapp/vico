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
	NSMutableArray *continuationsState;
	NSMutableArray *continuations;
	MHSysTree *scopeTree;
	NSMutableArray *uglyHack;

	// per-request state
	const unichar *chars;
	NSUInteger offset;
	unsigned lineOffset;
	ViSyntaxContext *currentContext;
	BOOL aborted;
	BOOL running;

	// statistics
	unsigned regexps_tried;
	unsigned regexps_overlapped;
	unsigned regexps_matched;
	unsigned regexps_cached;
}

@property(readwrite) BOOL aborted;

- (ViSyntaxParser *)initWithLanguage:(ViLanguage *)aLanguage delegate:(id)aDelegate;
- (void)parseContext:(ViSyntaxContext *)aContext;

- (void)setContinuation:(NSArray *)continuationMatches forLine:(unsigned)lineno;
- (void)setScopes:(NSArray *)aScopeArray inRange:(NSRange)aRange;

- (NSArray *)scopesFromMatches:(NSArray *)matches withoutContentForMatch:(ViSyntaxMatch *)skipContentMatch;

- (void)pushContinuations:(NSValue *)rangeValue;
- (void)pullContinuations:(NSValue *)rangeValue;

- (BOOL)abortIfRunningWithRestartingContext:(ViSyntaxContext **)contextPtr;

@end
