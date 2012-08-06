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
#import "ViDocument.h"
#import "ViJumpList.h"
#import "ViTextStorage.h"
#import "NSString-scopeSelector.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "ViRegisterManager.h"
#import "ViWindowController.h"
#import "ViCompletionController.h"
#import "ViDocumentView.h"
#import "ExParser.h"
#import "ViDocumentController.h"
#import "NSString-additions.h"
#import "NSView-additions.h"
#import "NSArray-patterns.h"
#import "ViTaskRunner.h"
#import "NSURL-additions.h"

#import "ViFileCompletion.h"
#import "ViWordCompletion.h"
#import "ViBufferCompletion.h"
#import "ExCommandCompletion.h"
#import "ViSyntaxCompletion.h"

@implementation ViTextView (vi_commands)

/* syntax: [count]<ctrl-i> */
- (BOOL)jumplist_forward:(ViCommand *)command
{
	ViWindowController *windowController = [[self window] windowController];
	ViJumpList *jumplist = [windowController jumpList];
	ViMark *jump = [jumplist forward];
	if (jump == nil) {
		MESSAGE(@"Already at end of jumplist");
		return NO;
	}
	return [windowController gotoMark:jump positioned:ViViewPositionDefault recordJump:NO];
}

/* syntax: [count]<ctrl-o> */
- (BOOL)jumplist_backward:(ViCommand *)command
{
	ViWindowController *windowController = [[self window] windowController];
	ViJumpList *jumplist = [windowController jumpList];
	ViMark *jump = [jumplist backwardFrom:[self currentMark]];
	if (jump == nil) {
		MESSAGE(@"Already at beginning of jumplist");
		return NO;
	}
	return [windowController gotoMark:jump positioned:ViViewPositionDefault recordJump:NO];
}

/* syntax: v */
- (BOOL)visual:(ViCommand *)command
{
	if (mode == ViVisualMode) {
		if (visual_line_mode == NO) {
			[self setNormalMode];
			[self resetSelection];
			return NO;
		}
	} else {
		visual_start_location = [self caret];
		[self setVisualMode];
	}

	visual_line_mode = NO;
	return TRUE;
}

/* syntax: V */
- (BOOL)visual_line:(ViCommand *)command
{
	if (mode == ViVisualMode) {
		if (visual_line_mode == YES) {
			[self setNormalMode];
			[self resetSelection];
			return NO;
		}
	} else {
		visual_start_location = [self caret];
		[self setVisualMode];
	}

	visual_line_mode = YES;
	return TRUE;
}

- (BOOL)visual_other:(ViCommand *)command
{
	if (mode != ViVisualMode)
		return NO;

	NSUInteger tmp = visual_start_location;
	visual_start_location = [self caret];
	final_location = tmp;
	return YES;
}

/* syntax: [count]H */
- (BOOL)move_high:(ViCommand *)command
{
	[self pushLocationOnJumpList:start_location];

	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

        NSRect visibleRect = [clipView bounds];
        NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect
							     inTextContainer:[self textContainer]];
        NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange
							 actualGlyphRange:NULL];
	end_location = final_location = range.location;

	NSRect highRect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(glyphRange.location, 1)
							  inTextContainer:[self textContainer]];
	[clipView scrollToPoint:NSMakePoint(0, highRect.origin.y)];
	[scrollView reflectScrolledClipView:clipView];

	return YES;
}

/* syntax: [count]M */
- (BOOL)move_middle:(ViCommand *)command
{
	[self pushLocationOnJumpList:start_location];

	NSScrollView *scrollView = [self enclosingScrollView];
        NSRect visibleRect = [[scrollView contentView] bounds];
        NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect
							     inTextContainer:[self textContainer]];
        NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange
							 actualGlyphRange:NULL];

	NSUInteger highLine = [[self textStorage] lineNumberAtLocation:range.location];
	NSUInteger lowLine = [[self textStorage] lineNumberAtLocation:NSMaxRange(range) - 1];
	NSUInteger middleLine = highLine + (lowLine - highLine) / 2;

	end_location = final_location = [[self textStorage] locationForStartOfLine:middleLine];
	return YES;
}

/* syntax: [count]L */
- (BOOL)move_low:(ViCommand *)command
{
	[self pushLocationOnJumpList:start_location];

	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

        NSRect visibleRect = [clipView bounds];
        NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect
							     inTextContainer:[self textContainer]];
        NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange
							 actualGlyphRange:NULL];

	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:NSMaxRange(range) - 1];
	end_location = final_location = bol;

	if (NSMaxRange(range) < [[self textStorage] length]) {
		NSRect lowRect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(NSMaxRange(glyphRange) - 1, 1)
								 inTextContainer:[self textContainer]];
		NSPoint topPoint = NSMakePoint(0, lowRect.origin.y - visibleRect.size.height + lowRect.size.height);
		[clipView scrollToPoint:topPoint];
		[scrollView reflectScrolledClipView:clipView];
	}

	return YES;
}

- (BOOL)reposition:(ViCommand *)command anchor:(int)anchor keepColumn:(BOOL)keepColumn
{
	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

	NSUInteger topLine;
	if (command.count == 0) {
		topLine = [self currentLine];
	} else {
		topLine = command.count;
		if (topLine >= [[self textStorage] lineCount])
			topLine = [[self textStorage] lineCount];
	}

	NSUInteger topLineLocation = [[self textStorage] locationForStartOfLine:topLine];
	if (keepColumn) {
		NSUInteger column = [self currentScreenColumn];
		NSUInteger glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:topLineLocation];
		[self gotoScreenColumn:column fromGlyphIndex:glyphIndex];
	} else
		final_location = [[self textStorage] firstNonBlankForLineAtLocation:topLineLocation];

	NSRange topLineGlyphRange = [[self layoutManager] glyphRangeForCharacterRange:NSMakeRange(topLineLocation, 1)
								 actualCharacterRange:NULL];
	NSRect rect = [[self layoutManager] boundingRectForGlyphRange:topLineGlyphRange
						      inTextContainer:[self textContainer]];
	NSRect bounds = [clipView bounds];
	NSPoint p;
	p.x = bounds.origin.x;

	if (anchor == 0) /* top */
		p.y = rect.origin.y;
	else if (anchor == 1) /* bottom */
		p.y = NSMaxY(rect) - bounds.size.height;
	else if (anchor == 2) /* middle */
		p.y = rect.origin.y + rect.size.height / 2.0 - bounds.size.height / 2.0;
	else
		p.y = 0;

	if (p.y < 0)
		p.y = 0;

	[clipView scrollToPoint:p];
	[scrollView reflectScrolledClipView:clipView];

	[[scrollView verticalRulerView] setNeedsDisplay:YES];

	return YES;
}

/* [count]z<cr> */
- (BOOL)reposition_top_bol:(ViCommand *)command
{
	return [self reposition:command anchor:0 keepColumn:NO];
}

/* [count]zt */
- (BOOL)reposition_top:(ViCommand *)command
{
	return [self reposition:command anchor:0 keepColumn:YES];
}

/* [count]z- */
- (BOOL)reposition_bottom_bol:(ViCommand *)command
{
	return [self reposition:command anchor:1 keepColumn:NO];
}

/* [count]zb */
- (BOOL)reposition_bottom:(ViCommand *)command
{
	return [self reposition:command anchor:1 keepColumn:YES];
}

/* [count]z. */
- (BOOL)reposition_middle_bol:(ViCommand *)command
{
	return [self reposition:command anchor:2 keepColumn:NO];
}

/* [count]zz */
- (BOOL)reposition_middle:(ViCommand *)command
{
	return [self reposition:command anchor:2 keepColumn:YES];
}

/* syntax: <ctrl-e> */
- (BOOL)scroll_down_by_line:(ViCommand *)command
{
	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

	NSRect visibleRect = [clipView bounds];
	NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];
	NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

	NSUInteger end;
	[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:range.location];

	/* Check if the top line is the last line in the file. */
	if (end >= [[self textStorage] length]) {
		MESSAGE(@"Already at end-of-file");
		return NO;
	}

	if (start_location < end) {
		[self move_down:command];
	}

	NSRange nextLineGlyphRange = [[self layoutManager] glyphRangeForCharacterRange:NSMakeRange(end, 1) actualCharacterRange:NULL];
	NSRect rect = [[self layoutManager] boundingRectForGlyphRange:nextLineGlyphRange inTextContainer:[self textContainer]];
	NSRect bounds = [clipView bounds];
	[clipView scrollToPoint:NSMakePoint(bounds.origin.x, rect.origin.y)];
	[scrollView reflectScrolledClipView:clipView];

	return YES;
}

/* syntax: <ctrl-y> */
- (BOOL)scroll_up_by_line:(ViCommand *)command
{
	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

	NSRect visibleRect = [clipView bounds];
	NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect
							     inTextContainer:[self textContainer]];
	NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange
							 actualGlyphRange:NULL];

	/* Check if first line is visible. */
	NSUInteger first_end;
	[self getLineStart:NULL end:&first_end contentsEnd:NULL forLocation:0];
	if (range.location < first_end) {
		MESSAGE(@"Already at the beginning of the file");
		return NO;
	}

	/* Get the line above the first visible line. */
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:range.location];
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:bol - 1];

	NSRect rect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(bol, 1)
						      inTextContainer:[self textContainer]];

	/* Check if caret will be moved outside the visible area. */
	NSRect caretRect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(start_location, 1)
							   inTextContainer:[self textContainer]];
	if (rect.origin.y + visibleRect.size.height < NSMaxY(caretRect)) {
		[self move_up:command];
	}

	[clipView scrollToPoint:NSMakePoint(visibleRect.origin.x, rect.origin.y)];
	[scrollView reflectScrolledClipView:clipView];
	[[scrollView verticalRulerView] setNeedsDisplay:YES];

	return YES;
}

- (NSInteger)matchCharacter:(unichar)matchChar
                 atLocation:(NSUInteger)location
              withCharacter:(unichar)otherChar
	     restrictScopes:(BOOL)restrictScopes
                    forward:(BOOL)forward
{
	/* Special case: already on the other matching character. */
	if ([self characterAtIndex:location] == otherChar)
		return location;

	NSUInteger length = [[self textStorage] length];

	/* Special case: check if inside a string or comment. */
	BOOL inSpecialScope = NO;
	NSRange specialScopeRange;
	if (restrictScopes) {
		ViScope *openingScope = [document scopeAtLocation:location];
		inSpecialScope = ([@"string" match:openingScope] > 0);
		if (inSpecialScope) {
			specialScopeRange = [document rangeOfScopeSelector:@"string"
								atLocation:location];
		} else {
			inSpecialScope = ([@"comment" match:openingScope ] > 0);
			if (inSpecialScope)
				specialScopeRange = [document rangeOfScopeSelector:@"comment"
									atLocation:location];
		}
	}

	/* Lookup the matching character and prepare search. */
	NSInteger startOffset, endOffset = 0;
	int delta = 1;
	if (forward) {
		startOffset = location + 1;
		if (restrictScopes && inSpecialScope)
			endOffset = NSMaxRange(specialScopeRange) - 1;
		else
			endOffset = length;
	} else {
		startOffset = location - 1;
		if (restrictScopes && inSpecialScope)
			endOffset = specialScopeRange.location;
		delta = -1;
	}

	// search for matching character
	NSString *string = [[self textStorage] string];
	int level = 1;
	NSInteger offset;
	for (offset = startOffset; delta > 0 ? offset <= endOffset : offset >= endOffset; offset += delta) {
		if (offset >= length)
			break;
		unichar c = [string characterAtIndex:offset];
		if (c == matchChar || c == otherChar) {
			/* Ignore match if scopes don't match. */
			if (restrictScopes && !inSpecialScope) {
				ViScope *scope = [document scopeAtLocation:offset];
				if ([@"string | comment" match:scope])
					continue;
			}

			if (c == matchChar)
				level++;
			else
				level--;

			if (level == 0)
				break;
		}
	}

	if (level > 0)
		return -1LL;
	return offset;
}

