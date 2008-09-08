#import "ViTextView.h"
#import "ViEditController.h"

@implementation ViTextView (vi_commands)

/* syntax: [buffer][count]d[count]motion */
- (BOOL)delete:(ViCommand *)command
{
	// need beginning of line for correcting caret position after deletion
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	
	[self cutToBuffer:0 append:NO range:affectedRange];
	
	// correct caret position if we deleted the last character(s) on the line
	if(bol > [[storage string] length])
		bol = IMAX(0, [[storage string] length] - 1);
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:bol];
	if(affectedRange.location >= eol)
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
	if(command.motion_key != 'y')
		final_location = affectedRange.location;
	return YES;
}

/* syntax: [buffer][count]P */
- (BOOL)put_before:(ViCommand *)command
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if([buffer length] == 0)
	{
		[[self delegate] message:@"The default buffer is empty"];
		return NO;
	}
	
	if([buffer hasSuffix:@"\n"])
	{
		NSUInteger bol;
		[self getLineStart:&bol end:NULL contentsEnd:NULL];
		
		start_location = final_location = bol;
	}
	[self insertString:buffer atLocation:start_location];
	[self recordInsertInRange:NSMakeRange(start_location, [buffer length])];
	
	return YES;
}

/* syntax: [buffer][count]p */
- (BOOL)put_after:(ViCommand *)command
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if([buffer length] == 0)
	{
		[[self delegate] message:@"The default buffer is empty"];
		return NO;
	}
	
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol];
	if([buffer hasSuffix:@"\n"])
	{
		// puting whole lines
		final_location = eol + 1;
	}
	else if(start_location < eol)
	{
		// in contrast to move_right, we are allowed to move to EOL here
		final_location = start_location + 1;
	}
	
	[self insertString:buffer atLocation:final_location];
	[self recordInsertInRange:NSMakeRange(final_location, [buffer length])];
	
	return YES;
}

/* syntax: [count]r<char> */
- (BOOL)replace:(ViCommand *)command
{
	[self recordReplacementOfRange:NSMakeRange(start_location, 1) withLength:1];
	
	[[storage mutableString] replaceCharactersInRange:NSMakeRange(start_location, 1)
					       withString:[NSString stringWithFormat:@"%C", command.argument]];
	
	return YES;
}

/* syntax: [buffer][count]c[count]motion */
- (BOOL)change:(ViCommand *)command
{
	/* The change command is implemented as delete + insert. This should be undone
	 * as a single operation, so we begin an undo group here and end it when recording
	 * the insert operation.
	 */
	[undoManager beginUndoGrouping];
	hasBeginUndoGroup = YES;

	if (command.line_mode)
	{
		/* adjust the range to exclude the last newline */
		NSUInteger bol;
		[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:end_location];
		if (end_location == bol)
		{
			INFO(@"adjusting last newline in line-mode change command");
			end_location--;
			affectedRange.length--;
		}
	}

	INFO(@"range = %u.%u", affectedRange.location, affectedRange.length);
	
	if([self delete:command])
	{
		end_location = final_location;
		[self setInsertMode:command];
		return YES;
	}
	else
		return NO;
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
	/* The substitute command is implemented as delete + insert. This should be undone
	 * as a single operation, so we begin an undo group here and end it when recording
	 * the insert operation.
	 */
	[undoManager beginUndoGrouping];
	hasBeginUndoGroup = YES;
	
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol];
	NSUInteger c = command.count;
	if(command.count == 0)
		c = 1;
	if(start_location + c >= eol)
		c = eol - start_location;
	[self cutToBuffer:0 append:NO range:NSMakeRange(start_location, c)];
	return [self insert:command];
}

