#import "ViTextView.h"
#import "ViDocument.h"
#import "ViMark.h"
#import "ViJumpList.h"
#import "ViTextStorage.h"
#import "NSString-scopeSelector.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "ViRegisterManager.h"
#import "ViWindowController.h"
#import "ViCompletionController.h"
#import "ViDocumentView.h"
#import "ExEnvironment.h"
#import "ViDocumentController.h"
#import "SFTPConnectionPool.h"
#import "NSString-additions.h"

@implementation ViTextView (vi_commands)

/* syntax: [count]<ctrl-i> */
- (BOOL)jumplist_forward:(ViCommand *)command
{
	ViJumpList *jumplist = [[[self window] windowController] jumpList];
	BOOL ok = [jumplist forwardToURL:NULL line:NULL column:NULL view:NULL];
	if (!ok) {
		MESSAGE(@"Already at end of jumplist");
		return NO;
	}

	return YES;
}

/* syntax: [count]<ctrl-o> */
- (BOOL)jumplist_backward:(ViCommand *)command
{
	NSURL *url = [document fileURL];
	NSUInteger line = [[self textStorage] lineNumberAtLocation:start_location];
	NSUInteger column = [[self textStorage] columnAtLocation:start_location];
	NSView *view = self;
	ViJumpList *jumplist = [[[self window] windowController] jumpList];
	BOOL ok = [jumplist backwardToURL:&url line:&line column:&column view:&view];
	if (!ok) {
		MESSAGE(@"Already at beginning of jumplist");
		return NO;
	}

	return YES;
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
		MESSAGE(@"Already at end-of-file");
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
		MESSAGE(@"Already at the beginning of the file");
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
                MESSAGE(@"No match character on this line");
                return NO;
        }

        /* Special case: check if inside a string or comment. */
	NSArray *openingScopes = [self scopesAtLocation:openingRange.location];
	BOOL inSpecialScope;
        NSRange specialScopeRange;

	inSpecialScope = ([@"string" matchesScopes:openingScopes] > 0);
        if (inSpecialScope)
        	specialScopeRange = [self rangeOfScopeSelector:@"string" atLocation:openingRange.location];
	else {
		inSpecialScope = ([@"comment" matchesScopes:openingScopes] > 0);
		if (inSpecialScope)
			specialScopeRange = [self rangeOfScopeSelector:@"comment" atLocation:openingRange.location];
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
                        endOffset = [[self textStorage] length];
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
		MESSAGE(@"Matching character not found");
		return NO;
        }

	[self pushLocationOnJumpList:start_location];

	final_location = end_location = offset;

	/*
	 * Adjust the start/end location to include the begin/end match.
	 * Do this when % is used as motion component in a non-line-oriented editing command.
	 */
	if (command.hasOperator &&
	    (command.operator.action == @selector(delete:) ||
	     command.operator.action == @selector(change:) ||
	     command.operator.action == @selector(yank:))) {
		if (delta == 1)
			end_location++;
		else
			start_location++;
	}

	return YES;
}

- (void)filterFinishedWithStatus:(int)status standardOutput:(NSString *)outputText contextInfo:(id)contextInfo
{
	if (status == 0) {
		NSRange range = [(NSValue *)contextInfo rangeValue];
		[self replaceRange:range withString:outputText];
		[self endUndoGroup];
	} else
		MESSAGE(@"filter exited with status %i", status);
}

