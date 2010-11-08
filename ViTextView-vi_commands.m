#import "ViTextView.h"
#import "ViDocument.h"
#import "ViMark.h"
#import "ViJumpList.h"
#import "NSTextStorage-additions.h"
#import "NSString-scopeSelector.h"

@implementation ViTextView (vi_commands)

/* syntax: [count]<ctrl-i> */
- (BOOL)jumplist_forward:(ViCommand *)command
{
	NSURL *url;
	NSUInteger line, column;
	BOOL ok = [[[self delegate] jumpList] forwardToURL:&url line:&line column:&column];
	if (!ok) {
		[[self delegate] message:@"Already at end of jumplist"];
		return NO;
	}

	return YES;
}

/* syntax: [count]<ctrl-o> */
- (BOOL)jumplist_backward:(ViCommand *)command
{
	NSURL *url = [[self delegate] fileURL];
	NSUInteger line = [[self textStorage] lineNumberAtLocation:start_location];
	NSUInteger column = [[self textStorage] columnAtLocation:start_location];
	BOOL ok = [[[self delegate] jumpList] backwardToURL:&url line:&line column:&column];
	if (!ok) {
		[[self delegate] message:@"Already at beginning of jumplist"];
		return NO;
	}

	return YES;
}

/* syntax: v */
- (BOOL)visual:(ViCommand *)command
{
	visual_start_location = [self caret];
	[self setVisualMode];
	visual_line_mode = NO;
	return TRUE;
}

/* syntax: V */
- (BOOL)visual_line:(ViCommand *)command
{
	[self visual:command];
	visual_line_mode = YES;
	return TRUE;
}

/* syntax: [count]H */
- (BOOL)move_high:(ViCommand *)command
{
	[self pushLocationOnJumpList:start_location];

	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

        NSRect visibleRect = [clipView bounds];
        NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];
        NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
	end_location = final_location = range.location;

	NSRect highRect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(glyphRange.location, 1) inTextContainer:[self textContainer]];
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
        NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];
        NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

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
        NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];
        NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:NSMaxRange(range) - 1];
	end_location = final_location = bol;

	if (NSMaxRange(range) < [[self textStorage] length])
	{
		NSRect lowRect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(NSMaxRange(glyphRange) - 1, 1) inTextContainer:[self textContainer]];
		NSPoint topPoint = NSMakePoint(0, lowRect.origin.y - visibleRect.size.height + lowRect.size.height);
		[clipView scrollToPoint:topPoint];
		[scrollView reflectScrolledClipView:clipView];
	}

	return YES;
}

/* syntax: <ctrl-e> */
- (BOOL)scroll_down_by_line:(ViCommand *)command
{
	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];

        NSRect visibleRect = [clipView bounds];
        NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];
        NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

	// check if last line is visible
	if (NSMaxRange(range) >= [[self textStorage] length]) {
		[[self delegate] message:@"Already at end-of-file"];
		return NO;
	}

	NSUInteger end;
	[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:range.location];

	if (start_location < end)
		[self move_down:command];

	NSRect rect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(end, 1) inTextContainer:[self textContainer]];
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
        NSRange glyphRange = [[self layoutManager] glyphRangeForBoundingRect:visibleRect inTextContainer:[self textContainer]];
        NSRange range = [[self layoutManager] characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

	// check if first line is visible
	NSUInteger first_end;
	[self getLineStart:NULL end:&first_end contentsEnd:NULL forLocation:0];
	if (range.location < first_end)
	{
		[[self delegate] message:@"Already at the beginning of the file"];
		return NO;
	}

	// check if caret is on the last line
	NSUInteger last_bol;
	[self getLineStart:&last_bol end:NULL contentsEnd:NULL forLocation:NSMaxRange(range) - 1];
	if (start_location >= last_bol)
		[self move_up:command];

	// get the line above the first visible line
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:range.location];
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:bol - 1];

	NSRect rect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(bol, 1) inTextContainer:[self textContainer]];
	NSRect bounds = [clipView bounds];
	[clipView scrollToPoint:NSMakePoint(bounds.origin.x, rect.origin.y)];
	[scrollView reflectScrolledClipView:clipView];

	return YES;
}