/* syntax: [count]J */
- (BOOL)join:(ViCommand *)command
{
	NSUInteger bol, eol, end;
	[self getLineStart:&bol end:&end contentsEnd:&eol];
	if(end == eol)
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
	// INFO(@"join: bol = %u, eol = %u, end = %u, eol2 = %u, end2 = %u", bol, eol, end, eol2, end2);
	
	if(eol2 == end || bol == eol || [whitespace characterIsMember:[[storage string] characterAtIndex:eol-1]])
	{
		/* From nvi: Empty lines just go away. */
		NSRange r = NSMakeRange(eol, end - eol);
		[self recordDeleteOfRange:r];
		[[storage mutableString] deleteCharactersInRange:r];
		if(bol == eol)
			final_location = IMAX(bol, eol2 - 1 - (end - eol));
		else
			final_location = IMAX(bol, eol - 1);
	}
	else
	{
		final_location = eol;
		NSString *joinPadding = @" ";
		if([[NSCharacterSet characterSetWithCharactersInString:@".!?"] characterIsMember:[[storage string] characterAtIndex:eol-1]])
			joinPadding = @"  ";
		else if([[storage string] characterAtIndex:end] == ')')
		{
			final_location = eol - 1;
			joinPadding = @"";
		}
		NSUInteger sol2 = [self skipWhitespaceFrom:end toLocation:eol2];
		NSRange r = NSMakeRange(eol, sol2 - eol);
		[self recordReplacementOfRange:r withLength:[joinPadding length]];
		[[storage mutableString] replaceCharactersInRange:r withString:joinPadding];
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
	if(eol > bol)
	{
		NSRange range;
		range.location = start_location;
		range.length = eol - start_location;
		
		[self cutToBuffer:0 append:NO range:range];
	}
	
	return [self insert:command];
}

/* syntax: [count]h */
- (BOOL)move_left:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if(start_location == bol)
	{
		if(command)
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
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol];
	if(start_location + 1 >= eol)
	{
		[[self delegate] message:@"Already at end-of-line"];
		return NO;
	}
	final_location = end_location = start_location + 1;
	return YES;
}
/* syntax: [count]k */
- (BOOL)move_up:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if(bol == 0)
	{
		[[self delegate] message:@"Already at the beginning of the file"];
		return NO;
	}
	
	NSUInteger column = start_location - bol;
	final_location = end_location = bol - 1; // previous line
	[self gotoColumn:column fromLocation:end_location];
	need_scroll = YES;
	return YES;
}

/* syntax: [count]j */
- (BOOL)move_down:(ViCommand *)command
{
	NSUInteger bol, end;
	[self getLineStart:&bol end:&end contentsEnd:NULL];
	if(end >= [storage length])
	{
		[[self delegate] message:@"Already at end-of-file"];
		return NO;
	}
	NSUInteger column = start_location - bol;
	final_location = end_location = end; // next line
	[self gotoColumn:column fromLocation:end_location];
	need_scroll = YES;
	return YES;
}

/* syntax: 0 */
- (BOOL)move_bol:(ViCommand *)command
{
	[self getLineStart:&end_location end:NULL contentsEnd:NULL];
	final_location = end_location;
	need_scroll = YES;
	return YES;
}

/* syntax: _ or ^ */
- (BOOL)move_first_char:(ViCommand *)command
{
	[self getLineStart:&end_location end:NULL contentsEnd:NULL];
	end_location = [self skipWhitespaceFrom:end_location];
	final_location = end_location;
	need_scroll = YES;
	return YES;
}

/* syntax: [count]$ */
- (BOOL)move_eol:(ViCommand *)command
{
	if([storage length] > 0)
	{
		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol];
		final_location = end_location = IMAX(bol, eol - command.ismotion);
		need_scroll = YES;
	}
	return YES;
}

