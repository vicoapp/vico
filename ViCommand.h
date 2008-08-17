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
	
	struct vikey *command_key;
	struct vikey *motion_key;
	int count;
	int motion_count;
	char key;
	char character;

	struct vikey *dot_command_key;
	struct vikey *dot_motion_key;
	int dot_count;
	int dot_motion_count;
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
@property(readonly) char key;
@property(readonly) char character;

@end
