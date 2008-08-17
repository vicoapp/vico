#import "ViTextView.h"
#import "ViLanguageStore.h"
#import "ViThemeStore.h"

@interface ViTextView (private)
- (BOOL)move_right:(ViCommand *)command;
- (void)disableWrapping;
@end

@implementation ViTextView

- (id)initWithFrame:(NSRect)frame textContainer:(NSTextContainer *)aTextContainer
{
	NSLog(@"%s initializing", _cmd);
	self = [super initWithFrame:frame textContainer:aTextContainer];
	if(self)
	{
		[self initEditor];
	}
	return self;
}

- (void)initEditor
{
	[self setCaret:0];

	[[self textStorage] setDelegate:self];

	parser = [[ViCommand alloc] init];
	buffers = [[NSMutableDictionary alloc] init];
	storage = [self textStorage];

	wordSet = [NSCharacterSet characterSetWithCharactersInString:@"_"];
	[wordSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	nonWordSet = [[NSMutableCharacterSet alloc] init];
	[nonWordSet formUnionWithCharacterSet:wordSet];
	[nonWordSet formUnionWithCharacterSet:whitespace];
	[nonWordSet invert];

	[self setRichText:NO];
	[self setImportsGraphics:NO];
	[self setUsesFontPanel:NO];
	//[self setPageGuideValues];
	[self disableWrapping];

	[self setTheme:[[ViThemeStore defaultStore] defaultTheme]];
}

- (void)setFilename:(NSURL *)aURL
{
	language = [[ViLanguageStore defaultStore] languageForFilename:[aURL path]];
	[language patterns];
}

- (BOOL)illegal:(ViCommand *)command
{
	NSLog(@"%c is not a vi command", command.key);
	return NO;
}

- (BOOL)nonmotion:(ViCommand *)command
{
	NSLog(@"%c may not be used as a motion command", command.key);
	return NO;
}

- (BOOL)nodot:(ViCommand *)command
{
	NSLog(@"No command to repeat");
	return NO;
}

- (BOOL)no_previous_ftFT:(ViCommand *)command
{
	NSLog(@"No previous F, f, T or t search");
	return NO;
}

- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr forLocation:(NSUInteger)aLocation
{
	[[storage string] getLineStart:bol_ptr end:end_ptr contentsEnd:eol_ptr forRange:NSMakeRange(aLocation, 0)];
}

- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr
{
	[self getLineStart:bol_ptr end:end_ptr contentsEnd:eol_ptr forLocation:start_location];
}

- (void)yankToBuffer:(unichar)bufferName append:(BOOL)appendFlag range:(NSRange)yankRange
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if(buffer == nil)
	{
		buffer = [[NSMutableString alloc] init];
		[buffers setObject:buffer forKey:@"unnamed"];
	}

	NSString *s = [storage string];
	[buffer setString:[s substringWithRange:yankRange]];
}

- (void)cutToBuffer:(unichar)bufferName append:(BOOL)appendFlag range:(NSRange)cutRange
{
	[self yankToBuffer:bufferName append:appendFlag range:cutRange];
	[storage deleteCharactersInRange:cutRange];
}

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
		final_location = IMAX(bol, eol - 1);
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
	final_location = affectedRange.location;
	return YES;
}

/* Like insertText:, but works within beginEditing/endEditing
 */
- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation
{
	[[storage mutableString] insertString:aString atIndex:aLocation];
}

/* syntax: [buffer][count]P */
- (BOOL)put_before:(ViCommand *)command
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if([buffer length] == 0)
	{
		NSLog(@"The default buffer is empty");
		return NO;
	}

	[self insertString:buffer atLocation:start_location];
	return YES;
}

/* syntax: [buffer][count]p */
- (BOOL)put_after:(ViCommand *)command
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if([buffer length] == 0)
	{
		NSLog(@"The default buffer is empty");
		return NO;
	}

	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol];
	if(start_location < eol)
	{
		// in contrast to move_right, we are allowed to move to EOL here
		final_location = start_location + 1;
	}

	[self insertString:buffer atLocation:final_location];
	return YES;
}

/* syntax: [buffer][count]c[count]motion */
- (BOOL)change:(ViCommand *)command
{
	[self setInsertMode];
	return [self delete:command];
}

/* syntax: i */
- (BOOL)insert:(ViCommand *)command
{
	[self setInsertMode];
	return YES;
}

/* syntax: [count]h */
- (BOOL)move_left:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if(start_location == bol)
	{
		NSLog(@"Already in the first column");
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
		NSLog(@"Already at end-of-line");
		return NO;
	}
	final_location = end_location = start_location + 1;
	return YES;
}

- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:aLocation];
	if(eol - bol > column)
		final_location = end_location = bol + column;
	else if(eol - bol > 1)
		final_location = end_location = eol - 1;
	else
		final_location = end_location = bol;
}