/* syntax: [count]f<char> */
- (BOOL)move_to_char:(ViCommand *)command
{
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol];
	NSUInteger i = start_location;
	int count = IMAX(command.count, 1);
	if(!command.ismotion)
		count = IMAX(command.motion_count, 1);
	while(count--)
	{
		while(++i < eol && [[storage string] characterAtIndex:i] != command.argument)
		/* do nothing */ ;
		if(i == eol)
		{
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
	if([self move_to_char:command])
	{
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
		NSInteger location = [self locationForStartOfLine:count];
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
		NSUInteger last_location = [[storage string] length];
		if(last_location > 0)
			--last_location;
		[self getLineStart:&end_location end:NULL contentsEnd:NULL forLocation:last_location];
		final_location = end_location;
	}
	need_scroll = YES;
	return YES;
}

/* syntax: [count]a */
- (BOOL)append:(ViCommand *)command
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if(start_location < eol)
	{
		start_location += 1;
		final_location = end_location = start_location;
	}
	return [self insert:command];
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
 	final_location = end_location + num_chars;
	[self recordInsertInRange:NSMakeRange(end_location, num_chars)];
	return [self insert:command];
}

/* syntax: O */
- (BOOL)open_line_above:(ViCommand *)command
{
	[self getLineStart:&end_location end:NULL contentsEnd:NULL];
	int num_chars = [self insertNewlineAtLocation:end_location indentForward:NO];
	final_location = end_location - 1 + num_chars;
	[self recordInsertInRange:NSMakeRange(end_location, num_chars)];
	return [self insert:command];
}

/* syntax: u */
- (BOOL)vi_undo:(ViCommand *)command
{
	if(![undoManager canUndo])
	{
		[[self delegate] message:@"Can't undo"];
		return NO;
	}
	[undoManager undo];
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
	if([storage length] == 0)
	{
		[[self delegate] message:@"Empty file"];
		return NO;
	}
	NSString *s = [storage string];
	unichar ch = [s characterAtIndex:start_location];
	
	BOOL bigword = (command.ismotion ? command.key == 'W' : command.motion_key == 'W');
	
	if(!bigword && [wordSet characterIsMember:ch])
	{
		// skip word-chars and whitespace
		end_location = [self skipCharactersInSet:wordSet fromLocation:start_location backward:NO];
		// INFO(@"from word char: %u -> %u", start_location, end_location);
	}
	else if(![whitespace characterIsMember:ch])
	{
		// inside non-word-chars
		end_location = [self skipCharactersInSet:bigword ? [whitespace invertedSet] : nonWordSet fromLocation:start_location backward:NO];
	}
	else if(!command.ismotion && command.key != 'd' && command.key != 'y')
	{
		/* We're in whitespace. */
		/* See comment from nvi below. */
		end_location = start_location + 1;
	}
	
	/* From nvi:
	 * Movements associated with commands are different than movement commands.
	 * For example, in "abc  def", with the cursor on the 'a', "cw" is from
	 * 'a' to 'c', while "w" is from 'a' to 'd'.  In general, trailing white
	 * space is discarded from the change movement.  Another example is that,
	 * in the same string, a "cw" on any white space character replaces that
	 * single character, and nothing else.  Ain't nothin' in here that's easy. 
	 */
	if(command.ismotion || command.key == 'd' || command.key == 'y')
		end_location = [self skipWhitespaceFrom:end_location];
	
	if(!command.ismotion && (command.key == 'd' || command.key == 'y'))
	{
		/* Restrict to current line if deleting/yanking last word on line.
		 * However, an empty line can be deleted as a word.
		 */
		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol];
		if(end_location > eol && bol != eol)
		{
			// INFO(@"adjusting location from %lu to %lu at EOL", end_location, eol);
			end_location = eol;
		}
	}
	else if(end_location >= [s length])
		end_location = [s length] - 1;
	final_location = end_location;
	return YES;
}