/* syntax: % */
- (BOOL)move_to_match:(ViCommand *)command
{
        // find first paren on current line
	NSString *parens = @"<>(){}[]";
        NSCharacterSet *parensSet = [NSCharacterSet characterSetWithCharactersInString:parens];

        NSUInteger end, eol;
	[self getLineStart:NULL end:&end contentsEnd:&eol];
	NSRange lineRange = NSMakeRange(start_location, end - start_location);

        NSRange openingRange = [[[self textStorage] string] rangeOfCharacterFromSet:parensSet options:0 range:lineRange];
        if (openingRange.location == NSNotFound)
        {
                [[self delegate] message:@"No match character on this line"];
                return NO;
        }

        /* Special case: check if inside a string or comment. */
	NSArray *openingScopes = [self scopesAtLocation:openingRange.location];
	BOOL inSpecialScope;
        NSRange specialScopeRange;

	inSpecialScope = ([@"string" matchesScopes:openingScopes] > 0);
        if (inSpecialScope)
        	specialScopeRange = [self trackScopeSelector:@"string" atLocation:openingRange.location];
	else {
		inSpecialScope = ([@"comment" matchesScopes:openingScopes] > 0);
		if (inSpecialScope)
			specialScopeRange = [self trackScopeSelector:@"comment" atLocation:openingRange.location];
	}

        // lookup the matching character and prepare search
        NSString *match = [[[self textStorage] string] substringWithRange:openingRange];
        unichar matchChar = [match characterAtIndex:0];
        unichar otherChar;
	NSUInteger startOffset, endOffset = 0;
	int delta = 1;
        NSRange r = [parens rangeOfString:match];
        if (r.location % 2 == 0)
        {
		// search forward
                otherChar = [parens characterAtIndex:r.location + 1];
                startOffset = openingRange.location + 1;
                if (inSpecialScope)
                	endOffset = NSMaxRange(specialScopeRange);
                else
                        endOffset = [[[self textStorage] string] length];
        }
	else
	{
		// search backwards
                otherChar = [parens characterAtIndex:r.location - 1];
		startOffset = openingRange.location - 1;
		if (inSpecialScope)
			endOffset = specialScopeRange.location;
                delta = -1;
        }

        // search for matching character
	int level = 1;
	NSUInteger offset;
	for (offset = startOffset; offset != endOffset; offset += delta)
	{
        	unichar c = [[[self textStorage] string] characterAtIndex:offset];
        	if (c == matchChar || c == otherChar)
                {
			/* Ignore match if scopes don't match. */
			if (!inSpecialScope) {
                                NSArray *scopes = [self scopesAtLocation:offset];
				if ([@"string"  matchesScopes:scopes] > 0 ||
				    [@"comment" matchesScopes:scopes] > 0)
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
	{
		[[self delegate] message:@"Matching character not found"];
		return NO;
        }

	[self pushLocationOnJumpList:start_location];

	final_location = end_location = offset;

	/*
	 * Adjust the start/end location to include the begin/end match.
	 * Do this when % is used as motion component in a non-line-oriented editing command.
	 */
	if (command.key == 'd' || command.key == 'c' || command.key == 'y') {
		if (delta == 1)
			end_location++;
		else
			start_location++;
	}

        return YES;
}

- (void)filter_through_shell_command:(NSString *)shellCommand contextInfo:(void *)contextInfo
{
	if ([shellCommand length] == 0)
		return;

	INFO(@"command = %@", contextInfo);

	NSString *inputText = [[[self textStorage] string] substringWithRange:affectedRange];

	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];

	NSPipe *shellInput = [NSPipe pipe];
	NSPipe *shellOutput = [NSPipe pipe];

	[task setStandardInput:shellInput];
	[task setStandardOutput:shellOutput];
	/* FIXME: set standard error to standard output? */

	[task launch];
	[[shellInput fileHandleForWriting] writeData:[inputText dataUsingEncoding:NSUTF8StringEncoding]];
	[[shellInput fileHandleForWriting] closeFile];
	[task waitUntilExit];
	int status = [task terminationStatus];

	if (status != 0)
	{
		[[self delegate] message:@"%@: exited with status %i", shellCommand, status];
	}
	else
	{
		NSData *outputData = [[shellOutput fileHandleForReading] readDataToEndOfFile];
		NSString *outputText = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
		[self replaceRange:affectedRange withString:outputText];
		[self endUndoGroup];
	}
}

/* syntax: [count]!motion command(s) */
- (BOOL)filter:(ViCommand *)command
{
	[[[self delegate] environment] getExCommandWithDelegate:self
						       selector:@selector(filter_through_shell_command:contextInfo:)
							 prompt:@"!"
						    contextInfo:command];
	final_location = start_location;
	return YES;
}

/* syntax: [count]} */
- (BOOL)paragraph_forward:(ViCommand *)command
{
	int count = IMAX(command.count, 1);
	if (!command.ismotion)
		count = IMAX(command.motion_count, 1);

	NSUInteger cur;
	[self getLineStart:NULL end:&cur contentsEnd:NULL];

	NSUInteger bol = cur, end, eol = 0;
	for (; eol < [[[self textStorage] string] length];)
	{
		[self getLineStart:&bol end:&eol contentsEnd:&end forLocation:cur];
		if ((bol == end || [[self textStorage] isBlankLineAtLocation:bol]) && --count <= 0)
		{
			// empty or blank line, we're done
			break;
		}
		cur = eol;
	}

	[self pushLocationOnJumpList:start_location];
	end_location = final_location = bol;
	return YES;
}

/* syntax: [count]{ */
- (BOOL)paragraph_backward:(ViCommand *)command
{
	int count = IMAX(command.count, 1);
	if (!command.ismotion)
		count = IMAX(command.motion_count, 1);

	NSUInteger cur;
	[self getLineStart:&cur end:NULL contentsEnd:NULL];

	NSUInteger bol = 0, end;
	for (; cur > 0;)
	{
		[self getLineStart:&bol end:NULL contentsEnd:&end forLocation:cur - 1];
		if ((bol == end || [[self textStorage] isBlankLineAtLocation:bol]) && --count <= 0)
		{
			// empty or blank line, we're done
			break;
		}
		cur = bol;
	}

	[self pushLocationOnJumpList:start_location];
	end_location = final_location = bol;
	return YES;
}

/* syntax: [buffer][count]d[count]motion */
- (BOOL)delete:(ViCommand *)command
{
	// need beginning of line for correcting caret position after deletion
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:affectedRange.location];

	/* If a line mode range includes the last line, also include the newline before the first line.
	 * This way delete doesn't leave an empty line.
	 */
	if (command.line_mode && NSMaxRange(affectedRange) == [[self textStorage] length] && bol > 0)
	{
		affectedRange.location--;	// FIXME: what about using CRLF at end-of-lines?
		affectedRange.length++;
		DEBUG(@"after including newline before first line: affected range: %@", NSStringFromRange(affectedRange));
	}

	[self cutToBuffer:0 append:NO range:affectedRange];

	// correct caret position if we deleted the last character(s) on the line
	if (bol >= [[self textStorage] length])
		bol = IMAX(0, [[self textStorage] length] - 1);
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:bol];
	if (affectedRange.location >= eol)
		final_location = IMAX(bol, eol - (command.key == 'c' ? 0 : 1));
	else
		final_location = affectedRange.location;

	return YES;
}

