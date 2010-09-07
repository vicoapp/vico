#import "ViTextView.h"
#import "ViLanguageStore.h"
#import "ViThemeStore.h"
#import "ViDocument.h"  // for declaration of the message: method
#import "NSString-scopeSelector.h"
#import "NSArray-patterns.h"
#import "ExCommand.h"
#import "ViAppController.h"  // for sharedBuffers
#import "ViDocumentView.h"
#import "ViJumpList.h"
#import "NSTextStorage-additions.h"

int logIndent = 0;

@interface ViTextView (private)
- (BOOL)move_right:(ViCommand *)command;
- (void)disableWrapping;
- (BOOL)insert:(ViCommand *)command;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation toLocation:(NSUInteger)toLocation;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation;
- (void)recordInsertInRange:(NSRange)aRange;
- (void)recordDeleteOfRange:(NSRange)aRange;
- (void)recordDeleteOfString:(NSString *)aString atLocation:(NSUInteger)aLocation;
- (void)recordReplacementOfRange:(NSRange)aRange withLength:(NSUInteger)aLength;
- (NSArray *)smartTypingPairsAtLocation:(NSUInteger)aLocation;
- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation undoGroup:(BOOL)undoGroup;
@end

#pragma mark -

@implementation ViTextView

- (void)initEditorWithDelegate:(id)aDelegate documentView:(ViDocumentView *)docView
{
	[self setDelegate:aDelegate];
	[self setCaret:0];

	documentView = docView;
	undoManager = [[self delegate] undoManager];
	if (undoManager == nil)
		undoManager = [[NSUndoManager alloc] init];
	parser = [[ViCommand alloc] init];
	buffers = [[NSApp delegate] sharedBuffers];
	inputKeys = [[NSMutableArray alloc] init];
	marks = [[NSMutableDictionary alloc] init];
	saved_column = -1;

	wordSet = [NSCharacterSet characterSetWithCharactersInString:@"_"];
	[wordSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	inputCommands = [NSDictionary dictionaryWithObjectsAndKeys:
			 @"input_newline:", [NSNumber numberWithUnsignedInteger:0x00000024], // enter
			 @"input_newline:", [NSNumber numberWithUnsignedInteger:0x0004002e], // ctrl-m
			 @"input_newline:", [NSNumber numberWithUnsignedInteger:0x00040026], // ctrl-j
			 @"increase_indent:", [NSNumber numberWithUnsignedInteger:0x00040011], // ctrl-t
			 @"decrease_indent:", [NSNumber numberWithUnsignedInteger:0x00040002], // ctrl-d
			 @"input_backspace:", [NSNumber numberWithUnsignedInteger:0x00000033], // backspace
			 @"input_backspace:", [NSNumber numberWithUnsignedInteger:0x00040004], // ctrl-h
			 @"input_forward_delete:", [NSNumber numberWithUnsignedInteger:0x00800075], // delete
			 @"input_tab:", [NSNumber numberWithUnsignedInteger:0x00000030], // tab
			 nil];
	
	normalCommands = [NSDictionary dictionaryWithObjectsAndKeys:
			  /*
			  @"switch_tab:", [NSNumber numberWithUnsignedInteger:0x00100012], // command-1
			  @"switch_tab:", [NSNumber numberWithUnsignedInteger:0x00100013], // command-2
			  @"switch_tab:", [NSNumber numberWithUnsignedInteger:0x00100014], // command-3
			  @"switch_tab:", [NSNumber numberWithUnsignedInteger:0x00100015], // command-4
			  @"switch_tab:", [NSNumber numberWithUnsignedInteger:0x00100017], // command-5
			  @"switch_tab:", [NSNumber numberWithUnsignedInteger:0x00100016], // command-6
			  @"switch_tab:", [NSNumber numberWithUnsignedInteger:0x0010001A], // command-7
			  @"switch_tab:", [NSNumber numberWithUnsignedInteger:0x0010001C], // command-8
			  @"switch_tab:", [NSNumber numberWithUnsignedInteger:0x00100019], // command-9
			  */
			  @"switch_file:", [NSNumber numberWithUnsignedInteger:0x0004001E], // ctrl-^
			  @"show_scope:", [NSNumber numberWithUnsignedInteger:0x00060023], // ctrl-shift-p
			 nil];
	
	nonWordSet = [[NSMutableCharacterSet alloc] init];
	[nonWordSet formUnionWithCharacterSet:wordSet];
	[nonWordSet formUnionWithCharacterSet:whitespace];
	[nonWordSet invert];

	[self setRichText:NO];
	[self setImportsGraphics:NO];
//	[self setUsesFontPanel:NO];
//	[self setUsesFindPanel:NO];
	//[self setPageGuideValues];
	[self disableWrapping];
//	[self setContinuousSpellCheckingEnabled:NO];
	// [[self layoutManager] setShowsInvisibleCharacters:YES];
	[[self layoutManager] setShowsControlCharacters:YES];
	[self setDrawsBackground:YES];

	[self setTheme:[[ViThemeStore defaultStore] defaultTheme]];
	[self resetTypingAttributes];
}

- (void)setString:(NSString *)aString
{
	[[[self textStorage] mutableString] setString:aString ?: @""];
	[[self textStorage] addAttribute:NSFontAttributeName value:[self font] range:NSMakeRange(0, [[self textStorage] length])];
	[self setCaret:0];
}

- (void)paste:(id)sender
{
	NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
	[pasteBoard types];
	NSString *string = [pasteBoard stringForType:NSStringPboardType];	
	if ([string length] > 0) {
		[self insertString:string atLocation:[self caret] undoGroup:NO];

		NSUInteger eol;
		[self getLineStart:NULL end:NULL contentsEnd:&eol forLocation:[self caret]];
		if ([self caret] + [string length] >= eol && mode == ViNormalMode)
			[self setCaret:eol - 1];
		else
			[self setCaret:[self caret] + [string length]];
	}
}

- (ViDocument *)document
{
        return [documentView document];
}

- (id <ViTextViewDelegate>)delegate
{
	return (id <ViTextViewDelegate>)[super delegate];
}

#pragma mark -
#pragma mark Vi error messages

- (BOOL)illegal:(ViCommand *)command
{
	[[self delegate] message:@"%C isn't a vi command", command.key];
	return NO;
}

- (BOOL)nonmotion:(ViCommand *)command
{
	[[self delegate] message:@"%C may not be used as a motion command", command.motion_key];
	return NO;
}

- (BOOL)nodot:(ViCommand *)command
{
	[[self delegate] message:@"No command to repeat"];
	return NO;
}

- (BOOL)no_previous_ftFT:(ViCommand *)command
{
	[[self delegate] message:@"No previous F, f, T or t search"];
	return NO;
}

#pragma mark -
#pragma mark Convenience methods

- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr forLocation:(NSUInteger)aLocation
{
	[[[self textStorage] string] getLineStart:bol_ptr end:end_ptr contentsEnd:eol_ptr forRange:NSMakeRange(aLocation, 0)];
}

- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr
{
	[self getLineStart:bol_ptr end:end_ptr contentsEnd:eol_ptr forLocation:start_location];
}


/* Like insertText:, but works within beginEditing/endEditing.
 * Also begins an undo group.
 */
- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation undoGroup:(BOOL)undoGroup
{
	if ([aString length] == 0)
		return;

	NSRange range = NSMakeRange(aLocation, [aString length]);

	if ([self delegate] != nil && [[self delegate] textView:self shouldChangeTextInRange:range replacementString:aString] == NO)
		return;

	if (undoGroup)
		[self beginUndoGroup];
	NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:aString attributes:[self typingAttributes]];
	[[self textStorage] insertAttributedString:attrString atIndex:aLocation];
	[self recordInsertInRange:range];

	if (activeSnippet)
	{
		if ([activeSnippet activeInRange:range])
		{
			INFO(@"found snippet %@ at %u", activeSnippet, aLocation - 1);
			if ([activeSnippet insertString:aString atLocation:aLocation] == NO)
			{
				INFO(@"insertion failed, cancelling snippet %@", activeSnippet);
				[self cancelSnippet:activeSnippet];
			}
		}
		else
		{
			INFO(@"outside active range, cancelling snippet %@", activeSnippet);
			[self cancelSnippet:activeSnippet];
		}
	}
}

- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation
{
	[self insertString:aString atLocation:aLocation undoGroup:YES];
}

- (void)deleteRange:(NSRange)aRange undoGroup:(BOOL)undoGroup
{
	DEBUG(@"undo in range %@", NSStringFromRange(aRange));

	if (aRange.length == 0)
		return;

	if ([self delegate] != nil && [[self delegate] textView:self shouldChangeTextInRange:aRange replacementString:nil] == NO)
		return;

	if (undoGroup)
		[self beginUndoGroup];
	[self recordDeleteOfRange:aRange];
	[[self textStorage] deleteCharactersInRange:aRange];

	if (activeSnippet) {
		if ([activeSnippet activeInRange:aRange]) {
			INFO(@"found snippet %@ at %u", activeSnippet, aRange.location);
			if ([activeSnippet deleteRange:aRange] == NO) {
				INFO(@"deleting failed, cancelling snippet %@", activeSnippet);
				[self cancelSnippet:activeSnippet];
			}
		} else {
			INFO(@"outside active range, cancelling snippet %@", activeSnippet);
			[self cancelSnippet:activeSnippet];
		}
	}
}

- (void)deleteRange:(NSRange)aRange
{
	[self deleteRange:aRange undoGroup:NO];
}

- (void)replaceRange:(NSRange)aRange withString:(NSString *)aString undoGroup:(BOOL)undoGroup
{
	if (undoGroup)
		[self beginUndoGroup];
#if 0
	[self recordReplacementOfRange:aRange withLength:[aString length]];
	[[[self textStorage] mutableString] replaceCharactersInRange:aRange withString:aString];
#else
	[self deleteRange:aRange undoGroup:NO];
	[self insertString:aString atLocation:aRange.location undoGroup:NO];
#endif
}

- (void)replaceRange:(NSRange)aRange withString:(NSString *)aString
{
	[self replaceRange:aRange withString:aString undoGroup:YES];
}

- (NSString *)lineForLocation:(NSUInteger)aLocation
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:aLocation];
	return [[[self textStorage] string] substringWithRange:NSMakeRange(bol, eol - bol)];
}

- (BOOL)isBlankLineAtLocation:(NSUInteger)aLocation
{
	NSString *line = [self lineForLocation:aLocation];
	return [line rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].location == NSNotFound;
}

- (NSArray *)scopesAtLocation:(NSUInteger)aLocation
{
	return [[self delegate] scopesAtLocation:aLocation];
}

#pragma mark -
#pragma mark Indentation

- (NSString *)indentStringOfLength:(int)length
{
	length = IMAX(length, 0);
	int tabstop = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"expandtab"] == NSOnState)
	{
		// length * " "
		return [@"" stringByPaddingToLength:length withString:@" " startingAtIndex:0];
	}
	else
	{
		// length / tabstop * "tab" + length % tabstop * " "
		int ntabs = (length / tabstop);
		int nspaces = (length % tabstop);
		NSString *indent = [@"" stringByPaddingToLength:ntabs withString:@"\t" startingAtIndex:0];
		return [indent stringByPaddingToLength:ntabs + nspaces withString:@" " startingAtIndex:0];
	}
}

- (NSString *)indentStringForLevel:(int)level
{
	int shiftWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"shiftwidth"] * level;
	return [self indentStringOfLength:shiftWidth * level];
}

- (NSString *)leadingWhitespaceForLineAtLocation:(NSUInteger)aLocation
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:aLocation];
	NSRange lineRange = NSMakeRange(bol, eol - bol);

	NSRange r = [[[self textStorage] string] rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]
						      options:0
							range:lineRange];

	if (r.location == NSNotFound)
                r.location = eol;
	else if (r.location == bol)
		return @"";
	
        return [[[self textStorage] string] substringWithRange:NSMakeRange(lineRange.location, r.location - lineRange.location)];
}

- (int)lengthOfIndentString:(NSString *)indent
{
	int tabStop = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	int i;
	int length = 0;
	for (i = 0; i < [indent length]; i++)
	{
		unichar c = [indent characterAtIndex:i];
		if (c == ' ')
			++length;
		else if (c == '\t')
			length += tabStop;
	}

	return length;
}

- (int)lenghtOfIndentAtLine:(NSUInteger)lineLocation
{
	return [self lengthOfIndentString:[self leadingWhitespaceForLineAtLocation:lineLocation]];
}

- (NSString *)bestMatchingScope:(NSArray *)scopeSelectors atLocation:(NSUInteger)aLocation
{
	NSArray *scopes = [self scopesAtLocation:aLocation];
	NSString *foundScopeSelector = nil;
	NSString *scopeSelector;
	u_int64_t highest_rank = 0;
	for (scopeSelector in scopeSelectors)
	{
		u_int64_t rank = [scopeSelector matchesScopes:scopes];
		if (rank > highest_rank)
		{
			foundScopeSelector = scopeSelector;
			highest_rank = rank;
		}
	}
	
	return foundScopeSelector;
}

- (BOOL)shouldIncreaseIndentAtLocation:(NSUInteger)aLocation
{
	NSDictionary *increaseIndentPatterns = [[ViLanguageStore defaultStore] preferenceItems:@"increaseIndentPattern"];
	NSString *bestMatchingScope = [self bestMatchingScope:[increaseIndentPatterns allKeys] atLocation:aLocation];

	if (bestMatchingScope)
	{
		NSString *pattern = [increaseIndentPatterns objectForKey:bestMatchingScope];
		ViRegexp *rx = [ViRegexp regularExpressionWithString:pattern];
		NSString *checkLine = [self lineForLocation:aLocation];
		if ([rx matchInString:checkLine])
		{
			return YES;
		}
	}
	
	return NO;
}

