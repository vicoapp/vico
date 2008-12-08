#import <Cocoa/Cocoa.h>

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
	MHSysTree *scopeTree;
	MHSysTree *wholeScopeTree;

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

@property(readwrite) BOOL ignoreEditing;
@property(readonly) MHSysTree *wholeScopeTree;

- (ViSyntaxParser *)initWithLanguage:(ViLanguage *)aLanguage;
- (void)parseContext:(ViSyntaxContext *)aContext;

- (void)setContinuation:(NSArray *)continuationMatches forLine:(unsigned)lineno;

- (NSArray *)scopesFromMatches:(NSArray *)matches withoutContentForMatch:(ViSyntaxMatch *)skipContentMatch;

- (void)pushContinuations:(NSValue *)rangeValue;
- (void)pullContinuations:(NSValue *)rangeValue;
- (void)pushScopes:(NSRange)affectedRange;
- (void)pullScopes:(NSRange)affectedRange;

@end