/* syntax: [buffer][count]y[count][motion] */
- (BOOL)yank:(ViCommand *)command
{
	[self yankToBuffer:0 append:NO range:affectedRange];

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
	if (command.motion_key != 'y')
		final_location = affectedRange.location;
	return YES;
}

/* syntax: [buffer][count]P */
- (BOOL)put_before:(ViCommand *)command
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if ([buffer length] == 0)
	{
		[[self delegate] message:@"The default buffer is empty"];
		return NO;
	}

	if ([buffer hasSuffix:@"\n"])
	{
		NSUInteger bol;
		[self getLineStart:&bol end:NULL contentsEnd:NULL];

		start_location = final_location = bol;
	}
	[self insertString:buffer atLocation:start_location];

	return YES;
}

/* syntax: [buffer][count]p */
- (BOOL)put_after:(ViCommand *)command
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if ([buffer length] == 0)
	{
		[[self delegate] message:@"The default buffer is empty"];
		return NO;
	}

	NSUInteger end, eol;
	[self getLineStart:NULL end:&end contentsEnd:&eol];
	if ([buffer hasSuffix:@"\n"])
	{
		// putting whole lines
		final_location = end;
	}
	else if (start_location < eol)
	{
		// in contrast to move_right, we are allowed to move to EOL here
		final_location = start_location + 1;
	}

	[self insertString:buffer atLocation:final_location];

	return YES;
}

/* syntax: [count]r<char> */
- (BOOL)replace:(ViCommand *)command
{
	NSUInteger count;

	if (mode == ViVisualMode)
		count = affectedRange.length;
	else {
		count = IMAX(1, command.count);
		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:start_location];
		if (start_location + count > eol) {
			[[self delegate] message:@"Movement past the end-of-line"];
			return NO;
		}
		affectedRange = NSMakeRange(start_location, count);
	}

	NSString *replacement = [@"" stringByPaddingToLength:count
						  withString:[NSString stringWithFormat:@"%C", command.argument]
					     startingAtIndex:0];
	[self replaceRange:affectedRange withString:replacement];

	return YES;
}