- (BOOL)shouldDecreaseIndentAtLocation:(NSUInteger)aLocation
{
	NSDictionary *decreaseIndentPatterns = [[ViLanguageStore defaultStore] preferenceItems:@"decreaseIndentPattern"];
	NSString *bestMatchingScope = [self bestMatchingScope:[decreaseIndentPatterns allKeys] atLocation:aLocation];

	if (bestMatchingScope)
	{
		NSString *pattern = [decreaseIndentPatterns objectForKey:bestMatchingScope];
		ViRegexp *rx = [ViRegexp regularExpressionWithString:pattern];
		NSString *checkLine = [self lineForLocation:aLocation];

		if ([rx matchInString:checkLine])
		{
			return YES;
		}
	}
	
	return NO;
}

- (BOOL)shouldNotIndentLineAtLocation:(NSUInteger)aLocation
{
	NSDictionary *unIndentPatterns = [[ViLanguageStore defaultStore] preferenceItems:@"unIndentedLinePattern"];
	NSString *bestMatchingScope = [self bestMatchingScope:[unIndentPatterns allKeys] atLocation:aLocation];

	if (bestMatchingScope)
	{
		NSString *pattern = [unIndentPatterns objectForKey:bestMatchingScope];
		ViRegexp *rx = [ViRegexp regularExpressionWithString:pattern];
		NSString *checkLine = [self lineForLocation:aLocation];

		if ([rx matchInString:checkLine])
		{
			return YES;
		}
	}
	
	return NO;
}

- (int)insertNewlineAtLocation:(NSUInteger)aLocation indentForward:(BOOL)indentForward
{
        NSString *leading_whitespace = [self leadingWhitespaceForLineAtLocation:aLocation];
		
	[self insertString:@"\n" atLocation:aLocation];

        if ([[self layoutManager] temporaryAttribute:ViSmartPairAttributeName
                                    atCharacterIndex:aLocation + 1
                                      effectiveRange:NULL] && aLocation > 0)
        {
		// assumes indentForward
                [self insertString:[NSString stringWithFormat:@"\n%@", leading_whitespace] atLocation:aLocation + 1];
        }

	if (aLocation != 0 && [[NSUserDefaults standardUserDefaults] integerForKey:@"autoindent"] == NSOnState)
	{
		NSUInteger checkLocation = aLocation;
		if (indentForward)
			checkLocation = aLocation - 1;

		if ([self shouldIncreaseIndentAtLocation:checkLocation])
		{
			int shiftWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"shiftwidth"];
			leading_whitespace = [self indentStringOfLength:[self lengthOfIndentString:leading_whitespace] + shiftWidth];
		}

		if (leading_whitespace)
		{
			[self insertString:leading_whitespace atLocation:aLocation + (indentForward ? 1 : 0)];
			return 1 + [leading_whitespace length];
		}
	}

	return 1;
}

- (NSRange)changeIndentation:(int)delta inRange:(NSRange)aRange updateCaret:(NSUInteger *)updatedCaret
{
	int shiftWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"shiftwidth"];
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:aRange.location];

	NSRange delta_offset = NSMakeRange(0, 0);
	BOOL has_delta_offset = NO;

	while (bol < NSMaxRange(aRange)) {
		NSString *indent = [self leadingWhitespaceForLineAtLocation:bol];
		int n = [self lengthOfIndentString:indent];
		NSString *newIndent = [self indentStringOfLength:n + delta * shiftWidth];
	
		NSRange indentRange = NSMakeRange(bol, [indent length]);
		[self replaceRange:indentRange withString:newIndent];

		aRange.length += [newIndent length] - [indent length];
		if (!has_delta_offset)
		{
          		has_delta_offset = YES;
			delta_offset.location = [newIndent length] - [indent length];
                }
		delta_offset.length += [newIndent length] - [indent length];
		if (updatedCaret && *updatedCaret >= indentRange.location)
		{
			NSInteger d = [newIndent length] - [indent length];
			*updatedCaret = IMAX((NSInteger)*updatedCaret + d, bol);
		}

		// get next line
		[self getLineStart:NULL end:&bol contentsEnd:NULL forLocation:bol];
		if (bol == NSNotFound)
			break;
	}

	return delta_offset;
}

- (NSRange)changeIndentation:(int)delta inRange:(NSRange)aRange
{
	return [self changeIndentation:delta inRange:aRange updateCaret:nil];
}

- (void)increase_indent:(NSString *)characters
{
        NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
        NSRange n = [self changeIndentation:+1 inRange:NSMakeRange(bol, IMAX(eol - bol, 1))];
        [self setCaret:start_location + n.location];
}

- (void)decrease_indent:(NSString *)characters
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	NSRange n = [self changeIndentation:-1 inRange:NSMakeRange(bol, eol - bol)];
        [self setCaret:start_location + n.location];
}

#pragma mark -
#pragma mark Undo support

- (void)endUndoGroup
{
	DEBUG(@"Ending undo-group: %@", hasUndoGroup ? @"YES" : @"NO");
	if (hasUndoGroup) {
		[undoManager endUndoGrouping];
		hasUndoGroup = NO;
	}
}

- (void)beginUndoGroup
{
	DEBUG(@"Beginning undo-group: %@", hasUndoGroup ? @"YES" : @"NO");
	if (!hasUndoGroup) {
		[undoManager beginUndoGrouping];
		hasUndoGroup = YES;
	}
}

- (void)undoDeleteOfString:(NSString *)aString atLocation:(NSUInteger)aLocation
{
	[self insertString:aString atLocation:aLocation undoGroup:NO];
	final_location = aLocation;
}

- (void)undoInsertInRange:(NSRange)aRange
{
	DEBUG(@"undoing insert in range %@", NSStringFromRange(aRange));
	[self deleteRange:aRange undoGroup:NO];
	final_location = aRange.location;
}

- (void)recordInsertInRange:(NSRange)aRange
{
	DEBUG(@"pushing insert of text in range %@ onto undo stack", NSStringFromRange(aRange));
	[[undoManager prepareWithInvocationTarget:self] undoInsertInRange:aRange];
	[undoManager setActionName:@"insert text"];
}

- (void)recordDeleteOfString:(NSString *)aString atLocation:(NSUInteger)aLocation
{
	DEBUG(@"pushing delete of [%@] (%p) at %u onto undo stack", aString, aString, aLocation);
	[[undoManager prepareWithInvocationTarget:self] undoDeleteOfString:aString atLocation:aLocation];
	[undoManager setActionName:@"delete text"];
}

- (void)recordDeleteOfRange:(NSRange)aRange
{
	NSString *s = [[[self textStorage] string] substringWithRange:aRange];
	[self recordDeleteOfString:s atLocation:aRange.location];
}

