#import "ViMap.h"
#import "ViCommand.h"

typedef enum {
	ViParserInitialState,		/* expecting a command, or " */
	ViParserNeedRegister,		/* after a " */
	ViParserPartialCommand,		/* got a prefix, eg g or <c-w> */
	ViParserNeedMotion,		/* for operators */
	ViParserPartialMotion,		/* for operators, prefix motions, eg g */
	ViParserNeedChar		/* for ftFTr */
} ViParserState;

@interface ViParser : NSObject
{
	ViMap *defaultMap;
	ViMap *map;

	ViParserState state;

	NSMutableArray *keySequence;
	NSMutableArray *totalKeySequence;

	ViCommand *command;
	unichar reg; /* register */
	int count;

	/* dot state */
	ViCommand *dot_command;

	/* Used for nvi-style undo. */
	BOOL nviStyleUndo;
	ViCommand *last_command;

	ViCommand *last_ftFT_command;

	// search state (XXX: move to "/ register?)
	NSString *last_search_pattern;
	int last_search_options;

	id text;
}

- (ViParser *)initWithDefaultMap:(ViMap *)aMap;

- (ViCommand *)pushKey:(NSInteger)keyCode;

- (ViCommand *)pushKey:(NSInteger)keyCode
           allowMacros:(BOOL)allowMacros
                 scope:(NSArray *)scopeArray
               timeout:(BOOL *)timeoutPtr
                 error:(NSError **)outError;

- (ViCommand *)timeoutInScope:(NSArray *)scopeArray
                        error:(NSError **)outError;

- (void)reset;

- (void)setMap:(ViMap *)aMap;
- (void)setVisualMap;
- (void)setInsertMap;
- (void)setExplorerMap;
- (BOOL)partial;
- (NSString *)keyString;

@property(readwrite) BOOL nviStyleUndo;
@property(readonly) ViCommand *last_ftFT_command;
@property(readwrite, assign) NSString *last_search_pattern;
@property(readwrite) int last_search_options;

@end