/* syntax: [buffer][count]c[count]motion */
- (BOOL)change:(ViCommand *)command
{
	if (command.line_mode) {
		/* adjust the range to exclude the last newline */
		NSUInteger bol, eol, end;
		[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:end_location];
		DEBUG(@"end_location = %u, bol = %u, eol = %u, end = %u", end_location, bol, eol, end);
		if (end_location == bol) {
			end_location--;
			affectedRange.length--;
		}
	}

	if ([self delete:command]) {
		end_location = start_location = affectedRange.location;
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

        NSString *leading_whitespace = nil;
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"autoindent"] == NSOnState)
                leading_whitespace = [self leadingWhitespaceForLineAtLocation:affectedRange.location];

	[self cutToBuffer:0 append:NO range:affectedRange];
	[self insertString:leading_whitespace ?: @"" atLocation:bol];

	/* a command count should not be treated as a count for the inserted text */
	command.count = 0;

	end_location = final_location = bol + [leading_whitespace length];
	[self setInsertMode:command];

	return YES;
}

/* syntax: i */
- (BOOL)insert:(ViCommand *)command
{
	[self setInsertMode:command];
	return YES;
}

/* syntax: [buffer][count]s */
- (BOOL)substitute:(ViCommand *)command
{
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:start_location];
	NSUInteger c = command.count;
	if (command.count == 0)
		c = 1;

	/* XXX: treat a command count as motion count */
	command.motion_count = c;
	command.count = 0;

	if (start_location + c >= eol)
		c = eol - start_location;
	[self cutToBuffer:0 append:NO range:NSMakeRange(start_location, c)];
	[self setInsertMode:command];
	return YES;
}

/* syntax: [count]J */
- (BOOL)join:(ViCommand *)command
{
	NSUInteger bol, eol, end;
	[self getLineStart:&bol end:&end contentsEnd:&eol];
	if (end == eol)
	{
		[[self delegate] message:@"No following lines to join"];
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

	if (eol2 == end || bol == eol || [whitespace characterIsMember:[[[self textStorage] string] characterAtIndex:eol-1]])
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

/* syntax: [buffer]D */
- (BOOL)delete_eol:(ViCommand *)command
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if(bol == eol)
	{
		[[self delegate] message:@"Already at end-of-line"];
		return NO;
	}

	NSRange range;
	range.location = start_location;
	range.length = eol - start_location;

	[self cutToBuffer:0 append:NO range:range];

	final_location = IMAX(bol, start_location - 1);
	return YES;
}

/* syntax: [buffer][count]C */
- (BOOL)change_eol:(ViCommand *)command
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if (eol > bol)
	{
		NSRange range;
		range.location = start_location;
		range.length = eol - start_location;

		[self cutToBuffer:0 append:NO range:range];
	}

	[self setInsertMode:command];
	return YES;
}

/* syntax: [count]h */
- (BOOL)move_left:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if (start_location == bol)
	{
		if (command)
		{
			/* XXX: this command is also used outside the scope of an explicit 'h' command.
			 * In such cases, we shouldn't issue an error message.
			 */
			[[self delegate] message:@"Already in the first column"];
		}
		return NO;
	}
	final_location = end_location = start_location - 1;
	return YES;
}

/* syntax: [count]l */
- (BOOL)move_right:(ViCommand *)command
{
	int count = IMAX(command.count, 1);
	if (!command.ismotion)
		count = IMAX(command.motion_count, 1);

	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol];
	if (start_location + (mode == ViInsertMode ? 0 : 1) >= eol) {
		[[self delegate] message:@"Already at end-of-line"];
		return NO;
	}
	if (start_location + count >= eol)
		final_location = end_location = eol - (mode == ViInsertMode ? 0 : 1);
	else
		final_location = end_location = start_location + count;
	return YES;
}

