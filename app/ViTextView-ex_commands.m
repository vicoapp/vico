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

#import "ViTextView.h"
#import "ViAppController.h"
#import "ViEventManager.h"
#import "ViError.h"
#import "NSString-additions.h"
#import "ViRegisterManager.h"
#import "NSView-additions.h"

@implementation ViTextView (ex_commands)

- (NSInteger)resolveExAddress:(ExAddress *)addr
		   relativeTo:(NSInteger)relline
			error:(NSError **)outError
{
	ViMark *m = nil;
	ViTextStorage *storage = [self textStorage];
	NSInteger line = -1;

	switch (addr.type) {
	case ExAddressAbsolute:
		if (addr.line == -1)
			line = [storage lineCount];
		else
			line = addr.line;
		break;
	case ExAddressCurrent:
		line = [self currentLine];
		break;
	case ExAddressMark:
		m = [[self document] markNamed:addr.mark];
		if (m == nil) {
			if (outError)
				*outError = [ViError errorWithFormat:@"Mark %C: not set", addr.mark];
			return -1;
		}
		if (m.document != [self document]) {
			if (outError)
				*outError = [ViError errorWithFormat:@"Mark %C: not local mark", addr.mark];
			return -1;
		}
		line = m.line;
		break;
	case ExAddressRelative:
		if (relline < 0)
			line = [self currentLine];
		else
			line = relline;
		break;
	case ExAddressSearch:
	{
		if (relline < 0)
			relline = [self currentLine];

		NSString *pattern = addr.pattern;
		if ([pattern length] == 0)
			pattern = [[ViRegisterManager sharedManager] contentOfRegister:'/'];
		if ([pattern length] == 0) {
			if (outError)
				*outError = [ViError message:@"No previous search pattern"];
			return -1;
		}

		NSInteger start = [storage locationForStartOfLine:relline + (addr.backwards ? 0 : 1)];
		if (start == -1LL)
			start = [storage length];
		NSError *error = nil;
		NSRange r = [self rangeOfPattern:pattern
				    fromLocation:start
					 forward:!addr.backwards
					   error:&error];
		if (error) {
			if (outError)
				*outError = error;
			return -1;
		}

		_keyManager.parser.lastSearchOptions = (addr.backwards ? ViSearchOptionBackwards : 0);

		if (r.location == NSNotFound) {
			if (outError)
				*outError = [ViError message:@"Pattern not found"];
			return -1;
		}

		line = [storage lineNumberAtLocation:r.location];
		break;
	}
	case ExAddressNone:
	default:
		if (relline < 0)
			return -1;
		line = relline;
		break;
	}

	line += addr.offset;

	if ([storage locationForStartOfLine:line] == -1ULL) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Invalid line address %li", line];
		return -1;
	}

	return line;
}

- (NSInteger)resolveExAddress:(ExAddress *)addr error:(NSError **)outError
{
	return [self resolveExAddress:addr relativeTo:-1 error:outError];
}

- (BOOL)resolveExAddresses:(ExCommand *)command
	     intoLineRange:(NSRange *)outRange
		     error:(NSError **)outError
{
	NSInteger begin_line, end_line;

	if (command.addr1 == nil || command.addr2 == nil) {
		*outRange = NSMakeRange(NSNotFound, 0);
		return YES;
	}

	begin_line = [self resolveExAddress:command.addr1 error:outError];
	if (begin_line < 0)
		return NO;
	end_line = [self resolveExAddress:command.addr2 relativeTo:begin_line error:outError];
	if (end_line < 0)
		return NO;

	if (end_line < begin_line) {
		NSInteger tmp = end_line;
		end_line = begin_line;
		begin_line = tmp;
	}

	*outRange = NSMakeRange(begin_line, end_line - begin_line);
	return YES;
}

- (NSRange)characterRangeForLineRange:(NSRange)lineRange
{
	if (lineRange.location == NSNotFound)
		return lineRange;

	ViTextStorage *storage = [self textStorage];
	NSUInteger beg = [storage locationForStartOfLine:lineRange.location];
	NSUInteger end = [storage locationForStartOfLine:NSMaxRange(lineRange)];

	/* end location should include the contents of the end_line */
	[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:end];
	return NSMakeRange(beg, end - beg);
}

- (BOOL)resolveExAddresses:(ExCommand *)command
		 intoRange:(NSRange *)outRange
		     error:(NSError **)outError
{
	NSRange lineRange;
	if ([self resolveExAddresses:command intoLineRange:&lineRange error:outError] == NO)
		return NO;

	*outRange = [self characterRangeForLineRange:lineRange];
	return YES;
}

- (id)ex_bang:(ExCommand *)command
{
	if (command.naddr == 0) {
		ExMapping *shell = [[ExMap defaultMap] lookup:@"shell"];
		if (shell == nil) {
			return [ViError message:@"Non-filtering version of ! not implemented"];
		}
		ExCommand *shellCommand = [ExCommand commandWithMapping:shell];
		shellCommand.arg = command.arg;
		[self evalExCommand:shellCommand];
	}
	if ([self filterRange:command.range throughCommand:command.arg])
		command.caret = command.range.location;
	return nil;
}

