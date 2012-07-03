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

#import "ViSyntaxContext.h"
#import "logging.h"

@implementation ViSyntaxContext

@synthesize characters = _characters;
@synthesize range = _range;
@synthesize lineOffset = _lineOffset;
@synthesize restarting = _restarting;
@synthesize cancelled = _cancelled;

+ (ViSyntaxContext *)syntaxContextWithLine:(NSUInteger)line
{
	return [[[ViSyntaxContext alloc] initWithLine:line] autorelease];
}

- (ViSyntaxContext *)initWithLine:(NSUInteger)line
{
	if ((self = [super init]) != nil) {
		_lineOffset = line;
		_restarting = YES;
	}
	return self;
}

- (ViSyntaxContext *)initWithCharacters:(unichar *)chars
				  range:(NSRange)aRange
				   line:(NSUInteger)line
			     restarting:(BOOL)flag
{
	if ((self = [super init]) != nil) {
		_characters = chars;
		_range = aRange;
		_lineOffset = line;
		_restarting = flag;
	}
	return self;
}

- (void)finalize
{
	free(_characters);
	[super finalize];
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	free(_characters);
	[super dealloc];
}

@end
