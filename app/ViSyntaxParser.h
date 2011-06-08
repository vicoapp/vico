#import "ViSyntaxContext.h"
#import "ViSyntaxMatch.h"
#import "MHSysTree.h"
#import "ViLanguage.h"

@interface ViSyntaxParser : NSObject
{
	// configuration
	ViLanguage *language;

	// persistent state
	NSMutableArray *continuationsState;
	NSMutableArray *continuations;
	NSMutableArray *scopeArray;

	// per-request state
	const unichar *chars;
	NSUInteger offset;
	ViSyntaxContext *context;

	BOOL ignoreEditing;

	// statistics
	unsigned regexps_tried;
	unsigned regexps_overlapped;
	unsigned regexps_matched;
	unsigned regexps_cached;
}

@property(nonatomic,readwrite) BOOL ignoreEditing;

- (ViSyntaxParser *)initWithLanguage:(ViLanguage *)aLanguage;
- (void)parseContext:(ViSyntaxContext *)aContext;

- (void)setContinuation:(NSArray *)continuationMatches forLine:(NSUInteger)lineno;

- (NSArray *)scopesFromMatches:(NSArray *)matches withoutContentForMatch:(ViSyntaxMatch *)skipContentMatch;

- (void)pushContinuations:(NSUInteger)changedLines
           fromLineNumber:(NSUInteger)lineNumber;

- (void)pullContinuations:(NSUInteger)changedLines
           fromLineNumber:(NSUInteger)lineNumber;

- (void)pushScopes:(NSRange)affectedRange;
- (void)pullScopes:(NSRange)affectedRange;

- (void)updateScopeRangesInRange:(NSRange)updateRange;

- (NSArray *)scopeArray;

@end
