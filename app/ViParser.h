#import "ViMap.h"
#import "ViCommand.h"
#import "ViScope.h"

typedef enum {
	ViParserInitialState,		/* expecting a command, or " */
	ViParserNeedRegister,		/* after a " */
	ViParserPartialCommand,		/* got a prefix, eg g or <c-w> */
	ViParserNeedMotion,		/* for operators */
	ViParserPartialMotion,		/* for operators, prefix motions, eg g */
	ViParserNeedChar		/* for ftFTr */
} ViParserState;

/** A parser for vi commands.
 *
 */
@interface ViParser : NSObject
{
	ViMap *defaultMap;
	ViMap *map;

	ViParserState state;

	NSMutableArray *keySequence;
	NSMutableArray *totalKeySequence;

	NSArray **remainingExcessKeysPtr;

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
	int last_search_options;

	id text;
}

/** Initialize a new key parser.
 * @param aMap The default map to use when mapping keys.
 * @see ViMap
 */
- (ViParser *)initWithDefaultMap:(ViMap *)aMap;

- (id)pushKey:(NSInteger)keyCode;

- (id)pushKey:(NSInteger)keyCode
  allowMacros:(BOOL)allowMacros
        scope:(ViScope *)scope
      timeout:(BOOL *)timeoutPtr
   excessKeys:(NSArray **)excessKeysPtr
        error:(NSError **)outError;

- (id)timeoutInScope:(ViScope *)scope
               error:(NSError **)outError;

/** Reset the parser.
 *
 * Parser state is reset and any partial keys are discarded.  The key
 * map is reset to the default map defined when the parser was created.
 */
- (void)reset;

/** Change the current key map.
 * @param aMap A new key map that should be used to parse following keys.
 */
- (void)setMap:(ViMap *)aMap;

- (void)setVisualMap;
- (void)setInsertMap;
- (void)setExplorerMap;

/**
 * @returns YES if there are partial keys received.
 */
- (BOOL)partial;

/**
 * @returns The current keys being parsed, or the empty string if not
 * partial keys received.
 */
- (NSString *)keyString;

@property(nonatomic,readwrite) BOOL nviStyleUndo;
@property(nonatomic,readonly) ViCommand *last_ftFT_command;
@property(nonatomic,readwrite) int last_search_options;

@end