/* syntax: [count]k */
- (BOOL)move_up:(ViCommand *)command
{
	int count = IMAX(command.count, 1);
	if (!command.ismotion)
		count = IMAX(command.motion_count, 1);

	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if (bol == 0) {
		[[self delegate] message:@"Already at the beginning of the file"];
		return NO;
	}

	DEBUG(@"count = %i", count);

	while (count-- > 0) {
		if (bol <= 0) {
			[[self delegate] message:@"Movement past the beginning of the file"];
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
	if (!command.ismotion)
		count = IMAX(command.motion_count, 1);

	NSUInteger end;
	[self getLineStart:NULL end:&end contentsEnd:NULL];
	if (end >= [[self textStorage] length]) {
		[[self delegate] message:@"Already at end-of-file"];
		return NO;
	}

	while (--count > 0) {
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:end];
		if (end >= [[self textStorage] length]) {
			[[self delegate] message:@"Movement past the end-of-file"];
			return NO;
		}
	}

	[self gotoColumn:saved_column fromLocation:end];
	return YES;
}

/* syntax: 0 */
- (BOOL)move_bol:(ViCommand *)command
{
	[self getLineStart:&end_location end:NULL contentsEnd:NULL];
	final_location = end_location;
	return YES;
}

/* syntax: _ or ^ */
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
		if (!command.ismotion)
			count = IMAX(command.motion_count, 1);
		NSUInteger cur = start_location, bol = 0, eol = 0;
		while (count--)
			[self getLineStart:&bol end:&cur contentsEnd:&eol forLocation:cur];
		final_location = end_location = IMAX(bol, eol - command.ismotion);
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
	if (!command.ismotion)
		count = IMAX(command.motion_count, 1);
	while (count--) {
		while (--i >= bol && [[[self textStorage] string] characterAtIndex:i] != command.argument)
			/* do nothing */ ;
		if (i < bol) {
			[[self delegate] message:@"%C not found", command.argument];
			return NO;
		}
	}

	final_location = command.ismotion ? i : start_location;
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
	if (!command.ismotion)
		count = IMAX(command.motion_count, 1);
	while (count--) {
		while (++i < eol && [[[self textStorage] string] characterAtIndex:i] != command.argument)
			/* do nothing */ ;
		if (i >= eol) {
			[[self delegate] message:@"%C not found", command.argument];
			return NO;
		}
	}

	final_location = command.ismotion ? i : start_location;
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

/* syntax: [count]G */
- (BOOL)goto_line:(ViCommand *)command
{
	int count = command.count;
	if(!command.ismotion)
		count = command.motion_count;

	if(count > 0)
	{
		NSInteger location = [[self textStorage] locationForStartOfLine:count];
		if(location == -1)
		{
			[[self delegate] message:@"Movement past the end-of-file"];
			final_location = end_location = start_location;
			return NO;
		}
		final_location = end_location = location;
	}
	else
	{
		/* goto last line */
		NSUInteger last_location = [[[self textStorage] string] length];
		if(last_location > 0)
			--last_location;
		[self getLineStart:&end_location end:NULL contentsEnd:NULL forLocation:last_location];
		final_location = end_location;
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
	{
		start_location += 1;
		final_location = end_location = start_location;
	}
	[self setInsertMode:command];
	return YES;
}

/* syntax: [count]A */
- (BOOL)append_eol:(ViCommand *)command
{
	[self move_eol:command];
	start_location = end_location;
	return [self append:command];
}

/* syntax: o */
- (BOOL)open_line_below:(ViCommand *)command
{
	[self getLineStart:NULL end:NULL contentsEnd:&end_location];
	int num_chars = [self insertNewlineAtLocation:end_location indentForward:YES];
	end_location += num_chars; // insert mode starts at end_location
 	final_location = end_location;

	[self setInsertMode:command];
	return YES;
}

/* syntax: O */
- (BOOL)open_line_above:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	int num_chars = [self insertNewlineAtLocation:bol indentForward:NO];
	final_location = end_location = bol - 1 + num_chars;

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

	DEBUG(@"undo_direction is %i", undo_direction);
	if (undo_direction == 0)
		undo_direction = 1;	// backward (normal undo)
	else if (!command.is_dot)
		undo_direction = (undo_direction == 1 ? 2 : 1);

	if (undo_direction == 1) {
		if (![undoManager canUndo]) {
			DEBUG(@"%s", "can't undo");
			[[self delegate] message:@"No changes to undo"];
			return NO;
		}
		[undoManager undo];
	} else {
		if (![undoManager canRedo]) {
			DEBUG(@"%s", "can't redo");
			[[self delegate] message:@"No changes to re-do"];
			return NO;
		}
		[undoManager redo];
	}

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
	if ([[self textStorage] length] == 0)
	{
		[[self delegate] message:@"Empty file"];
		return NO;
	}
	NSString *s = [[self textStorage] string];

	BOOL bigword = (command.ismotion ? command.key == 'W' : command.motion_key == 'W');

	int count = IMAX(command.count, 1);
	if (!command.ismotion)
		count = IMAX(command.motion_count, 1);

	NSUInteger word_location;
	while (count--)
	{
		word_location = end_location;
		unichar ch = [s characterAtIndex:word_location];
		if (!bigword && [wordSet characterIsMember:ch])
		{
			// skip word-chars and whitespace
			end_location = [[self textStorage] skipCharactersInSet:wordSet fromLocation:word_location backward:NO];
		}
		else if (![whitespace characterIsMember:ch])
		{
			// inside non-word-chars
			end_location = [[self textStorage] skipCharactersInSet:bigword ? [whitespace invertedSet] : nonWordSet fromLocation:word_location backward:NO];
		}
		else if (!command.ismotion && command.key != 'd' && command.key != 'y')
		{
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
	if (command.ismotion || command.key == 'd' || command.key == 'y')
		end_location = [[self textStorage] skipWhitespaceFrom:end_location];

	if (!command.ismotion && (command.key == 'd' || command.key == 'y' || command.key == 'c')) {
		/* Restrict to current line if deleting/yanking last word on line.
		 * However, an empty line can be deleted as a word.
		 */
		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol];
		if (end_location > eol && bol != eol)
			end_location = eol;
	}
	else if (end_location >= [s length])
		end_location = [s length] - 1;
	final_location = end_location;
	return YES;
}

/* syntax: [count]b */
/* syntax: [count]B */
- (BOOL)word_backward:(ViCommand *)command
{
	if ([[self textStorage] length] == 0)
	{
		[[self delegate] message:@"Empty file"];
		return NO;
	}
	if (start_location == 0)
	{
		[[self delegate] message:@"Already at the beginning of the file"];
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
	if ([whitespace characterIsMember:ch])
	{
		end_location = [[self textStorage] skipCharactersInSet:whitespace fromLocation:end_location backward:YES];
		if (end_location == 0)
		{
			final_location = end_location;
			return YES;
		}
	}

	int count = IMAX(command.count, 1);
	if (!command.ismotion)
		count = IMAX(command.motion_count, 1);

	BOOL bigword = (command.ismotion ? command.key == 'B' : command.motion_key == 'B');

	NSUInteger word_location;
	while (count--)
	{
		word_location = end_location;
		ch = [s characterAtIndex:word_location];

		if (bigword)
		{
			end_location = [[self textStorage] skipCharactersInSet:[whitespace invertedSet] fromLocation:word_location backward:YES];
			if (count == 0 && [whitespace characterIsMember:[s characterAtIndex:end_location]])
				end_location++;
		}
		else if ([wordSet characterIsMember:ch])
		{
			// skip word-chars and whitespace
			end_location = [[self textStorage] skipCharactersInSet:wordSet fromLocation:word_location backward:YES];
			if (count == 0 && ![wordSet characterIsMember:[s characterAtIndex:end_location]])
				end_location++;
		}
		else
		{
			// inside non-word-chars
			end_location = [[self textStorage] skipCharactersInSet:nonWordSet fromLocation:word_location backward:YES];
			if (count == 0 && [wordSet characterIsMember:[s characterAtIndex:end_location]])
				end_location++;
		}
		if (count > 0)
			end_location = [[self textStorage] skipCharactersInSet:whitespace fromLocation:end_location backward:YES];
	}

	final_location = end_location;
	return YES;
}

- (BOOL)end_of_word:(ViCommand *)command
{
	if ([[self textStorage] length] == 0)
	{
		[[self delegate] message:@"Empty file"];
		return NO;
	}
	NSString *s = [[self textStorage] string];
	end_location = start_location + 1;
	unichar ch = [s characterAtIndex:end_location];

	/* From nvi:
         * !!!
         * If in whitespace, or the next character is whitespace, move past
         * it.  (This doesn't count as a word move.)  Stay at the character
         * past the current one, it sets word "state" for the 'e' command.
         */
	if([whitespace characterIsMember:ch])
	{
		end_location = [[self textStorage] skipCharactersInSet:whitespace fromLocation:end_location backward:NO];
		if(end_location == [s length])
		{
			final_location = end_location;
			return YES;
		}
	}

	BOOL bigword = (command.ismotion ? command.key == 'E' : command.motion_key == 'E');

	ch = [s characterAtIndex:end_location];
	if (bigword) {
		end_location = [[self textStorage] skipCharactersInSet:[whitespace invertedSet] fromLocation:end_location backward:NO];
		if(command.ismotion || (command.key != 'd' && command.key != 'e'))
			end_location--;
	} else if ([wordSet characterIsMember:ch]) {
		end_location = [[self textStorage] skipCharactersInSet:wordSet fromLocation:end_location backward:NO];
		if(command.ismotion || (command.key != 'd' && command.key != 'e'))
			end_location--;
	} else {
		// inside non-word-chars
		end_location = [[self textStorage] skipCharactersInSet:nonWordSet fromLocation:end_location backward:NO];
		if(command.ismotion || (command.key != 'd' && command.key != 'e'))
			end_location--;
	}

	final_location = end_location;
	return YES;
}

/* syntax: [count]I */
- (BOOL)insert_bol:(ViCommand *)command
{
	NSString *s = [[self textStorage] string];
	if([s length] == 0)
		return YES;
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];

	unichar ch = [s characterAtIndex:bol];
	if ([whitespace characterIsMember:ch]) {
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
	if([s length] == 0) {
		[[self delegate] message:@"No characters to delete"];
		return NO;
	}
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if(bol == eol) {
		[[self delegate] message:@"No characters to delete"];
		return NO;
	}

	NSRange del;
	del.location = start_location;
	del.length = IMAX(1, command.count);
	if (del.location + del.length > eol)
		del.length = eol - del.location;
	[self cutToBuffer:0 append:NO range:del];

	// correct caret position if we deleted the last character(s) on the line
	end_location = start_location;
	--eol;
	if (end_location == eol && eol > bol)
		--end_location;
	final_location = end_location;
	return YES;
}

/* syntax: [count]X */
- (BOOL)delete_backward:(ViCommand *)command
{
	if([[self textStorage] length] == 0)
	{
		[[self delegate] message:@"Already in the first column"];
		return NO;
	}
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if(start_location == bol)
	{
		[[self delegate] message:@"Already in the first column"];
		return NO;
	}
	NSRange del;
	del.location = IMAX(bol, start_location - IMAX(1, command.count));
	del.length = start_location - del.location;
	[self cutToBuffer:0 append:NO range:del];
	end_location = del.location;
	final_location = end_location;

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
			[[self delegate] message:@"Already at end-of-file"];
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

	end_location = final_location = [[self textStorage] skipWhitespaceFrom:bol toLocation:eol];
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
			[[self delegate] message:@"Already at the beginning of the file"];
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

	return YES;
}

/* syntax: [count]> */
- (BOOL)shift_right:(ViCommand *)command
{
	final_location = start_location;
	[self changeIndentation:1 inRange:affectedRange updateCaret:&final_location];
	return YES;
}

/* syntax: [count]< */
- (BOOL)shift_left:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];

	final_location = start_location;
	[self changeIndentation:-1 inRange:affectedRange updateCaret:&final_location];
	return YES;
}

// syntax: ^]
- (BOOL)jump_tag:(ViCommand *)command
{
	if (tags == nil || [tags databaseHasChanged]) {
		tags = [[ViTagsDatabase alloc] initWithFile:@"tags"
						inDirectory:[[[[self delegate] fileURL] path] stringByDeletingLastPathComponent]];
	}

	if (tags == nil) {
		[[self delegate] message:@"tags: No such file or directory."];
		return NO;
	}

	NSString *word = [[self textStorage] wordAtLocation:start_location];
	if (word) {
		NSArray *tag = [tags lookup:word];
		if (tag) {
			[[self delegate] pushLine:[self currentLine] column:[self currentColumn]];
			[self pushLocationOnJumpList:start_location];

			NSString *file = [tag objectAtIndex:0];
			NSString *ex_command = [tag objectAtIndex:1];

			ViDocument *document = [[NSDocumentController sharedDocumentController]
				openDocumentWithContentsOfURL:[NSURL fileURLWithPath:file] display:YES error:nil];

			if (document) {
				ViWindowController *windowController = [[self delegate] windowController];
				NSArray *p = [ex_command componentsSeparatedByString:@"/;"];
				NSString *pattern = [[p objectAtIndex:0] substringFromIndex:1];
				[windowController selectDocument:document];
				[document findPattern:pattern options:0];
			}
		} else {
			[[self delegate] message:@"%@: tag not found", word];
		}
	}

	return YES;
}

// syntax: ^T
- (BOOL)pop_tag:(ViCommand *)command
{
	[[self delegate] popTag];
	return YES;
}

// syntax: ^A
// syntax: * (from vim, incompatible with nvi)
- (BOOL)find_current_word:(ViCommand *)command
{
	NSString *word = [[self textStorage] wordAtLocation:start_location];
	if(word)
	{
		NSString *pattern = [NSString stringWithFormat:@"\\b%@\\b", word];
		return [self findPattern:pattern options:0];
	}
	return NO;
}

// syntax: ^G
- (BOOL)show_info:(ViCommand *)command
{
	[[self delegate] message:@"%@: %s: line %u of %u [%.0f%%]",
	 [[[[self delegate] fileURL] path] stringByAbbreviatingWithTildeInPath],
	 [[[NSDocumentController sharedDocumentController] currentDocument] isDocumentEdited] ? "modified" : "unmodified",
	 [self currentLine],
	 [[self textStorage] lineNumberAtLocation:IMAX(0, [[[self textStorage] string] length] - 1)],
	 (float)[self caret]*100.0 / (float)[[[self textStorage] string] length]];
	return NO;
}

/* syntax: m<char> */
- (BOOL)set_mark:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	ViMark *m = [[ViMark alloc] initWithLine:[self currentLine] column:start_location - bol];
	[marks setObject:m forKey:[NSString stringWithFormat:@"%C", command.argument]];
	return YES;
}

