//
//  Parser for vi commands.
//
//  Created by Martin Hedenfalk on 2007-12-02.
//  Copyright 2007 Martin Hedenfalk. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum { ViCommandInitialState, ViCommandNeedMotion } ViCommandState;

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
	NSString *motion_method;
	
	struct vikey *command_key;
	int count;
	int motion_count;

	NSRange start_range;
	NSRange stop_range;

	struct vikey *dot_command_key;
	int dot_count;
	NSString *dot_motion_method;
	int dot_motion_count;
}

- (void)pushKey:(unichar)key;
- (void)reset;
- (int)key;

@property(readonly) BOOL complete;
@property(readonly) NSString *method;
@property(readonly) NSString *motion_method;
@property(readonly) int count;
@property(readonly) int motion_count;
@property NSRange start_range;
@property NSRange stop_range;

@end