- (id)ex_eval:(ExCommand *)command
{
	NSString *script = [[[self textStorage] string] substringWithRange:command.range];
	NSError *error = nil;
	[[NSApp delegate] eval:script
		    withParser:nil
		      bindings:nil
			 error:&error];
	if (error)
		return error;
	return nil;
}

- (id)ex_substitute:(ExCommand *)command
{
	NSRange exRange = command.lineRange;

	unsigned rx_options = 0;
	NSString *opts = command.options ?: @"";
	if ([opts rangeOfString:@"i"].location != NSNotFound)
		rx_options |= ONIG_OPTION_IGNORECASE;
	if ([opts rangeOfString:@"m"].location != NSNotFound)
		rx_options |= ONIG_OPTION_MULTILINE;

	BOOL reportMatches = NO;
	if ([opts rangeOfString:@"n"].location != NSNotFound)
		reportMatches = YES;

	BOOL global = [[NSUserDefaults standardUserDefaults] boolForKey:@"gdefault"];
	NSUInteger num_g = [opts occurrencesOfCharacter:'g'];
	while (num_g--)
		global = !global;

	NSString *pattern = command.pattern;
	if ([pattern length] == 0)
		pattern = [[ViRegisterManager sharedManager] contentOfRegister:'/'];
	if ([pattern length] == 0)
		return [ViError message:@"No previous search pattern"];

	NSError *error = nil;
	ViRegexp *rx = [ViRegexp regexpWithString:pattern
					  options:rx_options
					    error:&error];
	if (error)
		return error;

	[[ViRegisterManager sharedManager] setContent:pattern ofRegister:'/'];

	ViTextStorage *storage = [self textStorage];
	ViTransformer *transform = [[ViTransformer alloc] init];

	NSInteger startLocation = [storage locationForStartOfLine:exRange.location];
	NSRange replacementRange =
	  NSMakeRange(
		startLocation,
		NSMaxRange([storage rangeOfLine:NSMaxRange(exRange)]) - startLocation
	  );
	NSString *string = [[storage string] substringWithRange:replacementRange];
	DEBUG(@"ex range is %@", NSStringFromRange(exRange));

	NSUInteger numMatches = 0;
	NSUInteger numLines = 0;

	if (reportMatches) {
		[transform affectedLines:&numLines
					replacements:&numMatches
		   whenTransformingValue:string
					 withPattern:rx
						  global:global]; 
	} else {
		NSRange lastMatchedRange = NSMakeRange(NSNotFound, 0);
		NSString *globalReplacedText =
		  [transform transformValue:string
						withPattern:rx
							 format:command.replacement
							 global:global
							  error:&error
				  lastReplacedRange:&lastMatchedRange
					  affectedLines:&numLines
					   replacements:&numMatches];

		if (globalReplacedText != string) {
			[storage beginEditing];

			[self replaceCharactersInRange:replacementRange withString:globalReplacedText];
		}

		[storage endEditing];
		[self endUndoGroup];

		[self pushCurrentLocationOnJumpList];
		command.caret =
		  (lastMatchedRange.location == NSNotFound) ?
			[storage locationForStartOfLine:MIN(NSMaxRange(exRange), [storage lineCount])] :
			NSMaxRange(lastMatchedRange) + startLocation;
	}

	return [NSString stringWithFormat:@"%lu matches on %lu lines", numMatches, numLines];
}

- (id)ex_goto:(ExCommand *)command
{
	// XXX: What if two address given?
	[self pushCurrentLocationOnJumpList];
	command.caret = [[self textStorage] firstNonBlankForLineAtLocation:command.range.location];
	return nil;
}

- (id)ex_yank:(ExCommand *)command
{
	[self yankToRegister:command.reg range:command.range];
	return nil;
}

- (id)ex_delete:(ExCommand *)command
{
	[self cutToRegister:command.reg range:command.range];
	command.caret = [[self textStorage] firstNonBlankForLineAtLocation:command.range.location];
	return nil;
}

- (id)ex_copy:(ExCommand *)command
{
	NSInteger destline = command.line;
	if (destline > 0)
		++destline;

	NSString *content = [[[self textStorage] string] substringWithRange:command.range];
	NSInteger destloc = [[self textStorage] locationForStartOfLine:destline];
	if (destloc == -1)
		destloc = [[self textStorage] length];
	[self insertString:content atLocation:destloc];

	command.caret = [[self textStorage] firstNonBlankForLineAtLocation:destloc + [content length]];
	return nil;
}

- (id)ex_move:(ExCommand *)command
{
	NSInteger destline = command.line;

	if (destline >= command.lineRange.location && destline < NSMaxRange(command.lineRange))
		return [ViError message:@"Can't move lines into themselves"];

	if (destline > 0)
		++destline;

	NSString *content = [[[self textStorage] string] substringWithRange:command.range];
	NSInteger destloc = [[self textStorage] locationForStartOfLine:destline];
	if (destloc == -1)
		destloc = [[self textStorage] length];

	if (destloc > command.range.location) {
		[self insertString:content atLocation:destloc];
		[self deleteRange:command.range];
		command.caret = [[self textStorage] firstNonBlankForLineAtLocation:destloc - 1];
	} else {
		[self deleteRange:command.range];
		[self insertString:content atLocation:destloc];
		command.caret = [[self textStorage] firstNonBlankForLineAtLocation:destloc + command.range.length - 1];
	}

	return nil;
}

@end

