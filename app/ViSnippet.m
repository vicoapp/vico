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

#include <sys/types.h>
#include <sys/stat.h>
#include "sys_queue.h"

#import "ViSnippet.h"
#import "ViBundle.h"
#import "ViError.h"
#import "NSScanner-additions.h"
#import "ViTaskRunner.h"
#include "logging.h"


@implementation ViTabstop

@synthesize num = _num;
@synthesize parent = _parent;
@synthesize mirror = _mirror;
@synthesize range = _range;
@synthesize value = _value;
@synthesize rx = _rx;
@synthesize format = _format;
@synthesize options = _options;
@synthesize filter = _filter;
@synthesize index = _index;

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViTabstop %ld@%@: [%@], pipe: [%@], parent: %@, mirror of: %@>",
	    _num, NSStringFromRange(_range), _value, _filter, _parent, _mirror];
}
@end




@implementation ViSnippet

@synthesize range = _range;
@synthesize selectedRange = _selectedRange;
@synthesize caret = _caret;
@synthesize currentTabStop = _currentTabStop;
@synthesize finished = _finished;

- (void)snippetTask:(ViTaskRunner *)runner finishedWithStatus:(int)status contextInfo:(id)ctx
{
	if (status != 0)
		DEBUG(@"%@: exited with status %i", runner, status);
	[_shellOutput release];
	_shellOutput = [[NSMutableString alloc] initWithData:[runner standardOutput]
						    encoding:NSUTF8StringEncoding];

	if ([_shellOutput length] > 0)
		[_shellOutput replaceOccurrencesOfString:@"\n"
					      withString:@""
						 options:0
						   range:NSMakeRange([_shellOutput length] - 1, 1)];
}

- (NSMutableString *)runShellCommand:(NSString *)shellCommand
                           withInput:(NSString *)inputText
                               error:(NSError **)outError
{
	DEBUG(@"shell command = [%@]", shellCommand);

	if ([shellCommand length] == 0)
		return [NSMutableString stringWithString:@""];

	NSMutableDictionary *env = [_environment mutableCopy];
	for (ViTabstop *ts in _tabstops) {
		if (ts.mirror == nil)
			[env setObject:(ts.value ?: @"")
				forKey:[NSString stringWithFormat:@"TM_TABSTOP_%ld", ts.num]];
	}
	[env setObject:([self string] ?: @"") forKey:@"TM_SNIPPET"];
	DEBUG(@"shell environment is %@", env);

	ViTaskRunner *runner = [[ViTaskRunner alloc] init];
	[runner launchShellCommand:shellCommand
		 withStandardInput:[inputText dataUsingEncoding:NSUTF8StringEncoding]
		       environment:env
		  currentDirectory:nil
	    asynchronouslyInWindow:nil
			     title:shellCommand
			    target:self
			  selector:@selector(snippetTask:finishedWithStatus:contextInfo:)
		       contextInfo:nil
			     error:outError];
	[runner release];
	[env release];

	return [_shellOutput autorelease];
}

