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

#import "ViCommand.h"
#include "logging.h"

@implementation ViCommand

@synthesize mapping = _mapping;
@synthesize count = _count;
@synthesize saved_count = _saved_count;
@synthesize fromDot = _fromDot;
@synthesize argument = _argument;
@synthesize reg = _reg;
@synthesize motion = _motion;
@synthesize text = _text;
@synthesize isLineMode = _isLineMode;
@synthesize operator = _operator;
@synthesize range = _range;
@synthesize caret = _caret;
@synthesize macro = _macro;
@synthesize messages = _messages;
@synthesize keySequence = _keySequence;

+ (ViCommand *)commandWithMapping:(ViMapping *)aMapping count:(int)aCount
{
	return [[ViCommand alloc] initWithMapping:aMapping count:aCount];
}

- (ViCommand *)initWithMapping:(ViMapping *)aMapping count:(int)aCount
{
	if ((self = [super init]) != nil) {
		_mapping = aMapping;
		_isLineMode = _mapping.isLineMode;
		_count = _saved_count = aCount;
	}
	return self;
}

- (void)dealloc
{
	[_motion setOperator:nil];
}

- (BOOL)performWithTarget:(id)target
{
	if (target == nil)
		return NO;
	
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	
        return (BOOL)[target performSelector:_mapping.action withObject:self];
	
#pragma clang diagnostic pop
}

- (SEL)action
{
	return _mapping.action;
}

- (BOOL)isLineMode
{
	return _isLineMode;
}

- (BOOL)isMotion
{
	return [_mapping isMotion];
}

- (BOOL)isExcludedFromDot
{
	return [_mapping isExcludedFromDot];
}

- (BOOL)hasOperator
{
	return _operator != nil;
}

- (BOOL)isUndo
{
	return _mapping.action == @selector(vi_undo:);
}

- (BOOL)isDot
{
	return _mapping.action == @selector(dot:);
}

- (id)copyWithZone:(NSZone *)zone
{
	ViCommand *copy = [[ViCommand allocWithZone:zone] initWithMapping:_mapping count:_saved_count];

	/* Set the fromDot flag. 
	 * We copy commands mainly for the dot command. This flag is necessary for
	 * the nvi undo style as it needs to know if a command is a dot repeat or not.
	 */
	[copy setFromDot:YES];

	[copy setIsLineMode:_isLineMode];
	[copy setArgument:_argument];
	[copy setReg:_reg];
	if (_motion) {
		ViCommand *motionCopy = [_motion copy];
		[motionCopy setOperator:copy];
		[copy setMotion:motionCopy];
	} else
		[copy setOperator:_operator];
	[copy setText:_text];

	return copy;
}

- (NSString *)description
{
	if (_motion)
		return [NSString stringWithFormat:@"<ViCommand %@: %@ * %i, motion = %@>",
		    _mapping.keyString, NSStringFromSelector(_mapping.action), _count, _motion];
	else
		return [NSString stringWithFormat:@"<ViCommand %@: %@ * %i>",
		    _mapping.keyString, NSStringFromSelector(_mapping.action), _count];
}

- (void)message:(NSString *)message
{
	DEBUG(@"got message %@", message);
	if (message == nil)
		return;
	if (_messages == nil)
		_messages = [[NSMutableArray alloc] init];
	[_messages addObject:message];
}

@end