/* syntax: [count]b */
/* syntax: [count]B */
- (BOOL)word_backward:(ViCommand *)command
{
	if([storage length] == 0)
	{
		[[self delegate] message:@"Empty file"];
		return NO;
	}
	if(start_location == 0)
	{
		[[self delegate] message:@"Already at the beginning of the file"];
		return NO;
	}
	NSString *s = [storage string];
	end_location = start_location - 1;
	unichar ch = [s characterAtIndex:end_location];
	
	/* From nvi:
         * !!!
         * If in whitespace, or the previous character is whitespace, move
         * past it.  (This doesn't count as a word move.)  Stay at the
         * character before the current one, it sets word "state" for the
         * 'b' command.
         */
	if([whitespace characterIsMember:ch])
	{
		end_location = [self skipCharactersInSet:whitespace fromLocation:end_location backward:YES];
		if(end_location == 0)
		{
			final_location = end_location;
			return YES;
		}
	}
	ch = [s characterAtIndex:end_location];
	
	BOOL bigword = (command.ismotion ? command.key == 'B' : command.motion_key == 'B');
	
	if(bigword)
	{
		end_location = [self skipCharactersInSet:[whitespace invertedSet] fromLocation:end_location backward:YES];
		if([whitespace characterIsMember:[s characterAtIndex:end_location]])
			end_location++;
	}
	else if([wordSet characterIsMember:ch])
	{
		// skip word-chars and whitespace
		end_location = [self skipCharactersInSet:wordSet fromLocation:end_location backward:YES];
		if(![wordSet characterIsMember:[s characterAtIndex:end_location]])
			end_location++;
	}
	else
	{
		// inside non-word-chars
		end_location = [self skipCharactersInSet:nonWordSet fromLocation:end_location backward:YES];
		if([wordSet characterIsMember:[s characterAtIndex:end_location]])
			end_location++;
	}
	
	final_location = end_location;
	return YES;
}

- (BOOL)end_of_word:(ViCommand *)command
{
	if([storage length] == 0)
	{
		[[self delegate] message:@"Empty file"];
		return NO;
	}
	NSString *s = [storage string];
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
		end_location = [self skipCharactersInSet:whitespace fromLocation:end_location backward:NO];
		if(end_location == [s length])
		{
			final_location = end_location;
			return YES;
		}
	}
	
	BOOL bigword = (command.ismotion ? command.key == 'E' : command.motion_key == 'E');
	
	ch = [s characterAtIndex:end_location];
	if(bigword)
	{
		end_location = [self skipCharactersInSet:[whitespace invertedSet] fromLocation:end_location backward:NO];
		if(command.ismotion || (command.key != 'd' && command.key != 'e'))
			end_location--;
	}
	else if([wordSet characterIsMember:ch])
	{
		end_location = [self skipCharactersInSet:wordSet fromLocation:end_location backward:NO];
		if(command.ismotion || (command.key != 'd' && command.key != 'e'))
			end_location--;
	}
	else
	{
		// inside non-word-chars
		end_location = [self skipCharactersInSet:nonWordSet fromLocation:end_location backward:NO];
		if(command.ismotion || (command.key != 'd' && command.key != 'e'))
			end_location--;
	}
	
	final_location = end_location;
	return YES;
}

/* syntax: [count]I */
- (BOOL)insert_bol:(ViCommand *)command
{
	NSString *s = [storage string];
	if([s length] == 0)
		return YES;
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	
	unichar ch = [s characterAtIndex:bol];
	if([whitespace characterIsMember:ch])
	{
		// skip leading whitespace
		end_location = [self skipWhitespaceFrom:bol toLocation:eol];
	}
	else
		end_location = bol;
	final_location = end_location;
	return [self insert:command];
}

/* syntax: [count]x */
- (BOOL)delete_forward:(ViCommand *)command
{
	NSString *s = [storage string];
	if([s length] == 0)
	{
		[[self delegate] message:@"No characters to delete"];
		return NO;
	}
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if(bol == eol)
	{
		[[self delegate] message:@"no characters to delete"];
		return NO;
	}
	
	NSRange del;
	del.location = start_location;
	del.length = IMAX(1, command.count);
	if(del.location + del.length > eol)
		del.length = eol - del.location;
	[self cutToBuffer:0 append:NO range:del];
	
	// correct caret position if we deleted the last character(s) on the line
	end_location = start_location;
	--eol;
	if(end_location == eol && eol > bol)
		--end_location;
	final_location = end_location;
	return YES;
}

