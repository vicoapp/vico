#import <Cocoa/Cocoa.h>

typedef enum { ViCommandInitialState, ViCommandNeedMotion, ViCommandNeedChar } ViCommandState;

struct vikey
{
	NSString *method;
	int key;
	unsigned flags;
};

@interface ViCommand : NSObject
{
	BOOL complete;
	ViCommandState state;

	NSString *method;

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

	struct vikey *last_ftFT_command;
	unichar last_ftFT_argument;

	NSArray *text;
}

- (void)pushKey:(unichar)key;
- (void)reset;
- (BOOL)ismotion;
- (BOOL)line_mode;
- (NSString *)motion_method;
- (void)setVisualMap;

@property(readonly) BOOL complete;
@property(readonly) NSString *method;
@property(readwrite) int count;
@property(readwrite) int motion_count;
@property(readonly) unichar key;
@property(readonly) BOOL is_dot;
@property(readonly) unichar motion_key;
@property(readonly) unichar argument;
@property(readwrite, copy) NSArray *text;

@end