/* syntax: [count]k */
- (BOOL)move_up:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if(bol == 0)
	{
		NSLog(@"Already at the beginning of the file");
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
		NSLog(@"Already at end-of-file");
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
	return YES;
}

/* syntax: $ */
- (BOOL)move_eol:(ViCommand *)command
{
	if([storage length] > 0)
	{
		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol];
		final_location = end_location = IMAX(bol, eol - command.ismotion);
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
		while(++i < eol && [[storage string] characterAtIndex:i] != command.character)
			/* do nothing */ ;
		if(i == eol)
		{
			NSLog(@"%c not found", command.character);
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
		int line = 1;
		final_location = end_location = 0;
		while(line < count)
		{
			//NSLog(@"%s got line %i at location %u", _cmd, line, end_location);
			NSUInteger end;
			[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:end_location];
			if(end_location == end)
			{
				NSLog(@"%s Movement past the end-of-file", _cmd);
				final_location = end_location = start_location;
				return NO;
			}
			final_location = end_location = end;
			line++;
		}
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
		final_location = end_location = start_location + 1;
	[self setInsertMode];
	return YES;
}

/* syntax: [count]A */
- (BOOL)append_eol:(ViCommand *)command
{
	[self move_eol:command];
	start_location = end_location;
	[self append:command];
	return YES;
}

/* syntax: o */
- (BOOL)open_line_below:(ViCommand *)command
{
	[self getLineStart:NULL end:&end_location contentsEnd:NULL];
	[self insertString:@"\n" atLocation:end_location];
	[self setInsertMode];
	final_location = end_location;
	return YES;
}

/* syntax: O */
- (BOOL)open_line_above:(ViCommand *)command
{
	[self setInsertMode];
	[self getLineStart:&end_location end:NULL contentsEnd:NULL];
	[self insertString:@"\n" atLocation:end_location];
	final_location = end_location;
	return YES;
}

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet fromLocation:(NSUInteger)startLocation backward:(BOOL)backwardFlag
{
	NSString *s = [storage string];
	NSRange r = [s rangeOfCharacterFromSet:[characterSet invertedSet]
				       options:backwardFlag ? NSBackwardsSearch : 0
					 range:backwardFlag ? NSMakeRange(0, startLocation + 1) : NSMakeRange(startLocation, [s length] - startLocation)];
	if(backwardFlag && r.location == NSNotFound)
		return 0;
	return r.location;
}

- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation
{
	return [self skipCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
			    fromLocation:startLocation
				backward:NO];
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
- (BOOL)word_forward:(ViCommand *)command
{
	if([storage length] == 0)
	{
		NSLog(@"Empty file");
		return NO;
	}
	NSString *s = [storage string];
	unichar ch = [s characterAtIndex:start_location];

	if([wordSet characterIsMember:ch])
	{
		// skip word-chars and whitespace
		end_location = [self skipCharactersInSet:wordSet fromLocation:start_location backward:NO];
	}
	else if(![whitespace characterIsMember:ch])
	{
		// inside non-word-chars
		end_location = [self skipCharactersInSet:nonWordSet fromLocation:start_location backward:NO];
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
			NSLog(@"adjusting location from %lu to %lu at EOL", end_location, eol);
			end_location = eol;
		}
	}
	else if(end_location >= [s length])
		end_location = [s length] - 1;
	final_location = end_location;
	return YES;
}

/* syntax: [count]b */
- (BOOL)word_backward:(ViCommand *)command
{
	if([storage length] == 0)
	{
		NSLog(@"Empty file");
		return NO;
	}
	if(start_location == 0)
	{
		NSLog(@"Already at the beginning of the file");
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

	if([wordSet characterIsMember:ch])
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

/* syntax: [count]I */
- (BOOL)insert_bol:(ViCommand *)command
{
	[self insert:command];

	NSString *s = [storage string];
	if([s length] == 0)
		return YES;
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];

	unichar ch = [s characterAtIndex:bol];
	if([whitespace characterIsMember:ch])
	{
		// skip leading whitespace
		// FIXME: refactor, new method skipWhitespaceFrom:to:
		NSCharacterSet *nonWhitespace = [whitespace invertedSet];
		NSRange r = [s rangeOfCharacterFromSet:nonWhitespace
					       options:0
						 range:NSMakeRange(bol, eol - bol)];
		if(r.location == NSNotFound)
			end_location = eol;
		else
			end_location = r.location;
	}
	else
		end_location = bol;
	final_location = end_location;
	return YES;
}

/* syntax: [count]x */
- (BOOL)delete_forward:(ViCommand *)command
{
	NSString *s = [storage string];
	if([s length] == 0)
	{
		NSLog(@"No characters to delete");
		return NO;
	}
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if(bol == eol)
	{
		NSLog(@"no characters to delete");
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
		NSLog(@"Already in the first column");
		return NO;
	}
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if(start_location == bol)
	{
		NSLog(@"Already in the first column");
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





- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	if([theEvent type] != NSKeyDown && [theEvent type] != NSKeyUp)
		return NO;

	if([theEvent type] == NSKeyUp)
	{
		unichar charcode = [[theEvent characters] characterAtIndex:0];
		NSLog(@"Got a performKeyEquivalent event, characters: '%@', keycode = %u, modifiers = 0x%04X",
		      [theEvent charactersIgnoringModifiers],
		      charcode,
		      [theEvent modifierFlags]);
		return YES;
	}

	NSLog(@"Letting super handle unknown performKeyEquivalent event, keycode = %04X", [theEvent keyCode]);
	return [super performKeyEquivalent:theEvent];
}

/*
 * NSAlphaShiftKeyMask = 1 << 16,  (Caps Lock)
 * NSShiftKeyMask      = 1 << 17,
 * NSControlKeyMask    = 1 << 18,
 * NSAlternateKeyMask  = 1 << 19,
 * NSCommandKeyMask    = 1 << 20,
 * NSNumericPadKeyMask = 1 << 21,
 * NSHelpKeyMask       = 1 << 22,
 * NSFunctionKeyMask   = 1 << 23,
 * NSDeviceIndependentModifierFlagsMask = 0xffff0000U
 */

- (void)setCaret:(NSUInteger)location
{
	[self setSelectedRange:NSMakeRange(location, 0)];
}

- (NSUInteger)caret
{
	return [self selectedRange].location;
}

- (void)setCommandMode
{
	mode = ViCommandMode;
	//[self updateInsertionPoint];
}

- (void)setInsertMode
{
	mode = ViInsertMode;
	//[self updateInsertionPoint];
}

- (void)evaluateCommand:(ViCommand *)command
{
	/* Default start- and end-location is the current location. */
	start_location = [self caret];
	end_location = start_location;
	final_location = start_location;

	if(command.motion_method)
	{
		/* The command has an associated motion component.
		 * Run the motion method and record the start and end locations.
		 */
		if([self performSelector:NSSelectorFromString(command.motion_method) withObject:command] == NO)
		{
			/* the command failed */
			[command reset];
			final_location = start_location;
			return;
		}
	}

	/* Find out the affected range for this command */
	NSUInteger l1 = start_location, l2 = end_location;
	if(l2 < l1)
	{	/* swap if end < start */
		l2 = l1;
		l1 = end_location;
	}
	//NSLog(@"affected locations: %u -> %u (%u chars)", l1, l2, l2 - l1);

	if(command.line_mode && !command.ismotion)
	{
		/* if this command is line oriented, extend the affectedRange to whole lines */
		NSUInteger bol, end;
		[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:l1];
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:l2];
		l1 = bol;
		l2 = end;
		NSLog(@"after line mode correction: affected locations: %u -> %u (%u chars)", l1, l2, l2 - l1);

		/* If a line mode range includes the last line, also include the newline before the first line.
		 * This way delete doesn't leave an empty line.
		 */
		if(l2 == [storage length])
		{
			l1 = IMAX(0, l1 - 1);	// FIXME: what about using CRLF at end-of-lines?
			NSLog(@"after including newline before first line: affected locations: %u -> %u (%u chars)", l1, l2, l2 - l1);
		}
	}
	affectedRange = NSMakeRange(l1, l2 - l1);

	BOOL ok = (NSUInteger)[self performSelector:NSSelectorFromString(command.method) withObject:command];
	if(ok && command.line_mode)
	{
		/* For line mode operations, we always end up at the beginning of the line. */
		NSUInteger bol;
		[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:final_location];
		final_location = bol;
	}

	[command reset];
}

- (void)keyDown:(NSEvent *)theEvent
{
	unichar charcode = [[theEvent characters] characterAtIndex:0];
#if 0
	NSLog(@"Got a keyDown event, characters: '%@', keycode = %u, modifiers = 0x%04X",
	      [theEvent charactersIgnoringModifiers],
	      charcode,
	      [theEvent modifierFlags]);
#endif

	if(mode == ViInsertMode)
	{
		if(charcode == 0x1B)
		{
			/* escape, return to command mode */
			[self setCommandMode];
			start_location = end_location = [self caret];
			[self move_left:nil];
			[self setCaret:end_location];
		}
		else
		{
			[super keyDown:theEvent];
		}
	}
	else if(mode == ViCommandMode)
	{
		[parser pushKey:charcode];
		if(parser.complete)
		{
			[[self textStorage] beginEditing];
			[self evaluateCommand:parser];
			[[self textStorage] endEditing];
			[self setCaret:final_location];
			if(need_scroll)
				[self scrollRangeToVisible:NSMakeRange(final_location, 0)];
		}
	}
}

/* Takes a string of characters and creates key events for each one.
 * Then feeds them into the keyDown method to simulate key presses.
 * Mainly used for unit testing.
 */
- (void)input:(NSString *)inputString
{
	//NSLog(@"feeding input string [%@]", inputString);
	int i;
	for(i = 0; i < [inputString length]; i++)
	{
		NSEvent *ev = [NSEvent keyEventWithType:NSKeyDown
					       location:NSMakePoint(0, 0)
					  modifierFlags:0
					      timestamp:[[NSDate date] timeIntervalSinceNow]
					   windowNumber:0
						context:[NSGraphicsContext currentContext]
					     characters:[inputString substringWithRange:NSMakeRange(i, 1)]
			    charactersIgnoringModifiers:[inputString substringWithRange:NSMakeRange(i, 1)]
					      isARepeat:NO
						keyCode:[inputString characterAtIndex:i]];
		[self keyDown:ev];
		//[NSApp postEvent:ev atStart:NO];
		//BOOL r = [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
		//NSLog(@"runloop returned %i", r);
	}
}




/* This is SO stolen from Smultron.
 */
- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];

	NSRect bounds = [self bounds];
	if([self needsToDrawRect:NSMakeRect(pageGuideX, 0, 1, bounds.size.height)] == YES)
	{ // So that it doesn't draw the line if only e.g. the cursor updates
		[[self insertionPointColor] set];
		// pageGuideColour = [color colorWithAlphaComponent:([color alphaComponent] / 4)];
		[NSBezierPath strokeRect:NSMakeRect(pageGuideX, 0, 0, bounds.size.height)];
	}
}