- (void)recordReplacementOfRange:(NSRange)aRange withLength:(NSUInteger)aLength
{
	DEBUG(@"recording replacement in range %@ with length %u in an undo group", NSStringFromRange(aRange), aLength);
	[undoManager beginUndoGrouping];
	[self recordDeleteOfRange:aRange];
	[self recordInsertInRange:NSMakeRange(aRange.location, aLength)];
	[undoManager endUndoGrouping];
}

#pragma mark -
#pragma mark Buffers

- (void)yankToBuffer:(unichar)bufferName
              append:(BOOL)appendFlag
               range:(NSRange)yankRange
{
	// get the unnamed buffer
	NSMutableString *buffer = [buffers objectForKey:@"unnamed"];
	if (buffer == nil)
	{
		buffer = [[NSMutableString alloc] init];
		[buffers setObject:buffer forKey:@"unnamed"];
	}

	[buffer setString:[[[self textStorage] string] substringWithRange:yankRange]];
}

- (void)cutToBuffer:(unichar)bufferName
             append:(BOOL)appendFlag
              range:(NSRange)cutRange
{
	[self yankToBuffer:bufferName append:appendFlag range:cutRange];
	[self deleteRange:cutRange undoGroup:YES];
}

#pragma mark -
#pragma mark Convenience methods

- (NSUInteger)locationForColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:aLocation];
	NSUInteger c = 0, i;
	int ts = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	for (i = bol; i < eol; i++)
	{
		unichar ch = [[[self textStorage] string] characterAtIndex:i];
		if (ch == '\t')
			c += ts - (c % ts);
		else
			c++;
		if (c >= column)
			break;
	}
	if (mode != ViInsertMode && i == eol)
		i = IMAX(bol, eol - 1);
	return i;
}

- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation
{
	final_location = end_location = [self locationForColumn:column fromLocation:aLocation];
}

- (void)gotoLine:(NSUInteger)line column:(NSUInteger)column
{
	NSInteger bol = [[self textStorage] locationForStartOfLine:line];
	if(bol != -1)
	{
		[self gotoColumn:column fromLocation:bol];
		[self setCaret:final_location];
		[self scrollRangeToVisible:NSMakeRange(final_location, 0)];
	}
}

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet from:(NSUInteger)startLocation to:(NSUInteger)toLocation backward:(BOOL)backwardFlag
{
	NSString *s = [[self textStorage] string];
	NSRange r = [s rangeOfCharacterFromSet:[characterSet invertedSet]
				       options:backwardFlag ? NSBackwardsSearch : 0
					 range:backwardFlag ? NSMakeRange(toLocation, startLocation - toLocation + 1) : NSMakeRange(startLocation, toLocation - startLocation)];
	if (r.location == NSNotFound)
		return backwardFlag ? toLocation : toLocation; // FIXME: this is strange...
	return r.location;
}

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet fromLocation:(NSUInteger)startLocation backward:(BOOL)backwardFlag
{
	return [self skipCharactersInSet:characterSet
				    from:startLocation
				      to:backwardFlag ? 0 : [[self textStorage] length]
				backward:backwardFlag];
}

- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation toLocation:(NSUInteger)toLocation
{
	return [self skipCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
				    from:startLocation
				      to:toLocation
				backward:NO];
}

- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation
{
	return [self skipCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
			    fromLocation:startLocation
				backward:NO];
}

#pragma mark -
#pragma mark Ex command support

- (void)parseAndExecuteExCommand:(NSString *)exCommandString
{
	if ([exCommandString length] > 0)
	{
		ExCommand *ex = [[ExCommand alloc] initWithString:exCommandString];
		//DEBUG(@"got ex [%@], command = [%@], method = [%@]", ex, ex.command, ex.method);
		if (ex.command == NULL)
			[[self delegate] message:@"The %@ command is unknown.", ex.name];
		else
		{
			SEL selector = NSSelectorFromString([NSString stringWithFormat:@"%@:", ex.command->method]);
			if ([self respondsToSelector:selector])
				[self performSelector:selector withObject:ex];
			else
				[[self delegate] message:@"The %@ command is not implemented.", ex.name];
		}
	}
}

- (BOOL)ex_command:(ViCommand *)command
{
	[[self delegate] getExCommandForTextView:self selector:@selector(parseAndExecuteExCommand:)];
	return YES;
}

#pragma mark -
#pragma mark Searching

- (void)highlightFindMatch:(ViRegexpMatch *)match
{
	[self showFindIndicatorForRange:[match rangeOfMatchedString]];
}

- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(int)regexpSyntax
{
	unsigned rx_options = ONIG_OPTION_NOTBOL | ONIG_OPTION_NOTEOL;
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"ignorecase"] == NSOnState)
		rx_options |= ONIG_OPTION_IGNORECASE;

	ViRegexp *rx = nil;

	/* compile the pattern regexp */
	@try
	{
		rx = [ViRegexp regularExpressionWithString:pattern
						   options:rx_options
						    syntax:regexpSyntax];
	}
	@catch(NSException *exception)
	{
		INFO(@"***** FAILED TO COMPILE REGEXP ***** [%@], exception = [%@]", pattern, exception);
		[[self delegate] message:@"Invalid search pattern: %@", exception];
		return NO;
	}

	[[NSApp delegate] setLastSearchPattern:pattern];

	NSArray *foundMatches = [rx allMatchesInString:[[self textStorage] string] options:rx_options];

	if ([foundMatches count] == 0) {
		[[self delegate] message:@"Pattern not found"];
	} else {
		ViRegexpMatch *match, *nextMatch = nil;
		for (match in foundMatches) {
			NSRange r = [match rangeOfMatchedString];
			if (find_options == 0) {
				if (nextMatch == nil && r.location > start_location) {
					nextMatch = match;
					break;
				}
			} else if (r.location < start_location) {
				nextMatch = match;
			}
		}

		if (nextMatch == nil) {
			if (find_options == 0)
				nextMatch = [foundMatches objectAtIndex:0];
			else
				nextMatch = [foundMatches lastObject];

			[[self delegate] message:@"Search wrapped"];
		}

		if (nextMatch) {
			NSRange r = [nextMatch rangeOfMatchedString];
			[self scrollRangeToVisible:r];
			final_location = end_location = r.location;
			[self setCaret:final_location];
			[self performSelector:@selector(highlightFindMatch:)
				   withObject:nextMatch
				   afterDelay:0];
		}

		return YES;
	}

	return NO;
}

- (BOOL)findPattern:(NSString *)pattern options:(unsigned)find_options
{
	return [self findPattern:pattern options:find_options regexpType:0];
}

- (void)find_forward_callback:(NSString *)pattern
{
	if ([self findPattern:pattern options:0]) {
		[self pushLocationOnJumpList:start_location];
		[self setCaret:final_location];
	}
}