/* syntax: % */
- (BOOL)move_to_match:(ViCommand *)command
{
	/* Find first paren on current line. */
	NSString *parens = @"<>(){}[]";
	NSCharacterSet *parensSet = [NSCharacterSet characterSetWithCharactersInString:parens];

	NSUInteger end, eol;
	[self getLineStart:NULL end:&end contentsEnd:&eol];
	NSRange lineRange = NSMakeRange(start_location, end - start_location);

	NSRange openingRange = [[[self textStorage] string] rangeOfCharacterFromSet:parensSet
									    options:0
									      range:lineRange];
	if (openingRange.location == NSNotFound) {
		MESSAGE(@"No match character on this line");
		return NO;
	}

	/* Lookup the matching character and prepare search. */
	BOOL forward;
	NSString *match = [[[self textStorage] string] substringWithRange:openingRange];
	unichar matchChar = [match characterAtIndex:0];
	unichar otherChar;
	NSRange r = [parens rangeOfString:match];
	if (r.location % 2 == 0) {
		// search forward
		otherChar = [parens characterAtIndex:r.location + 1];
		forward = YES;
	} else {
		// search backwards
		otherChar = [parens characterAtIndex:r.location - 1];
		forward = NO;
	}

	NSInteger matchLocation = [self matchCharacter:matchChar
					    atLocation:openingRange.location
					 withCharacter:otherChar
					restrictScopes:YES
					       forward:forward];

	if (matchLocation < 0) {
		MESSAGE(@"Matching character not found");
		return NO;
	}

	[self pushLocationOnJumpList:start_location];
	final_location = end_location = matchLocation;

	/*
	 * Adjust the start/end location to include the begin/end match.
	 * Do this when % is used as motion component in a non-line-oriented editing command.
	 */
	if (command.hasOperator &&
	    (command.operator.action == @selector(delete:) ||
	     command.operator.action == @selector(change:) ||
	     command.operator.action == @selector(yank:))) {
		if (forward)
			end_location++;
		else
			start_location++;
	}

	return YES;
}

- (void)filter:(ViTaskRunner *)runner finishedWithStatus:(int)status contextInfo:(id)contextInfo
{
	if (status == 0) {
		NSRange range = [(NSValue *)contextInfo rangeValue];
		[self replaceRange:range withString:runner.stdoutString];
		[self endUndoGroup];
		final_location = range.location;
		[self setCaret:final_location];
	} else {
		MESSAGE(@"filter exited with status %i", status);
		keepMessagesHack = YES;
	}
}

- (BOOL)filterRange:(NSRange)range throughCommand:(NSString *)shellCommand
{
	DEBUG(@"filter range %@ through command %@", NSStringFromRange(range), shellCommand);
	if ([shellCommand length] == 0 || range.length == 0)
		return NO;

	NSString *inputText = [[[self textStorage] string] substringWithRange:range];

	NSTask *task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/bin/bash"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];

	NSMutableDictionary *env = [NSMutableDictionary dictionary];
	[env addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
	/*
	 * Be careful not to set selected range (ie, TM_SELECTED_TEXT) too big, or the task won't be able to launch.
	 * If environment is too big, the process fails with:
	 * *** NSTask: Task create for path '/bin/bash' failed: 22, "Invalid argument".  Terminating temporary process.
	 */
	[self setSelectedRange:NSMakeRange([self caret], 0)];
	[ViBundle setupEnvironment:env
		       forTextView:self
			inputRange:range
			    window:[self window]
			    bundle:nil];
	[task setEnvironment:env];

	NSURL *baseURL = [(ViWindowController *)[[self window] windowController] baseURL];
	if ([baseURL isFileURL])
		[task setCurrentDirectoryPath:[baseURL path]];
	else
		[task setCurrentDirectoryPath:NSTemporaryDirectory()];

	[_taskRunner launchTask:task
	      withStandardInput:[inputText dataUsingEncoding:NSUTF8StringEncoding]
	 asynchronouslyInWindow:nil
			  title:shellCommand
			 target:self
		       selector:@selector(filter:finishedWithStatus:contextInfo:)
		    contextInfo:[NSValue valueWithRange:range]];
	return (_taskRunner.status == 0);
}

/* syntax: [count]!motion command(s) */
- (BOOL)filter:(ViCommand *)command
{
	NSString *cmdline = nil;
	if (command.text)
		cmdline = command.text;
	else {
		cmdline = [self getExStringForCommand:command];
		command.text = cmdline;
	}

	return [self filterRange:affectedRange throughCommand:cmdline];
}

- (BOOL)format:(ViCommand *)command
{
	NSString *formatprg = [[NSUserDefaults standardUserDefaults] stringForKey:@"formatprg"];
	if ([formatprg length] == 0)
		formatprg = @"par";
	[self filterRange:affectedRange throughCommand:formatprg];
	return YES;
}

/* syntax: [count]} */
- (BOOL)paragraph_forward:(ViCommand *)command
{
	int count = IMAX(command.count, 1);

	NSUInteger cur = start_location;

	while (count--) {
		/* Skip blank lines. */
		while (cur < [[self textStorage] length] && [[self textStorage] isBlankLineAtLocation:cur])
			[self getLineStart:NULL end:&cur contentsEnd:NULL forLocation:cur];

		/* Skip non-blank lines. */
		while (cur < [[self textStorage] length] && ![[self textStorage] isBlankLineAtLocation:cur])
			[self getLineStart:NULL end:&cur contentsEnd:NULL forLocation:cur];
	}

	[self pushLocationOnJumpList:start_location];
	end_location = final_location = cur;
	return YES;
}

/* syntax: [count]{ */
- (BOOL)paragraph_backward:(ViCommand *)command
{
	int count = IMAX(command.count, 1);

	NSUInteger cur = start_location;

	while (count--) {
		/* Skip blank lines. */
		while (cur > 0 && [[self textStorage] isBlankLineAtLocation:cur])
			[self getLineStart:&cur end:NULL contentsEnd:NULL forLocation:cur - 1];

		/* Skip non-blank lines. */
		while (cur > 0 && ![[self textStorage] isBlankLineAtLocation:cur])
			[self getLineStart:&cur end:NULL contentsEnd:NULL forLocation:cur - 1];
	}

	[self pushLocationOnJumpList:start_location];
	end_location = final_location = cur;
	return YES;
}

/* syntax: [buffer][count]d[count]motion */
- (BOOL)delete:(ViCommand *)command
{
	// need beginning of line for correcting caret position after deletion
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:affectedRange.location];

	[self cutToRegister:command.reg range:affectedRange];

	// correct caret position if we deleted the last character(s) on the line
	if (bol >= [[self textStorage] length])
		bol = IMAX(0, [[self textStorage] length] - 1);
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:bol];
	if (modify_start_location >= eol)
		final_location = IMAX(bol, eol - (command.action == @selector(change:) ? 0 : 1));
	else
		final_location = modify_start_location;

	return YES;
}

/* syntax: [buffer][count]y[count][motion] */
- (BOOL)yank:(ViCommand *)command
{
	[self yankToRegister:command.reg range:affectedRange];

	/* From nvi:
	 * !!!
	 * Historic vi moved the cursor to the from MARK if it was before the current
	 * cursor and on a different line, e.g., "yk" moves the cursor but "yj" and
	 * "yl" do not.  Unfortunately, it's too late to change this now.  Matching
	 * the historic semantics isn't easy.  The line number was always changed and
	 * column movement was usually relative.  However, "y'a" moved the cursor to
	 * the first non-blank of the line marked by a, while "y`a" moved the cursor
	 * to the line and column marked by a.  Hopefully, the motion component code
	 * got it right...   Unlike delete, we make no adjustments here.
	 */
	/* yy shouldn't move the cursor */
	if (command.motion != nil)
		final_location = affectedRange.location;
	return YES;
}

/* syntax: [buffer][count]P */
- (BOOL)put_before:(ViCommand *)command
{
	NSString *content = [[ViRegisterManager sharedManager] contentOfRegister:command.reg];
	if ([content length] == 0) {
		MESSAGE(@"The %@ register is empty",
		    [[ViRegisterManager sharedManager] nameOfRegister:command.reg]);
		return NO;
	}

	if ([content hasSuffix:@"\n"]) {
		NSUInteger bol;
		[self getLineStart:&bol end:NULL contentsEnd:NULL];
		start_location = final_location = bol;
	}

	if (mode == ViVisualMode) {
		[self yankToRegister:0 range:affectedRange];
		[self replaceCharactersInRange:affectedRange withString:content];
		final_location = affectedRange.location;
	} else
		[self insertString:content atLocation:start_location];

	return YES;
}

/* syntax: [buffer][count]p */
- (BOOL)put_after:(ViCommand *)command
{
	NSString *content = [[ViRegisterManager sharedManager] contentOfRegister:command.reg];
	if ([content length] == 0) {
		MESSAGE(@"The %@ register is empty",
		    [[ViRegisterManager sharedManager] nameOfRegister:command.reg]);
		return NO;
	}

	NSUInteger end, eol;
	[self getLineStart:NULL end:&end contentsEnd:&eol];
	if ([content hasSuffix:@"\n"]) { // XXX: this assumes UNIX line endings
		// putting whole lines
		final_location = end;
	} else if (start_location < eol) {
		// in contrast to move_right, we are allowed to move to EOL here
		final_location = start_location + 1;
	} else
		final_location = start_location;

	if (mode == ViVisualMode) {
		[self yankToRegister:0 range:affectedRange];
		[self replaceCharactersInRange:affectedRange withString:content];
		final_location = affectedRange.location;
	} else
		[self insertString:content atLocation:final_location];

	return YES;
}

- (BOOL)replace:(ViCommand *)command literal:(BOOL)literal
{
	unichar key = command.argument;

	if (key == 0x0D)
		key = '\n';

	if (key < 0x20 && key != '\t' && key != '\n' && !literal) {
		if (key != 0x1B)
			MESSAGE(@"Illegal character: %@; quote to enter",
			    [NSString stringWithKeyCode:key]);
		return NO;
	}

	if (mode == ViVisualMode) {
		/*
		 * Replacements in visual mode is restricted to the selection,
		 * but doesn't affect the newlines.
		 * FIXME: support multiple selection ranges (ie, block selection).
		 * Need to process each line separately and avoid the newlines.
		 * [count] is ignored.
		 */
		NSUInteger bol = affectedRange.location, eol, end;
		while (bol < NSMaxRange(affectedRange)) {
			[self getLineStart:NULL end:&end contentsEnd:&eol forLocation:bol];
			if (eol > NSMaxRange(affectedRange))
				eol = NSMaxRange(affectedRange);

			NSString *replacement = [@"" stringByPaddingToLength:eol - bol
								  withString:[NSString stringWithFormat:@"%C", key]
							     startingAtIndex:0];
			[self replaceRange:NSMakeRange(bol, eol - bol) withString:replacement];
			bol = end;
		}
	} else {
		/*
		 * Replacements in normal mode is restricted to one line.
		 */
		NSUInteger count = IMAX(1, command.count);
		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:start_location];
		if (start_location + count > eol) {
			MESSAGE(@"Movement past the end-of-line");
			return NO;
		}
		affectedRange = NSMakeRange(start_location, count);

		NSString *replacement = [@"" stringByPaddingToLength:affectedRange.length
							  withString:[NSString stringWithFormat:@"%C", key]
						     startingAtIndex:0];
		[self replaceRange:affectedRange withString:replacement];
	}

	return YES;
}

- (BOOL)replace_literal:(ViCommand *)command
{
	return [self replace:command literal:YES];
}

/* syntax: [count]r<char> */
- (BOOL)replace:(ViCommand *)command
{
	return [self replace:command literal:NO];
}

/* syntax: [buffer][count]c[count]motion */
- (BOOL)change:(ViCommand *)command
{
	if (command.isLineMode) {
		/* adjust the range to exclude the last newline */
		NSUInteger bol, eol, end;
		[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:end_location];
		DEBUG(@"end_location = %u, bol = %u, eol = %u, end = %u", end_location, bol, eol, end);
		if (end_location == bol) {
			end_location -= (end - eol);
			affectedRange.length -= (end - eol);
		}
	}

	if ([self delete:command]) {
		end_location = start_location = modify_start_location;
		[self setInsertMode:command];
		return YES;
	} else
		return NO;
}

/* syntax: [buffer][count]S */
- (BOOL)subst_lines:(ViCommand *)command
{
	/* Adjust the range to exclude the last newline (if there is one). */
	NSUInteger bol, eol, end;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:affectedRange.location];
	[self getLineStart:NULL end:&end contentsEnd:&eol forLocation:NSMaxRange(affectedRange) - 1];
	if (eol < end)
		affectedRange.length--;

	NSString *leading_whitespace = [self suggestedIndentAtLocation:affectedRange.location
						      forceSmartIndent:YES];

	[self cutToRegister:command.reg range:affectedRange];
	[self insertString:leading_whitespace ?: @"" atLocation:bol];
	NSRange autoIndentRange = NSMakeRange(bol, [leading_whitespace length]);
	[[self layoutManager] addTemporaryAttribute:ViAutoIndentAttributeName
					      value:[NSNumber numberWithInt:1]
				  forCharacterRange:autoIndentRange];

	/* a command count should not be treated as a count for the inserted text */
	command.count = 0;

	end_location = final_location = bol + [leading_whitespace length];
	[self setInsertMode:command];

	return YES;
}

