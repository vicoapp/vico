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
	storage = [self textStorage];
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

- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr forLocation:(NSUInteger)aLocation
{
	[[storage string] getLineStart:bol_ptr end:end_ptr contentsEnd:eol_ptr forRange:NSMakeRange(aLocation, 0)];
}

- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr
{
	[self getLineStart:bol_ptr end:end_ptr contentsEnd:eol_ptr forLocation:start_location];
}

- (void)current_line:(ViCommand *)command
{
	[self getLineStart:&start_location end:&end_location contentsEnd:NULL];
}

/* syntax: [buffer][count]d[count]motion */
- (void)delete:(ViCommand *)command
{
	// need beginning of line for correcting caret position after deletion
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];

	[storage deleteCharactersInRange:affectedRange];

#if 0
	if([command.motion_method isEqualToString:@"current_line"])
		end_location = affectedRange.location;
#endif

	// correct caret position if we deleted the last character(s) on the line
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:bol];
	if(affectedRange.location >= eol)
		end_location = IMAX(bol, eol - 1);
	else
		end_location = affectedRange.location;
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

	NSString *s = [storage string];
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
	end_location = affectedRange.location;
}

/* Like insertText:, but works within beginEditing/endEditing
 */
- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation
{
	[storage insertAttributedString:[[NSAttributedString alloc] initWithString:aString]
				atIndex:aLocation];
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

	[self insertString:buffer atLocation:start_location];
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

	[self move_right:command]; // sets end_location
	[self insertString:buffer atLocation:end_location];
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
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if(start_location > bol)
		end_location = start_location - 1;
}

/* syntax: [count]l */
- (void)move_right:(ViCommand *)command
{
	NSUInteger eol;
	[self getLineStart:NULL end:NULL contentsEnd:&eol];
	if(start_location + 1 < eol)
		end_location = start_location + 1;
}

- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:aLocation];
	if(eol - bol > column)
		end_location = bol + column;
	else if(eol - bol > 1)
		end_location = eol - 1;
	else
		end_location = bol;
}

/* syntax: [count]k */
- (void)move_up:(ViCommand *)command
{
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if(bol > 0)
	{
		NSUInteger column = start_location - bol;
		end_location = bol - 1; // previous line
		[self gotoColumn:column fromLocation:end_location];
		[self scrollRangeToVisible:NSMakeRange(end_location, 0)];
	}
}

/* syntax: [count]j */
- (void)move_down:(ViCommand *)command
{
	NSUInteger bol, end;
	[self getLineStart:&bol end:&end contentsEnd:NULL];
	if(end < [[storage string] length])
	{
		NSUInteger column = start_location - bol;
		end_location = end; // next line
		[self gotoColumn:column fromLocation:end_location];
		[self scrollRangeToVisible:NSMakeRange(end_location, 0)];
	}
}

/* syntax: 0 */
- (void)move_bol:(ViCommand *)command
{
	[self getLineStart:&end_location end:NULL contentsEnd:NULL];
}

/* syntax: $ */
- (void)move_eol:(ViCommand *)command
{
	if([[storage string] length] == 0)
		return;
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	end_location = IMAX(bol, eol - command.ismotion);
}

/* syntax: [count]a */
- (void)append:(ViCommand *)command
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if(start_location < eol)
		end_location = start_location + 1;
	[self setInsertMode];
}

/* syntax: [count]A */
- (void)append_eol:(ViCommand *)command
{
	[self move_eol:command];
	start_location = end_location;
	[self append:command];
}

/* syntax: o */
- (void)open_line_below:(ViCommand *)command
{
	[self getLineStart:NULL end:&end_location contentsEnd:NULL];
	[self insertString:@"\n" atLocation:end_location];
	[self setInsertMode];
}

/* syntax: O */
- (void)open_line_above:(ViCommand *)command
{
	[self setInsertMode];
	[self getLineStart:&end_location end:NULL contentsEnd:NULL];
	[self insertString:@"\n" atLocation:end_location];
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
	NSString *s = [storage string];
	if([s length] == 0)
		return;
	unichar ch = [s characterAtIndex:start_location];

	NSMutableCharacterSet *wordSet = [NSCharacterSet characterSetWithCharactersInString:@"_"];
	[wordSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	if([wordSet characterIsMember:ch])
	{
		// skip word-chars and whitespace
		end_location = [self skipCharactersInSet:wordSet fromLocation:start_location];
	}
	else if(![whitespace characterIsMember:ch])
	{
		// inside non-word-chars
		[wordSet formUnionWithCharacterSet:whitespace];
		NSRange r = [s rangeOfCharacterFromSet:wordSet
					       options:0
						 range:NSMakeRange(start_location, [s length] - start_location)];
		end_location = r.location;
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
}

/* syntax: [count]I */
- (void)insert_bol:(ViCommand *)command
{
	[self insert:command];

	NSString *s = [storage string];
	if([s length] == 0)
		return;
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];

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
			end_location = eol;
		else
			end_location = r.location;
	}
	else
		end_location = bol;
}

/* syntax: [count]x */
- (void)delete_forward:(ViCommand *)command
{
	NSString *s = [storage string];
	if([s length] == 0)
		return;
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	if(bol == eol)
	{
		NSLog(@"no characters to delete");
		return;
	}

	NSRange del;
	del.location = start_location;
	del.length = IMAX(1, command.count);
	if(del.location + del.length > eol)
		del.length = eol - del.location;
	[storage deleteCharactersInRange:del];

	// correct caret position if we deleted the last character(s) on the line
	end_location = start_location;
	--eol;
	if(end_location == eol && eol > bol)
		--end_location;
}

/* syntax: [count]X */
- (void)delete_backward:(ViCommand *)command
{
	NSString *s = [storage string];
	if([s length] == 0)
		return;
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL];
	if(start_location == bol)
	{
		NSLog(@"Already in the first column");
		return;
	}
	NSRange del;
	del.location = IMAX(bol, start_location - IMAX(1, command.count));
	del.length = start_location - del.location;
	[storage deleteCharactersInRange:del];
	end_location = del.location;
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
	start_location = [self caret];
	end_location = start_location;
	final_location = NSNotFound;

	if(command.motion_method)
	{
		/* The command has an associated motion component.
		 * Run the motion method and record the start and
		 * stop ranges.
		 */
		/* if no count is given, act as if it were 1 */
		//if(parser.motion_count == 0)
		//	parser.motion_count = 1;
		[self performSelector:NSSelectorFromString(command.motion_method) withObject:command];

		NSUInteger l1 = start_location, l2 = end_location;
		if(l2 < l1)
		{
			l2 = l1;
			l1 = end_location;
		}
		affectedRange = NSMakeRange(l1, l2 - l1);
	}

	[self performSelector:NSSelectorFromString(command.method) withObject:command];
	final_location = end_location;
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
			start_location = [self caret];
			[self move_left:nil];
			[self setCaret:end_location];
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