- (void)find_backward_callback:(NSString *)pattern
{
	if ([self findPattern:pattern options:1]) {
		[self pushLocationOnJumpList:start_location];
		[self setCaret:final_location];
	}
}

/* syntax: /regexp */
- (BOOL)find:(ViCommand *)command
{
	[[self delegate] getExCommandForTextView:self selector:@selector(find_forward_callback:)];
	// FIXME: this won't work as a motion command!
	// d/pattern will not work!
	return YES;
}

/* syntax: ?regexp */
- (BOOL)find_backwards:(ViCommand *)command
{
	[[self delegate] getExCommandForTextView:self selector:@selector(find_backward_callback:)];
	// FIXME: this won't work as a motion command!
	// d?pattern will not work!
	return YES;
}

/* syntax: n */
- (BOOL)repeat_find:(ViCommand *)command
{
	NSString *pattern = [[NSApp delegate] lastSearchPattern];
	if (pattern == nil) {
		[[self delegate] message:@"No previous search pattern"];
		return NO;
	}

	[self pushLocationOnJumpList:start_location];
	return [self findPattern:pattern options:0];
}

/* syntax: N */
- (BOOL)repeat_find_backward:(ViCommand *)command
{
	NSString *pattern = [[NSApp delegate] lastSearchPattern];
	if (pattern == nil) {
		[[self delegate] message:@"No previous search pattern"];
		return NO;
	}

	[self pushLocationOnJumpList:start_location];
	return [self findPattern:pattern options:1];
}

#pragma mark -
#pragma mark Caret and selection handling

- (void)scrollToCaret
{
	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];
        NSRect visibleRect = [clipView bounds];
	NSUInteger glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:[self caret]];
	NSRect rect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1) inTextContainer:[self textContainer]];

	rect.size.width = 20;

	NSPoint topPoint;
	CGFloat topY = visibleRect.origin.y;
	CGFloat topX = visibleRect.origin.x;

	if (NSMinY(rect) < NSMinY(visibleRect))
		topY = NSMinY(rect);
	else if (NSMaxY(rect) > NSMaxY(visibleRect))
		topY = NSMaxY(rect) - NSHeight(visibleRect);

	CGFloat jumpX = 20*rect.size.width;

	if (NSMinX(rect) < NSMinX(visibleRect))
		topX = NSMinX(rect) > jumpX ? NSMinX(rect) - jumpX : 0;
	else if (NSMaxX(rect) > NSMaxX(visibleRect))
		topX = NSMaxX(rect) - NSWidth(visibleRect) + jumpX;

	if (topX < jumpX)
		topX = 0;

	topPoint = NSMakePoint(topX, topY);

	if (topPoint.x != visibleRect.origin.x || topPoint.y != visibleRect.origin.y)
	{
		[clipView scrollToPoint:topPoint];
		[scrollView reflectScrolledClipView:clipView];
	}
}

- (void)setCaret:(NSUInteger)location
{
        DEBUG(@"setting caret to %u", location);
	caret = location;
	if (!replayingInput)
		[self updateCaret];
}

- (NSUInteger)caret
{
	return caret;
}

- (NSRange)selectionRangeForProposedRange:(NSRange)proposedSelRange granularity:(NSSelectionGranularity)granularity
{
	if (proposedSelRange.length == 0 && granularity == NSSelectByCharacter) {
		NSUInteger bol, eol, end;
		[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:proposedSelRange.location];
		if (proposedSelRange.location == eol)
			proposedSelRange.location = IMAX(bol, eol - 1);
		return proposedSelRange;
	}
	visual_line_mode = (granularity == NSSelectByParagraph);
	return [super selectionRangeForProposedRange:proposedSelRange granularity:granularity];
}

- (void)setSelectedRanges:(NSArray *)ranges affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag
{
	[super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelectingFlag];

	if (stillSelectingFlag == NO)
		return;

	NSRange firstRange = [[ranges objectAtIndex:0] rangeValue];
	NSRange lastRange = [[ranges lastObject] rangeValue];

	if (mode != ViVisualMode)
	{
		[self setVisualMode];
		[self setCaret:firstRange.location];
		visual_start_location = firstRange.location;
	}
	else if (lastRange.length == 0)
	{
		[self setNormalMode];
	}
	else if (visual_start_location == firstRange.location)
	{
		[self setCaret:IMAX(lastRange.location, NSMaxRange(lastRange) - 1)];
	}
	else
	{
		[self setCaret:firstRange.location];
	}
}

- (void)setVisualSelection
{
	NSUInteger l1 = visual_start_location, l2 = [self caret];
	if (l2 < l1)
	{	/* swap if end < start */
		l2 = l1;
		l1 = end_location;
	}

	if (visual_line_mode)
	{
		NSUInteger bol, end;
		[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:l1];
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:l2];
		l1 = bol;
		l2 = end;
	}
	else
		l2++;

	NSRange sel = NSMakeRange(l1, l2 - l1);
	[self setSelectedRange:sel];
}

#pragma mark -

- (void)setNormalMode
{
	DEBUG(@"setting normal mode, caret = %u, final_location = %u, length = %u", caret, final_location, [[self textStorage] length]);
	mode = ViNormalMode;
}

- (void)resetSelection
{
	DEBUG(@"resetting selection, caret = %u", [self caret]);
	[self setSelectedRange:NSMakeRange([self caret], 0)];
}

- (void)setVisualMode
{
	mode = ViVisualMode;
}

- (void)setInsertMode:(ViCommand *)command
{
	DEBUG(@"entering insert mode at location %u (final location is %u), length is %u",
		end_location, final_location, [[self textStorage] length]);
	mode = ViInsertMode;

	if (command.text)
	{
		NSEvent *ev;
		replayingInput = YES;
		[self setCaret:end_location];
		DEBUG(@"replaying input, got %u events", [command.text count]);
		for (ev in command.text)
		{
			[self keyDown:ev];
		}
		replayingInput = NO;
		DEBUG(@"done replaying input, caret = %u, final_location = %u", [self caret], final_location);
	}
}

/* FIXME: these are nothing but UGLY!!!
 * Use invocations instead, if it can't be done immediately.
 */
- (void)addTemporaryAttribute:(NSDictionary *)what
{
        [[self layoutManager] addTemporaryAttribute:[what objectForKey:@"attributeName"]
                                              value:[what objectForKey:@"value"]
                                  forCharacterRange:[[what objectForKey:@"range"] rangeValue]];
}

- (void)removeTemporaryAttribute:(NSDictionary *)what
{
        [[self layoutManager] removeTemporaryAttribute:[what objectForKey:@"attributeName"]
                                     forCharacterRange:[[what objectForKey:@"range"] rangeValue]];
}

#pragma mark -
#pragma mark Input handling and command evaluation

/* Input a character from the user (in insert mode). Handle smart typing pairs.
 * FIXME: assumes smart typing pairs are single characters.
 * FIXME: need special handling if inside a snippet.
 */