- (void)filter_through_shell_command:(NSString *)shellCommand contextInfo:(void *)contextInfo
{
	if ([shellCommand length] == 0)
		return;

	NSString *inputText = [[[self textStorage] string] substringWithRange:affectedRange];

	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/bash"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];

	NSMutableDictionary *env = [NSMutableDictionary dictionary];
	[env addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
	[ViBundle setupEnvironment:env forTextView:self];
	[task setEnvironment:env];

	[[document environment] filterText:inputText
			       throughTask:task
				    target:self
				  selector:@selector(filterFinishedWithStatus:standardOutput:contextInfo:)
			       contextInfo:[NSValue valueWithRange:affectedRange]
			      displayTitle:shellCommand];
}

/* syntax: [count]!motion command(s) */
- (BOOL)filter:(ViCommand *)command
{
	[[document environment] getExCommandWithDelegate:self
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

	NSUInteger cur;
	[self getLineStart:NULL end:&cur contentsEnd:NULL];

	NSUInteger bol = cur, end, eol = 0;
	for (; eol < [[self textStorage] length];)
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
	if (command.isLineMode && NSMaxRange(affectedRange) == [[self textStorage] length] && bol > 0) {
		affectedRange.location--;	// FIXME: what about using CRLF at end-of-lines?
		affectedRange.length++;
		DEBUG(@"after including newline before first line: affected range: %@", NSStringFromRange(affectedRange));
	}

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
	if ([content hasSuffix:@"\n"]) {
		// putting whole lines
		final_location = end;
	} else if (start_location < eol) {
		// in contrast to move_right, we are allowed to move to EOL here
		final_location = start_location + 1;
	}

	[self insertString:content atLocation:final_location];

	return YES;
}

/* syntax: [count]r<char> */
- (BOOL)replace:(ViCommand *)command
{
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
								  withString:[NSString stringWithFormat:@"%C", command.argument]
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
							  withString:[NSString stringWithFormat:@"%C", command.argument]
						     startingAtIndex:0];
		[self replaceRange:affectedRange withString:replacement];
	}

	return YES;
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
			end_location--;
			affectedRange.length--;
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
	[[[self layoutManager] nextRunloop] addTemporaryAttribute:ViAutoIndentAttributeName
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
	[self setInsertMode:command];
	return YES;
}

/* syntax: [buffer][count]s */
- (BOOL)substitute:(ViCommand *)command
{
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:start_location];
	NSUInteger len = IMAX(1, command.count);

	/* A count should not cause multiplied text (after leaving insert mode). */
	command.count = 0;

	if (start_location + len >= eol)
		len = eol - start_location;
	[self cutToRegister:command.reg range:NSMakeRange(start_location, len)];
	[self setInsertMode:command];
	return YES;
}

/* syntax: [count]J */
- (BOOL)join:(ViCommand *)command
{
	NSUInteger bol, eol, end;
	[self getLineStart:&bol end:&end contentsEnd:&eol];
	if (end == eol) {
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
	    [whitespace characterIsMember:[[[self textStorage] string] characterAtIndex:eol-1]])
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
			MESSAGE(@"Already in the first column");
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

	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol];
	if (start_location + ((mode == ViInsertMode || command.hasOperator) ? 0 : 1) >= eol) {
		MESSAGE(@"Already at end-of-line");
		return NO;
	}
	if (start_location + count >= eol)
		final_location = end_location = eol - ((mode == ViInsertMode || command.hasOperator) ? 0 : 1);
	else
		final_location = end_location = start_location + count;
	return YES;
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
		NSUInteger cur = start_location, bol = 0, eol = 0;
		while (count--)
			[self getLineStart:&bol end:&cur contentsEnd:&eol forLocation:cur];
		final_location = end_location = IMAX(bol, eol - (command.hasOperator ? 0 : 1 ));
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
	ViCommand *c = [keyManager.parser.last_ftFT_command dotCopy];
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
	ViCommand *c = [keyManager.parser.last_ftFT_command dotCopy];
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
	if (start_location < eol) {
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

	NSString *undoStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"undostyle"];
	if ([undoStyle isEqualToString:@"nvi"]) {
		DEBUG(@"undo_direction is %i", undo_direction);
		if (undo_direction == 0)
			undo_direction = 1;	// backward (normal undo)
		else if (!command.fromDot)
			undo_direction = (undo_direction == 1 ? 2 : 1);

		if (undo_direction == 1) {
			if (![undoManager canUndo]) {
				MESSAGE(@"No changes to undo");
				return NO;
			}
			[[self textStorage] beginEditing];
			[undoManager undo];
			[[self textStorage] endEditing];
		} else {
			if (![undoManager canRedo]) {
				MESSAGE(@"No changes to re-do");
				return NO;
			}
			[[self textStorage] beginEditing];
			[undoManager redo];
			[[self textStorage] endEditing];
		}
	} else {
		if (![undoManager canUndo]) {
			MESSAGE(@"No changes to undo");
			return NO;
		}
		[[self textStorage] beginEditing];
		[undoManager undo];
		[[self textStorage] endEditing];
	}

	return YES;
}

