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

#import "ViRegisterManager.h"
#import "ViWindowController.h"
#include "logging.h"

@implementation ViRegisterManager

@synthesize lastExecutedRegister = _lastExecutedRegister;

+ (id)sharedManager
{
	static ViRegisterManager *__sharedManager = nil;
	if (__sharedManager == nil)
		__sharedManager = [[ViRegisterManager alloc] init];
	return __sharedManager;
}

- (id)init
{
	if ((self = [super init]) != nil) {
		_registers = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_registers release];
	[super dealloc];
}

- (NSString *)_contentOfRegister:(unichar)regName
{
	if (regName == '*' || regName == '+') {
		NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
		[pasteBoard types];
		return [pasteBoard stringForType:NSStringPboardType];	
	} else if (regName == '%') {
		return [[[[ViWindowController currentWindowController] currentDocument] fileURL] absoluteString];
	} else if (regName == '#') {
		return [[[ViWindowController currentWindowController] alternateURL] absoluteString];
	} else if (regName == '_')
		return @"";

	if (regName >= 'A' && regName <= 'Z')
		regName = tolower(regName);
	return [_registers objectForKey:[self nameOfRegister:regName]];
}

- (NSString *)contentOfRegister:(unichar)regName
{
	return [[[self _contentOfRegister:regName] retain] autorelease];
}

- (void)setContent:(NSString *)content ofRegister:(unichar)regName
{
	if (regName == '_')
		return;

	if (content == nil)
		content = @"";

	if (regName == '*' || regName == '+' || (regName == 0 && [[NSUserDefaults standardUserDefaults] boolForKey:@"clipboard"])) {
		NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
		[pasteBoard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil]
				   owner:nil];
		[pasteBoard setString:content forType:NSStringPboardType];
	}

	/* Uppercase registers append. */
	if (regName >= 'A' && regName <= 'Z') {
		regName = tolower(regName);
		NSString *currentContent = [self _contentOfRegister:regName];
		if (currentContent)
			content = [currentContent stringByAppendingString:content];
	}

	[_registers setObject:content forKey:[self nameOfRegister:regName]];
	if (regName != 0 && regName != '"' && regName != '/' && regName != ':')
		[_registers setObject:content forKey:[self nameOfRegister:0]];
}

- (NSString *)nameOfRegister:(unichar)regName
{
	if (regName == 0 || regName == '"')
		return @"unnamed";
	else if (regName == '*' || regName == '+')
		return @"pasteboard";
	else if (regName == '%')
		return @"current file";
	else if (regName == '#')
		return @"alternate file";
	else if (regName == ':')
		return @"last ex command";
	else
		return [NSString stringWithFormat:@"%C", regName];
}

@end
