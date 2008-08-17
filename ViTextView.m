#import "ViTextView.h"

#ifdef IMAX
# undef IMAX
#endif
#define IMAX(a, b)  (((NSInteger)a) > ((NSInteger)b) ? (a) : (b))

@interface ViTextView (private)
- (void)move_right:(ViCommand *)command;
@end

@implementation ViTextView

+ (void)initKeymaps
{
}

- (void)initEditor
{
	NSFont *font = [NSFont userFixedPitchFontOfSize:12.0];
	[self setFont:font];
	[self setCaret:0];
	[self setInsertionPointColor:[NSColor colorWithCalibratedRed:0.2
		green:0.2
		blue:0.2
		alpha:0.5]];

	[[self textStorage] setDelegate:self];

	parser = [[ViCommand alloc] init];
	buffers = [[NSMutableDictionary alloc] init];
}

- (void)illegal:(ViCommand *)command
{
	NSLog(@"%c is not a vi command", command.key);
}

- (void)nonmotion:(ViCommand *)command
{
	NSLog(@"%c may not be used as a motion command", command.key);
}

- (void)nodot:(ViCommand *)command
{
	NSLog(@"No command to repeat");
}

- (void)current_line:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSUInteger bol, end;
	[[text string] getLineStart:&bol end:&end contentsEnd:NULL forRange:command.start_range];
	command.start_range = NSMakeRange(bol, 0);
	[self setCaret:end];
	NSLog(@"selecting current line: %lu -> %lu", bol, end);
}

/* syntax: [buffer][count]d[count]motion */
- (void)delete:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];

	// need beginning of line for correcting caret position after deletion
	NSUInteger bol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:NULL forRange:command.start_range];

	[text deleteCharactersInRange:affectedRange];

#if 0
	if([command.motion_method isEqualToString:@"current_line"])
		[self setCaret:affectedRange.location];
#endif

	// correct caret position if we deleted the last character(s) on the line
	NSUInteger eol;
	[[text string] getLineStart:NULL end:NULL contentsEnd:&eol forRange:NSMakeRange(bol, 0)];
	if(affectedRange.location >= eol)
	{
		[self setCaret:IMAX(bol, eol - 1)];
	}
	else
		[self setCaret:affectedRange.location];
}

/* syntax: [buffer][count]y[count][motion] */
- (void)yank:(ViCommand *)command
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if(buffer == nil)
	{
		buffer = [[NSMutableString alloc] init];
		[buffers setObject:buffer forKey:@"unnamed"];
	}

	NSTextStorage *text = [self textStorage];
	NSString *s = [text string];
	[buffer setString:[s substringWithRange:affectedRange]];

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
	[self setCaret:affectedRange.location];
}

/* Like insertText:, but works within beginEditing/endEditing
 */
- (void)insertString:(NSString *)aString
{
	[[self textStorage] insertAttributedString:[[NSAttributedString alloc] initWithString:aString]
					   atIndex:[self caret]];
}

/* syntax: [buffer][count]P */
- (void)put_before:(ViCommand *)command
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if([buffer length] == 0)
	{
		NSLog(@"The default buffer is empty");
		return;
	}

	[self insertString:buffer];
	NSLog(@"put_before: adjusting caret to location %lu", command.start_range.location);
	[self setCaret:command.start_range.location];
}

/* syntax: [buffer][count]p */
- (void)put_after:(ViCommand *)command
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if([buffer length] == 0)
	{
		NSLog(@"The default buffer is empty");
		return;
	}

	[self move_right:command];
	NSUInteger loc = [self caret];
	[self insertString:buffer];
	// reset caret position
	[self setCaret:loc];
}

/* syntax: [buffer][count]c[count]motion */
- (void)change:(ViCommand *)command
{
	[self delete:command];
	[self setInsertMode];
}

/* syntax: i */
- (void)insert:(ViCommand *)command
{
	[self setInsertMode];
}

/* syntax: [count]h */
- (void)move_left:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSUInteger caret = [self caret];
	NSUInteger bol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:NULL forRange:NSMakeRange(caret, 0)];
	if(caret > bol)
		[self setCaret:caret - 1];
}

/* syntax: [count]l */
- (void)move_right:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSUInteger caret = [self caret];
	NSUInteger bol, eol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(caret ,0)];
	if(caret + 1 < eol)
		[self setCaret:caret + 1];
}