- (void)inputCharacters:(NSString *)characters
{
	DEBUG(@"insert characters [%@] at %i", characters, start_location);
	// If there is a non-zero length selection, remove it first.
	NSRange sel = [self selectedRange];
	if (sel.length > 0)
	{
		[self deleteRange:sel];
	}

	BOOL foundSmartTypingPair = NO;
	NSArray *smartTypingPairs = [self smartTypingPairsAtLocation:IMIN(start_location, [[self textStorage] length] - 1)];
	NSArray *pair;
	for (pair in smartTypingPairs)
	{
		// check if we're inserting the end character of a smart typing pair
		// if so, just overwrite the end character
		if ([[pair objectAtIndex:1] isEqualToString:characters] &&
		    [[[[self textStorage] string] substringWithRange:NSMakeRange(start_location, 1)] isEqualToString:[pair objectAtIndex:1]])
		{
			if ([[self layoutManager] temporaryAttribute:ViSmartPairAttributeName
						    atCharacterIndex:start_location
						      effectiveRange:NULL])
			{
				foundSmartTypingPair = YES;
				[self setCaret:start_location + 1];
			}
			break;
		}
		// check for the start character of a smart typing pair
		else if ([[pair objectAtIndex:0] isEqualToString:characters])
		{
			// don't use it if next character is alphanumeric
			if (start_location + 1 >= [[self textStorage] length] ||
			    ![[NSCharacterSet alphanumericCharacterSet] characterIsMember:[[[self textStorage] string] characterAtIndex:start_location]])
			{
				foundSmartTypingPair = YES;
				[self insertString:[NSString stringWithFormat:@"%@%@",
					[pair objectAtIndex:0],
					[pair objectAtIndex:1]] atLocation:start_location];

				// INFO(@"adding smart pair attr to %u + 2", start_location);
				// [[self layoutManager] addTemporaryAttribute:ViSmartPairAttributeName value:characters forCharacterRange:NSMakeRange(start_location, 2)];
				[self performSelector:@selector(addTemporaryAttribute:) withObject:[NSDictionary dictionaryWithObjectsAndKeys:
					ViSmartPairAttributeName, @"attributeName",
					characters, @"value",
					[NSValue valueWithRange:NSMakeRange(start_location, 2)], @"range",
					nil] afterDelay:0];

				[self setCaret:start_location + 1];
				break;
			}
		}
	}
	
	if (!foundSmartTypingPair) {
		DEBUG(@"%s", "no smart typing pairs triggered");
		[self insertString:characters atLocation:start_location];
		[self setCaret:start_location + [characters length]];
	}

#if 0
	if ([self shouldDecreaseIndentAtLocation:insert_end_location]) {
                int n = [self changeIndentation:-1 inRange:NSMakeRange(insert_end_location, 1)];
		insert_start_location += n;
		insert_end_location += n;
	} else if ([self shouldNotIndentLineAtLocation:insert_end_location]) {
                int n = [self changeIndentation:-1000 inRange:NSMakeRange(insert_end_location, 1)];
		insert_start_location += n;
		insert_end_location += n;
	}
#endif
}

- (void)input_newline:(NSString *)characters
{
	int num_chars = [self insertNewlineAtLocation:start_location indentForward:YES];
	[self setCaret:start_location + num_chars];
}

- (void)input_tab:(NSString *)characters
{
        // check if we're inside a snippet
        if ([activeSnippet activeInRange:NSMakeRange(start_location, 1)])
	{
		[self handleSnippetTab:activeSnippet atLocation:start_location];
		return;
	}

        // check for a new snippet
        if (start_location > 0)
        {
                // is there a word before the cursor that we just typed?
                NSString *word = [self wordAtLocation:start_location - 1];
                if ([word length] > 0)
                {
                        NSArray *scopes = [self scopesAtLocation:start_location];
                        if (scopes)
                        {
                                NSString *snippetString = [[ViLanguageStore defaultStore] tabTrigger:word matchingScopes:scopes];
                                if (snippetString)
                                {
                                        [self deleteRange:NSMakeRange(start_location - [word length], [word length])];
                                        activeSnippet = [self insertSnippet:snippetString atLocation:start_location - [word length]];
                                        return;
                                }
                        }
                }
        }
        
	// otherwise just insert a tab
	[self insertString:@"\t" atLocation:start_location];
	[self setCaret:start_location + 1];
}

