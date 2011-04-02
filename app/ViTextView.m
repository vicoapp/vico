#import "ViTextView.h"
#import "ViLanguageStore.h"
#import "ViThemeStore.h"
#import "ViDocument.h"  // for declaration of the message: method
#import "NSString-scopeSelector.h"
#import "NSString-additions.h"
#import "NSArray-patterns.h"
#import "ViAppController.h"  // for sharedBuffers
#import "ViDocumentView.h"
#import "ViJumpList.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "ViMark.h"
#import "ViCommandMenuItemView.h"
#import "NSScanner-additions.h"
#import "NSEvent-keyAdditions.h"
#import "ViError.h"
#import "ViRegisterManager.h"

int logIndent = 0;

@interface ViTextView (private)
- (void)recordReplacementOfRange:(NSRange)aRange withLength:(NSUInteger)aLength;
- (NSArray *)smartTypingPairsAtLocation:(NSUInteger)aLocation;
- (BOOL)normal_mode:(ViCommand *)command;
- (void)replaceCharactersInRange:(NSRange)aRange
                      withString:(NSString *)aString
                       undoGroup:(BOOL)undoGroup;
- (void)setVisualSelection;
- (void)updateStatus;
@end

#pragma mark -

@implementation ViTextView

@synthesize proxy;

- (void)initEditorWithDelegate:(id)aDelegate viParser:(ViParser *)aParser
{
	[self setDelegate:aDelegate];
	[self setCaret:0];

	keyManager = [[ViKeyManager alloc] initWithTarget:self
					       parser:aParser];

	undoManager = [[self delegate] undoManager];
	if (undoManager == nil)
		undoManager = [[NSUndoManager alloc] init];
	inputKeys = [NSMutableArray array];
	marks = [NSMutableDictionary dictionary];
	saved_column = -1;
	snippetMatchRange.location = NSNotFound;

	wordSet = [NSMutableCharacterSet characterSetWithCharactersInString:@"_"];
	[wordSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	nonWordSet = [[NSMutableCharacterSet alloc] init];
	[nonWordSet formUnionWithCharacterSet:wordSet];
	[nonWordSet formUnionWithCharacterSet:whitespace];
	[nonWordSet invert];

	[self setRichText:NO];
	[self setImportsGraphics:NO];
	[self setAutomaticDashSubstitutionEnabled:NO];
	[self setAutomaticDataDetectionEnabled:NO];
	[self setAutomaticLinkDetectionEnabled:NO];
	[self setAutomaticQuoteSubstitutionEnabled:NO];
	[self setAutomaticSpellingCorrectionEnabled:NO];
	[self setContinuousSpellCheckingEnabled:NO];
	[self setGrammarCheckingEnabled:NO];
	[self setDisplaysLinkToolTips:NO];
	[self setSmartInsertDeleteEnabled:NO];
	[self setAutomaticTextReplacementEnabled:NO];
	[self setUsesFindPanel:YES];
	[self setUsesFontPanel:NO];
	[self setWrapping:[[NSUserDefaults standardUserDefaults] boolForKey:@"wrap"]];
	[self setDrawsBackground:YES];

	DEBUG(@"got %lu lines", [[self textStorage] lineCount]);
	if ([[self textStorage] lineCount] > 3000)
		[[self layoutManager] setAllowsNonContiguousLayout:YES];
	else
		[[self layoutManager] setAllowsNonContiguousLayout:NO];

	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"antialias"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
	antialias = [[NSUserDefaults standardUserDefaults] boolForKey:@"antialias"];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(textStorageDidChangeLines:)
						     name:ViTextStorageChangedLinesNotification 
						   object:[self textStorage]];

	[self setTheme:[[ViThemeStore defaultStore] defaultTheme]];

	proxy = [[ViScriptProxy alloc] initWithObject:self];
}

- (ViTextStorage *)textStorage
{
	return (ViTextStorage *)[super textStorage];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context

{
	if ([keyPath isEqualToString:@"antialias"]) {
		antialias = [[NSUserDefaults standardUserDefaults] boolForKey:keyPath];
		[self setNeedsDisplayInRect:[self bounds]];
	}
}

- (void)textStorageDidChangeLines:(NSNotification *)notification
{
	/*
	 * Don't enable non-contiguous layout unless we have a huge document.
	 * It's buggy and annoying, but layout is unusable on huge documents otherwise...
	 */
	DEBUG(@"got %lu lines", [[self textStorage] lineCount]);
	if ([[self textStorage] lineCount] > 3000) {
		if (![[self layoutManager] allowsNonContiguousLayout])
			[[self layoutManager] setAllowsNonContiguousLayout:YES];
	} else {
		if ([[self layoutManager] allowsNonContiguousLayout])
			[[self layoutManager] setAllowsNonContiguousLayout:NO];
	}
}

- (void)rulerView:(NSRulerView *)aRulerView
  selectFromPoint:(NSPoint)fromPoint
          toPoint:(NSPoint)toPoint
{
	NSInteger fromIndex = [self characterIndexForInsertionAtPoint:fromPoint];
	if (fromIndex == NSNotFound)
		return;

	NSInteger toIndex = [self characterIndexForInsertionAtPoint:toPoint];
	if (toIndex == NSNotFound)
		return;

	if (keyManager.parser.partial) {
		[[self delegate] message:@"Vi command interrupted."];
		[keyManager.parser reset];
	}

	visual_start_location = fromIndex;
	visual_line_mode = YES;
	end_location = toIndex;

	[self setVisualMode];
	[self setCaret:toIndex];
	[self setVisualSelection];
}

- (void)copy:(id)sender
{
	[keyManager handleKeys:[@"\"+y" keyCodes]];
}

- (void)paste:(id)sender
{
	[keyManager handleKeys:[@"\"+P" keyCodes]];
}

- (void)cut:(id)sender
{
	[keyManager handleKeys:[@"\"+x" keyCodes]];
}

- (id <ViTextViewDelegate>)delegate
{
	return (id <ViTextViewDelegate>)[super delegate];
}

- (BOOL)shouldChangeTextInRanges:(NSArray *)affectedRanges
              replacementStrings:(NSArray *)replacementStrings
{
	/*
	 * If called by [super keyDown], just return yes.
	 * This allows us to type dead keys.
	 */
	if (handlingKey)
		return YES;

	/*
	 * Otherwise it's called from somewhere else, typically by
	 * dragging and dropping text, or using an input manager.
	 * We handle it ourselves, and return NO.
	 */

	[self beginUndoGroup];

	NSUInteger i;
	for (i = 0; i < [affectedRanges count]; i++) {
		NSRange range = [[affectedRanges objectAtIndex:i] rangeValue];
		NSString *string = [replacementStrings objectAtIndex:i];
		[self replaceCharactersInRange:range withString:string undoGroup:NO];
	}

	[self endUndoGroup];

	return NO;
}

- (void)setMark:(unichar)name atLocation:(NSUInteger)aLocation
{
	NSUInteger lineno = [[self textStorage] lineNumberAtLocation:aLocation];
	NSUInteger column = [[self textStorage] columnAtLocation:aLocation];
	ViMark *m = [[ViMark alloc] initWithLine:lineno column:column];
	[marks setObject:m forKey:[NSString stringWithFormat:@"%C", name]];
}

#pragma mark -
#pragma mark Convenience methods

- (void)getLineStart:(NSUInteger *)bol_ptr
                 end:(NSUInteger *)end_ptr
         contentsEnd:(NSUInteger *)eol_ptr
         forLocation:(NSUInteger)aLocation
{
	if ([[self textStorage] length] == 0) {
		if (bol_ptr != NULL)
			*bol_ptr = 0;
		if (end_ptr != NULL)
			*end_ptr = 0;
		if (eol_ptr != NULL)
			*eol_ptr = 0;
	} else
		[[[self textStorage] string] getLineStart:bol_ptr
		                                      end:end_ptr
		                              contentsEnd:eol_ptr
		                                 forRange:NSMakeRange(aLocation, 0)];
}

- (void)getLineStart:(NSUInteger *)bol_ptr
                 end:(NSUInteger *)end_ptr
         contentsEnd:(NSUInteger *)eol_ptr
{
	[self getLineStart:bol_ptr
	               end:end_ptr
	       contentsEnd:eol_ptr
	       forLocation:start_location];
}

- (void)setString:(NSString *)aString
{
	NSRange r = NSMakeRange(0, [[self textStorage] length]);
	[[self textStorage] replaceCharactersInRange:r
	                                  withString:aString];
	[[self textStorage] setAttributes:[self typingAttributes]
	                            range:r];
}

- (void)replaceCharactersInRange:(NSRange)aRange
                      withString:(NSString *)aString
                       undoGroup:(BOOL)undoGroup
{
	modify_start_location = aRange.location;

	ViSnippet *snippet = [self delegate].snippet;
	if (snippet) {
		/* Let the snippet drive the changes. */
		if ([snippet replaceRange:aRange withString:aString])
			return;
		[self cancelSnippet:snippet];
	}

	if (undoGroup)
		[self beginUndoGroup];

	[self recordReplacementOfRange:aRange withLength:[aString length]];
	[[self textStorage] replaceCharactersInRange:aRange withString:aString];
	NSRange r = NSMakeRange(aRange.location, [aString length]);
	[[self textStorage] setAttributes:[self typingAttributes]
	                            range:r];

	[self setMark:'.' atLocation:aRange.location];
}

- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)aString
{
	[self replaceCharactersInRange:aRange withString:aString undoGroup:YES];
}