- (void)gotoColumn:(NSUInteger)column fromRange:(NSRange)aRange
{
	NSUInteger bol, eol;
	NSTextStorage *text = [self textStorage];
	[[text string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:aRange];
	if(eol - bol > column)
		aRange.location = bol + column;
	else if(eol - bol > 1)
		aRange.location = eol - 1;
	else
		aRange.location = bol;
	[self setCaret:aRange.location];
}

/* syntax: [count]k */
- (void)move_up:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSRange sel = [self selectedRange];
	NSUInteger bol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:NULL forRange:sel];
	if(bol > 0)
	{
		NSUInteger column = sel.location - bol;
		// previous line:
		sel.location = bol - 1;
		[self gotoColumn:column fromRange:sel];
		[self scrollRangeToVisible:sel];
	}
}

/* syntax: [count]j */
- (void)move_down:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSRange sel = [self selectedRange];
	NSUInteger bol, end;
	[[text string] getLineStart:&bol end:&end contentsEnd:NULL forRange:sel];
	if(end < [[text string] length])
	{
		NSUInteger column = sel.location - bol;
		// next line:
		sel.location = end;
		[self gotoColumn:column fromRange:sel];
		[self scrollRangeToVisible:sel];
	}
}

/* syntax: 0 */
- (void)move_bol:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSRange sel = [self selectedRange];
	NSUInteger bol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:NULL forRange:sel];
	[self setCaret:bol];
}

/* syntax: $ */
- (void)move_eol:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	if([[text string] length] == 0)
		return;
	NSRange sel = [self selectedRange];
	NSUInteger bol, eol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:sel];
	[self setCaret:IMAX(bol, eol - command.ismotion)];
}

/* syntax: [count]a */
- (void)append:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSUInteger caret = [self caret];
	NSUInteger bol, eol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(caret, 0)];
	if(caret < eol)
		[self setCaret:caret + 1];
	[self setInsertMode];
}

/* syntax: [count]A */
- (void)append_eol:(ViCommand *)command
{
	[self move_eol:command];
	[self append:command];
}

/* syntax: o */
- (void)open_line_below:(ViCommand *)command
{
	[self setInsertMode];
	NSTextStorage *text = [self textStorage];
	NSRange sel = [self selectedRange];
	NSUInteger end;
	[[text string] getLineStart:NULL end:&end contentsEnd:NULL forRange:sel];
	[self setCaret:end];
	[self insertNewline:self];
	[self setCaret:end];
}

/* syntax: O */
- (void)open_line_above:(ViCommand *)command
{
	[self setInsertMode];
	NSTextStorage *text = [self textStorage];
	NSRange sel = [self selectedRange];
	NSUInteger bol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:NULL forRange:sel];
	[self setCaret:bol];
	[self insertNewline:self];
	[self setCaret:bol];
}

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet fromLocation:(NSUInteger)startLocation
{
	NSString *s = [[self textStorage] string];
	NSRange r = [s rangeOfCharacterFromSet:[characterSet invertedSet]
				       options:0
					 range:NSMakeRange(startLocation, [s length] - startLocation)];
	return r.location;
}

- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation
{
	return [self skipCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
			    fromLocation:startLocation];
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
- (void)word_forward:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSString *s = [text string];
	if([s length] == 0)
		return;
	NSUInteger location = command.start_range.location;
	unichar ch = [s characterAtIndex:location];

	NSMutableCharacterSet *wordSet = [NSCharacterSet characterSetWithCharactersInString:@"_"];
	[wordSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	if([wordSet characterIsMember:ch])
	{
		// skip word-chars and whitespace
		location = [self skipCharactersInSet:wordSet fromLocation:location];
	}
	else if(![whitespace characterIsMember:ch])
	{
		// inside non-word-chars
		[wordSet formUnionWithCharacterSet:whitespace];
		NSRange r = [s rangeOfCharacterFromSet:wordSet
					       options:0
						 range:NSMakeRange(location, [s length] - location)];
		location = r.location;
	}
	else if(!command.ismotion && command.key != 'd' && command.key != 'y')
	{
		/* We're in whitespace. */
		/* See comment from nvi below. */
		location++;
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
		location = [self skipWhitespaceFrom:location];

	if(!command.ismotion && (command.key == 'd' || command.key == 'y'))
	{
		/* Restrict to current line if deleting/yanking last word on line.
		 * However, an empty line can be deleted as a word.
		 */
		NSUInteger bol, eol;
		[s getLineStart:&bol end:NULL contentsEnd:&eol forRange:command.start_range];
		if(location > eol && bol != eol)
		{
			NSLog(@"adjusting location from %lu to %lu at EOL", location, eol);
			location = eol;
		}
	}
	else if(location >= [s length])
		location = [s length] - 1;
	[self setCaret:location];
}

/* syntax: [count]I */
- (void)insert_bol:(ViCommand *)command
{
	[self insert:command];

	NSTextStorage *text = [self textStorage];
	NSString *s = [text string];
	if([s length] == 0)
		return;
	NSRange sel = [self selectedRange];
	NSUInteger bol, eol;
	[s getLineStart:&bol end:NULL contentsEnd:&eol forRange:sel];

	unichar ch = [s characterAtIndex:bol];
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	if([whitespace characterIsMember:ch])
	{
		// skip leading whitespace
		// FIXME: refactor, new method skipWhitespaceFrom:to:
		NSCharacterSet *nonWhitespace = [whitespace invertedSet];
		NSRange r = [s rangeOfCharacterFromSet:nonWhitespace
					       options:0
						 range:NSMakeRange(bol, eol - bol)];
		if(r.location == NSNotFound)
			sel.location = eol;
		else
			sel.location = r.location;
	}
	else
		sel.location = bol;
	[self setCaret:sel.location];
}

/* syntax: [count]x */
- (void)delete_forward:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSString *s = [text string];
	if([s length] == 0)
		return;
	NSUInteger caret = [self caret];
	NSUInteger bol, eol;
	[s getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(caret, 0)];
	if(bol == eol)
	{
		NSLog(@"no characters to delete");
		return;
	}

	NSRange del;
	del.location = caret;
	del.length = IMAX(1, command.count);
	if(del.location + del.length > eol)
		del.length = eol - del.location;
	[text deleteCharactersInRange:del];

	// correct caret position if we deleted the last character on the line
	--eol;
	if(caret == eol && eol > bol)
	{
		--caret;
		[self setCaret:caret];
	}
}

/* syntax: [count]X */
- (void)delete_backward:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSString *s = [text string];
	if([s length] == 0)
		return;
	NSUInteger caret = [self caret];
	NSUInteger bol;
	[s getLineStart:&bol end:NULL contentsEnd:NULL forRange:NSMakeRange(caret, 0)];
	if(caret == bol)
	{
		NSLog(@"Already in the first column");
		return;
	}
	NSRange del;
	del.location = IMAX(bol, caret - IMAX(1, command.count));
	del.length = caret - del.location;
	[text deleteCharactersInRange:del];
	[self setCaret:del.location];
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
	[self updateInsertionPoint];
}

- (void)setInsertMode
{
	mode = ViInsertMode;
	[self updateInsertionPoint];
}

- (void)evaluateCommand:(ViCommand *)command
{
	/* default start-range is the current location */
	command.start_range = [self selectedRange];

	if(command.motion_method)
	{
		/* The command has an associated motion component.
		 * Run the motion method and record the start and
		 * stop ranges.
		 */
		/* if no count is given, act as if it were 1 */
		//if(parser.motion_count == 0)
		//	parser.motion_count = 1;
		NSString *motionMethodSignature = [NSString stringWithFormat:@"%@:", command.motion_method];
		// NSLog(@"executing motion-method '%@'", command.motion_method);
		[self performSelector:NSSelectorFromString(motionMethodSignature) withObject:command];
		command.stop_range = [self selectedRange];

		NSUInteger l1 = command.start_range.location, l2 = command.stop_range.location;
		if(l2 < l1)
		{
			l2 = l1;
			l1 = command.stop_range.location;
		}
		affectedRange = NSMakeRange(l1, l2 - l1);
	}

	NSString *methodSignature = [NSString stringWithFormat:@"%@:", command.method];
	// NSLog(@"executing method '%@'", command.method);
	[self performSelector:NSSelectorFromString(methodSignature) withObject:command];

	// NSRange selend = [self selectedRange];
	// NSLog(@"sel.location: %i -> %i", command.start_range.location, selend.location);

	final_location = [self caret];

	[command reset];
}

- (void)keyDown:(NSEvent *)theEvent
{
	unichar charcode = [[theEvent characters] characterAtIndex:0];
#if 1
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
			[self move_left:nil];
		}
		else
		{
			NSLog(@"passing key to super: %C", charcode);
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

@end
