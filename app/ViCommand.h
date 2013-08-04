/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViMap.h"
#import "ViMacro.h"

/** A generated vi command.
 */
@interface ViCommand : NSObject <NSCopying>
{
	ViMapping		*_mapping;
	ViCommand		*_motion;
	__weak ViCommand	*_operator;	// XXX: not retained!
	ViMacro			*_macro;
	BOOL			 _fromDot;
	BOOL			 _isLineMode;
	BOOL			 _updatesAllCursors;
	int			 _count;
	int			 _saved_count;
	unichar			 _argument;
	unichar			 _reg;
	id			 _text;
	NSRange			 _range;
	NSInteger		 _caret;
	NSMutableArray		*_messages;
	NSArray			*_keySequence;
}

/** The mapping that describes the action. */
@property(nonatomic,readonly) ViMapping *mapping;

/** Any count given to the command. */
@property(nonatomic,readwrite) int count;

@property(nonatomic,readwrite) int saved_count;
@property(nonatomic,readwrite) BOOL fromDot;

/** YES if the mapped action operates on whole lines. */
@property(nonatomic,readwrite) BOOL isLineMode;

/** YES if the mapped action is a motion command. */
@property(nonatomic,readonly) BOOL isMotion;

/** YES if the mapped action updates all cursors when there are more than one. */
@property(nonatomic,readonly) BOOL updatesAllCursors;

/** YES if the mapped action is a motion component for an operator. */
@property(nonatomic,readonly) BOOL hasOperator;

/** The total key sequence that generated this command. */
@property(nonatomic,readwrite,copy) NSArray *keySequence;

/** The argument, if any. Only applicable if the mapping specified the ViMapNeedArgument flag. */
@property(nonatomic,readwrite) unichar argument;

/** The register, if any. */
@property(nonatomic,readwrite) unichar reg;

/** The motion command, if this command is an operator action. */
@property(nonatomic,readwrite,retain) ViCommand *motion;

/** The operator command, if this command is a motion component. */
@property(nonatomic,readwrite,assign) __weak ViCommand *operator;

@property(nonatomic,readwrite,copy) id text;

@property(nonatomic,readonly) NSMutableArray *messages;

@property(nonatomic,readwrite) NSRange range;
@property(nonatomic,readwrite) NSInteger caret;

@property(nonatomic,readwrite,retain) ViMacro *macro;

+ (ViCommand *)commandWithMapping:(ViMapping *)aMapping
                            count:(int)aCount;
- (ViCommand *)initWithMapping:(ViMapping *)aMapping
                         count:(int)aCount;

- (SEL)action;
- (BOOL)isUndo;
- (BOOL)isDot;
- (void)message:(NSString *)message;
- (BOOL)performWithTarget:(id)target;

@end
