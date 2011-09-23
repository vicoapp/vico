#import "ViSyntaxContext.h"
#import "ViSyntaxMatch.h"
#import "ViLanguage.h"

@interface ViSyntaxParser : NSObject
{
	// configuration
	ViLanguage	*_language;

	// persistent state
	NSMutableArray	*_continuations;
	NSMutableArray	*_scopeArray;

	// per-request state
	const unichar	*_chars;
	NSUInteger	 _offset;
	ViSyntaxContext	*_context;

	// statistics
	unsigned	 _regexps_tried;
	unsigned	 _regexps_overlapped;
	unsigned	 _regexps_matched;
	unsigned	 _regexps_cached;
}

+ (ViSyntaxParser *)syntaxParserWithLanguage:(ViLanguage *)aLanguage;

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
