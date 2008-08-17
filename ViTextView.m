#import "ViTextView.h"

#ifdef IMAX
# undef IMAX
#endif
#define IMAX(a, b)  (((NSInteger)a) > ((NSInteger)b) ? (a) : (b))

@implementation ViTextView

+ (void)initKeymaps
{
}

- (void)initEditor
{
	NSFont *font = [NSFont userFixedPitchFontOfSize:12.0];
	[self setFont:font];
	[self setSelectedRange:NSMakeRange(0, 0)];	
	[self setInsertionPointColor:[NSColor colorWithCalibratedRed:0.2
		green:0.2
		blue:0.2
		alpha:0.5]];

	[[self textStorage] setDelegate:self];

	parser = [[ViCommand alloc] init];
}

- (void)illegal:(ViCommand *)command
{
	NSLog(@"? is not a vi command");
}

- (void)nonmotion:(ViCommand *)command
{
	NSLog(@"X may not be used as a motion command");
}

- (void)current_line:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSUInteger bol, end;
	[[text string] getLineStart:&bol end:&end contentsEnd:NULL forRange:command.start_range];
	command.start_range = NSMakeRange(bol, 0);
	[self setSelectedRange:NSMakeRange(end, 0)];
	NSLog(@"selecting current line: %lu -> %lu", bol, end);
}

/* syntax: [buffer][count]d[count]motion */
- (void)delete:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];

	// need beginning of line for correcting cursor position after deletion
	NSUInteger bol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:NULL forRange:command.start_range];

	NSRange range = NSMakeRange(command.start_range.location, command.stop_range.location - command.start_range.location);
	[text deleteCharactersInRange:range];

	// correct cursor position if we deleted the last character(s) on the line
	NSUInteger eol;
	[[text string] getLineStart:NULL end:NULL contentsEnd:&eol forRange:NSMakeRange(bol, 0)];
	if(command.start_range.location >= eol)
	{
		NSRange loc = NSMakeRange(IMAX(bol, eol - 1), 0);
		[self setSelectedRange:loc];
	}
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
	NSLog(@"entering insert mode");
	[self setInsertMode];
}

/* syntax: [count]h */
- (void)move_left:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSRange sel = [self selectedRange];
	NSUInteger bol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:NULL forRange:sel];
	if(sel.location > bol)
		[self setSelectedRange:NSMakeRange(sel.location - 1, 0)];
}

/* syntax: [count]l */
- (void)move_right:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSRange sel = [self selectedRange];
	NSUInteger bol, eol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:sel];
	if(sel.location + 1 < eol)
		[self setSelectedRange:NSMakeRange(sel.location + 1, 0)];
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
	[self setSelectedRange:NSMakeRange(aRange.location, 0)];
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
	[self setSelectedRange:NSMakeRange(bol, 0)];
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
	[self setSelectedRange:NSMakeRange(IMAX(bol, eol - 1), 0)];
}

/* syntax: [count]a */
- (void)append:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSRange sel = [self selectedRange];
	NSUInteger bol, eol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:sel];
	if(sel.location < eol)
		[self setSelectedRange:NSMakeRange(sel.location + 1, 0)];
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
	[self setSelectedRange:NSMakeRange(end, 0)];
	[self insertNewline:self];
	[self setSelectedRange:NSMakeRange(end, 0)];
}

/* syntax: O */
- (void)open_line_above:(ViCommand *)command
{
	[self setInsertMode];
	NSTextStorage *text = [self textStorage];
	NSRange sel = [self selectedRange];
	NSUInteger bol;
	[[text string] getLineStart:&bol end:NULL contentsEnd:NULL forRange:sel];
	[self setSelectedRange:NSMakeRange(bol, 0)];
	[self insertNewline:self];
	[self setSelectedRange:NSMakeRange(bol, 0)];
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

/* if cursor on word-char:
 *      skip word-chars
 *      skip whitespace
 * else if cursor on whitespace:
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
	else if(command.motion_method && command.key != 'd' && command.key != 'y')
	{
		/* We're in whitespace. */
		/* See command from nvi below. */
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
	if(command.motion_method == nil || command.key == 'd' || command.key == 'y')
		location = [self skipWhitespaceFrom:location];

	if(command.motion_method && (command.key == 'd' || command.key == 'y'))
	{
		/* restrict to current line if deleting/yanking last word on line */
		NSUInteger eol;
		[s getLineStart:NULL end:NULL contentsEnd:&eol forRange:command.start_range];
		if(location > eol)
			location = eol;
	}

	if(location >= [s length])
		location = [s length] - 1;
	[self setSelectedRange:NSMakeRange(location, 0)];
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
	[self setSelectedRange:sel];
}

/* syntax: [count]x */
- (void)delete_forward:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSString *s = [text string];
	if([s length] == 0)
		return;
	NSRange sel = [self selectedRange];
	NSUInteger bol, eol;
	[s getLineStart:&bol end:NULL contentsEnd:&eol forRange:sel];
	if(bol == eol)
	{
		NSLog(@"no characters to delete");
		return;
	}

	NSRange del;
	del.location = sel.location;
	del.length = IMAX(1, command.count);
	if(del.location + del.length > eol)
		del.length = eol - del.location;
	[text deleteCharactersInRange:del];

	// correct cursor position if we deleted the last character on the line
	--eol;
	if(sel.location == eol && eol > bol)
	{
		--sel.location;
		sel.length = 0;
		[self setSelectedRange:sel];
	}
}

/* syntax: [count]X */
- (void)delete_backward:(ViCommand *)command
{
	NSTextStorage *text = [self textStorage];
	NSString *s = [text string];
	if([s length] == 0)
		return;
	NSRange sel = [self selectedRange];
	NSUInteger bol;
	[s getLineStart:&bol end:NULL contentsEnd:NULL forRange:sel];
	if(sel.location == bol)
	{
		NSLog(@"Already in the first column");
		return;
	}
	NSRange del;
	del.location = IMAX(bol, sel.location - IMAX(1, command.count));
	del.length = sel.location - del.location;
	[text deleteCharactersInRange:del];
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
	}
	
	NSString *methodSignature = [NSString stringWithFormat:@"%@:", command.method];
	// NSLog(@"executing method '%@'", command.method);
	[self performSelector:NSSelectorFromString(methodSignature) withObject:command];
	
	NSRange selend = [self selectedRange];
	// NSLog(@"sel.location: %i -> %i", command.start_range.location, selend.location);

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
			[self evaluateCommand:parser];
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