- (NSMutableString *)parseString:(NSString *)aString
                       stopChars:(NSString *)stopChars
                   parentTabstop:(ViTabstop *)parentTabstop
                   allowTabstops:(BOOL)allowTabstops
                   scannedLength:(NSUInteger *)scannedLength
                           error:(NSError **)outError
{
	NSString *variable, *value;
	NSMutableString *defaultValue;
	NSScanner *scan;
	NSMutableString *s = [NSMutableString string];
	NSString *regexp, *format, *options, *filter;
	unichar ch;

	scan = [NSScanner scannerWithString:aString];
	[scan setCharactersToBeSkipped:nil];

	while ([scan scanCharacter:&ch]) {
		if (ch == '\\') {
			/* Skip the backslash escape if it's followed by a reserved character. */
			if ([scan scanCharacter:&ch]) {
				/* The TextMate escaping rules are totally insane! */
				NSString *insChar = [NSString stringWithFormat:@"%C", ch];
				if (ch != '$' && ch != '`' && ch != '\\' &&
				    [stopChars rangeOfString:insChar].location == NSNotFound)
					[s appendString:@"\\"];
				[s appendString:insChar];
			} else
				[s appendString:@"\\"];
		} else if (ch == '$') {
			BOOL bracedExpression = [scan scanString:@"{" intoString:nil];
			NSInteger tabStop = -1;
			ViTabstop *ts = nil;
			if (allowTabstops && [scan scanInteger:&tabStop]) {
				/*
				 * Tab Stop.
				 */
				if (tabStop < 0) {
					if (outError)
						*outError = [ViError errorWithFormat:@"Negative tab stop number %li", tabStop];
					return NO;
				}
				value = nil;
				DEBUG(@"got tab stop %li at %lu", tabStop, [s length]);
				ts = [[ViTabstop alloc] init];
				ts.num = tabStop;
				ts.parent = parentTabstop;
				ts.index = [_tabstops count];
				[_tabstops addObject:ts];
				[ts release];
				if (tabStop > _maxTabNum)
					_maxTabNum = tabStop;
			} else if ([scan scanShellVariableIntoString:&variable]) {
				/*
				 * Regular shell variable.
				 */
				value = [_environment objectForKey:variable];
				DEBUG(@"got variable [%@] = [%@]", variable, value);
			} else {
				if (outError)
					*outError = [ViError errorWithFormat:@"Invalid shell variable name at character %lu", [scan scanLocation] + 1];
				return NO;
			}

			regexp = nil;
			format = nil;
			options = nil;
			ViRegexp *rx = nil;
			filter = nil;
			defaultValue = nil;
			if (bracedExpression) {
				if ([scan scanString:@":" intoString:nil]) {
					/*
					 * Got a default value.
					 */
					NSString *substring = [aString substringFromIndex:[scan scanLocation]];
					NSUInteger len;
					defaultValue = [self parseString:substring
					                       stopChars:@"|}"
					                   parentTabstop:ts
					                   allowTabstops:ts ? YES : NO
					                   scannedLength:&len
					                           error:outError];
					if (!defaultValue)
						return NO;
					DEBUG(@"nested parse scanned %lu characters and returned [%@]", len, defaultValue);
					[scan setScanLocation:[scan scanLocation] + len];
				} else if ([scan scanString:@"/" intoString:nil]) {
					/*
					 * Regexp replacement.
					 */
					if (![scan scanUpToUnescapedCharacter:'/' intoString:&regexp] ||
					    ![scan scanString:@"/" intoString:nil] ||
					    ![scan scanUpToUnescapedCharacter:'/' intoString:&format] ||
					    ![scan scanString:@"/" intoString:nil]) {
						if (outError)
							*outError = [ViError errorWithFormat:@"Missing separating slash at %lu",
							    [scan scanLocation] + 1];
						return NO;
					}

					/*
					 * If the replacement format escaped the delimiting slash, we should remove the escape.
					 * Other escapes should be left intact though.
					 */
					format = [format stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];

					[scan scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet]
					                 intoString:&options];
					if (options == nil)
						options = @"";
					DEBUG(@"regexp = %@", regexp);
					DEBUG(@"format = %@", format);
					DEBUG(@"options = %@", options);

					int opts = 0;
					if ([options rangeOfString:@"i"].location != NSNotFound)
						opts |= ONIG_OPTION_IGNORECASE;

					rx = [ViRegexp regexpWithString:regexp options:opts error:outError];
					if (rx == nil)
						return NO;

					value = [self transformValue:(value ?: @"")
					                 withPattern:rx
					                      format:format
							      global:([options rangeOfString:@"g"].location != NSNotFound)
					                       error:outError];
					if (value == nil)
						return NO;
				}

				if ([scan scanString:@"|" intoString:nil]) {
					/*
					 * Shell pipe.
					 */
					NSUInteger startLocation = [scan scanLocation];
					if (![scan scanUpToUnescapedCharacter:'}' intoString:&filter]) {
						if (outError)
							*outError = [ViError errorWithFormat:
							    @"Unterminated shell pipe beginning at character %lu", startLocation + 1];
						return NO;
					}
					DEBUG(@"got shell pipe [%@], input is [%@]", filter, value);
					if (ts == nil) {
						value = [self runShellCommand:filter
								    withInput:(value ?: @"")
									error:outError];
						if (value == nil)
							return NO;
					}
				}

				if (![scan scanString:@"}" intoString:nil]) {
					if (outError)
						*outError = [ViError errorWithFormat:@"Missing closing brace at %lu",
						    [scan scanLocation] + 1];
					return NO;
				}
			}

			if (value == nil)
				value = defaultValue;

			if (ts != nil) {
				ts.rx = rx;
				ts.format = format;
				ts.options = options;
				ts.filter = filter;
				ts.value = defaultValue;
				ts.range = NSMakeRange([s length], [value length]);

				/*
				 * Find mirrors. The first defined tabstop with a default value is
				 * the master placeholder. All other tabstops mirrors that one.
				 */
				// First find the master.
				ViTabstop *master = nil;
				for (ViTabstop *candidate in _tabstops)
					if (candidate.num == tabStop) {
						if (master == nil || candidate.value)
							master = candidate;
						if (master.value)
							break;
					}
				// Then update all other tabstops to mirror the master.
				for (ViTabstop *mirror in _tabstops)
					if (mirror.num == tabStop && mirror != master)
						mirror.mirror = master;
			}

			if (value)
				[s appendString:value];
		} else if (ch == '`') {
			NSString *shellCommand;
			NSUInteger startLocation = [scan scanLocation];
			if (![scan scanUpToUnescapedCharacter:'`' intoString:&shellCommand] ||
			    ![scan scanString:@"`" intoString:nil]) {
				if (outError)
					*outError = [ViError errorWithFormat:@"Unterminated shell command beginning at character %lu", startLocation + 1];
				return NO;
			}
			NSMutableString *output = [self runShellCommand:shellCommand withInput:@"" error:outError];
			if (output == nil)
				return NO;
			[s appendString:output];
		} else {
			NSString *insChar = [NSString stringWithFormat:@"%C", ch];
			if ([stopChars rangeOfString:insChar].location != NSNotFound) {
				[scan setScanLocation:[scan scanLocation] - 1];
				break;
			}
			[s appendString:insChar];
		}
	}

	*scannedLength = [scan scanLocation];
	return s;
}