/* syntax: i */
- (BOOL)insert:(ViCommand *)command
{
	final_location = start_location;
	[self setInsertMode:command];
	return YES;
}

/* syntax: [buffer][count]s */
- (BOOL)substitute:(ViCommand *)command
{
	NSRange range;

	if (mode == ViVisualMode) {
		range = affectedRange;
	} else {
		NSUInteger eol;
		[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:start_location];
		NSUInteger len = IMAX(1, command.count);

		if (start_location + len >= eol)
			len = eol - start_location;
		range = NSMakeRange(start_location, len);
	}

	/* A count should not cause multiplied text (after leaving insert mode). */
	command.count = 0;

	end_location = final_location = range.location;
	[self cutToRegister:command.reg range:range];
	[self setInsertMode:command];
	return YES;
}

/* syntax: [count]J */
- (BOOL)join:(ViCommand *)command
{
	NSUInteger bol, eol, end;
	[self getLineStart:&bol end:&end contentsEnd:&eol];
	if (end == eol || end == [[self textStorage] length]) {
		MESSAGE(@"No following lines to join");
		return NO;
	}

	/* From nvi:
	 * Historic practice:
	 *
	 * If force specified, join without modification.
	 * If the current line ends with whitespace, strip leading
	 *    whitespace from the joined line.
	 * If the next line starts with a ), do nothing.
	 * If the current line ends with ., insert two spaces.
	 * Else, insert one space.
	 *
	 * One change -- add ? and ! to the list of characters for
	 * which we insert two spaces.  I expect that POSIX 1003.2
	 * will require this as well.
	 */

	/* From nvi:
	 * Historic practice for vi was to put the cursor at the first
	 * inserted whitespace character, if there was one, or the
	 * first character of the joined line, if there wasn't, or the
	 * last character of the line if joined to an empty line.  If
	 * a count was specified, the cursor was moved as described
	 * for the first line joined, ignoring subsequent lines.  If
	 * the join was a ':' command, the cursor was placed at the
	 * first non-blank character of the line unless the cursor was
	 * "attracted" to the end of line when the command was executed
	 * in which case it moved to the new end of line.  There are
	 * probably several more special cases, but frankly, my dear,
	 * I don't give a damn.  This implementation puts the cursor
	 * on the first inserted whitespace character, the first
	 * character of the joined line, or the last character of the
	 * line regardless.  Note, if the cursor isn't on the joined
	 * line (possible with : commands), it is reset to the starting
	 * line.
	 */

	NSUInteger end2, eol2;
	[self getLineStart:NULL end:&end2 contentsEnd:&eol2 forLocation:end];

	if (eol2 == end || bol == eol ||
	    [_whitespace characterIsMember:[[[self textStorage] string] characterAtIndex:eol-1]])
	{
		/* From nvi: Empty lines just go away. */
		NSRange r = NSMakeRange(eol, end - eol);
		[self deleteRange:r];
		if (bol == eol)
			final_location = IMAX(bol, eol2 - 1 - (end - eol));
		else
			final_location = IMAX(bol, eol - 1);
	}
	else
	{
		final_location = eol;
		NSString *joinPadding = @" ";
		if ([[NSCharacterSet characterSetWithCharactersInString:@".!?"] characterIsMember:[[[self textStorage] string] characterAtIndex:eol-1]])
			joinPadding = @"  ";
		else if ([[[self textStorage] string] characterAtIndex:end] == ')')
		{
			final_location = eol - 1;
			joinPadding = @"";
		}
		NSInteger sol2 = [[self textStorage] skipWhitespaceFrom:end toLocation:eol2];
		NSRange r = NSMakeRange(eol, sol2 - eol);
		[self replaceRange:r withString:joinPadding];
	}

	return YES;
}

/* syntax: <ctrl-w> */
- (BOOL)delete_word:(ViCommand *)command
{
	if (start_location == 0) {
		MESSAGE(@"Already at the beginning of the file");
		return NO;
	}

	NSRange range;
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];

	if (start_location == bol) {
		[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:bol - 1];
		range = NSMakeRange(eol, bol - eol);
	} else {
		NSUInteger word_start = start_location - 1;

		/* Skip initial whitespace. */
		unichar ch = [self characterAtIndex:word_start];
		if ([_whitespace characterIsMember:ch])
			word_start = [[self textStorage] skipCharactersInSet:_whitespace
								fromLocation:word_start
								    backward:YES];
		ch = [self characterAtIndex:word_start];
		if ([_wordSet characterIsMember:ch])
			word_start = [[self textStorage] skipCharactersInSet:_wordSet
								fromLocation:word_start
								    backward:YES];
		else
			word_start = [[self textStorage] skipCharactersInSet:_nonWordSet
								fromLocation:word_start
								    backward:YES];
		if (word_start > 0)
			++word_start; // back up to the first character

		ViMark *bocMark = [[self document] markNamed:'[']; // beginning-of-change
		NSUInteger boc = bocMark.location;
		if (boc < start_location && boc > word_start)
			range = NSMakeRange(boc, start_location - boc);
		else if (word_start > bol && word_start < start_location)
			range = NSMakeRange(word_start, start_location - word_start);
		else
			range = NSMakeRange(bol, start_location - bol);
	}

	[self deleteRange:range];
	final_location = range.location;
	return YES;
}

/* syntax: <ctrl-u> */
- (BOOL)delete_bol:(ViCommand *)command
{
	if (start_location == 0) {
		MESSAGE(@"Already at the beginning of the file");
		return NO;
	}

	NSRange range;
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];

	if (start_location == bol) {
		[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:bol - 1];
		range = NSMakeRange(eol, bol - eol);
	} else {
		NSUInteger nonblank = [[self textStorage] firstNonBlankForLineAtLocation:start_location];
		ViMark *bocMark = [[self document] markNamed:'[']; // beginning-of-change
		NSUInteger boc = bocMark.location;
		if (boc < start_location && boc > nonblank)
			range = NSMakeRange(boc, start_location - boc);
		else if (nonblank > bol && nonblank < start_location)
			range = NSMakeRange(nonblank, start_location - nonblank);
		else
			range = NSMakeRange(bol, start_location - bol);
	}

	[self deleteRange:range];
	final_location = range.location;
	return YES;
}

/* syntax: [buffer]D */
- (BOOL)delete_eol:(ViCommand *)command
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if (bol == eol) {
		MESSAGE(@"Already at end-of-line");
		return NO;
	}

	NSRange range;
	range.location = start_location;
	range.length = eol - start_location;

	[self cutToRegister:command.reg range:range];

	final_location = IMAX(bol, start_location - 1);
	return YES;
}

/* syntax: [buffer][count]C */
- (BOOL)change_eol:(ViCommand *)command
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if (eol > bol) {
		NSRange range;
		range.location = start_location;
		range.length = eol - start_location;

		[self cutToRegister:command.reg range:range];
	}

	[self setInsertMode:command];
	return YES;
}

/* syntax: [count]h */
- (BOOL)move_left:(ViCommand *)command andWrap:(BOOL)wrap
{
	int count = IMAX(command.count, 1);

	NSUInteger location = start_location;
	while (count--) {
		if (location == 0) {
			MESSAGE(@"Movement past the beginning of the file");
			return NO;
		}
		NSUInteger bol;
		[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:location];
		if (location == bol) {
			if (!wrap) {
				if (command) {
					/* XXX: this command is also used outside the scope of an explicit 'h' command.
					 * In such cases, we shouldn't issue an error message.
					 */
					MESSAGE(@"Already in the first column");
				}
				return NO;
			}
			NSUInteger end, eol;
			[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:bol - 1];
			location = IMAX(bol, eol - ((mode == ViInsertMode || command.hasOperator) ? 0 : 1));
		} else
			location--;
	}

	final_location = end_location = location;
	return YES;
}

- (BOOL)move_left:(ViCommand *)command
{
	return [self move_left:command andWrap:NO];
}

- (BOOL)move_left_and_wrap:(ViCommand *)command
{
	return [self move_left:command andWrap:YES];
}

/* syntax: [count]l */
- (BOOL)move_right:(ViCommand *)command andWrap:(BOOL)wrap
{
	int count = IMAX(command.count, 1);

	NSUInteger location = start_location;
	while (count--) {
		if (location >= [[self textStorage] length]) {
			MESSAGE(@"Movement past the end-of-file");
			return NO;
		}
		NSUInteger end, eol;
		[self getLineStart:NULL end:&end contentsEnd:&eol forLocation:location];
		if (location + ((mode == ViInsertMode || command.hasOperator) ? 0 : 1) >= eol) {
			if (!wrap) {
				MESSAGE(@"Already at end-of-line");
				return NO;
			}
			if (end == [[self textStorage] length]) {
				MESSAGE(@"Movement past the end-of-file");
				return NO;
			}
			[self getLineStart:&location end:NULL contentsEnd:NULL forLocation:end];
		} else
			location++;
	}
	final_location = end_location = location;
	return YES;
}

- (BOOL)move_right:(ViCommand *)command
{
	return [self move_right:command andWrap:NO];
}

- (BOOL)move_right_and_wrap:(ViCommand *)command
{
	return [self move_right:command andWrap:YES];
}

/* syntax: [count]k */
- (BOOL)move_up:(ViCommand *)command
{
	int count = IMAX(command.count, 1);

	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if (bol == 0) {
		MESSAGE(@"Already at the beginning of the file");
		return NO;
	}

	DEBUG(@"count = %i", count);

	while (count-- > 0) {
		if (bol <= 0) {
			MESSAGE(@"Movement past the beginning of the file");
			return NO;
		}
		[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:bol - 1];
	}

	[self gotoColumn:saved_column fromLocation:bol];
	return YES;
}

/* syntax: [count]j */
- (BOOL)move_down:(ViCommand *)command
{
	int count = IMAX(command.count, 1);

	NSUInteger end;
	[self getLineStart:NULL end:&end contentsEnd:NULL];
	if (end >= [[self textStorage] length]) {
		MESSAGE(@"Already at end-of-file");
		return NO;
	}

	while (--count > 0) {
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:end];
		if (end >= [[self textStorage] length]) {
			MESSAGE(@"Movement past the end-of-file");
			return NO;
		}
	}

	[self gotoColumn:saved_column fromLocation:end];
	return YES;
}

/* syntax: [count]gj */
- (BOOL)move_down_soft:(ViCommand *)command
{
	int count = IMAX(command.count, 1);

	if (start_location >= [[self textStorage] length]) {
		MESSAGE(@"Already at end-of-file");
		return NO;
	}

	NSRange lineRange;
	NSUInteger glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:start_location];
	for (NSUInteger i = 0; glyphIndex < [[self layoutManager] numberOfGlyphs] && i < count; i++) {
		[[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineRange];
		if (i == 0) {
			if (NSMaxRange(lineRange) >= [[self textStorage] length]) {
				MESSAGE(@"Already at end-of-file");
				return NO;
			}
		}
		glyphIndex = NSMaxRange(lineRange);
	}

	if (glyphIndex >= [[self layoutManager] numberOfGlyphs]) {
		MESSAGE(@"Movement past the end-of-file");
		return NO;
	}

	[self gotoScreenColumn:saved_column fromGlyphIndex:glyphIndex];
	return YES;
}

/* syntax: [count]gk */
- (BOOL)move_up_soft:(ViCommand *)command
{
	int count = IMAX(command.count, 1);

	if (start_location == 0) {
		MESSAGE(@"Already at the beginning of the file");
		return NO;
	}

	NSRange lineRange;
	NSUInteger loc = IMIN([self caret], [[self textStorage] length] - 1);
	NSUInteger glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:loc];
	[[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineRange];
	if (lineRange.location == 0) {
		MESSAGE(@"Already at the beginning of the file");
		return NO;
	}

	glyphIndex = lineRange.location;
	for (NSUInteger i = 0; glyphIndex > 0 && i < count; i++) {
		[[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex - 1 effectiveRange:&lineRange];
		glyphIndex = lineRange.location;
	}

	[self gotoScreenColumn:saved_column fromGlyphIndex:glyphIndex];
	return YES;
}

/* syntax: 0 */
- (BOOL)move_bol:(ViCommand *)command
{
	[self getLineStart:&end_location end:NULL contentsEnd:NULL];
	final_location = end_location;
	return YES;
}

/* syntax: [count]_ */
- (BOOL)move_down_bol2:(ViCommand *)command
{
	int count = IMAX(command.count, 1);
	NSUInteger end = start_location;

	while (--count > 0) {
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:end];
		if (end >= [[self textStorage] length]) {
			MESSAGE(@"Movement past the end-of-file");
			return NO;
		}
	}

	final_location = end_location = [[self textStorage] firstNonBlankForLineAtLocation:end];

	return YES;
}