- (NSArray *)smartTypingPairsAtLocation:(NSUInteger)aLocation
{
	NSDictionary *smartTypingPairs = [[ViLanguageStore defaultStore] preferenceItems:@"smartTypingPairs"];
	NSString *bestMatchingScope = [self bestMatchingScope:[smartTypingPairs allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		DEBUG(@"found smart typing pair scope selector [%@] at location %i", bestMatchingScope, aLocation);
		return [smartTypingPairs objectForKey:bestMatchingScope];
	}

	return nil;
}

- (void)input_backspace:(NSString *)characters
{
	if ([self caret] == 0)
	{
		[[self delegate] message:@"Already at the beginning of the document"];
		return;
	}

	/* check if we're deleting the first character in a smart pair */
	NSArray *smartTypingPairs = [self smartTypingPairsAtLocation:start_location - 1];
	NSArray *pair;
	for (pair in smartTypingPairs)
	{
		if([[pair objectAtIndex:0] isEqualToString:[[[self textStorage] string] substringWithRange:NSMakeRange(start_location - 1, 1)]] &&
		   start_location + 1 < [[self textStorage] length] &&
		   [[pair objectAtIndex:1] isEqualToString:[[[self textStorage] string] substringWithRange:NSMakeRange(start_location, 1)]])
		{
			[self deleteRange:NSMakeRange(start_location - 1, 2)];
			[self setCaret:start_location - 1];
			return;
		}
	}

	/* else a regular character, just delete it */
	[self deleteRange:NSMakeRange(start_location - 1, 1)];
	[self setCaret:start_location - 1];
}

- (void)input_forward_delete:(NSString *)characters
{
	/* FIXME: should handle smart typing pairs here!
	 */
	[self deleteRange:NSMakeRange(start_location, 1)];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	if ([theEvent type] != NSKeyDown && [theEvent type] != NSKeyUp)
		return NO;

	if ([theEvent type] == NSKeyUp) {
		DEBUG(@"Got a performKeyEquivalent event, characters: '%@', keycode = %u, modifiers = 0x%04X",
		      [theEvent charactersIgnoringModifiers],
		      [[theEvent characters] characterAtIndex:0],
		      [theEvent modifierFlags]);
		return YES;
	}

	return [super performKeyEquivalent:theEvent];
}

- (void)evaluateCommand:(ViCommand *)command
{
	/* Default start- and end-location is the current location. */
	start_location = [self caret];
	end_location = start_location;
	final_location = start_location;
	DEBUG(@"start_location = %u", start_location);

	if (command.motion_method)
	{
		/* The command has an associated motion component.
		 * Run the motion method and record the start and end locations.
		 */
		DEBUG(@"perform motion command %@", command.motion_method);
		if ([self performSelector:NSSelectorFromString(command.motion_method) withObject:command] == NO)
		{
			/* the command failed */
			[command reset];
			final_location = start_location;
			return;
		}
	}

	/* Find out the affected range for this command */
	NSUInteger l1, l2;
	if (mode == ViVisualMode)
	{
		NSRange sel = [self selectedRange];
		l1 = sel.location;
		l2 = NSMaxRange(sel);
	}
	else
	{
		l1 = start_location, l2 = end_location;
		if (l2 < l1)
		{	/* swap if end < start */
			l2 = l1;
			l1 = end_location;
		}
	}
	DEBUG(@"affected locations: %u -> %u (%u chars), caret = %u, length = %u", l1, l2, l2 - l1, [self caret], [[self textStorage] length]);

	if (command.line_mode && !command.ismotion && mode != ViVisualMode)
	{
		/* If this command is line oriented, extend the affectedRange to whole lines.
		 * However, don't do this for Visual-Line mode, this is done in setVisualSelection.
		 */
		NSUInteger bol, end, eol;

		[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:l1];

		if (!command.motion_method && mode != ViVisualMode)
		{
			/* This is a "doubled" command (like dd or yy).
			 * A count, or motion-count, affects that number of whole lines.
			 */
			int line_count = command.count;
			if (line_count == 0)
				line_count = command.motion_count;
			while (--line_count > 0)
			{
				l2 = end;
				[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:l2];
			}
		}
		else
		{
			[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:l2];
		}

		l1 = bol;
		l2 = end;
		DEBUG(@"after line mode correction: affected locations: %u -> %u (%u chars)", l1, l2, l2 - l1);
	}
	affectedRange = NSMakeRange(l1, l2 - l1);

	if (mode == ViVisualMode && !command.ismotion) {
		[self setNormalMode];
		[self resetSelection];
	}

	DEBUG(@"perform command %@", command.method);
	DEBUG(@"start_location = %u", start_location);
	BOOL ok = (NSUInteger)[self performSelector:NSSelectorFromString(command.method) withObject:command];
	if (ok && command.line_mode && !command.ismotion && (command.key != 'y' || command.motion_key != 'y') && command.key != '>' && command.key != '<' && command.key != 'S')
	{
		/* For line mode operations, we always end up at the beginning of the line. */
		/* ...well, except for yy :-) */
		/* ...and > */
		/* ...and < */
		// FIXME: this is not a generic case!
		NSUInteger bol;
		[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:final_location];
		final_location = bol;
	}
}

- (void)keyDown:(NSEvent *)theEvent
{
	DEBUG(@"Got a keyDown event, characters: '%@', keycode = 0x%04X, code = 0x%08X",
	      [theEvent characters],
	      [theEvent keyCode],
              ([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) | [theEvent keyCode]);

	if ([[theEvent characters] length] == 0)
		return [super keyDown:theEvent];
	unichar charcode = [[theEvent characters] characterAtIndex:0];

	if (mode == ViInsertMode) {
		// add the event to the input key replay queue
		if (!replayingInput)
			[inputKeys addObject:theEvent];

		if (charcode == 0x1B) {
			/* escape, return to command mode */
#if 0
			NSString *insertedText = [[[self textStorage] string] substringWithRange:NSMakeRange(insert_start_location, insert_end_location - insert_start_location)];
			INFO(@"registering replay text: [%@] at %u + %u (length %u), count = %i",
				insertedText, insert_start_location, insert_end_location, [insertedText length], parser.count);

			/* handle counts for inserted text here */
			NSString *multipliedText = insertedText;
			if (parser.count > 1) {
				multipliedText = [insertedText stringByPaddingToLength:[insertedText length] * (parser.count - 1)
						                            withString:insertedText
							               startingAtIndex:0];
				[self insertString:multipliedText atLocation:[self caret]];

				multipliedText = [insertedText stringByPaddingToLength:[insertedText length] * parser.count
						                            withString:insertedText
							               startingAtIndex:0];
			}

			[parser setText:multipliedText];
			if ([multipliedText length] > 0)
				[self recordInsertInRange:NSMakeRange(insert_start_location, [multipliedText length])];
#endif
			[self endUndoGroup];
			if (!replayingInput)
				parser.text = inputKeys; // copies the array
			[inputKeys removeAllObjects];
			[self setNormalMode];
			start_location = end_location = [self caret];
			[self move_left:nil];
			[self setCaret:end_location];
		} else {
			start_location = [self caret];

			/* Lookup the key in the input command map. Some keys are handled specially, or trigger macros. */
			NSUInteger code = (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) | [theEvent keyCode]);
			NSString *inputCommand = [inputCommands objectForKey:[NSNumber numberWithUnsignedInteger:code]];
			if (inputCommand)
				[self performSelector:NSSelectorFromString(inputCommand) withObject:[theEvent characters]];
			else if ((([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) & (NSCommandKeyMask | NSFunctionKeyMask)) == 0) {
				/* other keys insert themselves */
				/* but don't input control characters */
				if (([theEvent modifierFlags] & NSControlKeyMask) == NSControlKeyMask)
					[[self delegate] message:@"Illegal character; quote to enter"];
				else
					[self inputCharacters:[theEvent characters]];
			}
		}
	} else if (mode == ViNormalMode || mode == ViVisualMode){
		if (mode == ViNormalMode) {
			// check for a special key bound to a function
			NSUInteger code = (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) | [theEvent keyCode]);
			NSString *normalCommand = [normalCommands objectForKey:[NSNumber numberWithUnsignedInteger:code]];
			if (normalCommand) {
				[self performSelector:NSSelectorFromString(normalCommand) withObject:[theEvent characters]];
				return;
			}
		} else if (charcode == 0x1B) {
			[self setNormalMode];
			[self setCaret:final_location];
			[self resetSelection];
			return;
		}

		if (parser.complete)
			[parser reset];

		if (mode == ViVisualMode)
			[parser setVisualMap];

		[parser pushKey:charcode];
		if (parser.complete) {
			[[self delegate] message:@""]; // erase any previous message
			[[self textStorage] beginEditing];

			/* Set or reset the saved column for up/down movement. */
			if (parser.key == 'j' || parser.key == 'k' || parser.key == '\x05' || parser.key == '\x19') {
				if (saved_column < 0)
					saved_column = [self columnAtLocation:[self caret]];	
			} else
				saved_column = -1;

			if (parser.key != 'u' && !parser.is_dot)
				undo_direction = 0;
			[self evaluateCommand:parser];
			if (mode != ViInsertMode) {
				// still in normal mode
				[self endUndoGroup];
			}
			[[self textStorage] endEditing];
                        DEBUG(@"final_location is %u", final_location);
			[self setCaret:final_location];
			if (mode == ViVisualMode)
				[self setVisualSelection];
		}
	}

	if (!replayingInput)
		[self scrollToCaret];
}

- (void)swipeWithEvent:(NSEvent *)event
{
	BOOL rc = FALSE;

	DEBUG(@"got swipe event %@", event);

	if ([event deltaX] > 0)
		rc = [self jumplist_backward:nil];
	else if ([event deltaX] < 0)
		rc = [self jumplist_forward:nil];

	if (rc == TRUE)
		[[self delegate] message:@""]; // erase any previous message
}

/* Takes a string of characters and creates key events for each one.
 * Then feeds them into the keyDown method to simulate key presses.
 * Only used for unit testing.
 */
- (void)input:(NSString *)inputString
{
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
		DEBUG(@"textStorage = [%@]", [[self textStorage] string]);
	}
}