/* syntax: '<char> */
/* syntax: `<char> */
- (BOOL)move_to_mark:(ViCommand *)command
{
	ViMark *m = [marks objectForKey:[NSString stringWithFormat:@"%C", command.argument]];
	if (m == nil)
	{
		[[self delegate] message:@"Mark %C: not set", command.argument];
		return NO;
	}

	NSInteger bol = [[self textStorage] locationForStartOfLine:m.line];
	if (bol == -1)
	{
		[[self delegate] message:@"Mark %C: the line was deleted", command.argument];
		return NO;
	}
	final_location = bol;

	if (command.key == '`' || command.motion_key == '`')
		[self gotoColumn:m.column fromLocation:bol];
	else
		final_location = [[self textStorage] skipWhitespaceFrom:final_location];

	[self pushLocationOnJumpList:start_location];

	return YES;
}

- (BOOL)select_inner_word:(ViCommand *)command
{
	return NO;
}

- (BOOL)select_inner_bigword:(ViCommand *)command
{
	return NO;
}

- (BOOL)select_inner_paragraph:(ViCommand *)command
{
	return NO;
}

- (BOOL)select_inner_brace:(ViCommand *)command
{
	return NO;
}

- (BOOL)select_inner_bracket:(ViCommand *)command
{
	return NO;
}