/* syntax: [count]+ or [count]enter */
- (BOOL)move_down_bol:(ViCommand *)command
{
	if ([self move_down:command]) {
		final_location = end_location = [[self textStorage] firstNonBlankForLineAtLocation:final_location];
		return YES;
	}
	return NO;
}

/* syntax: [count]- */
- (BOOL)move_up_bol:(ViCommand *)command
{
	if ([self move_up:command]) {
		final_location = end_location = [[self textStorage] firstNonBlankForLineAtLocation:final_location];
		return YES;
	}
	return NO;
}

/* syntax: ^ */
- (BOOL)move_first_char:(ViCommand *)command
{
	[self getLineStart:&end_location end:NULL contentsEnd:NULL];
	end_location = [[self textStorage] skipWhitespaceFrom:end_location];
	final_location = end_location;
	return YES;
}

/* syntax: [count]$ */
- (BOOL)move_eol:(ViCommand *)command
{
	if ([[self textStorage] length] > 0) {
		int count = IMAX(command.count, 1);
		NSUInteger cur = start_location, bol = 0, eol = 0;
		while (count--)
			[self getLineStart:&bol end:&cur contentsEnd:&eol forLocation:cur];
		final_location = end_location = IMAX(bol, eol - (command.hasOperator || mode == ViInsertMode ? 0 : 1 ));
	}
	return YES;
}

/* syntax: [count]F<char> */
- (BOOL)move_back_to_char:(ViCommand *)command
{
	NSInteger bol;
	[self getLineStart:(NSUInteger *)&bol end:NULL contentsEnd:NULL];
	NSInteger i = start_location;
	int count = IMAX(command.count, 1);
	while (count--) {
		while (--i >= bol && [[[self textStorage] string] characterAtIndex:i] != command.argument)
			/* do nothing */ ;
		if (i < bol) {
			MESSAGE(@"%C not found", command.argument);
			return NO;
		}
	}

	final_location = command.hasOperator ? start_location : i;
	end_location = i;
	return YES;
}

/* syntax: [count]T<char> */
- (BOOL)move_back_til_char:(ViCommand *)command
{
	if ([self move_back_to_char:command]) {
		end_location++;
		final_location++;
		return YES;
	}
	return NO;
}

/* syntax: [count]f<char> */
- (BOOL)move_to_char:(ViCommand *)command
{
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol];
	NSUInteger i = start_location;
	int count = IMAX(command.count, 1);
	while (count--) {
		while (++i < eol && [[[self textStorage] string] characterAtIndex:i] != command.argument)
			/* do nothing */ ;
		if (i >= eol) {
			MESSAGE(@"%C not found", command.argument);
			return NO;
		}
	}

	final_location = command.hasOperator ? start_location : i;
	end_location = i + 1;
	return YES;
}

/* syntax: [count]t<char> */
- (BOOL)move_til_char:(ViCommand *)command
{
	if ([self move_to_char:command]) {
		end_location--;
		final_location--;
		return YES;
	}
	return NO;
}

/* syntax: [count]; */
- (BOOL)repeat_line_search_forward:(ViCommand *)command
{
	ViCommand *c = [[_keyManager.parser.lastLineSearchCommand copy] autorelease];
	if (c == nil) {
		MESSAGE(@"No previous F, f, T or t search");
		return NO;
	}

	c.count = command.count;

	SEL sel = c.action;
	if (sel == @selector(move_to_char:))
		return [self move_to_char:c];
	else if (sel == @selector(move_til_char:))
		return [self move_til_char:c];
	else if (sel == @selector(move_back_to_char:))
		return [self move_back_to_char:c];
	else if (sel == @selector(move_back_til_char:))
		return [self move_back_til_char:c];

	return NO;
}

/* syntax: [count], */
- (BOOL)repeat_line_search_backward:(ViCommand *)command
{
	ViCommand *c = [[_keyManager.parser.lastLineSearchCommand copy] autorelease];
	if (c == nil) {
		MESSAGE(@"No previous F, f, T or t search");
		return NO;
	}

	c.count = command.count;

	SEL sel = c.action;
	if (sel == @selector(move_to_char:))
		return [self move_back_to_char:c];
	else if (sel == @selector(move_til_char:))
		return [self move_back_til_char:c];
	else if (sel == @selector(move_back_to_char:))
		return [self move_to_char:c];
	else if (sel == @selector(move_back_til_char:))
		return [self move_til_char:c];

	return NO;
}

/* syntax: [count]G */
- (BOOL)goto_line:(ViCommand *)command
{
	int count = command.count;
	BOOL defaultToEOF = [command.mapping.parameter intValue];

	if (count > 0) {
		NSInteger location = [[self textStorage] locationForStartOfLine:count];
		if(location == -1) {
			MESSAGE(@"Movement past the end-of-file");
			final_location = end_location = start_location;
			return NO;
		}
		final_location = end_location = location;
	} else if (defaultToEOF) {
		/* default to last line */
		NSUInteger last_location = [[self textStorage] length];
		if (last_location > 0)
			--last_location;
		[self getLineStart:&end_location
			       end:NULL
		       contentsEnd:NULL
		       forLocation:last_location];
		final_location = end_location;
	} else {
		/* default to first line */
		final_location = end_location = 0;
	}
	[self pushLocationOnJumpList:start_location];
	return YES;
}

/* syntax: [count]a */
- (BOOL)append:(ViCommand *)command
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if (start_location < eol)
		start_location += 1;
	final_location = end_location = start_location;
	[self setInsertMode:command];
	return YES;
}

/* syntax: [count]A */
- (BOOL)append_eol:(ViCommand *)command
{
	/* Save the count for the append command. */
	int count = command.count;
	command.count = 0;
	[self move_eol:command];
	start_location = end_location;
	command.count = count;
	return [self append:command];
}

/* syntax: o */
- (BOOL)open_line_below:(ViCommand *)command
{
	[self getLineStart:NULL end:NULL contentsEnd:&end_location];
	end_location = [self insertNewlineAtLocation:end_location indentForward:YES];
 	final_location = end_location;

	[self setInsertMode:command];
	return YES;
}

/* syntax: O */
- (BOOL)open_line_above:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	end_location = [self insertNewlineAtLocation:bol indentForward:NO];
 	final_location = end_location;

	[self setInsertMode:command];
	return YES;
}

/* syntax: u */
- (BOOL)vi_undo:(ViCommand *)command
{
	/* From nvi:
	 * !!!
	 * In historic vi, 'u' toggled between "undo" and "redo", i.e. 'u'
	 * undid the last undo.  However, if there has been a change since
	 * the last undo/redo, we always do an undo.  To make this work when
	 * the user can undo multiple operations, we leave the old semantic
	 * unchanged, but make '.' after a 'u' do another undo/redo operation.
	 * This has two problems.
	 *
	 * The first is that 'u' didn't set '.' in historic vi.  So, if a
	 * user made a change, realized it was in the wrong place, does a
	 * 'u' to undo it, moves to the right place and then does '.', the
	 * change was reapplied.  To make this work, we only apply the '.'
	 * to the undo command if it's the command immediately following an
	 * undo command.  See vi/vi.c:getcmd() for the details.
	 *
	 * The second is that the traditional way to view the numbered cut
	 * buffers in vi was to enter the commands "1pu.u.u.u. which will
	 * no longer work because the '.' immediately follows the 'u' command.
	 * Since we provide a much better method of viewing buffers, and
	 * nobody can think of a better way of adding in multiple undo, this
	 * remains broken.
	 *
	 * !!!
	 * There is change to historic practice for the final cursor position
	 * in this implementation.  In historic vi, if an undo was isolated to
	 * a single line, the cursor moved to the start of the change, and
	 * then, subsequent 'u' commands would not move it again. (It has been
	 * pointed out that users used multiple undo commands to get the cursor
	 * to the start of the changed text.)  Nvi toggles between the cursor
	 * position before and after the change was made.  One final issue is
	 * that historic vi only did this if the user had not moved off of the
	 * line before entering the undo command; otherwise, vi would move the
	 * cursor to the most attractive position on the changed line.
	 *
	 * It would be difficult to match historic practice in this area. You
	 * not only have to know that the changes were isolated to one line,
	 * but whether it was the first or second undo command as well.  And,
	 * to completely match historic practice, we'd have to track users line
	 * changes, too.  This isn't worth the effort.
	 */

	[self cancelSnippet];
	[self endUndoGroup];

	NSString *undoStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"undostyle"];
	if ([undoStyle isEqualToString:@"nvi"]) {
		DEBUG(@"undo_direction is %i", undo_direction);
		if (undo_direction == 0)
			undo_direction = 1;	// backward (normal undo)
		else if (!command.fromDot)
			undo_direction = (undo_direction == 1 ? 2 : 1);

		if (undo_direction == 1) {
			if (![_undoManager canUndo]) {
				MESSAGE(@"No changes to undo");
				return NO;
			}
			[[self textStorage] beginEditing];
			[_undoManager undo];
			[[self textStorage] endEditing];
		} else {
			if (![_undoManager canRedo]) {
				MESSAGE(@"No changes to re-do");
				return NO;
			}
			[[self textStorage] beginEditing];
			[_undoManager redo];
			[[self textStorage] endEditing];
		}
	} else {
		if (![_undoManager canUndo]) {
			MESSAGE(@"No changes to undo");
			return NO;
		}
		[[self textStorage] beginEditing];
		[_undoManager undo];
		[[self textStorage] endEditing];
	}

	return YES;
}

/* syntax: C-r */
- (BOOL)vim_redo:(ViCommand *)command
{
	[self cancelSnippet];
	[self endUndoGroup];

	NSString *undoStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"undostyle"];
	if ([undoStyle isEqualToString:@"nvi"])
		return NO;

	if (![_undoManager canRedo]) {
		MESSAGE(@"No changes to re-do");
		return NO;
	}
	[_undoManager redo];

	return YES;
}

/* if caret on word-char:
 *      skip word-chars
 *      skip whitespace
 * else if caret on whitespace:
 *      skip whitespace
 * else:
 *      skip to first word-char-or-space
 *      skip whitespace
 */

/* syntax: [count]w */
/* syntax: [count]W */
- (BOOL)word_forward:(ViCommand *)command
{
	if ([[self textStorage] length] == 0) {
		MESSAGE(@"Empty file");
		return NO;
	}

	NSString *s = [[self textStorage] string];
	BOOL bigword = [command.mapping.keyString isEqualToString:@"W"];	// XXX: use another selector!
	int count = IMAX(command.count, 1);

	NSUInteger word_location;
	while (count--) {
		word_location = end_location;
		if (word_location >= [[self textStorage] length])
			break;
		unichar ch = [s characterAtIndex:word_location];
		if (!bigword && [_wordSet characterIsMember:ch]) {
			// skip word-chars and whitespace
			end_location = [[self textStorage] skipCharactersInSet:_wordSet
								  fromLocation:word_location
								      backward:NO];
		} else if (![_whitespace characterIsMember:ch]) {
			// inside non-word-chars
			end_location = [[self textStorage] skipCharactersInSet:bigword ? [_whitespace invertedSet] : _nonWordSet
								  fromLocation:word_location
								      backward:NO];
		} else if (command.hasOperator &&
		    command.operator.action != @selector(delete:) &&
		    command.operator.action != @selector(yank:)) {
			/* We're in whitespace. */
			/* See comment from nvi below. */
			end_location = word_location + 1;
		}

		if (count > 0)
			end_location = [[self textStorage] skipWhitespaceFrom:end_location];
	}

	/* From nvi:
	 * Movements associated with commands are different than movement commands.
	 * For example, in "abc  def", with the cursor on the 'a', "cw" is from
	 * 'a' to 'c', while "w" is from 'a' to 'd'.  In general, trailing white
	 * space is discarded from the change movement.  Another example is that,
	 * in the same string, a "cw" on any white space character replaces that
	 * single character, and nothing else.  Ain't nothin' in here that's easy.
	 */
	if (!command.hasOperator ||
	    command.operator.action == @selector(delete:) ||
	    command.operator.action == @selector(yank:))
		end_location = [[self textStorage] skipWhitespaceFrom:end_location];

	if (command.hasOperator &&
	    (command.operator.action == @selector(delete:) ||
	     command.operator.action == @selector(yank:) ||
	     command.operator.action == @selector(change:))) {
		/* Restrict to current line if deleting/yanking last word on line.
		 * However, an empty line can be deleted as a word.
		 */
		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol];
		if (end_location > eol && bol != eol)
			end_location = eol;
	} else if (end_location >= [s length])
		end_location = [s length] - 1;
	final_location = end_location;
	return YES;
}

