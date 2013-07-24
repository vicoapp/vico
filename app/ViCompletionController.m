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

#import "NSString-additions.h"
#import "ViCompletionController.h"
#import "ViCommand.h"
#import "ViKeyManager.h"
#import "ViRegexp.h"
#import "ViThemeStore.h"
#include "logging.h"

@implementation ViCompletionController

@synthesize delegate = _delegate;
@synthesize window;
@synthesize completions = _completions;
@synthesize terminatingKey = _terminatingKey;
@synthesize range = _range;
@synthesize filter = _filter;

+ (id)sharedController
{
	static ViCompletionController *__sharedController = nil;
	if (__sharedController == nil)
		__sharedController = [[ViCompletionController alloc] init];
	return __sharedController;
}

- (id)init
{
	if ((self = [super init])) {
		if (![NSBundle loadNibNamed:@"CompletionWindow" owner:self]) {
			[self release];
			return nil;
		}

		tableView.keyManager = [ViKeyManager keyManagerWithTarget:self
							       defaultMap:[ViMap completionMap]];

		[window setStyleMask:NSBorderlessWindowMask];
		[window setHasShadow:YES];

		// ViTheme *theme = [ViThemeStore defaultTheme];
		// [tableView setBackgroundColor:[_theme backgroundColor]];

		// _matchParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		// [_matchParagraphStyle setLineBreakMode:NSLineBreakByTruncatingHead];
	}
	return self;
}

- (void)dealloc
{
	[window release]; // Top-level nib object
	[_provider release];
	[_completions release];
	[_options release];
	[_prefix release];
	[_onlyCompletion release];
	[_filteredCompletions release];
	[_selection release];
	[_filter release];
	// [_matchParagraphStyle release];
	[super dealloc];
}

- (void)updateBounds
{
	NSSize winsz = NSMakeSize(0, 0);
	for (ViCompletion *c in _filteredCompletions) {
		NSSize sz = [c.title size];
		if (sz.width + 20 > winsz.width)
			winsz.width = sz.width + 20;
	}

	DEBUG(@"got %lu completions, row height is %f",
	    [_filteredCompletions count], [tableView rowHeight]);
	winsz.height = [_filteredCompletions count] * ([tableView rowHeight] + 2) + [label bounds].size.height;

	NSScreen *screen = [NSScreen mainScreen];
	NSSize scrsz = [screen visibleFrame].size;
	NSPoint origin = _screenOrigin;
	if (winsz.height > scrsz.height / 2)
		winsz.height = scrsz.height / 2;
	if (_upwards) {
		if (origin.y + winsz.height > scrsz.height)
			origin.y = scrsz.height - winsz.height - 5;
	} else {
		if (origin.y < winsz.height)
			origin.y = winsz.height + 5;
	}
	if (origin.x + winsz.width > scrsz.width)
		origin.x = scrsz.width - winsz.width - 5;

	NSRect frame = [window frame];
	frame.origin = origin;
	if (!_upwards)
		frame.origin.y -= winsz.height;
	frame.size = winsz;
	if (!NSEqualRects(frame, [window frame])) {
		DEBUG(@"setting frame %@", NSStringFromRect(frame));
		[window setFrame:frame display:YES];
	}
}

