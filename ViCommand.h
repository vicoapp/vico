//
//  Parser for vi commands.
//
//  Created by Martin Hedenfalk on 2007-12-02.
//  Copyright 2007 Martin Hedenfalk. All rights reserved.
//

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

	struct vikey *command;
	struct vikey *motion_command;
	int count;
	int motion_count;
	unichar key;
	unichar motion_key;
	unichar argument; // extra character argument for f, t, r etc.

	struct vikey *dot_command;
	struct vikey *dot_motion_command;
	int dot_count;
	int dot_motion_count;

	struct vikey *last_ftFT_command;
	unichar last_ftFT_argument;

	NSString *text;
}

- (void)pushKey:(unichar)key;
- (void)reset;
- (int)ismotion;
- (BOOL)line_mode;
- (NSString *)motion_method;

@property(readonly) BOOL complete;
@property(readonly) NSString *method;
@property(readonly) int count;
@property(readonly) int motion_count;
@property(readonly) unichar key;
@property(readonly) unichar motion_key;
@property(readonly) unichar argument;
@property(copy) NSString *text;

@end