/* Like insertText:, but works within beginEditing/endEditing.
 * Also begins an undo group.
 */
- (void)insertString:(NSString *)aString
          atLocation:(NSUInteger)aLocation
           undoGroup:(BOOL)undoGroup
{
	[self replaceCharactersInRange:NSMakeRange(aLocation, 0) withString:aString undoGroup:undoGroup];
}

- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation
{
	[self insertString:aString atLocation:aLocation undoGroup:YES];
}

- (void)insertString:(NSString *)aString
{
	[self insertString:aString atLocation:[self caret] undoGroup:YES];
}

- (void)deleteRange:(NSRange)aRange undoGroup:(BOOL)undoGroup
{
	[self replaceCharactersInRange:aRange withString:@"" undoGroup:undoGroup];
}

- (void)deleteRange:(NSRange)aRange
{
	[self deleteRange:aRange undoGroup:NO];
}

- (void)replaceRange:(NSRange)aRange withString:(NSString *)aString undoGroup:(BOOL)undoGroup
{
	[self replaceCharactersInRange:aRange withString:aString undoGroup:undoGroup];
}

- (void)replaceRange:(NSRange)aRange withString:(NSString *)aString
{
	[self replaceRange:aRange withString:aString undoGroup:YES];
}

- (void)snippet:(ViSnippet *)snippet replaceCharactersInRange:(NSRange)aRange withString:(NSString *)aString
{
	DEBUG(@"replace range %@ with [%@]", NSStringFromRange(aRange), aString);
	[self beginUndoGroup];
	[self recordReplacementOfRange:aRange withLength:[aString length]];
	[[self textStorage] replaceCharactersInRange:aRange withString:aString];
	NSRange r = NSMakeRange(aRange.location, [aString length]);
	[[self textStorage] setAttributes:[self typingAttributes]
	                            range:r];

	if (modify_start_location > NSMaxRange(r)) {
		NSInteger delta = [aString length] - aRange.length;
		DEBUG(@"modify_start_location %lu -> %lu", modify_start_location, modify_start_location + delta);
		modify_start_location += delta;
	}
}

- (NSArray *)scopesAtLocation:(NSUInteger)aLocation
{
	return [[self delegate] scopesAtLocation:aLocation];
}

#pragma mark -
#pragma mark Indentation

- (NSString *)indentStringOfLength:(NSInteger)length
{
	length = IMAX(length, 0);
	NSInteger tabstop = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"expandtab"] == NSOnState)
	{
		// length * " "
		return [@"" stringByPaddingToLength:length withString:@" " startingAtIndex:0];
	}
	else
	{
		// length / tabstop * "tab" + length % tabstop * " "
		NSInteger ntabs = (length / tabstop);
		NSInteger nspaces = (length % tabstop);
		NSString *indent = [@"" stringByPaddingToLength:ntabs withString:@"\t" startingAtIndex:0];
		return [indent stringByPaddingToLength:ntabs + nspaces withString:@" " startingAtIndex:0];
	}
}

- (NSString *)indentStringForLevel:(int)level
{
	NSInteger shiftWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"shiftwidth"] * level;
	return [self indentStringOfLength:shiftWidth * level];
}