- (ViSnippet *)initWithString:(NSString *)aString
                   atLocation:(NSUInteger)aLocation
                     delegate:(__weak id<ViSnippetDelegate>)aDelegate
                  environment:(NSDictionary *)env
                        error:(NSError **)outError
{
	self = [super init];
	if (self == nil)
		return nil;

	_environment = [env copy];
	_tabstops = [[NSMutableArray alloc] init];

	DEBUG(@"snippet string = %@ at location %lu", aString, aLocation);

	NSUInteger len;
	NSMutableString *string = [self parseString:aString
	                                  stopChars:@""
	                              parentTabstop:nil
	                              allowTabstops:YES
	                              scannedLength:&len
	                                      error:outError];
	if (!string)
		return nil;
	DEBUG(@"scanned %lu chars", len);

	if (len != [aString length]) {
		DEBUG(@"whole string not parsed? length = %lu, i = %lu", [aString length], len);
		return nil;
	}

	_beginLocation = aLocation;
	_range = NSMakeRange(_beginLocation, [string length]);

	_delegate = aDelegate; // XXX: not retained!
	[_delegate snippet:self replaceCharactersInRange:NSMakeRange(aLocation, 0) withString:string forTabstop:nil];

	DEBUG(@"tabstops = %@", _tabstops);

	_finished = ([_tabstops count] == 0);

	if (![self updateTabstopsError:outError])
		return NO;
	DEBUG(@"inserted string = [%@]", [self string]);

	if (_finished)
		_caret = NSMaxRange(_range);
	else
		[self advance];

	return self;
}

- (void)dealloc
{
	[_currentTabStop release];
	[_tabstops release];
	[_environment release];
	[super dealloc];
}

- (void)deselect
{
	DEBUG(@"deselecting tab range %@", NSStringFromRange(_selectedRange));
	_selectedRange = NSMakeRange(NSNotFound, 0);
	self.selectedRanges = [NSArray array];
}

- (void)filterTabstop:(ViTabstop *)ts
{
	if (ts.filter) {
		ts.value  = [self runShellCommand:ts.filter
		                        withInput:(ts.value ?: @"")
		                            error:nil];
		[self removeNestedIn:ts];
		[self updateTabstopsError:nil];
	}
}

- (ViTabstop *)findTabstop:(NSUInteger)num
{
	ViTabstop *candidate = nil;
	NSInteger i;

	DEBUG(@"finding candidate for tabstop %lu", num);

	for (i = 0; i < [_tabstops count]; i++) {
		ViTabstop *ts = [_tabstops objectAtIndex:i];
		DEBUG(@"testing candidate at index %i: %@", i, ts);
		if (ts.num == num) {
			candidate = ts;
			if (candidate.mirror == nil)
				break;
		}
	}

	return candidate;
}

