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
	NSString *last_search_pattern;
	int last_search_options;

	id text;
}

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

- (void)reset;

- (void)setMap:(ViMap *)aMap;
- (void)setVisualMap;
- (void)setInsertMap;
- (void)setExplorerMap;
- (BOOL)partial;
- (NSString *)keyString;

@property(nonatomic,readwrite) BOOL nviStyleUndo;
@property(nonatomic,readonly) ViCommand *last_ftFT_command;
@property(nonatomic,readwrite, assign) NSString *last_search_pattern;
@property(nonatomic,readwrite) int last_search_options;

@end