- (NSUInteger)lengthOfIndentString:(NSString *)indent
{
	NSInteger tabStop = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	NSUInteger i;
	NSUInteger length = 0;
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

- (NSUInteger)lenghtOfIndentAtLine:(NSUInteger)lineLocation
{
	return [self lengthOfIndentString:[[self textStorage] leadingWhitespaceForLineAtLocation:lineLocation]];
}

- (BOOL)shouldIncreaseIndentAtLocation:(NSUInteger)aLocation
{
	NSDictionary *increaseIndentPatterns = [[ViLanguageStore defaultStore] preferenceItem:@"increaseIndentPattern"];
	NSString *bestMatchingScope = [self bestMatchingScope:[increaseIndentPatterns allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		NSString *pattern = [increaseIndentPatterns objectForKey:bestMatchingScope];
		ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern];
		NSString *checkLine = [[self textStorage] lineForLocation:aLocation];

		if ([rx matchInString:checkLine])
			return YES;
	}

	return NO;
}

- (BOOL)shouldDecreaseIndentAtLocation:(NSUInteger)aLocation
{
	NSDictionary *decreaseIndentPatterns = [[ViLanguageStore defaultStore] preferenceItem:@"decreaseIndentPattern"];
	NSString *bestMatchingScope = [self bestMatchingScope:[decreaseIndentPatterns allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		NSString *pattern = [decreaseIndentPatterns objectForKey:bestMatchingScope];
		ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern];
		NSString *checkLine = [[self textStorage] lineForLocation:aLocation];

		if ([rx matchInString:checkLine])
			return YES;
	}
	
	return NO;
}

- (BOOL)shouldUnIndentLineAtLocation:(NSUInteger)aLocation
{
	NSDictionary *unIndentPatterns = [[ViLanguageStore defaultStore] preferenceItem:@"unIndentedLinePattern"];
	NSString *bestMatchingScope = [self bestMatchingScope:[unIndentPatterns allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		NSString *pattern = [unIndentPatterns objectForKey:bestMatchingScope];
		ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern];
		NSString *checkLine = [[self textStorage] lineForLocation:aLocation];

		if ([rx matchInString:checkLine])
			return YES;
	}

	return NO;
}

- (NSInteger)calculatedIndentLengthAtLocation:(NSUInteger)aLocation
{
	NSDictionary *indentExpressions = [[ViLanguageStore defaultStore] preferenceItem:@"indentExpression"];
	NSString *bestMatchingScope = [self bestMatchingScope:[indentExpressions allKeys] atLocation:aLocation];
	
	if (bestMatchingScope) {
		NSString *expression = [indentExpressions objectForKey:bestMatchingScope];
		DEBUG(@"running indent expression:\n%@", expression);
		NSError *error = nil;
		id result = [[NSApp delegate] evalExpression:expression error:&error];
		if (error)
			[[self delegate] message:@"indent expression failed: %@", [error localizedDescription]];
		else if ([result isKindOfClass:[NSNumber class]])
			return [result integerValue];
		else
			[[self delegate] message:@"non-numeric result: got %@", NSStringFromClass([result class])];
	}

	return -1;
}

- (NSInteger)insertNewlineAtLocation:(NSUInteger)aLocation indentForward:(BOOL)indentForward
{
        NSString *leading_whitespace = [[self textStorage] leadingWhitespaceForLineAtLocation:aLocation];

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

		NSInteger calcIndent = [self calculatedIndentLengthAtLocation:checkLocation];
		if (calcIndent >= 0) {
			leading_whitespace = [self indentStringOfLength:calcIndent];
		} else if ([self shouldIncreaseIndentAtLocation:checkLocation]) {
			NSInteger shiftWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"shiftwidth"];
			leading_whitespace = [self indentStringOfLength:[self lengthOfIndentString:leading_whitespace] + shiftWidth];
		}

		if (leading_whitespace) {
			[self insertString:leading_whitespace atLocation:aLocation + (indentForward ? 1 : 0)];
			return 1 + [leading_whitespace length];
		}
	}

	return 1;
}

- (NSRange)changeIndentation:(int)delta inRange:(NSRange)aRange updateCaret:(NSUInteger *)updatedCaret
{
	NSInteger shiftWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"shiftwidth"];
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:aRange.location];

	NSRange delta_offset = NSMakeRange(0, 0);
	BOOL has_delta_offset = NO;

	while (bol < NSMaxRange(aRange)) {
		NSString *indent = [[self textStorage] leadingWhitespaceForLineAtLocation:bol];
		NSUInteger n = [self lengthOfIndentString:indent];
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

- (BOOL)increase_indent:(ViCommand *)command
{
        NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
        NSRange n = [self changeIndentation:+1 inRange:NSMakeRange(bol, IMAX(eol - bol, 1))];
        final_location = start_location + n.location;
        return YES;
}

- (BOOL)decrease_indent:(ViCommand *)command
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	NSRange n = [self changeIndentation:-1 inRange:NSMakeRange(bol, eol - bol)];
        final_location = start_location + n.location;
        return YES;
}

#pragma mark -
#pragma mark Undo support

- (IBAction)undo:(id)sender
{
	[self setNormalMode];
	[[self textStorage] beginEditing];
	[undoManager undo];
	[[self textStorage] endEditing];
	[self setCaret:final_location];
}

- (IBAction)redo:(id)sender
{
	[self setNormalMode];
	[[self textStorage] beginEditing];
	[undoManager redo];
	[[self textStorage] endEditing];
	[self setCaret:final_location];
}

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
	if (!hasUndoGroup) {
		[undoManager beginUndoGrouping];
		hasUndoGroup = YES;
	}
}

- (void)undoReplaceOfString:(NSString *)aString inRange:(NSRange)aRange
{
	DEBUG(@"undoing replacement of string %@ in range %@", aString, NSStringFromRange(aRange));
	[self replaceCharactersInRange:aRange withString:aString undoGroup:NO];
	final_location = aRange.location;

	NSUInteger bol, eol, end;
	[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:final_location];
	if (final_location >= eol && final_location > bol)
		final_location = eol - 1;
}

- (void)recordReplacementOfRange:(NSRange)aRange withLength:(NSUInteger)aLength
{
	NSRange newRange = NSMakeRange(aRange.location, aLength);
	NSString *s = [[[self textStorage] string] substringWithRange:aRange];
	DEBUG(@"pushing replacement of range %@ (string [%@]) with %@ onto undo stack",
	    NSStringFromRange(aRange), s, NSStringFromRange(newRange));
	[[undoManager prepareWithInvocationTarget:self] undoReplaceOfString:s inRange:newRange];
	[undoManager setActionName:@"replace text"];
}

#pragma mark -
#pragma mark Register

- (void)yankToRegister:(unichar)regName
                 range:(NSRange)yankRange
{
	NSString *content = [[[self textStorage] string] substringWithRange:yankRange];
	[[ViRegisterManager sharedManager] setContent:content ofRegister:regName];
}

- (void)cutToRegister:(unichar)regName
                range:(NSRange)cutRange
{
	[self yankToRegister:regName range:cutRange];
	[self deleteRange:cutRange undoGroup:YES];
}

#pragma mark -
#pragma mark Convenience methods

- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation
{
	end_location = [[self textStorage] locationForColumn:column
	                                        fromLocation:aLocation
	                                           acceptEOL:(mode == ViInsertMode)];
	final_location = end_location;
}

- (BOOL)gotoLine:(NSUInteger)line column:(NSUInteger)column
{
	NSInteger bol = [[self textStorage] locationForStartOfLine:line];
	if (bol == -1)
		return NO;

	[self gotoColumn:column fromLocation:bol];
	[self setCaret:final_location];
	[self scrollRangeToVisible:NSMakeRange(final_location, 0)];

	return YES;
}