- (void)completionResponse:(NSArray *)array error:(NSError *)error
{
	DEBUG(@"got completions: %@, error %@", array, error);
	[_completions release];
	_completions = [[NSMutableArray alloc] initWithArray:array];

	NSUInteger ndropped = 0;
	for (NSUInteger i = 0; i < [_completions count];) {
		id c = [_completions objectAtIndex:i];
		if ([c isKindOfClass:[NSString class]]) {
			/*
			 * For strings, do initial prefix filtering here.
			 */
			if ([_prefix length] > 0 && [c rangeOfString:_prefix options:NSCaseInsensitiveSearch|NSAnchoredSearch].location == NSNotFound)
				[_completions removeObjectAtIndex:i];
			else {
				c = [ViCompletion completionWithContent:c];
				[_completions replaceObjectAtIndex:i++ withObject:c];
			}
		} else if ([c isKindOfClass:[ViCompletion class]]) {
			/*
			 * If prefix length not set (correctly), do initial prefix filtering here.
			 * Prefix length is updated for all items below.
			 */
			ViCompletion *cp = c;
			if (_prefix && cp.prefixLength != _prefixLength &&
			    [cp.content rangeOfString:_prefix options:NSCaseInsensitiveSearch|NSAnchoredSearch].location == NSNotFound)
				[_completions removeObjectAtIndex:i];
			else
				++i;
		} else {
			[_completions removeObjectAtIndex:i];
			++ndropped;
		}
	}

	if (ndropped > 0)
		INFO(@"dropped %lu invalid completions (expected NSString or ViCompletion objects)", ndropped);

	if ([_completions count] == 0) {
		if ([window isVisible]) {
			[self cancel:nil];
			return;
		}
	} else {
		[self updateCompletions];
		[self filterCompletions];
		if ([_filteredCompletions count] == 0) {
			if ([window isVisible]) {
				[self cancel:nil];
				return;
			}
		} else if ([_filteredCompletions count] == 1) {
			if ([window isVisible]) {
				[self acceptByKey:0];
			} else {
				[_onlyCompletion release];
				_onlyCompletion = [[_filteredCompletions objectAtIndex:0] retain];
			}
		}

		/* Automatically insert common prefix among all possible completions.
		 */
		if ([_options rangeOfString:@"p"].location != NSNotFound)
			[self complete_partially:nil];
	}
}

- (ViCompletion *)chooseFrom:(id<ViCompletionProvider>)aProvider
                       range:(NSRange)aRange
		      prefix:(NSString *)aPrefix
                          at:(NSPoint)origin
		     options:(NSString *)optionString
                   direction:(int)direction /* 0 = down, 1 = up */
               initialFilter:(NSString *)initialFilter
{
	_terminatingKey = 0;
	[self reset];

	[_onlyCompletion release];
	_onlyCompletion = nil;

	if (initialFilter)
		_filter = [initialFilter mutableCopy];
	else
		_filter = [[NSMutableString alloc] init];

	_provider = [aProvider retain];

	_range = aRange;
	_prefix = [aPrefix retain];
	_prefixLength = [aPrefix length];
	_options = [optionString retain];
	_fuzzySearch = ([_options rangeOfString:@"f"].location != NSNotFound);
	// Aggressive means we auto-select a unique suggestion.
	BOOL aggressive = ([_options rangeOfString:@"?"].location == NSNotFound);
	_screenOrigin = origin;
	_upwards = (direction == 1);

	DEBUG(@"range is %@, with prefix [%@] and [%@] as initial filter, w/options %@",
	    NSStringFromRange(_range), _prefix, initialFilter, _options);

	DEBUG(@"fetching completions for %@ w/options %@", _prefix, _options);
	NSError *error = nil;
	NSArray *result = nil;
	if ([_provider respondsToSelector:@selector(completionsForString:options:error:)])
		result = [_provider completionsForString:_prefix options:_options error:&error];
	else
		result = [_provider completionsForString:_prefix options:_options];
	if (error) {
		INFO(@"Completion provider %@ returned error %@", _provider, error);
		[self reset];
		return nil;
	}
	[self completionResponse:result error:nil];

	if (_onlyCompletion && aggressive) {
		DEBUG(@"returning %@ as only completion", _onlyCompletion);
		[self reset];
		ViCompletion *ret = [_onlyCompletion autorelease];
		_onlyCompletion = nil;
		return ret;
	}

	if ([_completions count] == 0 || [_filteredCompletions count] == 0) {
		DEBUG(@"%s", "returning without completions");
		[self reset];
		return nil;
	}

	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
	       byExtendingSelection:NO];

	DEBUG(@"showing window %@", window);
	[window orderFront:nil];
	NSInteger code = [NSApp runModalForWindow:window];
	[self reset];

	if (code == NSRunAbortedResponse)
		return nil;
	ViCompletion *ret = [_selection autorelease];
	_selection = nil;
	return ret;
}

+ (NSString *)commonPrefixInCompletions:(NSArray *)completions
{
	if ([completions count] == 0)
		return nil;

	int opts = NSCaseInsensitiveSearch;
	NSString *longestMatch = nil;
	ViCompletion *c = [completions objectAtIndex:0];
	NSString *firstMatch = c.content;
	for (c in completions) {
		NSString *s = c.content;
		NSString *commonPrefix = [firstMatch commonPrefixWithString:s options:opts];
		if (longestMatch == nil || [commonPrefix length] < [longestMatch length])
			longestMatch = commonPrefix;
	}
	return longestMatch;
}