/* syntax: [count]b */
/* syntax: [count]B */
- (BOOL)word_backward:(ViCommand *)command
{
	if ([[self textStorage] length] == 0) {
		MESSAGE(@"Empty file");
		return NO;
	}

	if (start_location == 0) {
		MESSAGE(@"Already at the beginning of the file");
		return NO;
	}

	NSString *s = [[self textStorage] string];
	end_location = start_location - 1;
	unichar ch = [s characterAtIndex:end_location];

	/* From nvi:
         * !!!
         * If in whitespace, or the previous character is whitespace, move
         * past it.  (This doesn't count as a word move.)  Stay at the
         * character before the current one, it sets word "state" for the
         * 'b' command.
         */
	if ([_whitespace characterIsMember:ch]) {
		end_location = [[self textStorage] skipCharactersInSet:_whitespace
							  fromLocation:end_location
							      backward:YES];
		if (end_location == 0) {
			final_location = end_location;
			return YES;
		}
	}

	int count = IMAX(command.count, 1);

	BOOL bigword = [command.mapping.keyString isEqualToString:@"B"];	// XXX: use another selector!

	NSUInteger word_location;
	while (count--) {
		word_location = end_location;
		ch = [s characterAtIndex:word_location];

		if (bigword) {
			end_location = [[self textStorage] skipCharactersInSet:[_whitespace invertedSet]
								  fromLocation:word_location
								      backward:YES];
			if (count == 0 && [_whitespace characterIsMember:[s characterAtIndex:end_location]])
				end_location++;
		} else if ([_wordSet characterIsMember:ch]) {
			// skip word-chars and whitespace
			end_location = [[self textStorage] skipCharactersInSet:_wordSet
								  fromLocation:word_location
								      backward:YES];
			if (count == 0 && ![_wordSet characterIsMember:[s characterAtIndex:end_location]])
				end_location++;
		} else {
			// inside non-word-chars
			end_location = [[self textStorage] skipCharactersInSet:_nonWordSet
								  fromLocation:word_location
								      backward:YES];
			if (count == 0 && [[_nonWordSet invertedSet] characterIsMember:[s characterAtIndex:end_location]])
				end_location++;
		}

		if (count > 0)
			end_location = [[self textStorage] skipCharactersInSet:_whitespace
								  fromLocation:end_location
								      backward:YES];
	}

	final_location = end_location;
	return YES;
}

- (BOOL)end_of_word:(ViCommand *)command
{
	if ([[self textStorage] length] == 0) {
		MESSAGE(@"Empty file");
		return NO;
	}

	NSString *s = [[self textStorage] string];
	end_location = start_location + 1;
	if (end_location >= [[self textStorage] length]) {
		final_location = start_location;
		return YES;
	}
	unichar ch = [s characterAtIndex:end_location];

	int count = IMAX(command.count, 1);

	/* From nvi:
	 * !!!
	 * If in whitespace, or the next character is whitespace, move past
	 * it.  (This doesn't count as a word move.)  Stay at the character
	 * past the current one, it sets word "state" for the 'e' command.
	 */
	if ([_whitespace characterIsMember:ch]) {
		end_location = [[self textStorage] skipCharactersInSet:_whitespace
							  fromLocation:end_location
							      backward:NO];
		if (end_location == [s length]) {
			final_location = end_location;
			return YES;
		}
	}

	BOOL bigword = [command.mapping.keyString isEqualToString:@"E"];	// XXX: use another selector!

	while (count--) {
		ch = [s characterAtIndex:end_location];
		if (bigword) {
			end_location = [[self textStorage] skipCharactersInSet:[_whitespace invertedSet]
								  fromLocation:end_location backward:NO];
		} else if ([_wordSet characterIsMember:ch]) {
			end_location = [[self textStorage] skipCharactersInSet:_wordSet
								  fromLocation:end_location
								      backward:NO];
		} else {
			// inside non-word-chars
			end_location = [[self textStorage] skipCharactersInSet:_nonWordSet
								  fromLocation:end_location
								      backward:NO];
		}

		if (count > 0)
			end_location = [[self textStorage] skipCharactersInSet:_whitespace
								  fromLocation:end_location
								      backward:NO];
	}

	if (!command.hasOperator && mode != ViInsertMode)
		end_location--;

	final_location = end_location;
	return YES;
}

/* syntax: [count]I */
- (BOOL)insert_bol:(ViCommand *)command
{
	NSString *s = [[self textStorage] string];
	if([s length] == 0) {
		[self setInsertMode:command];
		return YES;
	}
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];

	unichar ch = [s characterAtIndex:bol];
	if ([_whitespace characterIsMember:ch]) {
		// skip leading whitespace
		end_location = [[self textStorage] skipWhitespaceFrom:bol toLocation:eol];
	}
	else
		end_location = bol;
	final_location = end_location;
	[self setInsertMode:command];
	return YES;
}

/* syntax: [count]x */
- (BOOL)delete_forward:(ViCommand *)command
{
	NSString *s = [[self textStorage] string];
	if (start_location >= [s length]) {
		MESSAGE(@"No characters to delete");
		return NO;
	}

	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if (bol == eol) {
		MESSAGE(@"No characters to delete");
		return NO;
	}

	NSRange del;
	del.location = start_location;
	del.length = IMAX(1, command.count);
	if (del.location + del.length > eol)
		del.length = eol - del.location;
	[self cutToRegister:command.reg range:del];

	// correct caret position if we deleted the last character(s) on the line
	end_location = modify_start_location;
	eol -= del.length;
	if (end_location == eol && eol > bol)
		--end_location;
	final_location = end_location;
	return YES;
}

/* syntax: [count]X */
- (BOOL)delete_backward:(ViCommand *)command
{
	if ([[self textStorage] length] == 0) {
		MESSAGE(@"Already in the first column");
		return NO;
	}

	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if (start_location == bol) {
		MESSAGE(@"Already in the first column");
		return NO;
	}

	NSRange del;
	del.location = IMAX(bol, start_location - IMAX(1, command.count));
	del.length = start_location - del.location;
	[self cutToRegister:command.reg range:del];
	final_location = end_location = modify_start_location;

	return YES;
}

/* syntax: ^F */
- (BOOL)forward_screen:(ViCommand *)command
{
	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

        // get visible character range
        NSRect visibleRect = [clipView bounds];
        NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];
        NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

	// get last line
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:NSMaxRange(range) - 1];

	if (NSMaxRange(range) == [[self textStorage] length])
	{
		/* Already showing last page, place cursor at last line.
		 * Check if already on last line.
		 */
		if ([self caret] >= bol)
		{
			MESSAGE(@"Already at end-of-file");
			return NO;
		}

		end_location = final_location = [[self textStorage] skipWhitespaceFrom:bol toLocation:eol];
		return YES;
	}

	// get second last line
	[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:bol - 1];

	NSUInteger glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:bol];
	NSRect rect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1) inTextContainer:[self textContainer]];

	NSPoint topPoint;
	topPoint = NSMakePoint(0, NSMinY(rect));

	[clipView scrollToPoint:topPoint];
	[scrollView reflectScrolledClipView:clipView];
	[[scrollView verticalRulerView] setNeedsDisplay:YES];

	end_location = final_location = [[self textStorage] skipWhitespaceFrom:bol toLocation:eol];
	return YES;
}

/* syntax: ^D */
- (BOOL)scroll_downward:(ViCommand *)command
{
	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

        // get visible character range
        NSRect visibleRect = [clipView bounds];
	DEBUG(@"visibleRect is %@", NSStringFromRect(visibleRect));
        NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];
        NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

	// last screen line
	NSRange lastScreenLineGlyphRange;
	[[self layoutManager] lineFragmentRectForGlyphAtIndex:NSMaxRange(glyphRange) - 1 effectiveRange:&lastScreenLineGlyphRange];

	if (NSMaxRange(range) == [[self textStorage] length]) {
		/* Already showing last page, place cursor at last line.
		 * Check if already on last line.
		 */
		DEBUG(@"%s", "last page shown");
		NSRange lastScreenLineRange = [[self layoutManager] characterRangeForGlyphRange:lastScreenLineGlyphRange actualGlyphRange:NULL];

		if ([self caret] >= lastScreenLineRange.location) {
			MESSAGE(@"Already at end-of-file");
			return NO;
		}

		end_location = final_location = lastScreenLineRange.location;
		return YES;
	}

	// Count number of visible screen lines
	NSUInteger numberOfScreenLines = 0;
	NSRange lineRange;
	NSUInteger glyphIndex = glyphRange.location;
	while (glyphIndex < NSMaxRange(glyphRange) - 1) {
		[[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineRange];
		glyphIndex = NSMaxRange(lineRange);
		numberOfScreenLines++;
	}
	DEBUG(@"got %lu screen lines", numberOfScreenLines);

	NSUInteger numberOfScreenLinesToScroll = numberOfScreenLines / 2;
	glyphIndex = glyphRange.location;
	NSRect lineRect = NSZeroRect;
	for (NSUInteger i = 0; i < numberOfScreenLinesToScroll; i++) {
		lineRect = [[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineRange];
		glyphIndex = NSMaxRange(lineRange);
	}

	NSPoint topPoint;
	topPoint = NSMakePoint(0, NSMinY(lineRect));

	DEBUG(@"setting top point to %@", NSStringFromPoint(topPoint));
	[clipView scrollToPoint:topPoint];
	[scrollView reflectScrolledClipView:clipView];
	[[scrollView verticalRulerView] setNeedsDisplay:YES];

	/* Now place the caret numberOfScreenLinesToScroll lines below current caret. */
	glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:[self caret]];
	for (NSUInteger i = 0; glyphIndex < [[self layoutManager] numberOfGlyphs];) {
		[[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineRange];
		if (++i >= numberOfScreenLinesToScroll)
			break;
		glyphIndex = NSMaxRange(lineRange);
	}
	end_location = final_location = [[self layoutManager] characterIndexForGlyphAtIndex:glyphIndex];
	DEBUG(@"setting end location to %lu", end_location);

	return YES;
}

/* syntax: ^B */
- (BOOL)backward_screen:(ViCommand *)command
{
	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

	// get visible character range
	NSRect visibleRect = [clipView bounds];
	NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];
	NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

	// get first line
	NSUInteger bol, eol, end;
	[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:range.location];

	if (range.location == 0)
	{
		/* Already showing first page, place cursor at first line.
		 * Check if already on first line.
		 */
		if ([self caret] < eol)
		{
			MESSAGE(@"Already at the beginning of the file");
			return NO;
		}

		end_location = final_location = [[self textStorage] skipWhitespaceFrom:bol toLocation:eol];
		return YES;
	}

	BOOL has_final_location = NO;

	// count number of lines in the visibleRect
	unsigned lines = 0;
	while (end < NSMaxRange(range))
	{
		[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:end];
		if (!has_final_location)
		{
			has_final_location = YES;
			end_location = final_location = [[self textStorage] skipWhitespaceFrom:bol toLocation:eol];
		}
		lines++;
	}

	lines -= 1; // want 2 lines of overlap (first line already included)

	// now count the same number of lines backwards from top
	bol = range.location;
	while (bol > 0)
	{
		[self getLineStart:&bol end:&eol contentsEnd:&end forLocation:bol - 1];
		if (--lines <= 0)
			break;
	}

	NSUInteger glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:bol];
	NSRect rect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1) inTextContainer:[self textContainer]];

	NSPoint topPoint;
	topPoint = NSMakePoint(0, NSMinY(rect));

	[clipView scrollToPoint:topPoint];
	[scrollView reflectScrolledClipView:clipView];
	[[scrollView verticalRulerView] setNeedsDisplay:YES];

	return YES;
}