- (BOOL)gotoLine:(NSUInteger)line
{
	return [self gotoLine:line column:1];
}

#pragma mark -
#pragma mark Searching

- (BOOL)findPattern:(NSString *)pattern options:(unsigned)find_options
{
	unsigned rx_options = ONIG_OPTION_NOTBOL | ONIG_OPTION_NOTEOL;
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	if ([defs integerForKey:@"ignorecase"] == NSOnState) {
		if ([defs integerForKey:@"smartcase"] == NSOffState ||
		    [pattern rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location == NSNotFound)
			rx_options |= ONIG_OPTION_IGNORECASE;
	}

	ViRegexp *rx = nil;

	/* compile the pattern regexp */
	@try
	{
		rx = [[ViRegexp alloc] initWithString:pattern
					      options:rx_options];
	}
	@catch(NSException *exception)
	{
		INFO(@"***** FAILED TO COMPILE REGEXP ***** [%@], exception = [%@]", pattern, exception);
		[[self delegate] message:@"Invalid search pattern: %@", exception];
		return NO;
	}

	NSArray *foundMatches = [rx allMatchesInString:[[self textStorage] string]
					       options:rx_options];

	if ([foundMatches count] == 0) {
		[[self delegate] message:@"Pattern not found"];
	} else {
		[self pushLocationOnJumpList:start_location];

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
			[[self nextRunloop] showFindIndicatorForRange:[nextMatch rangeOfMatchedString]];
		}

		return YES;
	}

	return NO;
}

- (void)find_forward_callback:(NSString *)pattern contextInfo:(void *)contextInfo
{
	keyManager.parser.last_search_pattern = pattern;
	keyManager.parser.last_search_options = 0;
	if ([self findPattern:pattern options:0])
		[self setCaret:final_location];
}

- (void)find_backward_callback:(NSString *)pattern contextInfo:(void *)contextInfo
{
	keyManager.parser.last_search_pattern = pattern;
	keyManager.parser.last_search_options = ViSearchOptionBackwards;
	if ([self findPattern:pattern options:ViSearchOptionBackwards])
		[self setCaret:final_location];
}

/* syntax: /regexp */
- (BOOL)find:(ViCommand *)command
{
	[[[self delegate] environment] getExCommandWithDelegate:self
						       selector:@selector(find_forward_callback:contextInfo:)
							 prompt:@"/"
						    contextInfo:command];
	// FIXME: this won't work as a motion command!
	// d/pattern will not work!
	return YES;
}

/* syntax: ?regexp */
- (BOOL)find_backwards:(ViCommand *)command
{
	[[[self delegate] environment] getExCommandWithDelegate:self
						       selector:@selector(find_backward_callback:contextInfo:)
							 prompt:@"?"
						    contextInfo:command];
	// FIXME: this won't work as a motion command!
	// d?pattern will not work!
	return YES;
}

/* syntax: n */
- (BOOL)repeat_find:(ViCommand *)command
{
	NSString *pattern = keyManager.parser.last_search_pattern;
	if (pattern == nil) {
		[[self delegate] message:@"No previous search pattern"];
		return NO;
	}

	return [self findPattern:pattern options:keyManager.parser.last_search_options];
}

/* syntax: N */
- (BOOL)repeat_find_backward:(ViCommand *)command
{
	NSString *pattern = keyManager.parser.last_search_pattern;
	if (pattern == nil) {
		[[self delegate] message:@"No previous search pattern"];
		return NO;
	}

	int options = keyManager.parser.last_search_options;
	if (options & ViSearchOptionBackwards)
		options &= ~ViSearchOptionBackwards;
	else
		options |= ViSearchOptionBackwards;
	return [self findPattern:pattern options:options];
}

#pragma mark -
#pragma mark Caret and selection handling

- (void)scrollToCaret
{
	NSScrollView *scrollView = [self enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];
	NSLayoutManager *layoutManager = [self layoutManager];
        NSRect visibleRect = [clipView bounds];
	NSUInteger glyphIndex = [layoutManager glyphIndexForCharacterAtIndex:[self caret]];
	NSRect rect = [layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 0)
	                                       inTextContainer:[self textContainer]];

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

	if (topPoint.x != visibleRect.origin.x || topPoint.y != visibleRect.origin.y) {
		[clipView scrollToPoint:topPoint];
		[scrollView reflectScrolledClipView:clipView];
	}
}

- (void)setCaret:(NSUInteger)location
{
	NSInteger length = [[self textStorage] length];
	if (mode != ViInsertMode)
		length--;
	if (location > length)
		location = IMAX(0, length);
	caret = location;
	if (mode != ViVisualMode)
		[self setSelectedRange:NSMakeRange(location, 0)];
	if (!replayingInput)
		[self updateCaret];
}

- (NSUInteger)caret
{
	return caret;
}

- (NSRange)selectionRangeForProposedRange:(NSRange)proposedSelRange
                              granularity:(NSSelectionGranularity)granularity
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

- (void)setSelectedRanges:(NSArray *)ranges
                 affinity:(NSSelectionAffinity)affinity
           stillSelecting:(BOOL)stillSelectingFlag
{
	if (showingContextMenu)
		return;

	[super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelectingFlag];

	NSRange firstRange = [[ranges objectAtIndex:0] rangeValue];
	NSRange lastRange = [[ranges lastObject] rangeValue];

	/*DEBUG(@"still selecting = %s, firstRange = %@, lastRange = %@, mode = %i, visual_start = %lu",
	    stillSelectingFlag ? "YES" : "NO",
	    NSStringFromRange(firstRange),
	    NSStringFromRange(lastRange),
	    mode,
	    visual_start_location);*/

	if ([ranges count] > 1 || firstRange.length > 0) {
		if (mode != ViVisualMode) {
			[self setVisualMode];
			[self setCaret:firstRange.location];
			visual_start_location = firstRange.location;
		} else if (stillSelectingFlag) {
			if (visual_start_location == firstRange.location)
				[self setCaret:IMAX(lastRange.location, NSMaxRange(lastRange) - 1)];
			else
				[self setCaret:firstRange.location];
		}
	} else if (stillSelectingFlag) {
		[self setNormalMode];
		if (firstRange.location != [self caret])
			[self setCaret:firstRange.location];
	}

	[self updateStatus];
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
	DEBUG(@"setting normal mode, caret = %u, final_location = %u, length = %u",
	    caret, final_location, [[self textStorage] length]);
	mode = ViNormalMode;
	[self endUndoGroup];
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

	/*
	 * Remember the command that entered insert mode. When leaving insert mode,
	 * we update this command with the inserted text (or keys, actually). This
	 * is used for repeating the insertion with the dot command.
	 */
	lastEditCommand = command;

	if (command) {
		if (command.text) {
			replayingInput = YES;
			[self setCaret:end_location];
			int count = IMAX(1, command.count);
			int i;
			for (i = 0; i < count; i++)
				[keyManager handleKeys:command.text];
			[self normal_mode:command];
			replayingInput = NO;
		}
	}
}