- (void)setCompletions:(NSMutableArray *)newCompletions
{
	[_filter release];
	_filter = [[NSMutableString alloc] init];

	[newCompletions retain];
	[_completions release];
	_completions = newCompletions;

	[_filteredCompletions release];
	_filteredCompletions = nil;

	[self filterCompletions];
}

- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command
{
	if (![self respondsToSelector:command.action] ||
	    (command.motion && ![self respondsToSelector:command.motion.action])) {
		return NO;
	}

	return [command performWithTarget:self];
}

+ (void)appendFilter:(NSString *)string
           toPattern:(NSMutableString *)pattern
          fuzzyClass:(NSString *)fuzzyClass
{
	NSUInteger i;
	for (i = 0; i < [string length]; i++) {
		unichar c = [string characterAtIndex:i];
		if (i != 0)
			[pattern appendFormat:@"%@*?", fuzzyClass];
		[pattern appendFormat:@"(%s%C)", [ViRegexp needEscape:c] ? "\\" : "", c];
	}
}

- (void)filterCompletions
{
	if (_fuzzySearch)
		[label setStringValue:[NSString stringWithFormat:@"fuzzy filter: %@", _filter]];
	else
		[label setStringValue:[NSString stringWithFormat:@"prefix filter: %@%@", _prefix, _filter]];

	ViRegexp *rx = nil;
	if ([_filter length] > 0) {
		NSMutableString *pattern = [NSMutableString string];
		if (_fuzzySearch) {
			[pattern appendFormat:@"^.{%lu}.*", _prefixLength];
			[ViCompletionController appendFilter:_filter toPattern:pattern fuzzyClass:@"."];
			[pattern appendString:@".*$"];
		} else {
			[pattern appendFormat:@"^.{%lu}%@", _prefixLength, [ViRegexp escape:_filter]];
		}

		rx = [ViRegexp regexpWithString:pattern
					options:ONIG_OPTION_IGNORECASE];
	}

	[_filteredCompletions release];
	_filteredCompletions = [[NSMutableArray alloc] init];

	for (ViCompletion *c in _completions) {
		// DEBUG(@"filtering completion %@ on %@", c, rx);
		NSString *s = c.content;
		if ([s length] < _prefixLength)
			continue;
		ViRegexpMatch *m = nil;
		if (rx == nil || (m = [rx matchInString:s]) != nil) {
			c.filterMatch = m;
			[_filteredCompletions addObject:c];
		}
	}

	if (_fuzzySearch)
		[_filteredCompletions sortUsingComparator:^(id a, id b) {
			ViCompletion *ca = a, *cb = b;
			if (ca.score > cb.score)
				return (NSComparisonResult)NSOrderedAscending;
			else if (cb.score > ca.score)
				return (NSComparisonResult)NSOrderedDescending;
			return (NSComparisonResult)NSOrderedSame;
		}];

	[tableView reloadData];
	[self updateBounds];
}

- (void)setFilter:(NSString *)aString
{
	[_filter release];
	_filter = [aString mutableCopy];
	[self filterCompletions];
}

- (void)reset
{
	[_completions release];
	_completions = nil;

	[_filteredCompletions release];
	_filteredCompletions = nil;

	[_filter release];
	_filter = nil;

	[_provider release];
	_provider = nil;

	[_prefix release];
	_prefix = nil;

	[_options release];
	_options = nil;

	// [self setDelegate:nil]; // delegate must be set for each completion, we don't want a lingering deallocated delegate to be called
}

- (void)acceptByKey:(NSInteger)termKey
{
	_terminatingKey = termKey;
	NSInteger row = [tableView selectedRow];
	if (row >= 0 && row < [_filteredCompletions count]) {
		[_selection release];
		_selection = [[_filteredCompletions objectAtIndex:row] retain];
	}
	[window orderOut:nil];
	[NSApp stopModal];
	[self reset];
}

- (BOOL)cancel:(ViCommand *)command
{
	_terminatingKey = [[command.mapping.keySequence lastObject] integerValue];
	[window orderOut:nil];
	[NSApp abortModal];
	[self reset];

	return YES;
}

- (BOOL)accept:(ViCommand *)command
{
	[self acceptByKey:[[command.mapping.keySequence lastObject] integerValue]];
	return YES;
}

