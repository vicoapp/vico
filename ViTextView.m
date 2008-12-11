#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>

#import "ViTextView.h"
#import "ViLanguageStore.h"
#import "ViThemeStore.h"
#import "ViDocument.h"  // for declaration of the message: method
#import "NSString-scopeSelector.h"
#import "NSArray-patterns.h"
#import "ExCommand.h"
#import "ViAppController.h"  // for sharedBuffers
#import "ViCommandOutputController.h"
#import "ViDocumentView.h"
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
@end

#pragma mark -

@implementation ViTextView

- (void)initEditorWithDelegate:(id)aDelegate documentView:(ViDocumentView *)docView
{
	[self setDelegate:aDelegate];
	[self setCaret:0];

	documentView = docView;
	undoManager = [[self delegate] undoManager];
	parser = [[ViCommand alloc] init];
	buffers = [[NSApp delegate] sharedBuffers];
	inputKeys = [[NSMutableArray alloc] init];
	marks = [[NSMutableDictionary alloc] init];

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
	[self setUsesFontPanel:NO];
	[self setUsesFindPanel:NO];
	//[self setPageGuideValues];
	[self disableWrapping];
	[self setContinuousSpellCheckingEnabled:NO];
	// [[self layoutManager] setShowsInvisibleCharacters:YES];
	[[self layoutManager] setShowsControlCharacters:YES];
	[self setDrawsBackground:YES];

	[self setTheme:[[ViThemeStore defaultStore] defaultTheme]];
	[self setTabSize:[[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"]];
}

- (void)setString:(NSString *)aString
{
	[[[self textStorage] mutableString] setString:aString ?: @""];
	[[self textStorage] addAttribute:NSFontAttributeName value:[self font] range:NSMakeRange(0, [[self textStorage] length])];
	[self setCaret:0];
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

- (void)endUndoGroup
{
	if (hasUndoGroup)
	{
		[undoManager endUndoGrouping];
		hasUndoGroup = NO;
	}
}

- (void)beginUndoGroup
{
	if (!hasUndoGroup)
	{
		[undoManager beginUndoGrouping];
		hasUndoGroup = YES;
	}
}


/* Like insertText:, but works within beginEditing/endEditing.
 * Also begins an undo group.
 */
- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation undoGroup:(BOOL)undoGroup
{
	if ([aString length] == 0)
		return;

	NSRange range = NSMakeRange(aLocation, [aString length]);

	if ([[self delegate] textView:self shouldChangeTextInRange:range replacementString:aString] == NO)
		return;

	if (undoGroup)
		[self beginUndoGroup];
	[[[self textStorage] mutableString] insertString:aString atIndex:aLocation];
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
	if (aRange.length == 0)
		return;

	if ([[self delegate] textView:self shouldChangeTextInRange:aRange replacementString:nil] == NO)
		return;

	if (undoGroup)
		[self beginUndoGroup];
	[self recordDeleteOfRange:aRange];
	[[self textStorage] deleteCharactersInRange:aRange];

	if (activeSnippet)
	{
		if ([activeSnippet activeInRange:aRange])
		{
			INFO(@"found snippet %@ at %u", activeSnippet, aRange.location);
			if ([activeSnippet deleteRange:aRange] == NO)
			{
				INFO(@"deleting failed, cancelling snippet %@", activeSnippet);
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
	return [[self layoutManager] temporaryAttribute:ViScopeAttributeName
				       atCharacterIndex:aLocation
				         effectiveRange:NULL];
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

- (int)changeIndentation:(int)delta inRange:(NSRange)aRange
{
	int shiftWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"shiftwidth"];
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:aRange.location];

	int delta_offset = 0;
	BOOL has_delta_offset = NO;
	
	while (bol < NSMaxRange(aRange))
	{
		NSString *indent = [self leadingWhitespaceForLineAtLocation:bol];
		int n = [self lengthOfIndentString:indent];
		NSString *newIndent = [self indentStringOfLength:n + delta * shiftWidth];
	
		NSRange indentRange = NSMakeRange(bol, [indent length]);
		[self replaceRange:indentRange withString:newIndent];

		aRange.length += [newIndent length] - [indent length];
		if (!has_delta_offset)
		{
          		has_delta_offset = YES;
          		delta_offset = [newIndent length] - [indent length];
                }

		// get next line
		[self getLineStart:NULL end:&bol contentsEnd:NULL forLocation:bol];
		if (bol == NSNotFound)
			break;
	}

	return delta_offset;
}

- (void)increase_indent:(NSString *)characters
{
        NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
        int n = [self changeIndentation:+1 inRange:NSMakeRange(bol, IMAX(eol - bol, 1))];
        [self setCaret:start_location + n];
}

- (void)decrease_indent:(NSString *)characters
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	int n = [self changeIndentation:-1 inRange:NSMakeRange(bol, eol - bol)];
        [self setCaret:start_location + n];
}

#pragma mark -
#pragma mark Undo support

- (void)undoDeleteOfString:(NSString *)aString atLocation:(NSUInteger)aLocation
{
	[self insertString:aString atLocation:aLocation undoGroup:NO];
	final_location = aLocation;
}

- (void)undoInsertInRange:(NSRange)aRange
{
	[self deleteRange:aRange undoGroup:NO];
	final_location = aRange.location;
}

- (void)recordInsertInRange:(NSRange)aRange
{
	// INFO(@"pushing insert of text in range %u+%u onto undo stack", aRange.location, aRange.length);
	[[undoManager prepareWithInvocationTarget:self] undoInsertInRange:aRange];
	[undoManager setActionName:@"insert text"];
}

- (void)recordDeleteOfString:(NSString *)aString atLocation:(NSUInteger)aLocation
{
	// INFO(@"pushing delete of [%@] (%p) at %u onto undo stack", aString, aString, aLocation);
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
	[undoManager beginUndoGrouping]; // FIXME: no longer needed?
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
	[self deleteRange:cutRange];
}

#pragma mark -
#pragma mark Convenience methods

- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation
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
	final_location = end_location = i;
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
		DEBUG(@"got ex [%@], command = [%@], method = [%@]", ex, ex.command, ex.method);
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

	if ([foundMatches count] == 0)
	{
		[[self delegate] message:@"Pattern not found"];
	}
	else
	{
		ViRegexpMatch *match, *nextMatch = nil;
		for (match in foundMatches)
		{
			NSRange r = [match rangeOfMatchedString];
			if (find_options == 0)
			{
				if (nextMatch == nil && r.location > start_location)
					nextMatch = match;
			}
			else if (r.location < start_location)
			{
				nextMatch = match;
			}
			if (nextMatch)
				break;
		}

		if (nextMatch == nil)
		{
			if (find_options == 0)
				nextMatch = [foundMatches objectAtIndex:0];
			else
				nextMatch = [foundMatches lastObject];

			[[self delegate] message:@"Search wrapped"];
		}

		if (nextMatch)
		{
			NSRange r = [nextMatch rangeOfMatchedString];
			[self scrollRangeToVisible:r];
			final_location = end_location = r.location;
			[self setCaret:final_location];
			[self performSelector:@selector(highlightFindMatch:) withObject:nextMatch afterDelay:0];
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
	if ([self findPattern:pattern options:0])
	{
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

/* syntax: n */
- (BOOL)repeat_find:(ViCommand *)command
{
	NSString *pattern = [[NSApp delegate] lastSearchPattern];
	if (pattern == nil)
	{
		[[self delegate] message:@"No previous search pattern"];
		return NO;
	}

	return [self findPattern:pattern options:0];
}

/* syntax: N */
- (BOOL)repeat_find_backward:(ViCommand *)command
{
	NSString *pattern = [[NSApp delegate] lastSearchPattern];
	if (pattern == nil)
	{
		[[self delegate] message:@"No previous search pattern"];
		return NO;
	}

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

	NSPoint topPoint;
	if (NSMinY(rect) < NSMinY(visibleRect))
	{
		topPoint = NSMakePoint(0, NSMinY(rect));
	}
	else if (NSMaxY(rect) > NSMaxY(visibleRect))
	{
		topPoint = NSMakePoint(0, NSMaxY(rect) - NSHeight(visibleRect));
	}
	else
		return;

	[clipView scrollToPoint:topPoint];
	[scrollView reflectScrolledClipView:clipView];
}

- (void)updateCaret
{
	if (mode != ViVisualMode)
		[self setSelectedRange:NSMakeRange(caret, 0)];

	NSLayoutManager *lm = [self layoutManager];
	NSRange r = [lm glyphRangeForCharacterRange:NSMakeRange(caret, 1) actualCharacterRange:NULL];
	caretRect = [lm boundingRectForGlyphRange:r inTextContainer:[self textContainer]];
	if (NSWidth(caretRect) == 0)
		caretRect.size.width = 7; // XXX
	[self setNeedsDisplayInRect:oldCaretRect];
	[self setNeedsDisplayInRect:caretRect];
	oldCaretRect = caretRect;

	// update selection in symbol list
	[[self delegate] updateSelectedSymbolForLocation:caret];
}

- (void)setCaret:(NSUInteger)location
{
	caret = location;
	if (!replayingInput)
		[self updateCaret];
}

- (NSUInteger)caret
{
	return caret;
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
	mode = ViNormalMode;
	// [self setSelectedRange:NSMakeRange(caret, 0)];
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
		for (ev in command.text)
		{
			[self keyDown:ev];
		}
		replayingInput = NO;
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
	
	if (!foundSmartTypingPair)
	{
		[self insertString:characters atLocation:start_location];
		[self setCaret:start_location + [characters length]];
	}

#if 0
	if ([self shouldDecreaseIndentAtLocation:insert_end_location])
	{
                int n = [self changeIndentation:-1 inRange:NSMakeRange(insert_end_location, 1)];
		insert_start_location += n;
		insert_end_location += n;
	}
	else if ([self shouldNotIndentLineAtLocation:insert_end_location])
	{
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

	if (bestMatchingScope)
	{
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

	if ([theEvent type] == NSKeyUp)
	{
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

	if (command.motion_method)
	{
		/* The command has an associated motion component.
		 * Run the motion method and record the start and end locations.
		 */
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
	DEBUG(@"affected locations: %u -> %u (%u chars)", l1, l2, l2 - l1);

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

	BOOL resetVisualMode = NO;
	if (mode == ViVisualMode && !command.ismotion)
		resetVisualMode = YES;

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

	if (resetVisualMode)
		[self setNormalMode];
}

- (void)keyDown:(NSEvent *)theEvent
{
#if 0
	INFO(@"Got a keyDown event, characters: '%@', keycode = 0x%04X, code = 0x%08X",
	      [theEvent characters],
	      [theEvent keyCode],
              ([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) | [theEvent keyCode]);
#endif

	if ([[theEvent characters] length] == 0)
		return [super keyDown:theEvent];
	unichar charcode = [[theEvent characters] characterAtIndex:0];

	if (mode == ViInsertMode)
	{
		// add the event to the input key replay queue
		if (!replayingInput)
			[inputKeys addObject:theEvent];

		if (charcode == 0x1B)
		{
			/* escape, return to command mode */
#if 0
			NSString *insertedText = [[[self textStorage] string] substringWithRange:NSMakeRange(insert_start_location, insert_end_location - insert_start_location)];
			INFO(@"registering replay text: [%@] at %u + %u (length %u), count = %i",
				insertedText, insert_start_location, insert_end_location, [insertedText length], parser.count);

			/* handle counts for inserted text here */
			NSString *multipliedText = insertedText;
			if (parser.count > 1)
			{
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
		}
		else
		{
			start_location = [self caret];

			/* Lookup the key in the input command map. Some keys are handled specially, or trigger macros. */
			NSUInteger code = (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) | [theEvent keyCode]);
			NSString *inputCommand = [inputCommands objectForKey:[NSNumber numberWithUnsignedInteger:code]];
			if (inputCommand)
			{
				[self performSelector:NSSelectorFromString(inputCommand) withObject:[theEvent characters]];
			}
			else if ((([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) & (NSCommandKeyMask | NSFunctionKeyMask)) == 0)
			{
				/* other keys insert themselves */
				/* but don't input control characters */
				if (([theEvent modifierFlags] & NSControlKeyMask) == NSControlKeyMask)
				{
					[[self delegate] message:@"Illegal character; quote to enter"];
				}
				else
				{
					[self inputCharacters:[theEvent characters]];
				}
			}
		}
	}
	else if (mode == ViNormalMode || mode == ViVisualMode)
	{
		if (mode == ViNormalMode)
		{
			// check for a special key bound to a function
			NSUInteger code = (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) | [theEvent keyCode]);
			NSString *normalCommand = [normalCommands objectForKey:[NSNumber numberWithUnsignedInteger:code]];
			if (normalCommand)
			{
				[self performSelector:NSSelectorFromString(normalCommand) withObject:[theEvent characters]];
				return;
			}
		}
		else if (charcode == 0x1B)
		{
			[self setNormalMode];
			[self setCaret:final_location];
			return;
		}

		if (parser.complete)
			[parser reset];

		if (mode == ViVisualMode)
			[parser setVisualMap];

		[parser pushKey:charcode];
		if (parser.complete)
		{
			[[self delegate] message:@""]; // erase any previous message
			[[self textStorage] beginEditing];
			[self evaluateCommand:parser];
			if (mode != ViInsertMode)
			{
				// still in command mode
				[self endUndoGroup];
			}
			[[self textStorage] endEditing];
			[self setCaret:final_location];
			if (mode == ViVisualMode)
			{
				[self setVisualSelection];
			}
		}
	}

	if (!replayingInput)
		[self scrollToCaret];
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
	[self setInsertionPointColor:[aTheme caretColor]];
	[self setSelectedTextAttributes:[NSDictionary dictionaryWithObject:[aTheme selectionColor]
								    forKey:NSBackgroundColorAttributeName]];
}

- (NSFont *)font
{
	return [NSFont userFixedPitchFontOfSize:12.0];
}

- (void)setTabSize:(int)tabSize
{
	NSString *tab = [@"" stringByPaddingToLength:tabSize withString:@" " startingAtIndex:0];

	NSDictionary *attrs = [NSDictionary dictionaryWithObject:[self font] forKey:NSFontAttributeName];
	NSSize tabSizeInPoints = [tab sizeWithAttributes:attrs];

	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

	// remove all previous tab stops
	NSTextTab *tabStop;
	for (tabStop in [style tabStops])
	{
		[style removeTabStop:tabStop];
	}

	// "Tabs after the last specified in tabStops are placed at integral multiples of this distance."
	[style setDefaultTabInterval:tabSizeInPoints.width];

	ViTheme *theme = [[ViThemeStore defaultStore] defaultTheme];
	attrs = [NSDictionary dictionaryWithObjectsAndKeys:
			style, NSParagraphStyleAttributeName,
			[theme foregroundColor], NSForegroundColorAttributeName,
			nil];
	DEBUG(@"setting typing attributes to %@", attrs);
	[self setTypingAttributes:attrs];

	// ignoreEditing = YES; // XXX: don't parse scopes when setting tab size
	[[self textStorage] addAttributes:attrs range:NSMakeRange(0, [[self textStorage] length])];
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

- (NSString *)wordAtLocation:(NSUInteger)aLocation
{
	NSUInteger word_start = [self skipCharactersInSet:wordSet fromLocation:aLocation backward:YES];
	if (word_start < aLocation && word_start > 0)
		word_start += 1;

	NSUInteger word_end = [self skipCharactersInSet:wordSet fromLocation:aLocation backward:NO];
	if (word_end > word_start)
	{
		return [[[self textStorage] string] substringWithRange:NSMakeRange(word_start, word_end - word_start)];
	}

	return nil;
}

- (void)show_scope:(NSString *)characters
{
	[[self delegate] message:[[self scopesAtLocation:[self caret]] componentsJoinedByString:@" "]];
}

- (void)switch_file:(NSString *)character
{
        [[[self delegate] windowController] switchToLastFile];
}

#pragma mark -
#pragma mark Bundle commands

- (NSRange)trackScopeSelector:(NSString *)scopeSelector forward:(BOOL)forward fromLocation:(NSUInteger)aLocation
{
	NSRange trackedRange = NSMakeRange(aLocation, 0);
	NSUInteger i = aLocation;
	for (;;)
	{
		if (forward && i >= [[self textStorage] length])
			break;
		else if (!forward && i == 0)
			break;
	
		NSRange range = NSMakeRange(i, 0);
		NSArray *scopes = [[self layoutManager] temporaryAttribute:ViScopeAttributeName
							  atCharacterIndex:i
							    effectiveRange:&range];
		if (scopes == nil)
			break;

		if ([scopeSelector matchesScopes:scopes])
			trackedRange = NSUnionRange(trackedRange, range);
		else
			break;

		if (forward)
			i += range.length;
		else
			i -= range.length;
	}

	return trackedRange;
}

- (NSString *)inputOfType:(NSString *)type command:(NSDictionary *)command range:(NSRange *)rangePtr
{
	NSString *inputText = nil;

	if ([type isEqualToString:@"selection"])
	{
		NSRange sel = [self selectedRange];
		if (sel.length > 0)
		{
			*rangePtr = sel;
			inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
		}
	}
	else if ([type isEqualToString:@"document"])
	{
		inputText = [[self textStorage] string];
		*rangePtr = NSMakeRange(0, [[self textStorage] length]);
	}
	else if ([type isEqualToString:@"scope"])
	{
		NSRange rb = [self trackScopeSelector:[command objectForKey:@"scope"] forward:NO fromLocation:[self caret]];
		NSRange rf = [self trackScopeSelector:[command objectForKey:@"scope"] forward:YES fromLocation:[self caret]];
		*rangePtr = NSUnionRange(rb, rf);
		INFO(@"union range %@", NSStringFromRange(*rangePtr));
		inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
	}
	else if ([type isEqualToString:@"none"])
	{
		inputText = @"";
		*rangePtr = NSMakeRange(0, 0);
	}

	return inputText;
}

- (NSString*)inputForCommand:(NSDictionary *)command range:(NSRange *)rangePtr
{
	NSString *inputText = [self inputOfType:[command objectForKey:@"input"] command:command range:rangePtr];
	if (inputText == nil)
		inputText = [self inputOfType:[command objectForKey:@"fallbackInput"] command:command range:rangePtr];

	return inputText;
}

- (void)setenv:(const char *)var value:(NSString *)value
{
	if (value)
		setenv(var, [value UTF8String], 1);
}

- (void)setenv:(const char *)var integer:(NSInteger)intValue
{
	setenv(var, [[NSString stringWithFormat:@"%li", intValue] UTF8String], 1);
}

- (void)setupEnvironmentForCommand:(NSDictionary *)command
{
	[self setenv:"TM_BUNDLE_PATH" value:[[command objectForKey:@"bundle"] path]];

	NSString *bundleSupportPath = [[command objectForKey:@"bundle"] supportPath];
	[self setenv:"TM_BUNDLE_SUPPORT" value:bundleSupportPath];

	NSString *supportPath = @"/Library/Application Support/TextMate/Support";
	[self setenv:"TM_SUPPORT_PATH" value:supportPath];

	char *path = getenv("PATH");
	[self setenv:"PATH" value:[NSString stringWithFormat:@"%s:%@:%@",
		path,
		[supportPath stringByAppendingPathComponent:@"bin"],
		[bundleSupportPath stringByAppendingPathComponent:@"bin"]]];

	[self setenv:"TM_CURRENT_LINE" value:[self lineForLocation:[self caret]]];
	[self setenv:"TM_CURRENT_WORD" value:[self wordAtLocation:[self caret]]];
	[self setenv:"TM_DIRECTORY" value:[[[[self delegate] fileURL] path] stringByDeletingLastPathComponent]];
	[self setenv:"TM_FILENAME" value:[[[[self delegate] fileURL] path] lastPathComponent]];
	[self setenv:"TM_FILEPATH" value:[[[self delegate] fileURL] path]];
	[self setenv:"TM_FULLNAME" value:NSFullUserName()];
	[self setenv:"TM_LINE_INDEX" integer:[self currentColumn]];
	[self setenv:"TM_LINE_NUMBER" integer:[self currentLine]];
	[self setenv:"TM_SCOPE" value:[[self scopesAtLocation:[self caret]] componentsJoinedByString:@" "]];

	// FIXME: TM_PROJECT_DIRECTORY
	// FIXME: TM_SELECTED_FILES
	// FIXME: TM_SELECTED_FILE
	[self setenv:"TM_SELECTED_TEXT" value:[[[self textStorage] string] substringWithRange:[self selectedRange]]];

	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"expandtab"] == NSOnState)
		setenv("TM_SOFT_TABS", "YES", 1);
	else
		setenv("TM_SOFT_TABS", "NO", 1);

	setenv("TM_TAB_SIZE", [[[NSUserDefaults standardUserDefaults] stringForKey:@"shiftwidth"] UTF8String], 1);

	// FIXME: shellVariables in bundle preferences
}

- (void)performBundleCommand:(id)sender
{
	NSDictionary *command = [sender representedObject];
	INFO(@"command = %@", command);
	NSRange inputRange;

	/*  FIXME: need to verify correct behaviour of these env.variables
	 * cf. http://www.e-texteditor.com/forum/viewtopic.php?t=1644
	 */
	NSString *inputText = [self inputForCommand:command range:&inputRange];
	[self setenv:"TM_INPUT_START_COLUMN" integer:[self columnAtLocation:inputRange.location]];
	[self setenv:"TM_INPUT_END_COLUMN" integer:[self columnAtLocation:NSMaxRange(inputRange)]];
	[self setenv:"TM_INPUT_START_LINE_INDEX" integer:[self columnAtLocation:inputRange.location]];
	[self setenv:"TM_INPUT_END_LINE_INDEX" integer:[self columnAtLocation:NSMaxRange(inputRange)]];
	[self setenv:"TM_INPUT_START_LINE" integer:[[self textStorage] lineNumberAtLocation:inputRange.location]];
	[self setenv:"TM_INPUT_END_LINE" integer:[[self textStorage] lineNumberAtLocation:NSMaxRange(inputRange)]];
	
	// FIXME: beforeRunningCommand
	
	char *templateFilename = NULL;
	int fd = -1;

	NSString *shellCommand = [command objectForKey:@"command"];
	if ([shellCommand hasPrefix:@"#!"])
	{
		const char *tmpl = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"xi_cmd.XXXXXX"] fileSystemRepresentation];
		INFO(@"using template %s", tmpl);
		templateFilename = strdup(tmpl);
		fd = mkstemp(templateFilename);
		if (fd == -1)
		{
			NSLog(@"failed to open temporary file: %s", strerror(errno));
			return;
		}
		const char *data = [shellCommand UTF8String];
		ssize_t rc = write(fd, data, strlen(data));
		INFO(@"wrote %i byte", rc);
		chmod(templateFilename, 0700);
		shellCommand = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:templateFilename length:strlen(templateFilename)];
	}
	
	INFO(@"input text = [%@]", inputText);
	
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/bash"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];

	id shellInput;
	if ([inputText length] > 0)
		shellInput = [NSPipe pipe];
	else
		shellInput = [NSFileHandle fileHandleWithNullDevice];
	NSPipe *shellOutput = [NSPipe pipe];

	[task setStandardInput:shellInput];
	[task setStandardOutput:shellOutput];
	/* FIXME: set standard error to standard output? */

	NSString *outputFormat = [command objectForKey:@"output"];

	[self setupEnvironmentForCommand:command];
	[task launch];
	if ([inputText length] > 0)
	{
		[[shellInput fileHandleForWriting] writeData:[inputText dataUsingEncoding:NSUTF8StringEncoding]];
		[[shellInput fileHandleForWriting] closeFile];
	}

	[task waitUntilExit];
	int status = [task terminationStatus];

	if (fd != -1)
	{
		unlink(templateFilename);
		close(fd);
		free(templateFilename);
	}

	if (status >= 200 && status <= 207)
	{
		NSArray *overrideOutputFormat = [NSArray arrayWithObjects:
			@"discard",
			@"replaceSelectedText", 
			@"replaceDocument", 
			@"insertAsText", 
			@"insertAsSnippet", 
			@"showAsHTML", 
			@"showAsTooltip", 
			@"createNewDocument", 
			nil];
		outputFormat = [overrideOutputFormat objectAtIndex:status - 200];
		status = 0;
	}

	if (status != 0)
	{
		[[self delegate] message:@"%@: exited with status %i", [command objectForKey:@"name"], status];
	}
	else
	{
		NSData *outputData = [[shellOutput fileHandleForReading] readDataToEndOfFile];
		NSString *outputText = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

		INFO(@"command output: %@", outputText);

		if ([outputFormat isEqualToString:@"replaceSelectedText"])
			[self replaceRange:inputRange withString:outputText undoGroup:NO];
		else if ([outputFormat isEqualToString:@"showAsTooltip"])
		{
			[[self delegate] message:@"%@", [outputText stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
			// [self addToolTipRect: owner:outputText userData:nil];
		}
		else if ([outputFormat isEqualToString:@"showAsHTML"])
		{
			ViCommandOutputController *oc = [[ViCommandOutputController alloc] initWithHTMLString:outputText];
			[[oc window] makeKeyAndOrderFront:self];
		}
		else if ([outputFormat isEqualToString:@"insertAsSnippet"])
			activeSnippet = [self insertSnippet:outputText atLocation:[self caret]];
		else if ([outputFormat isEqualToString:@"discard"])
			;
		else
			INFO(@"unknown output format: %@", outputFormat);
	}
}

@end