#pragma mark -
#pragma mark Input handling and command evaluation

- (BOOL)handleSmartPair:(NSString *)characters
{
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"smartpair"])
		return NO;

	BOOL foundSmartTypingPair = NO;

	NSArray *smartTypingPairs = [self smartTypingPairsAtLocation:IMIN(start_location, [[self textStorage] length] - 1)];
	NSArray *pair;
	for (pair in smartTypingPairs) {
		/*
		 * Check if we're inserting the end character of a smart typing pair.
		 * If so, just overwrite the end character.
		 * Note: start and end characters might be the same (eg, "").
		 */
		if ([characters isEqualToString:[pair objectAtIndex:1]] &&
		    [[[[self textStorage] string] substringWithRange:NSMakeRange(start_location, 1)] isEqualToString:[pair objectAtIndex:1]]) {
			if ([[self layoutManager] temporaryAttribute:ViSmartPairAttributeName
						    atCharacterIndex:start_location
						      effectiveRange:NULL]) {
				foundSmartTypingPair = YES;
				final_location = start_location + 1;
			}
			break;
		}
		// check for the start character of a smart typing pair
		else if ([characters isEqualToString:[pair objectAtIndex:0]]) {
			/*
			 * Only use if next character is not alphanumeric.
			 * FIXME: ...and next character is not any start character of a smart pair?
			 */
			if (start_location >= [[self textStorage] length] ||
			    ![[NSCharacterSet alphanumericCharacterSet] characterIsMember:[[[self textStorage] string] characterAtIndex:start_location]])
			{
				foundSmartTypingPair = YES;
				[self insertString:[NSString stringWithFormat:@"%@%@",
					[pair objectAtIndex:0],
					[pair objectAtIndex:1]] atLocation:start_location];

				// INFO(@"adding smart pair attr to %u + 2", start_location);
				[[[self layoutManager] nextRunloop] addTemporaryAttribute:ViSmartPairAttributeName
				                                                    value:characters
				                                        forCharacterRange:NSMakeRange(start_location, 2)];

				final_location = start_location + 1;
				break;
			}
		}
	}

	return foundSmartTypingPair;
}

/* Input a character from the user (in insert mode). Handle smart typing pairs.
 * FIXME: assumes smart typing pairs are single characters.
 */
- (void)handle_input:(unichar)character
{
	DEBUG(@"insert character %C at %i", character, start_location);

	// If there is a selected snippet range, remove it first.
	ViSnippet *snippet = [self delegate].snippet;
	NSRange sel = snippet.selectedRange;
	if (sel.length > 0) {
		[self deleteRange:sel];
		start_location = modify_start_location;
	}

	NSString *s = [NSString stringWithFormat:@"%C", character];
	if (![self handleSmartPair:s]) {
		DEBUG(@"%s", "no smart typing pairs triggered");
		[self insertString:s
			atLocation:start_location];
		final_location = modify_start_location + 1;
	}

#if 0
	if ([self shouldDecreaseIndentAtLocation:insert_end_location]) {
                int n = [self changeIndentation:-1 inRange:NSMakeRange(insert_end_location, 1)];
		insert_start_location += n;
		insert_end_location += n;
	} else if ([self shouldUnIndentLineAtLocation:insert_end_location]) {
                int n = [self changeIndentation:-1000 inRange:NSMakeRange(insert_end_location, 1)];
		insert_start_location += n;
		insert_end_location += n;
	}
#endif
}

- (BOOL)literal_next:(ViCommand *)command
{
	[self handle_input:command.argument];
	return YES;
}

- (BOOL)input_character:(ViCommand *)command
{
	for (NSNumber *n in command.mapping.keySequence) {
		NSInteger keyCode = [n integerValue];

		if ((keyCode & 0xFFFF0000) != 0) {
			[[self delegate] message:@"Can't insert key equivalent: %@.",
			    [NSString stringWithKeyCode:keyCode]];
			return NO;
		}

		if (keyCode < 0x20) {
			[[self delegate] message:@"Illegal character: %@; quote to enter",
			    [NSString stringWithKeyCode:keyCode]];
			return NO;
		}

		[self handle_input:keyCode];
		start_location = final_location;
	}

	return YES;
}

- (BOOL)input_newline:(ViCommand *)command
{
	NSInteger num_chars = [self insertNewlineAtLocation:start_location
					      indentForward:YES];
	final_location = start_location + num_chars;
	return YES;
}

- (BOOL)input_tab:(ViCommand *)command
{
	// check if we're inside a snippet
	ViSnippet *snippet = [self delegate].snippet;
	if (snippet) {
		[[self layoutManager] invalidateDisplayForCharacterRange:snippet.selectedRange];
		if ([snippet advance]) {
			final_location = snippet.caret;
			[[self layoutManager] invalidateDisplayForCharacterRange:snippet.selectedRange];
			return YES;
		} else
			[self cancelSnippet:snippet];
	}

	/* Check for a tab trigger before the caret.
	 */
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	NSString *prefix = [[[self textStorage] string] substringWithRange:NSMakeRange(bol, start_location - bol)];
	if ([prefix length] > 0) {
		NSArray *scopes = [self scopesAtLocation:eol];
		NSUInteger triggerLength;
		NSArray *matches = [[ViLanguageStore defaultStore] itemsWithTabTrigger:prefix
									matchingScopes:scopes
										inMode:mode
									 matchedLength:&triggerLength];
		if ([matches count] > 0) {
			snippetMatchRange = NSMakeRange(start_location - triggerLength, triggerLength);
			[self performBundleItems:matches];
			return NO;
		}
	}

	// otherwise just insert a tab
	[self insertString:@"\t" atLocation:start_location];
	final_location = start_location + 1;

	return YES;
}

- (NSArray *)smartTypingPairsAtLocation:(NSUInteger)aLocation
{
	NSDictionary *smartTypingPairs = [[ViLanguageStore defaultStore] preferenceItem:@"smartTypingPairs"];
	NSString *bestMatchingScope = [self bestMatchingScope:[smartTypingPairs allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		DEBUG(@"found smart typing pair scope selector [%@] at location %i", bestMatchingScope, aLocation);
		return [smartTypingPairs objectForKey:bestMatchingScope];
	}

	return nil;
}

- (BOOL)input_backspace:(ViCommand *)command
{
	// If there is a selected snippet range, remove it first.
	ViSnippet *snippet = [self delegate].snippet;
	NSRange sel = snippet.selectedRange;
	if (sel.length > 0) {
		[self deleteRange:sel];
		start_location = modify_start_location;
		return YES;
	}

	if (start_location == 0) {
		[[self delegate] message:@"Already at the beginning of the document"];
		return YES;
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
			final_location = modify_start_location;
			return YES;
		}
	}

	/* else a regular character, just delete it */
	[self deleteRange:NSMakeRange(start_location - 1, 1)];
	final_location = modify_start_location;

	return YES;
}