/* syntax: C-r */
- (BOOL)vim_redo:(ViCommand *)command
{
	NSString *undoStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"undostyle"];
	if ([undoStyle isEqualToString:@"nvi"])
		return NO;

	if (![undoManager canRedo]) {
		MESSAGE(@"No changes to re-do");
		return NO;
	}
	[undoManager redo];

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
		unichar ch = [s characterAtIndex:word_location];
		if (!bigword && [wordSet characterIsMember:ch]) {
			// skip word-chars and whitespace
			end_location = [[self textStorage] skipCharactersInSet:wordSet
								  fromLocation:word_location
								      backward:NO];
		} else if (![whitespace characterIsMember:ch]) {
			// inside non-word-chars
			end_location = [[self textStorage] skipCharactersInSet:bigword ? [whitespace invertedSet] : nonWordSet
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
	if ([whitespace characterIsMember:ch]) {
		end_location = [[self textStorage] skipCharactersInSet:whitespace fromLocation:end_location backward:YES];
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
			end_location = [[self textStorage] skipCharactersInSet:[whitespace invertedSet]
								  fromLocation:word_location
								      backward:YES];
			if (count == 0 && [whitespace characterIsMember:[s characterAtIndex:end_location]])
				end_location++;
		} else if ([wordSet characterIsMember:ch]) {
			// skip word-chars and whitespace
			end_location = [[self textStorage] skipCharactersInSet:wordSet
								  fromLocation:word_location
								      backward:YES];
			if (count == 0 && ![wordSet characterIsMember:[s characterAtIndex:end_location]])
				end_location++;
		} else {
			// inside non-word-chars
			end_location = [[self textStorage] skipCharactersInSet:nonWordSet
								  fromLocation:word_location
								      backward:YES];
			if (count == 0 && [wordSet characterIsMember:[s characterAtIndex:end_location]])
				end_location++;
		}

		if (count > 0)
			end_location = [[self textStorage] skipCharactersInSet:whitespace
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

	/* From nvi:
	 * !!!
	 * If in whitespace, or the next character is whitespace, move past
	 * it.  (This doesn't count as a word move.)  Stay at the character
	 * past the current one, it sets word "state" for the 'e' command.
	 */
	if ([whitespace characterIsMember:ch]) {
		end_location = [[self textStorage] skipCharactersInSet:whitespace
							  fromLocation:end_location
							      backward:NO];
		if (end_location == [s length]) {
			final_location = end_location;
			return YES;
		}
	}

	BOOL bigword = [command.mapping.keyString isEqualToString:@"E"];	// XXX: use another selector!

	ch = [s characterAtIndex:end_location];
	if (bigword) {
		end_location = [[self textStorage] skipCharactersInSet:[whitespace invertedSet]
							  fromLocation:end_location backward:NO];
		if (!command.hasOperator ||
		    (command.operator.action != @selector(delete:) &&
		     command.operator.action != @selector(end_of_word:)))
			end_location--;
	} else if ([wordSet characterIsMember:ch]) {
		end_location = [[self textStorage] skipCharactersInSet:wordSet
							  fromLocation:end_location
							      backward:NO];
		if (!command.hasOperator ||
		    (command.operator.action != @selector(delete:) &&
		     command.operator.action != @selector(end_of_word:)))
			end_location--;
	} else {
		// inside non-word-chars
		end_location = [[self textStorage] skipCharactersInSet:nonWordSet
							  fromLocation:end_location
							      backward:NO];
		if (!command.hasOperator ||
		    (command.operator.action != @selector(delete:) &&
		     command.operator.action != @selector(end_of_word:)))
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
	if ([s length] == 0) {
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
	--eol;
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

- (void)gotoSymbol:(id)sender
{
	ViWindowController *windowController = [[self window] windowController];
	ViSymbol *sym = sender;
	if ([sender respondsToSelector:@selector(representedObject)])
		sym = [sender representedObject];

	ViTagStack *stack = windowController.tagStack;
	NSURL *url = [document fileURL];
	if (url)
		[stack pushURL:url
			  line:[self currentLine]
			column:[self currentColumn]];

	[windowController gotoSymbol:sym];
	final_location = NSNotFound;
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
		for (ViSymbol *sym in syms) {
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
		for (ViSymbol *sym in syms) {
			NSMutableArray *a = [docs objectForKey:sym.document];
			if (a == nil) {
				a = [NSMutableArray array];
				[docs setObject:a forKey:sym.document];
			}
			[a addObject:sym];
		}
		BOOL multiDocs = [docs count] > 1;

		NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Symbol matches"];
		[menu setAllowsContextMenuPlugIns:NO];
		int quickindex = 1;
		for (ViDocument *doc in docs) {
			if (multiDocs) {
				NSMenuItem *item = [menu addItemWithTitle:[doc title]
								   action:nil
							    keyEquivalent:@""];
				[item setEnabled:NO];
			}

			for (ViSymbol *sym in [docs objectForKey:doc]) {
				NSString *key = @"";
				if (quickindex <= 10)
					key = [NSString stringWithFormat:@"%i", quickindex % 10];
				NSMenuItem *item = [menu addItemWithTitle:sym.displayName
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
	ViTagStack *stack = windowController.tagStack;

	if (db == nil) {
		return [self jump_symbol:command];
		// MESSAGE(@"tags: No such file or directory.");
	}

	NSString *word = [[self textStorage] wordAtLocation:start_location];
	if (word) {
		NSArray *tag = [db lookup:word];
		if (tag) {
			NSURL *url = [document fileURL];
			if (url)
				[stack pushURL:url line:[self currentLine] column:[self currentColumn]];
			[self pushCurrentLocationOnJumpList];

			NSString *path = [tag objectAtIndex:0];
			NSString *ex_command = [tag objectAtIndex:1];

			if (![windowController gotoURL:[NSURL fileURLWithPath:path]])
				return NO;

			NSArray *p = [ex_command componentsSeparatedByString:@"/;"];
			NSString *pattern = [[p objectAtIndex:0] substringFromIndex:1];
			ViDocumentView *docView = (ViDocumentView *)[windowController currentView];
			[[docView textView] findPattern:pattern options:0];
			final_location = NSNotFound;
		} else {
			return [self jump_symbol:command];
			// MESSAGE(@"%@: tag not found", word);
		}
	}

	return YES;
}

// syntax: ^T
- (BOOL)pop_tag:(ViCommand *)command
{
	ViWindowController *windowController = [[self window] windowController];
	ViTagStack *stack = windowController.tagStack;
	NSDictionary *tag = [stack pop];
	if (tag) {
		[windowController gotoURL:[tag objectForKey:@"url"]
				     line:[[tag objectForKey:@"line"] unsignedIntegerValue]
				   column:[[tag objectForKey:@"column"] unsignedIntegerValue]];
	} else {
		MESSAGE(@"The tag stack is empty");
		return NO;
	}
	return YES;
}

- (BOOL)find_current_word:(ViCommand *)command options:(int)options
{
	NSString *word = [[self textStorage] wordAtLocation:start_location];
	if (word) {
		NSString *pattern = [NSString stringWithFormat:@"\\b%@\\b", word];
		keyManager.parser.last_search_pattern = pattern;
		keyManager.parser.last_search_options = options;
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
	else if ([url isFileURL])
		path = [[url path] stringByAbbreviatingWithTildeInPath];
	else
		path = [url absoluteString];

	MESSAGE(@"%@: %s: line %u of %u [%.0f%%] %@ syntax, %@ encoding",
	 path,
	 [[[NSDocumentController sharedDocumentController] currentDocument] isDocumentEdited] ? "modified" : "unmodified",
	 [self currentLine],
	 [[self textStorage] lineNumberAtLocation:IMAX(0, [[[self textStorage] string] length] - 1)],
	 (float)[self caret]*100.0 / ((float)[[[self textStorage] string] length] ?: 1),
	 [[document language] displayName] ?: "No",
	 [NSString localizedNameOfStringEncoding:[document encoding]]);
	return NO;
}

/* syntax: m<char> */
- (BOOL)set_mark:(ViCommand *)command
{
	[self setMark:command.argument atLocation:start_location];
	return YES;
}

/* syntax: '<char> */
/* syntax: `<char> */
- (BOOL)move_to_mark:(ViCommand *)command
{
	ViMark *m = [marks objectForKey:[NSString stringWithFormat:@"%C", command.argument]];
	if (m == nil) {
		MESSAGE(@"Mark %C: not set", command.argument);
		return NO;
	}

	NSInteger bol = [[self textStorage] locationForStartOfLine:m.line];
	if (bol == -1) {
		MESSAGE(@"Mark %C: the line was deleted", command.argument);
		return NO;
	}
	final_location = bol;

	if ([command.mapping.keyString isEqualToString:@"`"])	// XXX: use another selector!
		[self gotoColumn:m.column fromLocation:bol];
	else
		final_location = [[self textStorage] skipWhitespaceFrom:final_location];

	[[self nextRunloop] showFindIndicatorForRange:NSMakeRange(final_location, 1)];
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
	NSRange range = [self rangeOfScopeSelector:selector atLocation:location];

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
	case 'S':
		return [self select_inner_scope:command];
		break;
	default:
		MESSAGE(@"Unrecognized text object.");
		return NO;
	}
}

- (BOOL)uppercase:(ViCommand *)command
{
	NSString *string = [[[self textStorage] string] substringWithRange:affectedRange];
	[self replaceRange:affectedRange withString:[string uppercaseString]];
	final_location = end_location = start_location;
	return YES;
}

- (BOOL)lowercase:(ViCommand *)command
{
	NSString *string = [[[self textStorage] string] substringWithRange:affectedRange];
	[self replaceRange:affectedRange withString:[string lowercaseString]];
	final_location = end_location = start_location;
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

/* syntax: : */
- (BOOL)ex_command:(ViCommand *)command
{
	[[document environment] executeForTextView:self];
	return YES;
}

#pragma mark -
#pragma mark Completion

- (BOOL)completionController:(ViCompletionController *)completionController
     insertPartialCompletion:(NSString *)partialCompletion
                     inRange:(NSRange)range
{
	[self replaceRange:range withString:partialCompletion];
	final_location = range.location + [partialCompletion length];
	[self setCaret:final_location];
	return YES;
}

- (BOOL)presentCompletions:(NSArray *)completions
                 fromRange:(NSRange)range
                   options:(NSString *)options
{
	if ([completions count] == 0) {
		MESSAGE(@"No available completion.");
		return NO;
	} else if ([completions count] == 1) {
		ViCompletion *c = [completions objectAtIndex:0];
		[self insertSnippet:c.content inRange:range];
		return YES;
	} else {
		/* Automatically insert common prefix among all possible completions.
		 * FIXME: can't the completionController do this?
		 */
		if ([options rangeOfString:@"p"].location != NSNotFound) {
			NSString *commonPrefix = [ViCompletionController commonPrefixInCompletions:completions];
			if ([commonPrefix length] > range.length) {
				[self replaceRange:range withString:commonPrefix];
				range.length = [commonPrefix length];
				final_location = NSMaxRange(range);
				[self setCaret:final_location];

				for (ViCompletion *c in completions)
					c.prefixLength = range.length;
			}
		}

		BOOL positionAbove = ([options rangeOfString:@"a"].location != NSNotFound);
		BOOL fuzzySearch = ([options rangeOfString:@"f"].location != NSNotFound);

		/* Present a list to choose from. */
		ViCompletionController *cc = [ViCompletionController sharedController];
		cc.delegate = self;
		NSPoint point = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange([self caret], 0)
								inTextContainer:[self textContainer]].origin;
		/* Offset the completion window a bit. */
		point.x += (positionAbove ? 0 : 5);
		point.y += (positionAbove ? -3 : 10);
		ViCompletion *selection;
		selection = [cc chooseFrom:completions
			             range:range
			      prefixLength:range.length
					at:[[self window] convertBaseToScreen:[self convertPointToBase:point]]
				 direction:(positionAbove ? 1 : 0)
			       fuzzySearch:fuzzySearch
			     initialFilter:nil];
		DEBUG(@"completion controller returned [%@] in range %@", selection, NSStringFromRange(cc.range));
		if (selection)
			[self insertSnippet:selection.content inRange:cc.range];

		NSInteger termKey = cc.terminatingKey;
		if (termKey >= 0x20 && termKey < 0xFFFF) {
			NSString *special = [NSString stringWithKeyCode:termKey];
			if ([special length] == 1) {
				[self insertString:[NSString stringWithFormat:@"%C", termKey]];
				final_location++;
			} /* otherwise it's a <special> key code, ignore it */
		} else if (termKey == 0x0D && [self isFieldEditor]) {
			[keyManager handleKey:termKey];
		}

		if (selection == nil)
			return NO;
		return YES;
	}
}

- (BOOL)complete_keyword:(ViCommand *)command
{
	NSRange range;
	NSString *word = [[self textStorage] wordAtLocation:start_location
						      range:&range
					        acceptAfter:YES];

	BOOL fuzzySearch = ([command.mapping.parameter rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([command.mapping.parameter rangeOfString:@"F"].location != NSNotFound);
	NSString *pattern;
	if (word == nil) {
		pattern = @"\\b\\w{3,}";
		range = NSMakeRange([self caret], 0);
	} else if (fuzzyTrigger) { /* Fuzzy completion trigger. */
		pattern = [NSMutableString string];
		[(NSMutableString *)pattern appendString:@"\\b\\w*"];
		[ViCompletionController appendFilter:word toPattern:(NSMutableString *)pattern fuzzyClass:@"\\w"];
		[(NSMutableString *)pattern appendString:@"\\w*"];
	} else {
		pattern = [NSString stringWithFormat:@"\\b(%@)\\w*", word];
	}

	DEBUG(@"searching for %@", pattern);

	unsigned rx_options = ONIG_OPTION_NOTBOL | ONIG_OPTION_NOTEOL | ONIG_OPTION_IGNORECASE;
	ViRegexp *rx;
	rx = [[ViRegexp alloc] initWithString:pattern
				      options:rx_options];
	NSArray *foundMatches = [rx allMatchesInString:[[self textStorage] string]
					       options:rx_options];

	NSMutableSet *uniq = [NSMutableSet set];
	for (ViRegexpMatch *m in foundMatches) {
		NSRange r = [m rangeOfMatchedString];
		if (r.location == NSNotFound || r.location == range.location)
			/* Don't include the word we're about to complete. */
			continue;
		NSString *content = [[[self textStorage] string] substringWithRange:r];
		ViCompletion *c;
		if (fuzzySearch) {
			c = [ViCompletion completionWithContent:content fuzzyMatch:m];
			if (!fuzzyTrigger)
				c.prefixLength = range.length;
		} else
			c = [ViCompletion completionWithContent:content prefixLength:range.length];
		c.location = r.location;
		[uniq addObject:c];
	}

	BOOL sortDescending = ([command.mapping.parameter rangeOfString:@"d"].location != NSNotFound);
	NSUInteger ref = [self caret];
	NSComparator sortByLocation = ^(id a, id b) {
		ViCompletion *ca = a, *cb = b;
		NSUInteger al = ca.location;
		NSUInteger bl = cb.location;
		if (al > bl) {
			if (bl < ref && al > ref)
				return (NSComparisonResult)(sortDescending ? NSOrderedDescending : NSOrderedAscending); // a < b
			return (NSComparisonResult)(sortDescending ? NSOrderedAscending : NSOrderedDescending); // a > b
		} else if (al < bl) {
			if (al < ref && bl > ref)
				return (NSComparisonResult)(sortDescending ? NSOrderedAscending : NSOrderedDescending); // a > b
			return (NSComparisonResult)(sortDescending ? NSOrderedDescending : NSOrderedAscending); // a < b
		}
		return (NSComparisonResult)NSOrderedSame;
	};
	NSArray *completions = [[uniq allObjects] sortedArrayUsingComparator:sortByLocation];

	if (![self presentCompletions:completions
			    fromRange:range
			      options:command.mapping.parameter])
		return NO;
	return YES;
}

- (void)appendFilter:(NSString *)string toPattern:(NSMutableString *)pattern
{
	NSUInteger i;
	for (i = 0; i < [string length]; i++) {
		unichar c = [string characterAtIndex:i];
		if (i != 0)
			[pattern appendString:@".*?"];
		[pattern appendFormat:@"(%s%C)", c == '.' ? "\\" : "", c];
	}
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

	NSString *basePath = nil;
	NSURL *baseURL = nil;
	NSURL *relURL = nil, *url = nil;
	BOOL isAbsoluteURL = NO;
	if ([path rangeOfString:@"://"].location != NSNotFound) {
		isAbsoluteURL = YES;
		url = [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		if (url == nil) {
			INFO(@"failed to parse url %@", path);
			return NO;
		}
		if ([path hasSuffix:@"/"])
			baseURL = url;
		else
			baseURL = [url URLByDeletingLastPathComponent];
	} else if ([path isAbsolutePath]) {
		if ([path hasSuffix:@"/"])
			basePath = path;
		else
			basePath = [path stringByDeletingLastPathComponent];
		url = [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]];
	} else {
		if ([path hasSuffix:@"/"])
			basePath = path;
		else
			basePath = [path stringByDeletingLastPathComponent];
		relURL = [(ExEnvironment *)[[[self window] windowController] environment] baseURL];
		url = [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
			     relativeToURL:relURL];
	}

	NSString *suffix = @"";
	if (![path hasSuffix:@"/"] && ![path isEqualToString:@""]) {
		suffix = [path lastPathComponent];
		url = [url URLByDeletingLastPathComponent];
	}

	BOOL fuzzySearch = ([command.mapping.parameter rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([command.mapping.parameter rangeOfString:@"F"].location != NSNotFound);
	ViRegexp *rx = nil;
	if (fuzzyTrigger) { /* Fuzzy completion trigger. */
		NSMutableString *pattern = [NSMutableString string];
		[pattern appendString:@"^"];
		[self appendFilter:suffix toPattern:pattern];
		[pattern appendString:@".*$"];
		rx = [[ViRegexp alloc] initWithString:pattern options:ONIG_OPTION_IGNORECASE];
	}

	DEBUG(@"suffix = [%@], rx = [%@], url = %@", suffix, rx, url);

	int options = 0;
	if ([url isFileURL]) {
		/* Check if local filesystem is case sensitive. */
		NSNumber *isCaseSensitive;
		if ([url getResourceValue:&isCaseSensitive
				   forKey:NSURLVolumeSupportsCaseSensitiveNamesKey
				    error:NULL] && ![isCaseSensitive intValue] == 1) {
			options |= NSCaseInsensitiveSearch;
		}
	}

	SFTPConnection *conn = nil;
	NSFileManager *fm = nil;

	NSArray *directoryContents;
	NSError *error = nil;
	if ([url isFileURL]) {
		fm = [NSFileManager defaultManager];
		directoryContents = [fm contentsOfDirectoryAtPath:[url path] error:&error];
	} else {
		conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:&error];
		directoryContents = [conn contentsOfDirectoryAtPath:[url path] error:&error];
	}

	if (error) {
		INFO(@"error is %@", error);
		return NO;
	}

	NSMutableArray *matches = [NSMutableArray array];
	for (id entry in directoryContents) {
		NSString *filename;
		if ([url isFileURL])
			filename = entry;
		else
			filename = [[(SFTPDirectoryEntry *)entry filename] lastPathComponent];

		NSRange r = NSIntersectionRange(NSMakeRange(0, [suffix length]),
		    NSMakeRange(0, [filename length]));
		BOOL match;
		ViRegexpMatch *m = nil;
		if (fuzzyTrigger)
			match = ((m = [rx matchInString:filename]) != nil);
		else
			match = [filename compare:suffix options:options range:r] == NSOrderedSame;

		if (match) {
			/* Only show dot-files if explicitly requested. */
			if ([filename hasPrefix:@"."] && ![suffix hasPrefix:@"."])
				continue;

			NSString *s;
			if (isAbsoluteURL)
				s = [[baseURL URLByAppendingPathComponent:filename] absoluteString];
			else
				s = [basePath stringByAppendingPathComponent:filename];
			BOOL isDirectory = NO;

			if ([url isFileURL]) {
				if (![s hasSuffix:@"/"]) {
					NSString *p = [[url path] stringByAppendingPathComponent:filename];
					[fm fileExistsAtPath:p
						 isDirectory:&isDirectory];
				}
			} else
				isDirectory = [entry isDirectory];
			if (isDirectory)
				s = [s stringByAppendingString:@"/"];

			ViCompletion *c;
			if (fuzzySearch) {
				c = [ViCompletion completionWithContent:s fuzzyMatch:m];
				c.prefixLength = range.length;
			} else
				c = [ViCompletion completionWithContent:s prefixLength:range.length];
			[matches addObject:c];
		}
	}

	if (![self presentCompletions:matches
			    fromRange:range
			      options:command.mapping.parameter])
		return NO;
	return YES;
}

- (BOOL)complete_buffer:(ViCommand *)command
{
	NSRange range;
	NSString *word = [[self textStorage] wordAtLocation:start_location
						      range:&range
					        acceptAfter:YES];

	BOOL fuzzySearch = ([command.mapping.parameter rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([command.mapping.parameter rangeOfString:@"F"].location != NSNotFound);
	NSMutableString *pattern = [NSMutableString string];
	if (word == nil) {
		range = NSMakeRange([self caret], 0);
	} else if (fuzzyTrigger) {
		[ViCompletionController appendFilter:word toPattern:pattern fuzzyClass:@"."];
	} else {
		pattern = [NSString stringWithFormat:@"^%@.*", word];
	}

	unsigned rx_options = ONIG_OPTION_IGNORECASE;
	ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern
						options:rx_options];

	NSMutableArray *buffers = [NSMutableArray array];
	for (ViDocument *doc in [[[self window] windowController] documents]) {
		NSString *fn = [[doc fileURL] absoluteString];
		if (fn == nil)
			continue;
		ViRegexpMatch *m = nil;
		if (pattern == nil || (m = [rx matchInString:fn]) != nil) {
			ViCompletion *c;
			if (fuzzySearch)
				c = [ViCompletion completionWithContent:fn fuzzyMatch:m];
			else
				c = [ViCompletion completionWithContent:fn prefixLength:range.length];
			[buffers addObject:c];
		}
	}

	if (![self presentCompletions:buffers fromRange:range options:command.mapping.parameter])
		return NO;
	return YES;
}

- (BOOL)indent:(ViCommand *)command
{
	DEBUG(@"indenting range %@", NSStringFromRange(affectedRange));
	NSUInteger endLocation = NSMaxRange(affectedRange);
	NSUInteger loc = affectedRange.location;
	NSUInteger bol;
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

	final_location = [[self textStorage] firstNonBlankAtLocation:affectedRange.location];
	return YES;
}

@end

