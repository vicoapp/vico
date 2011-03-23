typedef enum { ViCommandInitialState, ViCommandNeedMotion, ViCommandNeedChar } ViCommandState;

struct vikey
{
	NSString *method;
	unichar key;
	unsigned int flags;
	struct vikey *map;
};

@interface ViCommand : NSObject
{
	BOOL complete;
	ViCommandState state;

	NSString *method;

	BOOL literal_next;

	struct vikey *map;
	struct vikey *command;
	struct vikey *motion_command;
	int count;
	int motion_count;
	unichar key;
	unichar motion_key;
	unichar argument; // extra character argument for f, t, r etc.

	BOOL is_dot;	// true if command is the dot command
	struct vikey *dot_command;
	struct vikey *dot_motion_command;
	int dot_count;
	int dot_motion_count;
	unichar dot_argument;

	// used for nvi-style undo
	BOOL nviStyleUndo;
	struct vikey *last_command;

	unichar last_ftFT_command;
	unichar last_ftFT_argument;

	// search state
	NSString *last_search_pattern;
	int last_search_options;

	id text;
	BOOL partial;
}

- (void)pushKey:(unichar)key;
- (void)reset;
- (BOOL)ismotion;
- (BOOL)line_mode;
- (NSString *)motion_method;
- (void)setVisualMap;
- (void)setInsertMap;
- (void)setExplorerMap;

@property(readonly) BOOL complete;
@property(readonly) BOOL partial;
@property(readonly) NSString *method;
@property(readwrite) int count;
@property(readwrite) int motion_count;
@property(readonly) unichar key;
@property(readonly) BOOL is_dot;
@property(readonly) unichar motion_key;
@property(readwrite) unichar argument;
@property(readwrite, assign) id text;
@property(readwrite) BOOL nviStyleUndo;
@property(readonly) unichar last_ftFT_command;
@property(readonly) unichar last_ftFT_argument;
@property(readwrite, assign) NSString *last_search_pattern;
@property(readwrite) int last_search_options;

@end

@interface ViKey : NSObject
{
	unichar		 code;
	unsigned int	 flags;
}
+ (ViKey *)keyWithCode:(unichar)aCode flags:(unsigned int)aFlags;
- (ViKey *)initWithCode:(unichar)aCode flags:(unsigned int)aFlags;
@property(readonly) unichar code;
@property(readonly) unsigned int flags;
@end