- (BOOL)input_forward_delete:(ViCommand *)command
{
	/* FIXME: should handle smart typing pairs here!
	 */
	[self deleteRange:NSMakeRange(start_location, 1)];
	final_location = start_location;
	return YES;
}

- (BOOL)normal_mode:(ViCommand *)command
{
	if (mode == ViInsertMode) {
		if (!replayingInput) {
			/*
			 * Remember the typed keys so we can repeat it
			 * with the dot command.
			 */
			[lastEditCommand setText:inputKeys];

			/*
			 * A count given to the command that started insert
			 * mode (i, I, a or A) means we should multiply the
			 * inserted text.
			 */
			DEBUG(@"last edit command is %@, got %lu input keys",
			    lastEditCommand, [inputKeys count]);
			int count = IMAX(1, lastEditCommand.count);
			if (count > 1) {
				replayingInput = YES;
				for (int i = 1; i < count; i++)
					[keyManager handleKeys:inputKeys];
				replayingInput = NO;
			}
		}

		inputKeys = [NSMutableArray array];
		start_location = end_location = [self caret];
		[self move_left:nil];
	}

	[self setNormalMode];
	[self setCaret:final_location];
	[self resetSelection];

	return YES;
}

- (void)updateStatus
{
	const char *modestr = "";
	if (mode == ViInsertMode) {
		if ([self delegate].snippet)
			modestr = "--SNIPPET--";
		else
			modestr = "--INSERT--";
	} else if (mode == ViVisualMode) {
		if (visual_line_mode)
			modestr = "--VISUAL LINE--";
		else
			modestr = "--VISUAL--";
	}
	[[self delegate] message:[NSString stringWithFormat:@"%lu,%lu   %s",
	    (unsigned long)[self currentLine],
	    (unsigned long)[self currentColumn],
	    modestr]];
}

- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command
{
	if (mode != ViInsertMode)
		[self endUndoGroup];

	if (![self respondsToSelector:command.action]) {
		[[self delegate] message:@"Command %@ not implemented.",
		    command.mapping.keyString];
		return NO;
	}

	if (command.motion && ![self respondsToSelector:command.motion.action]) {
		[[self delegate] message:@"Motion command %@ not implemented.",
		    command.motion.mapping.keyString];
		return NO;
	}

	/* Default start- and end-location is the current location. */
	start_location = [self caret];
	end_location = start_location;
	final_location = start_location;
	DEBUG(@"start_location = %u", start_location);

	/* Set or reset the saved column for up/down movement. */
	if (command.action == @selector(move_down:) ||
	    command.action == @selector(move_up:) ||
	    command.action == @selector(scroll_down_by_line:) ||
	    command.action == @selector(scroll_up_by_line:) ||
	    command.motion.action == @selector(move_down:) ||
	    command.motion.action == @selector(move_up:) ||
	    command.motion.action == @selector(scroll_down_by_line:) ||
	    command.motion.action == @selector(scroll_up_by_line:)) {
		if (saved_column < 0)
			saved_column = [self currentColumn];
	} else
		saved_column = -1;

	if (command.action != @selector(vi_undo:) && !command.fromDot)
		undo_direction = 0;

	if (command.motion) {
		/* The command has an associated motion component.
		 * Run the motion command and record the start and end locations.
		 */
		DEBUG(@"perform motion command %@", command.motion);
		if (![self performSelector:command.motion.action
			        withObject:command.motion])
			/* the command failed */
			return NO;
	}

	/* Find out the affected range for this command. */
	NSUInteger l1, l2;
	if (mode == ViVisualMode) {
		NSRange sel = [self selectedRange];
		l1 = sel.location;
		l2 = NSMaxRange(sel);
	} else {
		l1 = start_location, l2 = end_location;
		if (l2 < l1) {
			/* swap if end < start */
			l2 = l1;
			l1 = end_location;
		}
	}
	DEBUG(@"affected locations: %u -> %u (%u chars), caret = %u, length = %u",
	    l1, l2, l2 - l1, [self caret], [[self textStorage] length]);

	if (command.isLineMode && !command.isMotion && mode != ViVisualMode) {
		/*
		 * If this command is line oriented, extend the
		 * affectedRange to whole lines. However, don't
		 * do this for Visual-Line mode, this is done in
		 * setVisualSelection.
		 */
		NSUInteger bol, end, eol;
		[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:l1];

		if (command.motion == nil) {
			/*
			 * This is a "doubled" command (like dd or yy).
			 * A count affects that number of whole lines.
			 */
			int line_count = command.count;
			while (--line_count > 0) {
				l2 = end;
				[self getLineStart:NULL
					       end:&end
				       contentsEnd:NULL
				       forLocation:l2];
			}
		} else
			[self getLineStart:NULL
				       end:&end
			       contentsEnd:NULL
			       forLocation:l2];

		l1 = bol;
		l2 = end;
		DEBUG(@"after line mode correction: %u -> %u (%u chars)",
		    l1, l2, l2 - l1);
	}
	affectedRange = NSMakeRange(l1, l2 - l1);

	BOOL leaveVisualMode = NO;
	if (mode == ViVisualMode && !command.isMotion &&
	    command.action != @selector(visual:) &&
	    command.action != @selector(visual_line:)) {
		/* If in visual mode, edit commands leave visual mode. */
		leaveVisualMode = YES;
	}

	DEBUG(@"perform command %@", command);
	DEBUG(@"start_location = %u", start_location);
	BOOL ok = (NSUInteger)[self performSelector:command.action withObject:command];
	if (ok && command.isLineMode && !command.isMotion &&
	    command.action != @selector(yank:) &&
	    command.action != @selector(shift_right:) &&
	    command.action != @selector(shift_left:) &&
	    command.action != @selector(subst_lines:))
	{
		/* For line mode operations, we always end up at the beginning of the line. */
		/* ...well, except for yy :-) */
		/* ...and > */
		/* ...and < */
		// FIXME: this is not a generic case!
		NSUInteger bol;
		[self getLineStart:&bol
			       end:NULL
		       contentsEnd:NULL
		       forLocation:final_location];
		final_location = bol;
	}

	if (leaveVisualMode && mode == ViVisualMode) {
		/* If the command didn't itself leave visual mode, do it now. */
		[self setNormalMode];
		[self resetSelection];
	}

	DEBUG(@"final_location is %u", final_location);
	if (final_location != NSNotFound)
		[self setCaret:final_location];
	if (mode == ViVisualMode)
		[self setVisualSelection];

	if (!replayingInput)
		[self scrollToCaret];

	if (ok)
		[self updateStatus];

	return ok;
}