/* syntax: ^U */
- (BOOL)scroll_upwards:(ViCommand *)command
{
	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

	// get visible character range
	NSRect visibleRect = [clipView bounds];
	DEBUG(@"visibleRect is %@", NSStringFromRect(visibleRect));
	NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];
	NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

	// first screen line
	NSRange firstScreenLineGlyphRange;
	[[self layoutManager] lineFragmentRectForGlyphAtIndex:0 effectiveRange:&firstScreenLineGlyphRange];

	if (range.location == 0) {
		/* Already showing first page, place cursor at first line.
		 * Check if already on first line.
		 */
		DEBUG(@"%s", "first page shown");
		NSRange firstScreenLineRange = [[self layoutManager] characterRangeForGlyphRange:firstScreenLineGlyphRange actualGlyphRange:NULL];

		if ([self caret] < NSMaxRange(firstScreenLineRange)) {
			MESSAGE(@"Already at the beginning of the file");
			return NO;
		}

		end_location = final_location = firstScreenLineRange.location;
		return YES;
	}

	// Count number of visible screen lines
	NSUInteger numberOfScreenLines = 0;
	NSRange lineRange;
	NSUInteger glyphIndex = glyphRange.location;
	while (glyphIndex < NSMaxRange(glyphRange) - 1) {
		[[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineRange];
		glyphIndex = NSMaxRange(lineRange);
		numberOfScreenLines++;
	}
	DEBUG(@"got %lu screen lines", numberOfScreenLines);

	NSUInteger numberOfScreenLinesToScroll = numberOfScreenLines / 2;

	glyphIndex = glyphRange.location;
	NSRect lineRect = NSZeroRect;
	for (NSUInteger i = 0; i < numberOfScreenLinesToScroll && glyphIndex > 0; i++) {
		lineRect = [[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex - 1 effectiveRange:&lineRange];
		glyphIndex = lineRange.location;
	}

	NSPoint topPoint;
	topPoint = NSMakePoint(0, NSMinY(lineRect));

	DEBUG(@"setting top point to %@", NSStringFromPoint(topPoint));
	[clipView scrollToPoint:topPoint];
	[scrollView reflectScrolledClipView:clipView];
	[[scrollView verticalRulerView] setNeedsDisplay:YES];

	/* Now place the caret numberOfScreenLinesToScroll lines above current caret. */
	glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:[self caret]];
	for (NSUInteger i = 0; glyphIndex > 0;) {
		[[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex - 1 effectiveRange:&lineRange];
		glyphIndex = lineRange.location;
		if (++i >= numberOfScreenLinesToScroll)
			break;
	}
	end_location = final_location = [[self layoutManager] characterIndexForGlyphAtIndex:glyphIndex];
	DEBUG(@"setting end location to %lu", end_location);

	return YES;
}

/* syntax: [count]> */
- (BOOL)shift_right:(ViCommand *)command
{
	final_location = start_location;
	[self changeIndentation:(mode == ViVisualMode ? IMAX(1, command.count) : 1)
			inRange:affectedRange
		    updateCaret:&final_location
		 alignToTabstop:NO
	       indentEmptyLines:NO];
	return YES;
}

/* syntax: [count]< */
- (BOOL)shift_left:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];

	final_location = start_location;
	[self changeIndentation:(mode == ViVisualMode ? IMIN(-1, -command.count) : -1)
			inRange:affectedRange
		    updateCaret:&final_location
		 alignToTabstop:NO
	       indentEmptyLines:NO];
	return YES;
}

- (void)gotoSymbol:(id)sender
{
	ViWindowController *windowController = [[self window] windowController];
	ViMark *sym = sender;
	if ([sender isKindOfClass:[NSMenuItem class]])
		sym = [sender representedObject];

	[windowController.tagStack push:[self currentMark]];
	[windowController gotoMark:sym];
}

- (BOOL)jump_symbol:(ViCommand *)command
{
	ViWindowController *windowController = [[self window] windowController];

	NSString *word = [[self textStorage] wordAtLocation:start_location];
	if (word == nil)
		return NO;

	NSString *pattern = [NSString stringWithFormat:@"\\b%@\\b", word];
	NSMutableArray *syms = [windowController symbolsFilteredByPattern:pattern];

	if ([syms count] > 1) {
		NSMutableArray *toRemove = [NSMutableArray array];
		for (ViMark *sym in syms) {
			if (sym.document == document) {
				NSRange range = sym.range;
				NSUInteger lineno = [[self textStorage] lineNumberAtLocation:range.location];
				if (lineno == [[self textStorage] lineNumberAtLocation:start_location])
					/* Ignore symbol matches on the current line. */
					[toRemove addObject:sym];
			}
		}
		[syms removeObjectsInArray:toRemove];
	}

	if ([syms count] == 0) {
		MESSAGE(
		    @"Symbol \"%@\" not found. Perhaps its document isn't open?", word);
		return NO;
	} else if ([syms count] == 1) {
		[self gotoSymbol:[syms objectAtIndex:0]];
	} else {
		/* Sort symbols per document. */
		NSMapTable *docs = [NSMapTable mapTableWithStrongToStrongObjects];
		for (ViMark *sym in syms) {
			NSMutableArray *a = [docs objectForKey:sym.document];
			if (a == nil) {
				a = [NSMutableArray array];
				[docs setObject:a forKey:sym.document];
			}
			[a addObject:sym];
		}
		BOOL multiDocs = [docs count] > 1;

		NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"Symbol matches"] autorelease];
		[menu setAllowsContextMenuPlugIns:NO];
		int quickindex = 1;
		for (ViDocument *doc in docs) {
			if (multiDocs) {
				NSMenuItem *item = [menu addItemWithTitle:[doc title]
								   action:nil
							    keyEquivalent:@""];
				[item setEnabled:NO];
			}

			for (ViMark *sym in [docs objectForKey:doc]) {
				NSString *key = @"";
				if (quickindex <= 10)
					key = [NSString stringWithFormat:@"%i", quickindex % 10];
				NSMenuItem *item = [menu addItemWithTitle:sym.title
								   action:@selector(gotoSymbol:)
							    keyEquivalent:key];
				[item setKeyEquivalentModifierMask:0];
				[item setRepresentedObject:sym];
				if (multiDocs)
					[item setIndentationLevel:1];
				++quickindex;
			}
		}
		[self popUpContextMenu:menu];
	}

	return YES;
}

// syntax: ^]
- (BOOL)jump_tag:(ViCommand *)command
{
	ViWindowController *windowController = [[self window] windowController];
	ViTagsDatabase *db = windowController.tagsDatabase;
	ViMarkList *stack = windowController.tagStack;

	if (db == nil)
		return [self jump_symbol:command];

	NSString *word = [[self textStorage] wordAtLocation:start_location];
	if (word) {
		[db lookup:word onCompletion:^(NSArray *tag, NSError *error) {
			DEBUG(@"got tag %@, error %@", tag, error);
			if (tag) {
				[stack push:[self currentMark]];
				[self pushCurrentLocationOnJumpList];

				NSURL *url = [tag objectAtIndex:0];

				if (![windowController gotoURL:url])
					return;

				NSString *pattern = [tag objectAtIndex:1];
				NSRange r = NSMakeRange(0, [pattern length]);
				if ([pattern hasPrefix:@"^"])
					r.location++, r.length--;
				if ([pattern hasSuffix:@"$"])
					r.length--;
				NSString *escapedPattern = [ViRegexp escape:pattern inRange:r];
				ViDocumentView *docView = (ViDocumentView *)[windowController currentView];
				[[docView textView] findPattern:escapedPattern options:0];
				final_location = NSNotFound;
			} else {
				[self jump_symbol:command];
			}
		}];
	}

	return YES;
}

// syntax: ^T
- (BOOL)pop_tag:(ViCommand *)command
{
	ViWindowController *windowController = [[self window] windowController];
	ViMark *tag = [windowController.tagStack pop];
	if (tag) {
		[windowController gotoMark:tag];
	} else {
		MESSAGE(@"The tag stack is empty");
		return NO;
	}
	return YES;
}

- (BOOL)find_current_word:(ViCommand *)command options:(int)options
{
	NSRange wordRange;
	NSString *word = [[self textStorage] wordAtLocation:start_location range:&wordRange];
	if (word) {
		NSString *pattern = [NSString stringWithFormat:@"\\b%@\\b", word];
		_keyManager.parser.lastSearchOptions = options;
		if (options == ViSearchOptionBackwards)
			start_location = wordRange.location;
		return [self findPattern:pattern options:options];
	}
	return NO;
}

// syntax: #
- (BOOL)find_current_word_backward:(ViCommand *)command
{
	return [self find_current_word:command options:ViSearchOptionBackwards];
}

// syntax: *
- (BOOL)find_current_word_forward:(ViCommand *)command
{
	return [self find_current_word:command options:0];
}

// syntax: ^G
- (BOOL)show_info:(ViCommand *)command
{
	NSURL *url = [document fileURL];
	NSString *path;

	if (url == nil)
		path = @"[untitled]";
	else
		path = [url displayString];

	MESSAGE(@"%@: %s: line %u of %u [%.0f%%] %@ syntax, %@ encoding",
	 path,
	 [[[NSDocumentController sharedDocumentController] currentDocument] isDocumentEdited] ? "modified" : "unmodified",
	 [self currentLine],
	 [[self textStorage] lineNumberAtLocation:IMAX(0, [[[self textStorage] string] length] - 1)],
	 (float)[self caret]*100.0 / ((float)[[[self textStorage] string] length] ?: 1),
	 [[document language] displayName] ?: @"No",
	 [NSString localizedNameOfStringEncoding:[document encoding]]);
	return NO;
}

/* syntax: m<char> */
- (BOOL)set_mark:(ViCommand *)command
{
	ViMark *m = [[self document] setMark:command.argument atLocation:start_location];
	m.persistent = NO;
	return YES;
}

/* syntax: '<char> */
/* syntax: `<char> */
/* syntax: g'<char> */
/* syntax: g`<char> */
- (BOOL)move_to_mark:(ViCommand *)command
{
	ViMark *m = [[self document] markNamed:command.argument];
	if (m == nil) {
		MESSAGE(@"Mark %C: not set", command.argument);
		return NO;
	}

	BOOL recordJump = ![command.mapping.keyString hasPrefix:@"g"];	// XXX: use another selector!
	BOOL moveToColumn = [command.mapping.keyString isEqualToString:@"`"];	// XXX: use another selector!

	BOOL isLatestJumpMark = (command.argument == '\'' || command.argument == '`');

	if (!moveToColumn) {
		m = [ViMark markWithURL:m.url line:m.line column:0];
	} else if (isLatestJumpMark) {
		/* Need to copy the mark as it's modified by pushCurrentLocationOnJumpList/setMark below. */
		m = [[m copy] autorelease];
	}

	if (m.document != [self document]) {
		/* Motion components don't work across documents. */
		if (command.hasOperator) {
			MESSAGE(@"Mark %C: not local mark", command.argument);
			return NO;
		}
		return [[[self window] windowController] gotoMark:m
						       positioned:ViViewPositionDefault
						       recordJump:recordJump];
	}

	if (!moveToColumn) {
		[m setLocation:[[self textStorage] skipWhitespaceFrom:m.location]];
	}

	if (recordJump && !command.hasOperator) {
		[self pushCurrentLocationOnJumpList];
	} else if (isLatestJumpMark) {
		/* Update ' and ` mark even if not updating the jump list. */
		[[self document] setMark:'\'' atLocation:[self caret]];
		[[self document] setMark:'`' atLocation:[self caret]];
	}

	[self gotoMark:m];
	end_location = [self caret];

	return YES;
}

- (BOOL)vi_gi:(ViCommand *)command
{
	ViMark *m = [[self document] markNamed:'^'];
	if (m != nil) {
		NSInteger bol = [[self textStorage] locationForStartOfLine:m.line];
		if (bol != -1) {
			final_location = [[self textStorage] locationForColumn:m.column
								  fromLocation:bol
								     acceptEOL:YES];
		}
	}

	[self setInsertMode:command];
	return YES;
}

- (BOOL)vi_gv:(ViCommand *)command
{
	ViMark *vs = [[self document] markNamed:'<'];
	ViMark *ve = [[self document] markNamed:'>'];

	if (vs && ve) {
		visual_start_location = vs.location;
		final_location = ve.location;
	} else
		visual_start_location = [self caret];

	[self setVisualMode];
	visual_line_mode = NO;
	return TRUE;
}

#pragma mark -
#pragma mark Text Objects

/* If on a word (letters, numbers, underscore): select the word
 * If on whitespace: select the whitespace
 * If on other non-whitespace: select that
 */