- (BOOL)filter:(ViCommand *)command
{
	NSInteger keyCode = [[command.mapping.keySequence lastObject] integerValue];

	SEL sel = @selector(completionController:shouldTerminateForKey:);
	if ([_delegate respondsToSelector:sel]) {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
		    [(NSObject *)_delegate methodSignatureForSelector:sel]];
		[invocation setSelector:sel];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&keyCode atIndex:3];
		[invocation invokeWithTarget:_delegate];
		BOOL shouldTerminate;
		[invocation getReturnValue:&shouldTerminate];
		if (shouldTerminate) {
			[self acceptByKey:keyCode];
			return YES;
		}
	}

	if (keyCode < 0x20) /* ignore control characters? */
		return NO;
	if (keyCode > 0xFFFF) /* ignore key equivalents? */
		return NO;

	NSString *string = [NSString stringWithFormat:@"%C", (unichar)keyCode];
	[_filter appendString:string];
	[self filterCompletions];
	if ([_filteredCompletions count] == 0) {
		_terminatingKey = keyCode;
		[window orderOut:nil];
		[NSApp abortModal];
		return YES;
	} else {
		SEL sel = @selector(completionController:appendedStringWithoutCompleting:);
		NSInvocation *invocation =
		  [NSInvocation invocationWithMethodSignature:[(NSObject *)_delegate methodSignatureForSelector:sel]];
		[invocation setSelector:sel];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&string atIndex:3];
		[invocation invokeWithTarget:_delegate];
	}

	return YES;
}

- (void)updateCompletions
{
	for (ViCompletion *c in _completions) {
		c.prefixLength = _prefixLength;
		c.filterIsFuzzy = _fuzzySearch;
	}
}

- (BOOL)complete_partially:(ViCommand *)command
{
	SEL sel = @selector(completionController:insertPartialCompletion:inRange:);

	if (![_delegate respondsToSelector:sel])
		return NO;

	NSString *partialCompletion =
	    [ViCompletionController commonPrefixInCompletions:_filteredCompletions];
	if ([partialCompletion length] == 0)
		return YES;
	DEBUG(@"common prefix is [%@], range is %@", partialCompletion, NSStringFromRange(_range));
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
	    [(NSObject *)_delegate methodSignatureForSelector:sel]];
	[invocation setSelector:sel];
	[invocation setArgument:&self atIndex:2];
	[invocation setArgument:&partialCompletion atIndex:3];
	[invocation setArgument:&_range atIndex:4];
	[invocation invokeWithTarget:_delegate];
	BOOL ret;
	[invocation getReturnValue:&ret];
	if (!ret)
		return NO;

	_range = NSMakeRange(_range.location, [partialCompletion length]);
	DEBUG(@"_range => %@", NSStringFromRange(_range));
	_prefixLength = _range.length;
	[self setCompletions:_filteredCompletions];
	[self updateCompletions];

	return YES;
}

- (BOOL)accept_or_complete_partially:(ViCommand *)command
{
	SEL sel = @selector(completionController:insertPartialCompletion:inRange:);

	if (_fuzzySearch || ![_delegate respondsToSelector:sel])
		return [self accept:command];

	if (![self complete_partially:command])
		return [self cancel:command];

	if ([_filteredCompletions count] == 1)
		return [self accept:command];

	return YES;
}

- (BOOL)move_up:(ViCommand *)command
{
	NSUInteger row = [tableView selectedRow];
	if (row == -1)
		row = 0;
	else if (row == 0)
		return NO;
	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:--row]
	       byExtendingSelection:NO];
	[tableView scrollRowToVisible:row];
	return YES;
}

- (BOOL)move_down:(ViCommand *)command
{
	NSUInteger row = [tableView selectedRow];
	if (row == -1)
		row = 0;
	else if (row + 1 >= [tableView numberOfRows])
		return NO;
	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:++row]
	       byExtendingSelection:NO];
	[tableView scrollRowToVisible:row];
	return YES;
}

- (BOOL)toggle_fuzzy:(ViCommand *)command
{
	_fuzzySearch = !_fuzzySearch;
	for (ViCompletion *c in _completions)
		c.filterIsFuzzy = _fuzzySearch;
	[self filterCompletions];
	if ([_filteredCompletions count] == 1)
		return [self accept:command];
	return YES;
}

#pragma mark -
#pragma mark NSTableViewDataSource Protocol

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [_filteredCompletions count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex
{
	return [(ViCompletion *)[_filteredCompletions objectAtIndex:rowIndex] title];
}

@end