- (void)insertText:(id)aString replacementRange:(NSRange)replacementRange
{
	NSString *string;

	if ([aString isMemberOfClass:[NSAttributedString class]])
		string = [aString string];
	else
		string = aString;

	DEBUG(@"string = [%@], len %i, replacementRange = %@",
	    string, [string length], NSStringFromRange(replacementRange));

	if ([self hasMarkedText])
		[self unmarkText];

	/*
	 * For some weird reason, ctrl-alt-a wants to insert the character 0x01.
	 * We don't want that, but rather have the opportunity to map it.
	 * If you want a real 0x01 (ctrl-a) in the text, type <ctrl-v><ctrl-a>.
	 */
	if ([string length] > 0) {
		unichar ch = [string characterAtIndex:0];
		if (ch < 0x20)
			return;
	}

	if (replacementRange.location == NSNotFound) {
		NSInteger i;
		for (i = 0; i < [string length]; i++)
			[keyManager handleKey:[string characterAtIndex:i]];
		insertedKey = YES;
	}
}

- (void)doCommandBySelector:(SEL)aSelector
{
	DEBUG(@"selector = %@ (ignored)", NSStringFromSelector(aSelector));
}

- (void)keyManager:(ViKeyManager *)aKeyManager
      presentError:(NSError *)error
{
	[[self delegate] message:@"%@", [error localizedDescription]];
}

- (void)keyManager:(ViKeyManager *)aKeyManager
  partialKeyString:(NSString *)keyString
{
	[[self delegate] message:@"%@", keyString];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	DEBUG(@"got key equivalent event %p = %@", theEvent, theEvent);

	if ([[self window] firstResponder] != self)
		return NO;

	return [keyManager performKeyEquivalent:theEvent];
}

- (void)keyDown:(NSEvent *)theEvent
{
	DEBUG(@"got keyDown event: %p = %@", theEvent, theEvent);

#if 0
	NSResponder *r = [[self window] firstResponder];
	if (r && r != self && r == [[self window] fieldEditor:NO forObject:nil]) {
		/* Pass the (generated) event to the ex command line. */
		INFO(@"passing generated key event to ex command line %@", r);
		[r keyDown:theEvent];
		return;
	}
#endif

	handlingKey = YES;
	[super keyDown:theEvent];
	handlingKey = NO;
	DEBUG(@"done interpreting key events, inserted key = %s",
	    insertedKey ? "YES" : "NO");

	if (!insertedKey && ![self hasMarkedText]) {
		DEBUG(@"decoding event %@", theEvent);
		[keyManager keyDown:theEvent];
	}
	insertedKey = NO;
}

- (BOOL)keyManager:(ViKeyManager *)aKeyManager
    shouldParseKey:(NSInteger)keyCode
{
	if (mode == ViInsertMode && !replayingInput && keyCode != 0x1B) {
		/* Add the key to the input replay queue. */
		[inputKeys addObject:[NSNumber numberWithInteger:keyCode]];
	}

//	[proxy emit:@"keyDown" with:self, keyCode, nil];

	/*
	 * Find and perform bundle commands. Show a menu with commands
	 * if multiple matches found.
	 * FIXME: should this be part of the key replay queue?
	 */
	if (!keyManager.parser.partial) {
		NSArray *scopes = [self scopesAtLocation:[self caret]];
		NSArray *matches = [[ViLanguageStore defaultStore] itemsWithKeyCode:keyCode
								     matchingScopes:scopes
									     inMode:mode];
		if ([matches count] > 0) {
			[self performBundleItems:matches];
			return NO; /* We already handled the key */
		}
	}

	if (!keyManager.parser.partial) {
		if (mode == ViVisualMode)
			[keyManager.parser setVisualMap];
		else if (mode == ViInsertMode)
			[keyManager.parser setInsertMap];
	}

	return YES;
}

- (void)swipeWithEvent:(NSEvent *)event
{
	BOOL rc = NO, keep_message = NO;

	DEBUG(@"got swipe event %@", event);

	if ([event deltaX] != 0 && mode == ViInsertMode) {
		[[self delegate] message:@"Swipe event interrupted text insert mode."];
		[self normal_mode:lastEditCommand];
		keep_message = YES;
	}

	if ([event deltaX] > 0)
		rc = [self jumplist_backward:nil];
	else if ([event deltaX] < 0)
		rc = [self jumplist_forward:nil];

	if (rc == YES && !keep_message)
		[[self delegate] message:@""]; // erase any previous message
}

/* Takes a string of characters and creates key events for each one.
 * Then feeds them into the keyDown method to simulate key presses.
 */
- (void)input:(NSString *)inputString
{
	NSArray *keys = [inputString keyCodes];
	if (keys == nil) {
		INFO(@"invalid key sequence: %@", inputString);
		return;
	}
	[keyManager handleKeys:keys];
}

#pragma mark -

/* This is stolen from Smultron.
 */
- (void)drawPageGuideInRect:(NSRect)rect
{
	if (pageGuideX > 0) {
		NSRect bounds = [self bounds];
		if ([self needsToDrawRect:NSMakeRect(pageGuideX, 0, 1, bounds.size.height)] == YES) {
			// So that it doesn't draw the line if only e.g. the cursor updates
			[[[self insertionPointColor] colorWithAlphaComponent:0.3] set];
			[NSBezierPath strokeRect:NSMakeRect(pageGuideX, 0, 0, bounds.size.height)];
		}
	}
}

- (void)setPageGuide:(NSInteger)pageGuideValue
{
	if (pageGuideValue == 0)
		pageGuideX = 0;
	else {
		NSDictionary *sizeAttribute = [[NSDictionary alloc] initWithObjectsAndKeys:[self font], NSFontAttributeName, nil];
		CGFloat sizeOfCharacter = [@" " sizeWithAttributes:sizeAttribute].width;
		pageGuideX = (sizeOfCharacter * (pageGuideValue + 1)) - 1.5;
		// -1.5 to put it between the two characters and draw only on one pixel and
		// not two (as the system draws it in a special way), and that's also why the
		// width above is set to zero
	}
	[self display];
}