- (BOOL)select_inner_scope:(ViCommand *)command
{
	NSUInteger location = start_location;
	if ([self selectedRange].length > 0)
		location = start_location + 1;
	NSString *selector = [[self scopesAtLocation:location] componentsJoinedByString:@" "];
	NSRange range = [self trackScopeSelector:selector atLocation:location];

	visual_start_location = start_location = range.location;
	final_location = end_location = NSMaxRange(range) - 1;
	return YES;
}

- (BOOL)select_inner:(ViCommand *)command
{
	switch (command.argument) {
	case 'w':
		return [self select_inner_word:command];
		break;
	case 'W':
		return [self select_inner_bigword:command];
		break;
	case '(':
	case ')':
	case 'b':
		return [self select_inner_paragraph:command];
		break;
	case '{':
	case '}':
	case 'B':
		return [self select_inner_brace:command];
		break;
	case '[':
	case ']':
		return [self select_inner_bracket:command];
		break;
	case 's':
		return [self select_inner_scope:command];
		break;
	default:
		[[self delegate] message:@"Unrecognized text object."];
		return NO;
	}
}

- (BOOL)window_left:(ViCommand *)command
{
	return [[[self delegate] environment] selectViewAtPosition:ViViewLeft relativeTo:self];
}

- (BOOL)window_down:(ViCommand *)command
{
	return [[[self delegate] environment] selectViewAtPosition:ViViewDown relativeTo:self];
}

- (BOOL)window_up:(ViCommand *)command
{
	return [[[self delegate] environment] selectViewAtPosition:ViViewUp relativeTo:self];
}

- (BOOL)window_right:(ViCommand *)command
{
	return [[[self delegate] environment] selectViewAtPosition:ViViewRight relativeTo:self];
}

- (BOOL)window_split:(ViCommand *)command
{
	return [[[self delegate] environment] ex_split:nil];
}

- (BOOL)window_vsplit:(ViCommand *)command
{
	return [[[self delegate] environment] ex_vsplit:nil];
}

@end

