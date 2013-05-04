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

#import "ExTextField.h"
#import "ViThemeStore.h"
#import "ViTextView.h"
#import "ExParser.h"
#include "logging.h"

@interface NSObject (private)
- (void)textField:(ExTextField *)textField executeExCommand:(NSString *)exCommand;
@end

@implementation ExTextField

@synthesize exMode;

- (void)awakeFromNib
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSArray *exCommandHistory = [defs arrayForKey:@"exCommandHistory"];
	NSArray *exSearchHistory = [defs arrayForKey:@"exSearchHistory"];

	if (exCommandHistory)
		_commandHistory = [exCommandHistory mutableCopy];
	else
		_commandHistory = [[NSMutableArray alloc] init];

	if (exSearchHistory)
		_searchHistory = [exSearchHistory mutableCopy];
	else
		_searchHistory = [[NSMutableArray alloc] init];

	DEBUG(@"loaded %lu lines from history", [_history count]);
}

- (void)dealloc
{
	[_commandHistory release];
	[_searchHistory release];
	[_current release];
	[super dealloc];
}

- (void)addToHistory:(NSString *)line
{
	NSMutableArray *history = [self currentHistory];

	/* Add the command to the history. */
	NSUInteger i = [history indexOfObject:line];
	if (i != NSNotFound)
		[history removeObjectAtIndex:i];
	[history insertObject:line atIndex:0];
	while ([history count] > 100)
		[history removeLastObject];

	DEBUG(@"history = %@", history);
	[self updateCurrentHistoryWith:history];
}

- (NSMutableArray *)currentHistory
{
	if ([self.exMode isEqualToString:ViExModeCommand])
		return _commandHistory;
	else
		return _searchHistory;
}

- (int)currentHistoryIndex
{
	if ([self.exMode isEqualToString:ViExModeCommand])
		return _commandHistoryIndex;
	else
		return _searchHistoryIndex;
}

- (void)updateCurrentHistoryWith:(NSArray *)history
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	if ([self.exMode isEqualToString:ViExModeCommand])
		[defs setObject:history forKey:@"exCommandHistory"];
	else
		[defs setObject:history forKey:@"exSearchHistory"];
}

- (void)setCurrentHistoryIndex:(int)newIndex
{
	if ([self.exMode isEqualToString:ViExModeCommand])
		_commandHistoryIndex = newIndex;
	else
		_searchHistoryIndex = newIndex;
}

- (BOOL)becomeFirstResponder
{
	ViTextView *editor = [self editor];
	DEBUG(@"using field editor %@", editor);

    NSRect superFrame = [[self superview] frame];
    CGFloat superSuperWidth = [[[self superview] superview] bounds].size.width;
    superFrame.size.width = superSuperWidth - 2 * (superFrame.origin.x);
    [[self superview] setFrame:superFrame];

	[_current release];
	_current = nil;
	[self setCurrentHistoryIndex:-1];

	[editor setInsertMode:nil];
	[editor setCaret:0];

	_running = YES;
	return [super becomeFirstResponder];
}

- (BOOL)navigateHistory:(BOOL)upwards prefix:(NSString *)prefix
{
	if ([self currentHistoryIndex] == -1) {
		[_current release];
		_current = [[self stringValue] copy];
	}

	ViTextView *editor = (ViTextView *)[self currentEditor];

	int i = [self currentHistoryIndex];
	DEBUG(@"history index = %i, count = %lu, prefix = %@",
	    [self currentHistoryIndex], [[self currentHistory] count], prefix);
	while (upwards ? i + 1 < [[self currentHistory] count] : i > 0) {
		i += (upwards ? +1 : -1);
		NSString *item = [[self currentHistory] objectAtIndex:i];
		DEBUG(@"got item %@", item);
		if ([prefix length] == 0 || [[item lowercaseString] hasPrefix:prefix]) {
			DEBUG(@"insert item %@", item);
			[editor setString:item];
			[editor setInsertMode:nil];
			[self setCurrentHistoryIndex:i];
			return YES;
		}
	}

	if (!upwards && i == 0) {
		[editor setString:_current];
		[editor setInsertMode:nil];
		[self setCurrentHistoryIndex:-1];
		return YES;
	}

	return NO;
}

- (ViTextView *)editor {
	return (ViTextView *)[[self window] fieldEditor:YES forObject:self];
}

- (BOOL)prev_history_ignoring_prefix:(ViCommand *)command
{
	return [self navigateHistory:YES prefix:nil];
}

- (BOOL)prev_history:(ViCommand *)command
{
	NSRange sel = [[self currentEditor] selectedRange];
	NSString *prefix = [[[self stringValue] substringToIndex:sel.location] lowercaseString];
	return [self navigateHistory:YES prefix:prefix];
}

- (BOOL)next_history_ignoring_prefix:(ViCommand *)command
{
	return [self navigateHistory:NO prefix:nil];
}

- (BOOL)next_history:(ViCommand *)command
{
	NSRange sel = [[self currentEditor] selectedRange];
	NSString *prefix = [[[self stringValue] substringToIndex:sel.location] lowercaseString];
	return [self navigateHistory:NO prefix:prefix];
}

- (BOOL)ex_cancel:(ViCommand *)command
{
	_running = NO;
	if ([[self delegate] respondsToSelector:@selector(textField:executeExCommand:)])
		[(NSObject *)[self delegate] textField:self executeExCommand:nil];
	ViTextView *editor = [self editor];
	[editor endUndoGroup];
	return YES;
}

- (BOOL)ex_execute:(ViCommand *)command
{
	NSString *exCommand = [self stringValue];
	[self addToHistory:exCommand];
	_running = NO;
	if ([[self delegate] respondsToSelector:@selector(textField:executeExCommand:)])
		[(NSObject *)[self delegate] textField:self executeExCommand:exCommand];
	ViTextView *editor = [self editor];
	[editor endUndoGroup];
	return YES;
}

- (BOOL)ex_complete:(ViCommand *)command
{
	ViTextView *editor = [self editor];

	id<ViCompletionProvider> provider = nil;
	NSRange range;
	NSError *error = nil;
	[[ExParser sharedParser] parse:[self stringValue]
				 caret:[editor caret]
			    completion:&provider
				 range:&range
				 error:&error];

	DEBUG(@"completion provider is %@", provider);
	if (provider == nil)
		return NO;

	DEBUG(@"completion range is %@", NSStringFromRange(range));
	NSString *word = [[[editor textStorage] string] substringWithRange:range];
	DEBUG(@"completing word [%@]", word);

	return [editor presentCompletionsOf:word
			       fromProvider:provider
				  fromRange:range
				    options:command.mapping.parameter];
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
	if (_running)
		[self ex_cancel:nil];
	else
		[super textDidEndEditing:aNotification];
}

@end