- (void)setWrapping:(BOOL)enabled
{
	const float LargeNumberForText = 1.0e7;

	NSScrollView *scrollView = [self enclosingScrollView];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setHasHorizontalScroller:!enabled];
	[scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

	NSTextContainer *textContainer = [self textContainer];
	if (enabled)
		[textContainer setContainerSize:NSMakeSize([scrollView contentSize].width, LargeNumberForText)];
	else
		[textContainer setContainerSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[textContainer setWidthTracksTextView:enabled];
	[textContainer setHeightTracksTextView:NO];

	if (enabled)
		[self setMaxSize:NSMakeSize([scrollView contentSize].width, LargeNumberForText)];
	else
		[self setMaxSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
	[self setHorizontallyResizable:!enabled];
	[self setVerticallyResizable:YES];
	[self setAutoresizingMask:(enabled ? NSViewWidthSizable : NSViewNotSizable)];
}

- (void)setTheme:(ViTheme *)aTheme
{
	caretColor = [[[ViThemeStore defaultStore] defaultTheme] caretColor];
	[self setBackgroundColor:[aTheme backgroundColor]];
	[[self enclosingScrollView] setBackgroundColor:[aTheme backgroundColor]];
	[self setInsertionPointColor:[aTheme caretColor]];
	[self setSelectedTextAttributes:[NSDictionary dictionaryWithObject:[aTheme selectionColor]
								    forKey:NSBackgroundColorAttributeName]];
}

- (NSFont *)font
{
	return [[self delegate] font];
}

- (void)setTypingAttributes:(NSDictionary *)attributes
{
//	DEBUG(@"ignored, attributes = %@", attributes);
}

- (NSDictionary *)typingAttributes
{
	return [[self delegate] typingAttributes];
}

- (NSUInteger)currentLine
{
	return [[self textStorage] lineNumberAtLocation:[self caret]];
}

- (NSUInteger)currentColumn
{
	return [[self textStorage] columnAtLocation:[self caret]];
}

- (BOOL)show_scope:(ViCommand *)command
{
	[[self delegate] message:[[self scopesAtLocation:[self caret]] componentsJoinedByString:@" "]];
	return NO;
}

/* syntax: ctrl-^ */
- (BOOL)switch_file:(ViCommand *)command
{
	[[[self window] windowController] selectLastDocument];
	return YES;
}

- (BOOL)switch_tab:(ViCommand *)command
{
	if (![command.mapping.parameter respondsToSelector:@selector(intValue)]) {
		[[self delegate] message:@"Unexpected parameter type %@",
		    NSStringFromClass([command.mapping.parameter class])];
		return NO;
	}
	int arg = [command.mapping.parameter intValue];
	[[[self window] windowController] selectTabAtIndex:arg];
	return YES;
}

- (void)pushLocationOnJumpList:(NSUInteger)aLocation
{
	ViJumpList *jumplist = [[[self window] windowController] jumpList];
	[jumplist pushURL:[[self delegate] fileURL]
		     line:[[self textStorage] lineNumberAtLocation:aLocation]
		   column:[[self textStorage] columnAtLocation:aLocation]
		     view:self];
}

- (void)pushCurrentLocationOnJumpList
{
	[self pushLocationOnJumpList:[self caret]];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
	NSMenu *menu = [self menuForEvent:theEvent];
	[NSMenu popUpContextMenu:menu withEvent:theEvent forView:self];

	/*
	 * Must remove the bundle menu items, otherwise the key equivalents
	 * remain active and interfere with the handling in keyDown:.
	 */
	[menu removeAllItems];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	NSMenu *menu = [super menuForEvent:theEvent];
	int n = 0;

	NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSInteger charIndex = [self characterIndexForInsertionAtPoint:point];
	if (charIndex == NSNotFound)
		return menu;

	[self setCaret:charIndex];
	NSArray *scopes = [self scopesAtLocation:charIndex];
	NSRange sel = [self selectedRange];
	NSMenuItem *item;
	NSMenu *submenu;

	for (ViBundle *bundle in [[ViLanguageStore defaultStore] allBundles]) {
		submenu = [bundle menuForScopes:scopes
				   hasSelection:sel.length > 0
					   font:[menu font]];
		if (submenu) {
			item = [menu insertItemWithTitle:[bundle name]
						  action:NULL
					   keyEquivalent:@""
						 atIndex:n++];
			[item setSubmenu:submenu];
		}
	}

	if (n > 0)
		[menu insertItem:[NSMenuItem separatorItem] atIndex:n++];

	ViLanguage *curLang = [[self delegate] language];

	submenu = [[NSMenu alloc] initWithTitle:@"Language syntax"];
	item = [menu insertItemWithTitle:@"Language syntax"
				  action:NULL
			   keyEquivalent:@""
				 atIndex:n++];
	[item setSubmenu:submenu];

	item = [submenu addItemWithTitle:@"Unknown"
				  action:@selector(setLanguageAction:)
			   keyEquivalent:@""];
	[item setTag:1001];
	[item setEnabled:NO];
	if (curLang == nil)
		[item setState:NSOnState];
	[submenu addItem:[NSMenuItem separatorItem]];

	NSArray *languages = [[ViLanguageStore defaultStore] languages];
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
	NSArray *sortedLanguages = [languages sortedArrayUsingDescriptors:[NSArray arrayWithObject:descriptor]];

	for (ViLanguage *lang in sortedLanguages) {
		item = [submenu addItemWithTitle:[lang displayName]
					  action:@selector(setLanguageAction:)
				   keyEquivalent:@""];
		[item setRepresentedObject:lang];
		if (curLang == lang)
			[item setState:NSOnState];
	}

	if ([languages count] > 0)
		[submenu addItem:[NSMenuItem separatorItem]];
	[submenu addItemWithTitle:@"Get more bundles..."
			   action:@selector(getMoreBundles:)
		    keyEquivalent:@""];

	[menu insertItem:[NSMenuItem separatorItem] atIndex:n];

	return menu;
}

- (IBAction)performNormalModeMenuItem:(id)sender
{
	if (keyManager.parser.partial) {
		[[[self delegate] nextRunloop] message:@"Vi command interrupted."];
		[keyManager.parser reset];
	}

	ViCommandMenuItemView *view = (ViCommandMenuItemView *)[sender view];
	if (view) {
		NSString *command = view.command;
		if (command) {
			if (mode == ViInsertMode)
				[self setNormalMode];
			DEBUG(@"performing command: %@", command);
			[self input:command];
		}
	}
}

- (BOOL)show_bundle_menu:(ViCommand *)command
{
	showingContextMenu = YES;	/* XXX: this disables the selection caused by NSMenu. */
	[self rightMouseDown:[self popUpContextEvent]];
	showingContextMenu = NO;
	return YES;
}

- (NSEvent *)popUpContextEvent
{
	NSPoint point = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange([self caret], 0)
							inTextContainer:[self textContainer]].origin;
	NSEvent *ev = [NSEvent mouseEventWithType:NSRightMouseDown
			  location:[self convertPoint:point toView:nil]
		     modifierFlags:0
			 timestamp:[[NSDate date] timeIntervalSinceNow]
		      windowNumber:[[self window] windowNumber]
			   context:[NSGraphicsContext currentContext]
		       eventNumber:0
			clickCount:1
			  pressure:1.0];
	return ev;
}

- (void)popUpContextMenu:(NSMenu *)menu
{
	showingContextMenu = YES;	/* XXX: this disables the selection caused by NSMenu. */
	[NSMenu popUpContextMenu:menu withEvent:[self popUpContextEvent] forView:self];
	showingContextMenu = NO;
}

@end