- (void)setPageGuideValues
{
	NSDictionary *sizeAttribute = [[NSDictionary alloc] initWithObjectsAndKeys:[self font], NSFontAttributeName, nil];
	CGFloat sizeOfCharacter = [@" " sizeWithAttributes:sizeAttribute].width;
	pageGuideX = (sizeOfCharacter * (80 + 1)) - 1.5;
	// -1.5 to put it between the two characters and draw only on one pixel and
	// not two (as the system draws it in a special way), and that's also why the
	// width above is set to zero
	[self display];
}

/* This one is from CocoaDev.
 */
- (void)disableWrapping
{
	const float LargeNumberForText = 1.0e7;
	
	NSScrollView *scrollView = [self enclosingScrollView];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setHasHorizontalScroller:YES];
	[scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	
	NSTextContainer *textContainer = [self textContainer];
	[textContainer setContainerSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[textContainer setWidthTracksTextView:NO];
	[textContainer setHeightTracksTextView:NO];
	
	[self setMaxSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[self setHorizontallyResizable:YES];
	[self setVerticallyResizable:YES];
	[self setAutoresizingMask:NSViewNotSizable];
}

- (void)setTheme:(ViTheme *)aTheme
{
	NSLog(@"setting theme %@", [aTheme name]);
	theme = aTheme;
	[self setBackgroundColor:[theme backgroundColor]];
	[self setDrawsBackground:YES];
	[self setInsertionPointColor:[theme caretColor]];
	[self setSelectedTextAttributes:[NSDictionary dictionaryWithObject:[theme selectionColor] forKey:NSBackgroundColorAttributeName]];
	NSFont *font = [NSFont userFixedPitchFontOfSize:12.0];
	[self setFont:font];
	[self setTabSize:8];
	[self highlightEverything];
	[self setNeedsDisplay:YES];
}

- (void)setTabSize:(int)tabSize
{
	NSString *tab = [@"" stringByPaddingToLength:tabSize withString:@" " startingAtIndex:0];

	NSLog(@"setting tab size %i for font %@", tabSize, [self font]);

	NSDictionary *attrs = [NSDictionary dictionaryWithObject:[self font] forKey:NSFontAttributeName];
	NSSize tabSizeInPoints = [tab sizeWithAttributes:attrs];

	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

	// remove all previous tab stops
	NSArray *array = [style tabStops];
	NSTextTab *tabStop;
	for(tabStop in array)
	{
		[style removeTabStop:tabStop];
	}

	// "Tabs after the last specified in tabStops are placed at integral multiples of this distance."
	[style setDefaultTabInterval:tabSizeInPoints.width];

	NSLog(@"font = %@", [self font]);
	attrs = [NSDictionary dictionaryWithObjectsAndKeys:style, NSParagraphStyleAttributeName,
						           [self font], NSFontAttributeName, nil];
	[self setTypingAttributes:attrs];

	[storage addAttributes:attrs range:NSMakeRange(0, [[storage string] length])];
}

@end