- (NSArray *)findMirrorsOf:(ViTabstop *)tabstop
{
	NSUInteger num = tabstop.num;
	return [_tabstops objectsAtIndexes:[_tabstops indexesOfObjectsPassingTest:^BOOL(id aTabstop, NSUInteger i, BOOL *stop) {
		ViTabstop *tabstop = (ViTabstop *)aTabstop;

		return tabstop.mirror != nil && tabstop.num == num;
	}]];
}

- (void)updateSelectedRanges {
	NSMutableArray *allSelectedRanges = [NSMutableArray arrayWithObject:[NSValue valueWithRange:_selectedRange]];
	[[self findMirrorsOf:_currentTabStop] enumerateObjectsUsingBlock:^(id aTabstop, NSUInteger i, BOOL *stop) {
		ViTabstop *tabstop = (ViTabstop *)aTabstop;

		NSRange trueRange = tabstop.range;
		ViTabstop *parent = tabstop;
		while ((parent = parent.parent)) {
			trueRange = NSMakeRange(trueRange.location + parent.range.location, trueRange.length);
		}

		[allSelectedRanges addObject:[NSValue valueWithRange:trueRange]];
	}];
	self.selectedRanges = [NSArray arrayWithArray:allSelectedRanges];
}

- (BOOL)advance
{
	if (_finished)
		return NO;

	[self filterTabstop:_currentTabStop];

	NSUInteger nextTabNum;
	for (nextTabNum = ++_currentTabNum; ; nextTabNum++) {
		if (nextTabNum > _maxTabNum)
			nextTabNum = 0;

		[self setCurrentTabStop:[self findTabstop:nextTabNum]];
		if (_currentTabStop || nextTabNum == 0)
			break;
	}

	if (_currentTabStop == nil) {
		DEBUG(@"%s", "next tabstop not found");
		_finished = YES;
		return NO;
	}

	DEBUG(@"advancing to tab stop %i range %@",
	    _currentTabStop.num, NSStringFromRange(_currentTabStop.range));

	if (nextTabNum == 0) {
		[self filterTabstop:_currentTabStop];
		_finished = YES;
	}

	NSRange r = _currentTabStop.range;
	_caret = _beginLocation + r.location;
	if (_currentTabStop.parent)
		_caret += [self parentLocation:_currentTabStop];
	_selectedRange = NSMakeRange(_caret, r.length);

	[self updateSelectedRanges];

	_currentTabNum = nextTabNum;

	DEBUG(@"tabstops = %@", _tabstops);

	return YES;
}

- (NSRange)tabRange
{
	if (_finished || _currentTabStop == nil)
		return NSMakeRange(NSNotFound, 0);
	NSRange r = _currentTabStop.range;
	return NSMakeRange(_beginLocation + r.location, r.length);
}

- (void)pushTabstopsFromIndex:(NSUInteger)startIndex
           withChangeInLength:(NSInteger)delta
                     inParent:(ViTabstop *)parent
{
	DEBUG(@"update tabstops from index %lu with change %li in parent %@", startIndex, delta, parent);

	NSUInteger i;
	for (i = startIndex; i < [_tabstops count]; i++) {
		ViTabstop *ts = [_tabstops objectAtIndex:i];
		if (ts.parent == parent) {
			NSRange r = ts.range;
			r.location += delta;
			DEBUG(@"tabstop %u range %@ -> %@",
			    ts.num, NSStringFromRange(ts.range), NSStringFromRange(r));
			ts.range = r;
		} else
			DEBUG(@"tabstop %u range %@ unchanged",
			    ts.num, NSStringFromRange(ts.range));
	}

	if (parent == nil) {
		_range.length += delta;
		DEBUG(@"snippet range -> %@", NSStringFromRange(_range));
	}
}

