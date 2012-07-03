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

#import "ViBundleCommand.h"
#include "logging.h"

@implementation ViBundleCommand

@synthesize input = _input;
@synthesize output = _output;
@synthesize fallbackInput = _fallbackInput;
@synthesize beforeRunningCommand = _beforeRunningCommand;
@synthesize command = _command;
@synthesize htmlMode = _htmlMode;

- (ViBundleCommand *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle
{
	if ((self = (ViBundleCommand *)[super initFromDictionary:dict inBundle:aBundle]) != nil) {
		_input = [[[dict objectForKey:@"input"] lowercaseString] retain];
		_output = [[[dict objectForKey:@"output"] lowercaseString] retain];
		_fallbackInput = [[[dict objectForKey:@"fallbackInput"] lowercaseString] retain];
		_beforeRunningCommand = [[dict objectForKey:@"beforeRunningCommand"] retain];
		_command = [[dict objectForKey:@"command"] retain];
		if (_command == nil) {
			INFO(@"missing command in bundle item %@", self.name);
			[self release];
			return nil;
		}
		_htmlMode = [[[dict objectForKey:@"htmlMode"] lowercaseString] retain];
	}
	return self;
}

- (void)dealloc
{
	[_input release];
	[_output release];
	[_fallbackInput release];
	[_beforeRunningCommand release];
	[_command release];
	[_htmlMode release];
	[super dealloc];
}

@end