- (BOOL)select_inner_word:(ViCommand *)command bigword:(BOOL)bigword
{
	ViTextStorage *ts = [self textStorage];

	NSUInteger location = start_location;
	if (mode == ViVisualMode && [self selectedRange].length > 1)
		location = NSMaxRange([self selectedRange]);
	if (location >= [ts length])
		return NO;

	BOOL first = YES;
	NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet]; /* without newlines */
	NSCharacterSet *bigwordSet = [_whitespace invertedSet];
	int count = IMAX(command.count, 1);
	while (count--) {
		if (location >= [ts length])
			break;
		unichar ch = [[ts string] characterAtIndex:location];
		if (first && [[NSCharacterSet newlineCharacterSet] characterIsMember:ch]) {
			first = NO;
			start_location = location;
			location = [ts skipCharactersInSet:[NSCharacterSet newlineCharacterSet]
					      fromLocation:location
						  backward:NO];
			if (location >= [ts length]) {
				end_location = [ts length];
				break;
			}
			ch = [[ts string] characterAtIndex:location];
		}

		NSCharacterSet *set = nil;
		if (bigword && [bigwordSet characterIsMember:ch])
			set = bigwordSet;
		else if (!bigword && [_wordSet characterIsMember:ch])
			set = _wordSet;
		else if ([ws characterIsMember:ch])
			set = ws;
		else
			set = _nonWordSet;

		NSRange range = [ts rangeOfCharactersFromSet:set
						  atLocation:location
						 acceptAfter:NO];

		if (range.location == NSNotFound || range.length == 0)
			break;
		location = NSMaxRange(range);
		if (first) {
			start_location = range.location;
			first = NO;
		}
		end_location = NSMaxRange(range);
	}

	if (visual_start_location > start_location)
		visual_start_location = start_location;
	visual_line_mode = NO;
	final_location = end_location - 1;
	return YES;
}

- (BOOL)select_inner_word:(ViCommand *)command
{
	return [self select_inner_word:command bigword:NO];
}

- (BOOL)select_inner_bigword:(ViCommand *)command
{
	return [self select_inner_word:command bigword:YES];
}

- (BOOL)select_outer_word:(ViCommand *)command bigword:(BOOL)bigword
{
	ViTextStorage *ts = [self textStorage];

	NSUInteger location = start_location;
	if (mode == ViVisualMode && [self selectedRange].length > 1)
		location = NSMaxRange([self selectedRange]);
	if (location >= [ts length])
		return NO;

	BOOL first = YES;
	NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet]; /* without newlines */
	NSCharacterSet *bigwordSet = [_whitespace invertedSet];
	BOOL gotWhitespace = NO;
	int count = IMAX(command.count, 1);
	int n = 0;
	while (count > 0 || !gotWhitespace) {
		if (location >= [ts length])
			break;
		unichar ch = [[ts string] characterAtIndex:location];
		if (first && [[NSCharacterSet newlineCharacterSet] characterIsMember:ch]) {
			first = NO;
			start_location = location;
			location = [ts skipCharactersInSet:[NSCharacterSet newlineCharacterSet]
					      fromLocation:location
						  backward:NO];
			if (location >= [ts length]) {
				end_location = [ts length];
				break;
			}
			ch = [[ts string] characterAtIndex:location];
		}

		NSCharacterSet *set = nil;
		if (bigword && [bigwordSet characterIsMember:ch]) {
			set = bigwordSet;
			if (count-- == 0)
				break;
		} else if (!bigword && [_wordSet characterIsMember:ch]) {
			set = _wordSet;
			if (count-- == 0)
				break;
		} else if ([ws characterIsMember:ch]) {
			set = ws;
			if (first || count == 0)
				gotWhitespace = YES;
		} else {
			set = _nonWordSet;
			if (count-- == 0)
				break;
		}

		NSRange range = [ts rangeOfCharactersFromSet:set
						  atLocation:location
						 acceptAfter:NO];

		if (range.location == NSNotFound || range.length == 0)
			break;
		end_location = location = NSMaxRange(range);
		if (first) {
			start_location = range.location;
			first = NO;
		}
		++n;
	}

	/* Check for leading whitespace. */
	if (!gotWhitespace && start_location > 0 && n == 1) {
		NSRange range = [ts rangeOfCharactersFromSet:ws
						  atLocation:start_location - 1
						 acceptAfter:NO];
		if (range.location != NSNotFound && range.length > 0) {
			/* Vim doesn't include leading whitespace if it's only indentation. (?) */
			NSUInteger bol;
			[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:start_location - 1];
			if (range.location > bol)
				start_location = range.location;
		}
	}

	if (visual_start_location > start_location)
		visual_start_location = start_location;
	visual_line_mode = NO;
	final_location = end_location - 1;
	return YES;
}

- (BOOL)select_outer_word:(ViCommand *)command
{
	return [self select_outer_word:command bigword:NO];
}

- (BOOL)select_outer_bigword:(ViCommand *)command
{
	return [self select_outer_word:command bigword:YES];
}

- (BOOL)select_paragraph:(ViCommand *)command
       includeWhitespace:(BOOL)includeWhitespace
{
	int count = IMAX(command.count, 1);
	NSUInteger location = start_location;

	NSUInteger bol = location;
	NSUInteger end = 0, eol = 0;

	if (mode == ViVisualMode && [self selectedRange].length > 1)
		location = NSMaxRange([self selectedRange]);

	BOOL blankLine = [[self textStorage] isBlankLineAtLocation:location];
	BOOL initialBlankLine = blankLine;

	for (; location > 0;) {
		[self getLineStart:&bol end:&end contentsEnd:NULL forLocation:location - 1];
		if (blankLine != [[self textStorage] isBlankLineAtLocation:bol])
			break;
		location = bol;
	}

	if (location < visual_start_location)
		visual_start_location = location;
	start_location = location;
	end_location = location;

	for (location = end; end < [[self textStorage] length]; location = end) {
		[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:location];
		if ([[self textStorage] isBlankLineAtLocation:bol] != blankLine) {
			blankLine = !blankLine;
			if ((!includeWhitespace || blankLine) && --count == 0)
				break;
		}

		end_location = eol;
		final_location = bol;
	}

	if (includeWhitespace && !initialBlankLine) {
		for (location = end; end < [[self textStorage] length]; location = end) {
			end_location = eol;
			final_location = bol;
			[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:location];
			if ([[self textStorage] isBlankLineAtLocation:bol] != blankLine)
				break;
		}
	}

	visual_line_mode = YES;

	return YES;
}

- (BOOL)select_inner_paragraph:(ViCommand *)command
{
	return [self select_paragraph:command includeWhitespace:NO];
}

- (BOOL)select_outer_paragraph:(ViCommand *)command
{
	return [self select_paragraph:command includeWhitespace:YES];
}

- (BOOL)select_string:(ViCommand *)command
	    inclusive:(BOOL)inclusive
{
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:start_location];
	NSUInteger location;
	ViScope *scope = nil;
	for (location = start_location; location <= eol; ) {
		scope = [document scopeAtLocation:location];
		if (scope == nil)
			return NO;
		if ([@"string - (punctuation.definition.string.begin | keyword.control.heredoc-token)" match:scope] > 0)
			break;
		location = NSMaxRange(scope.range);
	}

	if (location > eol)
		return NO;

	DEBUG(@"got scope %@", scope);
	NSInteger i;
	NSArray *scopes = scope.scopes;
	for (i = [scopes count]; i > 0; i--) {
		if ([[scopes objectAtIndex:i - 1] hasPrefix:@"string."])
			break;
	}
	NSArray *baseScopes = [scopes subarrayWithRange:NSMakeRange(0, i)];
	DEBUG(@"base scopes are %@", baseScopes);
	NSString *baseSelector = [baseScopes componentsJoinedByString:@" > "];
	NSString *selector = baseSelector;
	if (!inclusive)
		selector = [NSString stringWithFormat:@"%@ - (%@ > punctuation.definition.string.begin | %@ > punctuation.definition.string.end | %@ > keyword.control.heredoc-token)", baseSelector, baseSelector, baseSelector, baseSelector];
	DEBUG(@"selector is %@", selector);
	NSRange range = [document rangeOfScopeSelector:selector atLocation:location];
	DEBUG(@"range = %@", NSStringFromRange(range));

	visual_start_location =	start_location = range.location;
	end_location = NSMaxRange(range);
	final_location = end_location - 1;
	return YES;
}

- (BOOL)select_inner_string:(ViCommand *)command
{
	return [self select_string:command inclusive:NO];
}

- (BOOL)select_outer_string:(ViCommand *)command
{
	return [self select_string:command inclusive:YES];
}

- (BOOL)selectBlock:(ViCommand *)command
	    inRange:(NSRange)range
              match:(unichar)matchChar
               with:(unichar)otherChar
          inclusive:(BOOL)isInclusive
{
	DEBUG(@"range is %@", NSStringFromRange(range));

	if (NSMaxRange(range) >= [[self textStorage] length])
		return NO;

	NSUInteger leftLocation = range.location;

again:
	DEBUG(@"looking for %C backwards from %lu", matchChar, leftLocation);
	NSInteger startMatch = [self matchCharacter:otherChar
					 atLocation:leftLocation
				      withCharacter:matchChar
				     restrictScopes:NO
					    forward:NO];

	if (startMatch < 0)
		return NO;

	DEBUG(@"looking for %C forward from %lu", otherChar, startMatch);
	NSInteger endMatch = [self matchCharacter:matchChar
				       atLocation:startMatch
				    withCharacter:otherChar
				   restrictScopes:YES
					  forward:YES];

	if (endMatch < 0)
		return NO;

	DEBUG(@"found start at %lu, end at %lu", startMatch, endMatch);

	if (startMatch > range.location || endMatch + 1 < NSMaxRange(range)) {
		/* We selected a smaller block inside the current range. Skip it and try again from the found start. */
		DEBUG(@"%s", "found smaller range");
		if (startMatch == 0)
			return NO;
		--leftLocation;
		goto again;
	}

	if (!isInclusive) {
		++startMatch;
		--endMatch;
		DEBUG(@"adjusted found range %@", NSStringFromRange(NSMakeRange(startMatch, endMatch - startMatch + 1)));
	}

	if (startMatch == range.location && endMatch + 1 == NSMaxRange(range)) {
		/* We selected the same range again. Try to extend the range. */
		DEBUG(@"found same range %@", NSStringFromRange(NSMakeRange(startMatch, endMatch - startMatch + 1)));
		if (startMatch == 0)
			return NO;
		--leftLocation;
		goto again;
	}

	/*
	 * Adjust the start/end location to include the begin/end match.
	 * Do this when % is used as motion component in a non-line-oriented editing command.
	 */
	if (command.hasOperator &&
	    (command.operator.action == @selector(delete:) ||
	     command.operator.action == @selector(change:) ||
	     command.operator.action == @selector(yank:)))
		endMatch++;

	start_location = startMatch;
	end_location = endMatch;
	if (mode == ViVisualMode) {
		visual_start_location = start_location;
		visual_line_mode = NO;
	}
	final_location = end_location;

	return YES;
}

- (BOOL)select_inner_block:(ViCommand *)command
{
	return [self selectBlock:command inRange:affectedRange match:'(' with:')' inclusive:NO];
}

- (BOOL)select_outer_block:(ViCommand *)command
{
	return [self selectBlock:command inRange:affectedRange match:'(' with:')' inclusive:YES];
}

- (BOOL)select_inner_bracket:(ViCommand *)command
{
	return [self selectBlock:command inRange:affectedRange match:'[' with:']' inclusive:NO];
}

- (BOOL)select_outer_bracket:(ViCommand *)command
{
	return [self selectBlock:command inRange:affectedRange match:'[' with:']' inclusive:YES];
}

- (BOOL)select_inner_angle_bracket:(ViCommand *)command
{
	return [self selectBlock:command inRange:affectedRange match:'<' with:'>' inclusive:NO];
}

- (BOOL)select_outer_angle_bracket:(ViCommand *)command
{
	return [self selectBlock:command inRange:affectedRange match:'<' with:'>' inclusive:YES];
}

- (BOOL)select_inner_brace:(ViCommand *)command
{
	return [self selectBlock:command inRange:affectedRange match:'{' with:'}' inclusive:NO];
}

- (BOOL)select_outer_brace:(ViCommand *)command
{
	return [self selectBlock:command inRange:affectedRange match:'{' with:'}' inclusive:YES];
}

- (BOOL)select_inner_scope:(ViCommand *)command
{
	NSUInteger location = start_location;
	if ([self selectedRange].length > 0)
		location = start_location + 1;
	NSString *selector = [[[document scopeAtLocation:location] scopes] componentsJoinedByString:@" "];
	NSRange range = [document rangeOfScopeSelector:selector atLocation:location];

	visual_start_location = start_location = range.location;
	final_location = end_location = NSMaxRange(range) - 1;
	return YES;
}