- (BOOL)updateTabstop:(ViTabstop *)ts
                error:(NSError **)outError
{
	ViTabstop *mirror = ts.mirror;
	NSString *value;
	if (mirror) {
		value = mirror.value;
		if (ts.rx) {
			value = [self transformValue:(value ?: @"")
			                 withPattern:ts.rx
			                      format:ts.format
					      global:([ts.options rangeOfString:@"g"].location != NSNotFound)
			                       error:outError];
			if (outError && *outError)
				return NO;
		}

		if (ts.filter) {
			value = [self runShellCommand:ts.filter
			                    withInput:(value ?: @"")
			                        error:outError];
			if (value == nil)
				return NO;
		}
	} else
		value = ts.value;

	if (value) {
		NSRange r = ts.range;
		if (ts.parent) {
			NSMutableString *s = ts.parent.value;
			DEBUG(@"update tab stop %i range %@ with value [%@] in string [%@]",
			    ts.num, NSStringFromRange(r), value, s);
			if (![value isEqualToString:[s substringWithRange:r]]) {
				[s replaceCharactersInRange:r withString:value];
				DEBUG(@"string -> [%@]", s);
				[self updateTabstop:ts.parent error:outError];
			}
		} else {
			DEBUG(@"update tab stop %i range %@ with value [%@] in string [%@]",
			    (int)ts.num, NSStringFromRange(r), value, [_delegate string]);
			r.location += _beginLocation;
			if (![value isEqualToString:[[_delegate string] substringWithRange:r]]) {
				[_delegate snippet:self replaceCharactersInRange:r withString:value forTabstop:ts];
				DEBUG(@"string -> [%@]", [_delegate string]);
			}
			r.location -= _beginLocation;
		}

		NSInteger delta = [value length] - r.length;
		r.length = [value length];
		ts.range = r;

		[self pushTabstopsFromIndex:ts.index + 1 withChangeInLength:delta inParent:ts.parent];
	}

	return YES;
}

- (BOOL)updateTabstopsError:(NSError **)outError
{
	[_delegate beginUpdatingSnippet:self];
	BOOL ret = YES;
	for (ViTabstop *ts in _tabstops) {
		if (![self updateTabstop:ts error:outError]) {
			ret = NO;
			break;
		}
	}
	[_delegate endUpdatingSnippet:self];

	return ret;
}

- (void)removeNestedIn:(ViTabstop *)parent
{
	BOOL found;
	NSUInteger i;

	for (found = YES; found;) {
		found = NO;
		for (i = 0; i < [_tabstops count]; i++) {
			ViTabstop *ts = [_tabstops objectAtIndex:i];
			if (ts.parent == parent) {
				[self removeNestedIn:ts];
				DEBUG(@"removing nested tabstop %@", ts);
				[_tabstops removeObjectAtIndex:i];
				found = YES;
				break;
			}
		}
	}
}

- (BOOL)replaceRange:(NSRange)updateRange withString:(NSString *)replacementString
{
	[self deselect];

	if (_finished || ![self activeInRange:updateRange])
		return NO;

	/* Remove any nested tabstops. */
	[self removeNestedIn:_currentTabStop];

	NSRange normalizedRange = updateRange;
	normalizedRange.location -= _beginLocation;

	DEBUG(@"replace range %@ with [%@]", NSStringFromRange(normalizedRange), replacementString);

	NSRange r = _currentTabStop.range;
	normalizedRange.location -= r.location;
	normalizedRange.location -= [self parentLocation:_currentTabStop];
	if (_currentTabStop.value == nil)
		_currentTabStop.value = [NSMutableString string];
	[_currentTabStop.value replaceCharactersInRange:normalizedRange withString:replacementString];

	BOOL updateSuccessful = [self updateTabstopsError:nil];
	if (updateSuccessful) {
		[self updateSelectedRanges];
	}

	return updateSuccessful;
}

- (NSUInteger)parentLocation:(ViTabstop *)ts
{
	if (ts.parent)
		return ts.parent.range.location + [self parentLocation:ts.parent];
	return 0ULL;
}

- (BOOL)activeInRange:(NSRange)aRange
{
	if (_currentTabStop == nil) {
		DEBUG(@"%s", "current tab stop is nil");
		return NO;
	}

	NSRange normalizedRange = aRange;
	normalizedRange.location -= _beginLocation;
	normalizedRange.location -= [self parentLocation:_currentTabStop];

	NSRange r = _currentTabStop.range;
	if (normalizedRange.location < r.location ||
	    normalizedRange.location > NSMaxRange(r) ||
	    NSMaxRange(normalizedRange) > NSMaxRange(r)) {
		DEBUG(@"update range %@ outside current tabstop %@",
		    NSStringFromRange(normalizedRange), NSStringFromRange(r));
		return NO;
	}

	return YES;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViSnippet at %@>", NSStringFromRange(_range)];
}

- (NSString *)string
{
	return [_delegate string];
}

@end