/* syntax: [count]X */
- (BOOL)delete_backward:(ViCommand *)command
{
	if([storage length] == 0)
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
	[self pageDown:self];
	end_location = final_location = [self caret];
	return YES;
}

/* syntax: ^B */
- (BOOL)backward_screen:(ViCommand *)command
{
	[self pageUp:self];
	end_location = final_location = [self caret];
	return YES;
}

/* syntax: [count]> */
- (BOOL)shift_right:(ViCommand *)command
{
	int lines = command.count;
	if(lines == 0)
		lines = 1;
	
	[undoManager beginUndoGrouping];
	
	// process each line separately (remember that line mode is set)
	NSUInteger nextLocation = affectedRange.location;
	while(lines--)
	{
		[self insertString:@"\t" atLocation:nextLocation];
		[self recordInsertInRange:NSMakeRange(nextLocation, 1)];
		
		// get next line
		NSUInteger end;
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:nextLocation];
		if(end == nextLocation || end == NSNotFound)
			break;
		nextLocation = end;
	}
	[undoManager endUndoGrouping];
	
	end_location = final_location = start_location + 1;
	
	return YES;
}

/* syntax: [count]< */
- (BOOL)shift_left:(ViCommand *)command
{
	int lines = command.count;
	if(lines == 0)
		lines = 1;
	
	BOOL hasUndoGrouping = NO;
	BOOL gotEndLocation = NO;
	
	// process each line separately (remember that line mode is set)
	NSUInteger nextLocation = affectedRange.location;
	while(lines--)
	{
		NSUInteger end;
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:nextLocation];
		if(end == nextLocation || end == NSNotFound)
			break;
		NSRange line = NSMakeRange(nextLocation, end - nextLocation);
		nextLocation = end;
		
		NSString *s = [[storage string] substringWithRange:line];
		if([s hasPrefix:@"\t"])
		{
			if(!hasUndoGrouping)
			{
				[undoManager beginUndoGrouping];
				hasUndoGrouping = YES;
			}
			[self recordDeleteOfRange:NSMakeRange(line.location, 1)];
			[storage deleteCharactersInRange:NSMakeRange(line.location, 1)];
			nextLocation--;
			
			if(!gotEndLocation && start_location > affectedRange.location)
				end_location = final_location = start_location - 1;
		}
		gotEndLocation = YES;
	}
	
	if(hasUndoGrouping)
		[undoManager endUndoGrouping];
	
	return YES;
}

// syntax: ^]
- (BOOL)jump_tag:(ViCommand *)command
{
	if(tags == nil || [tags databaseHasChanged])
		tags = [[ViTagsDatabase alloc] initWithFile:@"tags" inDirectory:[[[[self delegate] fileURL] path] stringByDeletingLastPathComponent]];
	if(tags == nil)
		return YES;

	NSString *word = [self wordAtLocation:start_location];
	if(word)
	{
		NSArray *tag = [tags lookup:word];
		if(tag)
		{
			[[self delegate] pushLine:[self currentLine] column:[self currentColumn]];

			NSString *file = [tag objectAtIndex:0];
			NSString *ex_command = [tag objectAtIndex:1];
			ViEditController *editor = [[self delegate] openFileInTab:file];
			
			if(editor)
			{
				NSArray *p = [ex_command componentsSeparatedByString:@"/;"];
				NSString *pattern = [[p objectAtIndex:0] substringFromIndex:1];
				[editor findPattern:pattern options:0 regexpType:OgreRubySyntax ignoreLastRegexp:YES];
			}
		}
		else
		{
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
	NSString *word = [self wordAtLocation:start_location];
	if(word)
	{
		lastSearchRegexp = nil;
		lastSearchPattern = [NSString stringWithFormat:@"\\b%@\\b", word];
		return [self findPattern:lastSearchPattern options:OgreNoneOption];
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
	 [self lineNumberAtLocation:IMAX(0, [[storage string] length] - 1)],
	 (float)[self caret]*100.0 / (float)[[storage string] length]];
	return YES;
}

@end