#pragma mark -

- (void)toggleCaseOfRange:(NSRange)range
{
	NSString *s = [[self textStorage] string];

	NSMutableString *string = [[s substringWithRange:range] mutableCopy];

	NSUInteger i;
	for (i = 0; i < range.length; i++) {
		NSRange chRange = NSMakeRange(i, 1);
		NSString *ch = [string substringWithRange:chRange];
		NSString *uc = [ch uppercaseString];
		if ([ch isEqualToString:uc]) {
			NSString *lc = [ch lowercaseString];
			if (![ch isEqualToString:lc])
				[string replaceCharactersInRange:chRange withString:lc];
		} else {
			[string replaceCharactersInRange:chRange withString:uc];
		}
	}
	[self replaceRange:range withString:string];
	final_location = end_location = IMIN(NSMaxRange(range), [s length] - 1);
}

/* syntax: [count]~ */
- (BOOL)toggle_case:(ViCommand *)command
{
	int count = IMAX(command.count, 1);

	NSUInteger end, eol;
	[self getLineStart:NULL end:&end contentsEnd:&eol forLocation:start_location];
	if (start_location + count > eol)
		count = (int)(eol - start_location);

	if (start_location + count > [[self textStorage] length])
		return NO;
	[self toggleCaseOfRange:NSMakeRange(start_location, count)];
	if (final_location >= eol && eol != end)
		final_location = eol - 1;
	return YES;
}

/* syntax: g~motion */
- (BOOL)toggle_case_op:(ViCommand *)command
{
	[self toggleCaseOfRange:affectedRange];
	final_location = affectedRange.location;
	return YES;
}

/* syntax: gU motion */
- (BOOL)uppercase:(ViCommand *)command
{
	NSString *string = [[[self textStorage] string] substringWithRange:affectedRange];
	[self replaceRange:affectedRange withString:[string uppercaseString]];
	final_location = end_location = affectedRange.location;
	return YES;
}

/* syntax: gu motion */
- (BOOL)lowercase:(ViCommand *)command
{
	NSString *string = [[[self textStorage] string] substringWithRange:affectedRange];
	[self replaceRange:affectedRange withString:[string lowercaseString]];
	final_location = end_location = affectedRange.location;
	return YES;
}

- (BOOL)input_register:(ViCommand *)command
{
	NSString *content = [[ViRegisterManager sharedManager] contentOfRegister:command.argument];
	if (content == nil) {
		MESSAGE(@"The %@ register is empty",
		    [[ViRegisterManager sharedManager] nameOfRegister:command.argument]);
		return NO;
	}
	[self insertString:content atLocation:start_location];
	final_location = start_location + [content length];
	return YES;
}

- (BOOL)evalExString:(NSString *)exline
{
	if (![[self document] isEntireFileLoaded]) {
		[self setInitialExCommand:exline];
		return YES;
	}

	NSError *error = nil;
	ExCommand *ex = [[ExParser sharedParser] parse:exline error:&error];
	if (error) {
		DEBUG(@"ex command failed with error %@", error);
		MESSAGE(@"%@", [error localizedDescription]);
		return NO;
	}

	DEBUG(@"parsed ex command %@", ex);

	for (;ex; ex = ex.nextCommand) {
		NSRange lineRange;
		DEBUG(@"resolving addresses %@ , %@", ex.addr1, ex.addr2);
		if ([self resolveExAddresses:ex intoLineRange:&lineRange error:&error] == NO) {
			MESSAGE(@"%@", [error localizedDescription]);
			return NO;
		}
		ex.lineRange = lineRange;
		ex.range = [self characterRangeForLineRange:lineRange];

		ExAddress *lineAddress = ex.lineAddress;
		if (lineAddress) {
			DEBUG(@"resolving line addresses %@", ex.lineAddress);
			NSInteger line = [self resolveExAddress:ex.lineAddress error:&error];
			if (error) {
				MESSAGE(@"%@", [error localizedDescription]);
				return NO;
			}
			ex.line = line;
		}

		ex.caret = final_location;
		BOOL ok = [self evalExCommand:ex];
		DEBUG(@"messages: %@", ex.messages);
		if ([ex.messages count] > 0) {
			MESSAGE(@"%@", [ex.messages lastObject]);
			keepMessagesHack = YES;
		}
		if (!ok) {
			DEBUG(@"ex command failed: %@", ex);
			return NO;
		}
		final_location = ex.caret;
		[self setCaret:ex.caret];
	}

	return YES;
}

/* syntax: : */
- (BOOL)ex_command:(ViCommand *)command
{
	NSString *prefix = nil;
	if (mode == ViVisualMode)
		prefix = @"'<,'>";
	else if (command.count == 1)
		prefix = @".";
	else if (command.count > 1)
		prefix = [NSString stringWithFormat:@".,.+%i", command.count - 1];
	NSString *exline = [self getExStringForCommand:command prefix:prefix];
	if (exline == nil)
		return NO;

	[[ViRegisterManager sharedManager] setContent:exline ofRegister:':'];

	// XXX: scope for ex command?

	return [self evalExString:exline];
}

#pragma mark -
#pragma mark Completion

- (BOOL)completionController:(ViCompletionController *)completionController
     insertPartialCompletion:(NSString *)partialCompletion
                     inRange:(NSRange)range
{
	DEBUG(@"insert partial completion [%@] in range %@, length = %lu",
	    partialCompletion, NSStringFromRange(range), [[self textStorage] length]);
	[self replaceRange:range withString:partialCompletion];
	final_location = range.location + [partialCompletion length];
	[self setCaret:final_location];
	return YES;
}

- (BOOL)presentCompletionsOf:(NSString *)string
		fromProvider:(id<ViCompletionProvider>)provider
		   fromRange:(NSRange)range
		     options:(NSString *)options
{
	BOOL positionAbove = ([options rangeOfString:@"a"].location != NSNotFound);
	BOOL fuzzyTrigger = ([options rangeOfString:@"F"].location != NSNotFound);

	/* Present a list to choose from. */
	ViCompletionController *cc = [ViCompletionController sharedController];
	cc.delegate = self;
	NSPoint point = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange([self caret], 0)
							inTextContainer:[self textContainer]].origin;
	/* Offset the completion window a bit. */
	point.x += (positionAbove ? 0 : 5);
	point.y += (positionAbove ? -3 : 15);
	ViCompletion *selection;
	selection = [cc chooseFrom:provider
			     range:range
			    prefix:fuzzyTrigger ? nil : string
				at:[[self window] convertBaseToScreen:[self convertPointToBase:point]]
			   options:options
			 direction:(positionAbove ? 1 : 0)
		     initialFilter:fuzzyTrigger ? string : nil];
	DEBUG(@"completion controller returned [%@] in range %@", selection, NSStringFromRange(cc.range));
	if (selection)
		[self insertSnippet:selection.content inRange:cc.range];

	NSInteger termKey = cc.terminatingKey;
	if (termKey >= 0x20 && termKey < 0xFFFF) {
		NSString *special = [NSString stringWithKeyCode:termKey];
		if ([special length] == 1) {
			[self insertString:[NSString stringWithFormat:@"%C", (unichar)termKey]];
			final_location++;
		} /* otherwise it's a <special> key code, ignore it */
	} else if (termKey == 0x0D && [self isFieldEditor]) {
		[_keyManager handleKey:termKey];
	}

	if (selection == nil)
		return NO;
	return YES;
}

- (void)removeFromInputKeys:(ViCommand *)command
{
	NSArray *keySequence = command.keySequence;
	DEBUG(@"remove %@ from %@", keySequence, _inputKeys);
	if ([_inputKeys hasSuffix:keySequence]) {
		NSRange r = NSMakeRange([_inputKeys count] - [keySequence count], [keySequence count]);
		[_inputKeys removeObjectsInRange:r];
	}
}

- (BOOL)complete_keyword:(ViCommand *)command
{
	NSRange range;
	NSString *word = [[self textStorage] wordAtLocation:start_location
						      range:&range
					        acceptAfter:YES];

	if (word == nil) {
		word = @"";
		range = NSMakeRange([self caret], 0);
	}

	// FIXME: replace completion command keys (<c-n> or <c-x><c-n>) with the completed text
	// [self removeFromInputKeys:command];

	return [self presentCompletionsOf:word
			     fromProvider:[[[ViWordCompletion alloc] init] autorelease]
				fromRange:range
				  options:command.mapping.parameter];
}

- (BOOL)complete_path:(ViCommand *)command
{
	NSRange range;
	NSString *path = [[self textStorage] pathAtLocation:start_location
						      range:&range
						acceptAfter:YES];
	if (path == nil) {
		path = @"";
		range = NSMakeRange([self caret], 0);
	}

	return [self presentCompletionsOf:path
			     fromProvider:[[[ViFileCompletion alloc] init] autorelease]
				fromRange:range
				  options:command.mapping.parameter];
}

- (BOOL)complete_buffer:(ViCommand *)command
{
	NSRange range;
	NSString *word = [[self textStorage] wordAtLocation:start_location
						      range:&range
					        acceptAfter:YES];

	if (word == nil) {
		word = @"";
		range = NSMakeRange([self caret], 0);
	}

	return [self presentCompletionsOf:word
			     fromProvider:[[[ViBufferCompletion alloc] init] autorelease]
				fromRange:range
				  options:command.mapping.parameter];
}

- (BOOL)complete_ex_command:(ViCommand *)command
{
	NSRange range;
	NSString *word = [[self textStorage] wordAtLocation:start_location
						      range:&range
					        acceptAfter:YES];

	if (word == nil) {
		word = @"";
		range = NSMakeRange([self caret], 0);
	}

	return [self presentCompletionsOf:word
			     fromProvider:[[[ExCommandCompletion alloc] init] autorelease]
				fromRange:range
				  options:command.mapping.parameter];
}

- (BOOL)complete_syntax:(ViCommand *)command
{
	NSRange range;
	NSString *word = [[self textStorage] wordAtLocation:start_location
                                                      range:&range
                                                acceptAfter:YES
                                            extraCharacters:@"."];

	if (word == nil) {
		word = @"";
		range = NSMakeRange([self caret], 0);
	}

	return [self presentCompletionsOf:word
			     fromProvider:[[[ViSyntaxCompletion alloc] init] autorelease]
				fromRange:range
				  options:command.mapping.parameter];
}

- (BOOL)indent:(ViCommand *)command
{
	DEBUG(@"indenting range %@", NSStringFromRange(affectedRange));
	NSUInteger endLocation = NSMaxRange(affectedRange);
	NSUInteger loc = affectedRange.location;
	NSUInteger bol;
	[[self textStorage] beginEditing];
	while (loc < endLocation) {
		DEBUG(@"indenting line %lu at %lu", [[self textStorage] lineNumberAtLocation:loc], loc);
		[self getLineStart:&bol end:&loc contentsEnd:NULL forLocation:loc];
		NSRange curIndent = [[self textStorage] rangeOfLeadingWhitespaceForLineAtLocation:bol];
		NSString *newIndent = nil;
		if (![[self textStorage] isBlankLineAtLocation:bol])
			newIndent = [self suggestedIndentAtLocation:bol];
		NSRange indentRange = NSMakeRange(bol, curIndent.length);
		[self replaceRange:indentRange withString:newIndent ?: @""];
		NSInteger delta = [newIndent length] - indentRange.length;
		loc += delta;
		endLocation += delta;
	}
	[[self textStorage] endEditing];

	final_location = [[self textStorage] firstNonBlankForLineAtLocation:affectedRange.location];
	return YES;
}

- (BOOL)execute_register:(ViCommand *)command
{
	unichar reg = command.argument;
	if (reg == '%' || reg == '#') {
		MESSAGE(@"Invalid register name '%C'", reg);
		return NO;
	}

	ViRegisterManager *regs = [ViRegisterManager sharedManager];

	if (reg == '@') {
		reg = regs.lastExecutedRegister;
		if (reg == 0) {
			MESSAGE(@"No previously used register");
			return NO;
		}
	} else
		regs.lastExecutedRegister = reg;

	NSString *content = [regs contentOfRegister:reg];
	if (content == nil) {
		MESSAGE(@"The %@ register is empty",
		    [[ViRegisterManager sharedManager] nameOfRegister:reg]);
		return NO;
	}

	int count = IMAX(command.count, 1);
	while (count--)
		if (![self input:content])
			return NO;

	return YES;
}

@end