#pragma mark -

/* This is stolen from Smultron.
 */
- (void)drawPageGuideInRect:(NSRect)rect
{
	if (pageGuideX > 0)
	{
		NSRect bounds = [self bounds];
		if ([self needsToDrawRect:NSMakeRect(pageGuideX, 0, 1, bounds.size.height)] == YES)
		{
			// So that it doesn't draw the line if only e.g. the cursor updates
			[[self insertionPointColor] set];
			[NSBezierPath strokeRect:NSMakeRect(pageGuideX, 0, 0, bounds.size.height)];
		}
	}
}

- (void)setPageGuide:(int)pageGuideValue
{
	if (pageGuideValue == 0)
	{
		pageGuideX = 0;
	}
	else
	{
		NSDictionary *sizeAttribute = [[NSDictionary alloc] initWithObjectsAndKeys:[self font], NSFontAttributeName, nil];
		CGFloat sizeOfCharacter = [@" " sizeWithAttributes:sizeAttribute].width;
		pageGuideX = (sizeOfCharacter * (pageGuideValue + 1)) - 1.5;
		// -1.5 to put it between the two characters and draw only on one pixel and
		// not two (as the system draws it in a special way), and that's also why the
		// width above is set to zero
	}
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

- (void)enableWrapping
{
	const float LargeNumberForText = 1.0e7;

	NSScrollView *scrollView = [self enclosingScrollView];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setHasHorizontalScroller:NO];
	[scrollView setAutoresizingMask:NSViewHeightSizable];

	NSTextContainer *textContainer = [self textContainer];
	[textContainer setContainerSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[textContainer setWidthTracksTextView:YES];
	[textContainer setHeightTracksTextView:NO];

	[self setMaxSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[self setHorizontallyResizable:NO];
	[self setVerticallyResizable:YES];
	[self setAutoresizingMask:NSViewNotSizable];
}

- (void)setTheme:(ViTheme *)aTheme
{
	[self setBackgroundColor:[aTheme backgroundColor]];
	[[self enclosingScrollView] setBackgroundColor:[aTheme backgroundColor]];
	[self setInsertionPointColor:[aTheme caretColor]];
	[self setSelectedTextAttributes:[NSDictionary dictionaryWithObject:[aTheme selectionColor]
								    forKey:NSBackgroundColorAttributeName]];
}

- (NSFont *)font
{
//	return [NSFont userFixedPitchFontOfSize:11.0];
	return [NSFont fontWithName:@"Menlo Regular" size:11.0];
}

- (void)setTypingAttributes:(NSDictionary *)attributes
{
	typingAttributes = attributes;
}

- (NSDictionary *)typingAttributes
{
	if (typingAttributes == nil)
		[self resetTypingAttributes];
	return typingAttributes;
}

- (void)resetTypingAttributes
{
	int tabSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	NSString *tab = [@"" stringByPaddingToLength:tabSize withString:@" " startingAtIndex:0];

	NSDictionary *attrs = [NSDictionary dictionaryWithObject:[self font] forKey:NSFontAttributeName];
	NSSize tabSizeInPoints = [tab sizeWithAttributes:attrs];

	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	// remove all previous tab stops
	for (NSTextTab *tabStop in [style tabStops])
		[style removeTabStop:tabStop];

	// "Tabs after the last specified in tabStops are placed at integral multiples of this distance."
	[style setDefaultTabInterval:tabSizeInPoints.width];

	[self setTypingAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		style, NSParagraphStyleAttributeName,
		[self font], NSFontAttributeName,
		nil]];
	[[self textStorage] addAttributes:[self typingAttributes] range:NSMakeRange(0, [[self textStorage] length])];
}

- (NSUndoManager *)undoManager
{
	return undoManager;
}


- (NSUInteger)currentLine
{
	return [[self textStorage] lineNumberAtLocation:[self caret]];
}

- (NSUInteger)columnAtLocation:(NSUInteger)aLocation
{
	NSUInteger bol, eol, end;
	[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:aLocation];
	NSUInteger c = 0, i;
	int ts = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	for (i = bol; i <= [self caret] && i < end; i++)
	{
		unichar ch = [[[self textStorage] string] characterAtIndex:i];
		if (ch == '\t')
			c += ts - (c % ts);
		else
			c++;
	}
	return c;
}

- (NSUInteger)currentColumn
{
	return [self columnAtLocation:[self caret]];
}

- (NSString *)wordAtLocation:(NSUInteger)aLocation range:(NSRange *)returnRange
{
	if (aLocation >= [[self textStorage] length]) {
		INFO(@"start/to outside valid range (length %u)", [[self textStorage] length]);
		if (returnRange != nil)
			*returnRange = NSMakeRange(0, 0);
		return @"";
	}

	NSUInteger word_start = [self skipCharactersInSet:wordSet fromLocation:aLocation backward:YES];
	if (word_start < aLocation && word_start > 0)
		word_start += 1;

	NSUInteger word_end = [self skipCharactersInSet:wordSet fromLocation:aLocation backward:NO];
	if (word_end > word_start)
	{
		NSRange range = NSMakeRange(word_start, word_end - word_start);
		if (returnRange)
			*returnRange = range;
		return [[[self textStorage] string] substringWithRange:range];
	}

	if (returnRange)
		*returnRange = NSMakeRange(0, 0);

	return nil;
}

- (NSString *)wordAtLocation:(NSUInteger)aLocation
{
	return [self wordAtLocation:aLocation range:nil];
}

- (void)show_scope:(NSString *)characters
{
	[[self delegate] message:[[self scopesAtLocation:[self caret]] componentsJoinedByString:@" "]];
}

- (void)switch_file:(NSString *)character
{
        [[[self delegate] windowController] switchToLastFile];
}

- (void)pushLocationOnJumpList:(NSUInteger)aLocation
{
	[[ViJumpList defaultJumpList] pushURL:[[self delegate] fileURL]
	                                 line:[[self textStorage] lineNumberAtLocation:aLocation]
	                               column:[self columnAtLocation:aLocation]];
}

- (void)pushCurrentLocationOnJumpList
{
	[self pushLocationOnJumpList:[self caret]];
}

@end

