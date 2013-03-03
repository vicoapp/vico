/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViTextView.h"
#import "ViBundleStore.h"
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
#import "ViLayoutManager.h"
#import "NSView-additions.h"
#import "ViPreferencePaneEdit.h"
#import "ViTaskRunner.h"
#import "ViEventManager.h"

#import <objc/runtime.h>

int logIndent = 0;

@interface ViTextView (private)
- (void)recordReplacementOfRange:(NSRange)aRange withLength:(NSUInteger)aLength;
- (NSArray *)smartTypingPairsAtLocation:(NSUInteger)aLocation;
- (BOOL)normal_mode:(ViCommand *)command;
- (void)replaceCharactersInRange:(NSRange)aRange
                      withString:(NSString *)aString
                       undoGroup:(BOOL)undoGroup;
- (void)setVisualSelection;
- (void)postModeChangedNotification;
- (NSUInteger)removeTrailingAutoIndentForLineAtLocation:(NSUInteger)aLocation;
- (void)setCaret:(NSUInteger)location updateSelection:(BOOL)updateSelection;
@end

#pragma mark -

@implementation ViTextView

@synthesize keyManager = _keyManager;
@synthesize document;
@synthesize mode;
@synthesize visual_line_mode;
@synthesize initialFindPattern = _initialFindPattern;
@synthesize initialExCommand = _initialExCommand;
@synthesize caretColor = _caretColor;
@synthesize lineHighlightColor = _lineHighlightColor;
@synthesize lastEditCommand = _lastEditCommand;
@synthesize undoManager = _undoManager;
@synthesize initialMark = _initialMark;

+ (ViTextView *)makeFieldEditorWithTextStorage:(ViTextStorage *)textStorage
{
	ViLayoutManager *layoutManager = [[[ViLayoutManager alloc] init] autorelease];
	[textStorage addLayoutManager:layoutManager];
	NSTextContainer *container = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(100, 10)] autorelease];
	[layoutManager addTextContainer:container];
	[layoutManager setShowsControlCharacters:YES];
	NSRect frame = NSMakeRect(0, 0, 100, 10);
	ViTextView *editor = [[ViTextView alloc] initWithFrame:frame textContainer:container];
	ViParser *fieldParser = [ViParser parserWithDefaultMap:[ViMap mapWithName:@"exCommandMap"]];
	[editor setFieldEditor:YES];
	[editor initWithDocument:nil viParser:fieldParser];
	return [editor autorelease];
}

- (void)initWithDocument:(ViDocument *)aDocument viParser:(ViParser *)aParser
{
	MEMDEBUG(@"init %p", self);
	[self setKeyManager:[ViKeyManager keyManagerWithTarget:self parser:aParser]];

	mode = ViNormalMode;
	document = [aDocument retain];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(documentRemoved:)
						     name:ViDocumentRemovedNotification
						   object:document];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(documentBusyChanged:)
						     name:ViDocumentBusyChangedNotification
						   object:document];

	_undoManager = [[document undoManager] retain];
	if (_undoManager == nil) {
		_undoManager = [[NSUndoManager alloc] init];
		[_undoManager setGroupsByEvent:NO];
	}
	_inputKeys = [[NSMutableArray alloc] init];
	saved_column = -1;
	reverted_line = -1;
	snippetMatchRange.location = NSNotFound;
	original_insert_source = [[NSApp delegate] original_input_source];
	_taskRunner = [[ViTaskRunner alloc] init];

	_wordSet = [[NSMutableCharacterSet characterSetWithCharactersInString:@"_"] retain];
	[_wordSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	_whitespace = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];

	_nonWordSet = [[NSMutableCharacterSet alloc] init];
	[_nonWordSet formUnionWithCharacterSet:_wordSet];
	[_nonWordSet formUnionWithCharacterSet:_whitespace];
	[_nonWordSet invert];

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
	[self setDrawsBackground:YES];

	DEBUG(@"got %lu lines", [[self textStorage] lineCount]);
	if ([[self textStorage] lineCount] > 3000)
		[[self layoutManager] setAllowsNonContiguousLayout:YES];
	else
		[[self layoutManager] setAllowsNonContiguousLayout:NO];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults addObserver:self forKeyPath:@"theme" options:NSKeyValueObservingOptionNew context:NULL];
	[defaults addObserver:self forKeyPath:@"antialias" options:NSKeyValueObservingOptionNew context:NULL];
	[defaults addObserver:self forKeyPath:@"cursorline" options:NSKeyValueObservingOptionNew context:NULL];
	[defaults addObserver:self forKeyPath:@"blinkmode" options:NSKeyValueObservingOptionNew context:NULL];
	[defaults addObserver:self forKeyPath:@"blinktime" options:NSKeyValueObservingOptionNew context:NULL];

	antialias = [defaults boolForKey:@"antialias"];
	_highlightCursorLine = [defaults boolForKey:@"cursorline"];

	caretBlinkTime = [defaults floatForKey:@"blinktime"];
	NSString *blinkmode = [defaults stringForKey:@"blinkmode"];
	if ([blinkmode isEqualToString:@"insert"])
		caretBlinkMode = ViInsertMode;
	else if ([blinkmode isEqualToString:@"normal"])
		caretBlinkMode = ViNormalMode | ViVisualMode;
	else if ([blinkmode isEqualToString:@"both"])
		caretBlinkMode = ViInsertMode | ViNormalMode | ViVisualMode;

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(textStorageDidChangeLines:)
						     name:ViTextStorageChangedLinesNotification
						   object:[self textStorage]];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(frameDidChange:)
						     name:NSViewFrameDidChangeNotification
						   object:self];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(enclosingFrameDidChange:)
						     name:NSViewFrameDidChangeNotification
						   object:[self enclosingScrollView]];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(windowBecameKey:)
						     name:NSWindowDidBecomeKeyNotification
						   object:[self window]];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(windowResignedKey:)
						     name:NSWindowDidResignKeyNotification
						   object:[self window]];

	[self setTheme:[[ViThemeStore defaultStore] defaultTheme]];
	[self setCaret:0];
	[self updateFont];

	[self postModeChangedNotification];
}

- (NSPoint)textContainerOrigin
{
	NSPoint origin = [super textContainerOrigin];
	if (![self isFieldEditor]) {
		// Add two pixel space at top of text container.
		// XXX: using -setTextContainerInset proved to be too buggy.
		origin.y += 2;
	}
	return origin;
}


DEBUG_FINALIZE();

- (void)dealloc
{
	DEBUG_DEALLOC();

	[[ViEventManager defaultManager] clearFor:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObserver:self forKeyPath:@"theme"];
	[defaults removeObserver:self forKeyPath:@"antialias"];
	[defaults removeObserver:self forKeyPath:@"cursorline"];
	[defaults removeObserver:self forKeyPath:@"blinkmode"];
	[defaults removeObserver:self forKeyPath:@"blinktime"];

	[document release];
	[_keyManager setTarget:nil];
	[_keyManager release];
	[_lastEditCommand release];
	[_inputKeys release];
	[_undoManager release];
	[_caretColor release];
	[_lineHighlightColor release];
	[_caretBlinkTimer release];
	[_taskRunner release];

	[_initialExCommand release];
	[_initialFindPattern release];

	[_wordSet release];
	[_whitespace release];
	[_nonWordSet release];

	[super dealloc];
}

- (void)documentRemoved:(NSNotification *)notification
{
	if ([notification object] != document)
		return;

	DEBUG(@"document removed %@ from text view %@", document, self);

	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:ViDocumentRemovedNotification
						      object:document];

	[document release];
	document = nil;
}

- (void)documentBusyChanged:(NSNotification *)notification
{
	if ([notification object] != document)
		return;

	[self postModeChangedNotification];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViTextView %p>", self];
}

- (void)prepareRevertDocument
{
	reverted_line = [self currentLine];
	reverted_column = [self currentColumn];
}

- (BOOL)gotoMark:(ViMark *)mark
{
	if (document && ![document isEntireFileLoaded]) {
		[self setInitialMark:mark];
	} else {
		NSRange range = mark.range;
		if (mark.line < 0)
			return YES;
		if (range.location >= [[self textStorage] length])
			return NO;
		[self setCaret:range.location];
		[self scrollRangeToVisible:range];
		[[self nextRunloop] showFindIndicatorForRange:range];
	}
	return YES;
}

- (void)documentDidLoad:(ViDocument *)aDocument
{
	if (initial_line >= 0)
		[self gotoLine:initial_line column:initial_column];
	else if (reverted_line >= 0)
		[self gotoLine:reverted_line column:reverted_column];

	if (_initialMark)
		[self gotoMark:_initialMark];

	if (_initialFindPattern)
		[self findPattern:_initialFindPattern options:initial_find_options];

	NSUInteger len = [[self textStorage] length];
	if ([self caret] >= len) {
		[self setCaret:IMAX(0, len - 1)];
		[self scrollRangeToVisible:NSMakeRange(final_location, 0)];
	}

	if (_initialExCommand)
		[self evalExString:_initialExCommand];

	initial_line = -1;
	reverted_line = -1;

	[self setInitialExCommand:nil];
	[self setInitialFindPattern:nil];
	[self setInitialMark:nil];
}

- (NSSize)frameSizeInCharacters
{
	NSRect rect = [[self enclosingScrollView] frame];
	return NSMakeSize(rect.size.width / _characterSize.width, rect.size.height / _characterSize.height);
}

- (void)enclosingFrameDidChange:(NSNotification *)notification
{
	[[ViEventManager defaultManager] emit:ViEventTextFrameDidChange
					  for:self
					 with:self, [NSValue valueWithSize:[self frameSizeInCharacters]], nil];
}

- (void)frameDidChange:(NSNotification *)notification
{
	[[[self enclosingScrollView] verticalRulerView] setNeedsDisplay:YES];
	[[self layoutManager] invalidateDisplayForCharacterRange:NSMakeRange([self caret], 1)];
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
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([keyPath isEqualToString:@"antialias"]) {
		antialias = [defaults boolForKey:keyPath];
		[self setNeedsDisplayInRect:[self bounds]];
	} else if ([keyPath isEqualToString:@"theme"]) {
		/*
		 * Change the theme and invalidate all layout.
		 */
		ViTheme *theme = [[ViThemeStore defaultStore] themeWithName:[change objectForKey:NSKeyValueChangeNewKey]];
		[self setTheme:theme];
		ViLayoutManager *lm = (ViLayoutManager *)[self layoutManager];
		[lm setInvisiblesAttributes:[theme invisiblesAttributes]];
		[lm invalidateDisplayForCharacterRange:NSMakeRange(0, [[self textStorage] length])];
	} else if ([keyPath isEqualToString:@"cursorline"]) {
		_highlightCursorLine = [defaults boolForKey:keyPath];
		[self invalidateCaretRect];
	} else if ([keyPath isEqualToString:@"blinktime"]) {
		caretBlinkTime = [defaults floatForKey:@"blinktime"];
		[self updateCaret];
	} else if ([keyPath isEqualToString:@"blinkmode"]) {
		NSString *blinkmode = [defaults stringForKey:@"blinkmode"];
		if ([blinkmode isEqualToString:@"insert"])
			caretBlinkMode = ViInsertMode;
		else if ([blinkmode isEqualToString:@"normal"])
			caretBlinkMode = ViNormalMode | ViVisualMode;
		else if ([blinkmode isEqualToString:@"both"])
			caretBlinkMode = ViInsertMode | ViNormalMode | ViVisualMode;
		else
			caretBlinkMode = 0;
		[self updateCaret];
	}
}

- (void)textStorageDidChangeLines:(NSNotification *)notification
{
	/*
	 * Don't enable non-contiguous layout unless we have a huge document.
	 * It's buggy and annoying, but layout is unusable on huge documents otherwise...
	 */
	DEBUG(@"got %lu lines", [[self textStorage] lineCount]);
	if ([self isFieldEditor])
		return;
	if ([[self textStorage] lineCount] > 3000)
		[[self layoutManager] setAllowsNonContiguousLayout:YES];
	else
		[[self layoutManager] setAllowsNonContiguousLayout:NO];
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

	if (_keyManager.parser.partial) {
		MESSAGE(@"Vi command interrupted.");
		[_keyManager.parser reset];
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
	if ([self isFieldEditor]) {
		[super copy:sender];
	} else {
		[_keyManager handleKeys:[@"\"+y" keyCodes]];
	}
}

- (void)paste:(id)sender
{
	if ([self isFieldEditor]) {
		[super paste:sender];
	} else {
		[_keyManager handleKeys:[@"\"+P" keyCodes]];
	}
}

- (void)cut:(id)sender
{
	if ([self isFieldEditor]) {
		NSBeep();
	} else {
		[_keyManager handleKeys:[@"\"+x" keyCodes]];
	}
}

- (void)selectAll:(id)sender
{
	if ([self isFieldEditor]) {
		[super selectAll:sender];
	} else {
		[_keyManager handleKeys:[@"<esc>ggVG" keyCodes]];
	}
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
	if (document.busy) {
		MESSAGE(@"Document is busy");
		return;
	}

	NSUInteger oldCaret = [self caret];
	[[[self textStorage] mutableString] setString:aString ?: @""];
	NSDictionary *attrs = [self typingAttributes];
	if (attrs) {
		NSRange r = NSMakeRange(0, [[self textStorage] length]);
		[[self textStorage] setAttributes:attrs
					    range:r];
	}
	[self setCaret:oldCaret];
}

- (BOOL)autoNewline
{
	if ([self isFieldEditor])
		return NO;
	if ([_undoManager isUndoing] || [_undoManager isRedoing])
		return NO;

	NSString *s = [[self textStorage] string];
	NSUInteger len = [s length];
	if (len == 0)
		return NO;

	unichar lastchar = [s characterAtIndex:len-1];
	if (![[NSCharacterSet newlineCharacterSet] characterIsMember:lastchar]) {
		NSRange r = NSMakeRange(len, 0);
		[self recordReplacementOfRange:r withLength:1];
		[[self textStorage] replaceCharactersInRange:r withString:@"\n"];
		r.length = 1;
		[[self textStorage] setAttributes:[self typingAttributes] range:r];
		[[self textStorage] addAttribute:ViAutoNewlineAttributeName
					   value:[NSNumber numberWithInt:1]
					   range:r];
		return YES;
	} else if (len == 1) {
		if ([[self textStorage] attribute:ViAutoNewlineAttributeName
					  atIndex:0
				   effectiveRange:NULL]) {
			NSRange r = NSMakeRange(0, 1);
			[self recordReplacementOfRange:r withLength:0];
			[[self textStorage] replaceCharactersInRange:r withString:@""];
			return YES;
		}
	}

	return NO;
}

- (void)replaceCharactersInRange:(NSRange)aRange
                      withString:(NSString *)aString
                       undoGroup:(BOOL)undoGroup
{
	if (document.busy) {
		MESSAGE(@"Document is busy");
		return;
	}

	modify_start_location = aRange.location;
	DEBUG(@"modify_start_location -> %lu", modify_start_location);

	DEBUG(@"replace range %@ with string [%@]", NSStringFromRange(aRange), aString);

	ViSnippet *snippet = document.snippet;
	if (snippet) {
		/* If there is a selected snippet range, remove it first. */
		NSRange sel = snippet.selectedRange;
		if (sel.length > 0) {
			DEBUG(@"got snippet selection range %@", NSStringFromRange(sel));
			if (NSLocationInRange(aRange.location, sel) || NSLocationInRange(NSMaxRange(aRange), sel)) {
				aRange = NSUnionRange(sel, aRange);
				DEBUG(@"union range = %@", NSStringFromRange(aRange));
			} else
				[self deselectSnippet];
		}

		/* Let the snippet drive the changes. */
		if ([snippet replaceRange:aRange withString:aString])
			return;
		[self cancelSnippet];
	}

	if (undoGroup)
		[self beginUndoGroup];

	[self recordReplacementOfRange:aRange withLength:[aString length]];
	[[self textStorage] replaceCharactersInRange:aRange withString:aString];
	NSRange r = NSMakeRange(aRange.location, [aString length]);
	[[self textStorage] setAttributes:[self typingAttributes]
	                            range:r];
	[[self document] setMark:'.' atLocation:aRange.location];
	[self autoNewline];
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
{
	[self replaceCharactersInRange:NSMakeRange(aLocation, 0) withString:aString undoGroup:YES];
}

- (void)insertString:(NSString *)aString
{
	[self insertString:aString atLocation:[self caret]];
}

- (void)deleteRange:(NSRange)aRange
{
	[self replaceCharactersInRange:aRange withString:@"" undoGroup:YES];
}

- (void)replaceRange:(NSRange)aRange withString:(NSString *)aString
{
	[self replaceCharactersInRange:aRange withString:aString undoGroup:YES];
}

- (void)snippet:(ViSnippet *)snippet
replaceCharactersInRange:(NSRange)aRange
     withString:(NSString *)aString
     forTabstop:(ViTabstop *)tabstop
{
	DEBUG(@"replace range %@ with [%@] for tab %@, currentTabStop = %@, tabRange = %@",
	    NSStringFromRange(aRange), aString, tabstop, snippet.currentTabStop, NSStringFromRange(snippet.tabRange));
	[self beginUndoGroup];
	[self recordReplacementOfRange:aRange withLength:[aString length]];
	[[self textStorage] replaceCharactersInRange:aRange withString:aString];
	NSRange r = NSMakeRange(aRange.location, [aString length]);
	[[self textStorage] setAttributes:[self typingAttributes]
	                            range:r];
	[[self document] setMark:'.' atLocation:aRange.location];

	NSInteger delta = [aString length] - aRange.length;
	if (modify_start_location > NSMaxRange(r)) {
		DEBUG(@"modify_start_location %lu -> %lu", modify_start_location, modify_start_location + delta);
		modify_start_location += delta;
	} else if (modify_start_location == r.location && delta > 0 && tabstop != snippet.currentTabStop) {
		DEBUG(@"modify_start_location %lu -> %lu", modify_start_location, modify_start_location + delta);
		modify_start_location += delta;
	}

	[self autoNewline];
}

- (void)beginUpdatingSnippet:(ViSnippet *)snippet
{
	[[self textStorage] beginEditing];
}

- (void)endUpdatingSnippet:(ViSnippet *)snippet
{
	[[self textStorage] endEditing];
}

- (unichar)characterAtIndex:(NSUInteger)location
{
	NSString *s = [[self textStorage] string];
	if (location >= [s length])
		return 0;
	return [s characterAtIndex:location];
}

- (unichar)currentCharacter
{
	return [self characterAtIndex:[self caret]];
}

- (NSString *)line
{
	return [[self textStorage] lineAtLocation:[self caret]];
}

- (ViMark *)markAtLocation:(NSUInteger)location
{
	ViWindowController *windowController = [[self window] windowController];
	NSRange r = NSMakeRange(location, 0);
	if (r.location < [[self textStorage] length])
		r.length = 1;
	ViViewController *viewController = [windowController viewControllerForView:self];
	if ([viewController isKindOfClass:[ViDocumentView class]])
		return [ViMark markWithView:(ViDocumentView *)viewController
				       name:nil
				      range:r];
	else
		return [ViMark markWithDocument:document
					   name:nil
					  range:r];
}

- (ViMark *)currentMark
{
	return [self markAtLocation:[self caret]];
}

- (BOOL)atEOF
{
	return [self caret] >= [[self textStorage] length];
}

#pragma mark -
#pragma mark Indentation

- (NSString *)indentStringOfLength:(NSInteger)length
{
	length = IMAX(length, 0);
	NSInteger tabstop = [[self preference:@"tabstop"] integerValue];
	if ([[self preference:@"expandtab"] integerValue] == NSOnState) {
		// length * " "
		return [@"" stringByPaddingToLength:length withString:@" " startingAtIndex:0];
	} else {
		// length / tabstop * "tab" + length % tabstop * " "
		NSInteger ntabs = (length / tabstop);
		NSInteger nspaces = (length % tabstop);
		NSString *indent = [@"" stringByPaddingToLength:ntabs withString:@"\t" startingAtIndex:0];
		return [indent stringByPaddingToLength:ntabs + nspaces withString:@" " startingAtIndex:0];
	}
}

- (NSUInteger)lengthOfIndentString:(NSString *)indent
{
	NSInteger tabstop = [[self preference:@"tabstop"] integerValue];
	NSUInteger i;
	NSUInteger length = 0;
	for (i = 0; i < [indent length]; i++)
	{
		unichar c = [indent characterAtIndex:i];
		if (c == ' ')
			++length;
		else if (c == '\t')
			length += tabstop - (length % tabstop);
	}

	return length;
}

- (NSUInteger)lengthOfIndentAtLocation:(NSUInteger)aLocation
{
	return [self lengthOfIndentString:[[self textStorage] leadingWhitespaceForLineAtLocation:aLocation]];
}

- (BOOL)shouldIncreaseIndentAtLocation:(NSUInteger)aLocation
{
	NSDictionary *increaseIndentPatterns = [[ViBundleStore defaultStore] preferenceItem:@"increaseIndentPattern"];
	NSString *bestMatchingScope = [document bestMatchingScope:[increaseIndentPatterns allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		NSString *pattern = [increaseIndentPatterns objectForKey:bestMatchingScope];
		ViRegexp *rx = [ViRegexp regexpWithString:pattern];
		NSString *checkLine = [[self textStorage] lineAtLocation:aLocation];

		if ([rx matchInString:checkLine])
			return YES;
	}

	return NO;
}

- (BOOL)shouldIncreaseIndentOnceAtLocation:(NSUInteger)aLocation
{
	NSDictionary *increaseIndentPatterns = [[ViBundleStore defaultStore] preferenceItem:@"indentNextLinePattern"];
	NSString *bestMatchingScope = [document bestMatchingScope:[increaseIndentPatterns allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		NSString *pattern = [increaseIndentPatterns objectForKey:bestMatchingScope];
		ViRegexp *rx = [ViRegexp regexpWithString:pattern];
		NSString *checkLine = [[self textStorage] lineAtLocation:aLocation];

		if ([rx matchInString:checkLine])
			return YES;
	}

	return NO;
}

- (BOOL)shouldDecreaseIndentAtLocation:(NSUInteger)aLocation
{
	NSDictionary *decreaseIndentPatterns = [[ViBundleStore defaultStore] preferenceItem:@"decreaseIndentPattern"];
	NSString *bestMatchingScope = [document bestMatchingScope:[decreaseIndentPatterns allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		NSString *pattern = [decreaseIndentPatterns objectForKey:bestMatchingScope];
		ViRegexp *rx = [ViRegexp regexpWithString:pattern];
		NSString *checkLine = [[self textStorage] lineAtLocation:aLocation];

		if ([rx matchInString:checkLine])
			return YES;
	}

	return NO;
}

- (BOOL)shouldIgnoreIndentAtLocation:(NSUInteger)aLocation
{
	NSDictionary *unIndentPatterns = [[ViBundleStore defaultStore] preferenceItem:@"unIndentedLinePattern"];
	NSString *bestMatchingScope = [document bestMatchingScope:[unIndentPatterns allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		NSString *pattern = [unIndentPatterns objectForKey:bestMatchingScope];
		ViRegexp *rx = [ViRegexp regexpWithString:pattern];
		NSString *checkLine = [[self textStorage] lineAtLocation:aLocation];

		if ([rx matchInString:checkLine])
			return YES;
	}

	return NO;
}

- (NSInteger)calculatedIndentLengthAtLocation:(NSUInteger)aLocation
{
	NSDictionary *indentExpressions = [[ViBundleStore defaultStore] preferenceItem:@"indentExpressionBlock"];
	NSString *bestMatchingScope = [document bestMatchingScope:[indentExpressions allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		NuBlock *expression = [indentExpressions objectForKey:bestMatchingScope];
		DEBUG(@"running indent expression:\n%@", [expression stringValue]);
		/* Expressions depend on caret being set to the location in question. */
		NSUInteger oldCaret = [self caret];
		[self setCaret:aLocation updateSelection:NO];

		@try {
			id result = [[expression body] evalWithContext:[expression context]];
			DEBUG(@"got result %@, class %@", result, NSStringFromClass([result class]));
			if ([result isKindOfClass:[NSNumber class]]) {
				[self setCaret:oldCaret updateSelection:NO];
				return [result integerValue];
			}
			INFO(@"non-numeric result from indent expression: got %@", NSStringFromClass([result class]));
		}
		@catch (NSException *exception) {
			INFO(@"got exception %@ while evaluating indent expression:\n%@", [exception name], [exception reason]);
			DEBUG(@"context was: %@", [expression context]);
		}

		[self setCaret:oldCaret updateSelection:NO];
	}

	return -1;
}

- (NSString *)suggestedIndentAtLocation:(NSUInteger)location forceSmartIndent:(BOOL)smartFlag
{
	BOOL smartIndent = smartFlag || [[self preference:@"smartindent" atLocation:location] integerValue];

	NSInteger calcIndent = -1;
	if (smartIndent)
		calcIndent = [self calculatedIndentLengthAtLocation:location];
	if (calcIndent >= 0) {
		DEBUG(@"calculated indent at %lu to %lu", location, calcIndent);
		return [self indentStringOfLength:calcIndent];
	}

	/* Find out indentation of first (non-blank) line before the affected range. */
	NSUInteger bol, end;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:location];
	NSUInteger len = 0;
	if (bol == 0) /* First line can't be indented. */
		return 0;
	for (; bol > 0;) {
		[self getLineStart:&bol end:NULL contentsEnd:&end forLocation:bol - 1];
		if (smartIndent && [[self textStorage] isBlankLineAtLocation:bol])
			DEBUG(@"line %lu is blank", [[self textStorage] lineNumberAtLocation:bol]);
		else if (smartIndent && [self shouldIgnoreIndentAtLocation:bol])
			DEBUG(@"line %lu is ignored", [[self textStorage] lineNumberAtLocation:bol]);
		else {
			len = [self lengthOfIndentAtLocation:bol];
			DEBUG(@"indent at line %lu is %lu", [[self textStorage] lineNumberAtLocation:bol], len);
			break;
		}
	}

	NSInteger shiftWidth = [[self preference:@"shiftwidth" atLocation:location] integerValue];
	if (smartIndent && ![self shouldIgnoreIndentAtLocation:bol]) {
		if ([self shouldIncreaseIndentAtLocation:bol] ||
		    ([self shouldIncreaseIndentOnceAtLocation:bol] && ![self shouldIncreaseIndentAtLocation:location])) {
			DEBUG(@"increase indent at %lu", bol);
			len += shiftWidth;
		} else {
			/* Check if previous lines are indented by an indentNextLinePattern. */
			while (bol > 0) {
				[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:bol - 1];
				if ([self shouldIgnoreIndentAtLocation:bol]) {
					continue;
				} if ([self shouldIncreaseIndentOnceAtLocation:bol]) {
					DEBUG(@"compensating for indentNextLinePattern at line %lu",
					    [[self textStorage] lineNumberAtLocation:bol]);
					len = [self lengthOfIndentAtLocation:bol];
				} else
					break;
			}
		}

		if ([self shouldDecreaseIndentAtLocation:location]) {
			DEBUG(@"decrease indent at %lu", location);
			len -= shiftWidth;
		}
	}

	return [self indentStringOfLength:len];
}

- (NSString *)suggestedIndentAtLocation:(NSUInteger)location
{
	return [self suggestedIndentAtLocation:location forceSmartIndent:NO];
}

- (id)preference:(NSString *)name atLocation:(NSUInteger)aLocation
{
	return [ViPreferencePaneEdit valueForKey:name inScope:[document scopeAtLocation:aLocation]];
}

- (id)preference:(NSString *)name
{
	return [self preference:name atLocation:[self caret]];
}

- (NSUInteger)insertNewlineAtLocation:(NSUInteger)aLocation indentForward:(BOOL)indentForward
{
	NSString *leading_whitespace = [[self textStorage] leadingWhitespaceForLineAtLocation:aLocation];

	aLocation = [self removeTrailingAutoIndentForLineAtLocation:aLocation];

	NSRange smartRange;
	if ([[self textStorage] attribute:ViSmartPairAttributeName
				  atIndex:aLocation
			   effectiveRange:&smartRange] && smartRange.length > 1 && smartRange.location == aLocation - 1)
	{
		// assumes indentForward
		[self insertString:[NSString stringWithFormat:@"\n\n%@", leading_whitespace] atLocation:aLocation];
	} else
		[self insertString:@"\n" atLocation:aLocation];

	if ([[self preference:@"autoindent"] integerValue] == NSOnState) {
		if (indentForward)
			aLocation += 1;

		[self setCaret:aLocation];
		leading_whitespace = [self suggestedIndentAtLocation:aLocation];
		if (leading_whitespace) {
			NSRange curIndent = [[self textStorage] rangeOfLeadingWhitespaceForLineAtLocation:aLocation];
			[self replaceCharactersInRange:curIndent withString:leading_whitespace];
			NSRange autoIndentRange = NSMakeRange(curIndent.location, [leading_whitespace length]);
			[[self textStorage] addAttribute:ViAutoIndentAttributeName
						   value:[NSNumber numberWithInt:1]
						   range:autoIndentRange];
			return aLocation + autoIndentRange.length;
		}
	}

	if (indentForward)
		return aLocation + 1;
	else
		return aLocation;
}

- (NSRange)changeIndentation:(int)delta
		     inRange:(NSRange)aRange
		 updateCaret:(NSUInteger *)updatedCaret
	      alignToTabstop:(BOOL)alignToTabstop
	    indentEmptyLines:(BOOL)indentEmptyLines
{
	NSInteger shiftWidth = [[self preference:@"shiftwidth" atLocation:aRange.location] integerValue];
	if (shiftWidth == 0)
		shiftWidth = 8;
	NSUInteger bol;
	[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:aRange.location];

	NSRange delta_offset = NSMakeRange(0, 0);
	BOOL has_delta_offset = NO;

	[[self textStorage] beginEditing];
	while (bol < NSMaxRange(aRange)) {
		NSString *indent = [[self textStorage] leadingWhitespaceForLineAtLocation:bol];
		NSUInteger n = [self lengthOfIndentString:indent];
		if (n % shiftWidth != 0 && alignToTabstop) {
			/* ctrl-t / ctrl-d aligns to tabstop, but <> doesn't */
			if (delta < 0)
				n += shiftWidth - (n % shiftWidth);
			else
				n -= n % shiftWidth;
		}
		NSString *newIndent = [self indentStringOfLength:n + delta * shiftWidth];
		if (!indentEmptyLines && [[self textStorage] isBlankLineAtLocation:bol])
			/* should not indent empty lines when using the < or > operators. */
			newIndent = indent;

		NSRange indentRange = NSMakeRange(bol, [indent length]);
		[self replaceRange:indentRange withString:newIndent];

		aRange.length += [newIndent length] - [indent length];
		if (!has_delta_offset) {
			has_delta_offset = YES;
			delta_offset.location = [newIndent length] - [indent length];
		}
		delta_offset.length += [newIndent length] - [indent length];
		if (updatedCaret && *updatedCaret >= indentRange.location) {
			NSInteger d = [newIndent length] - [indent length];
			*updatedCaret = IMAX((NSInteger)*updatedCaret + d, bol);
		}

		// get next line
		[self getLineStart:NULL end:&bol contentsEnd:NULL forLocation:bol];
		if (bol == NSNotFound)
			break;
	}
	[[self textStorage] endEditing];

	return delta_offset;
}

- (BOOL)increase_indent:(ViCommand *)command
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	final_location = start_location;
	[self changeIndentation:+1
			inRange:NSMakeRange(bol, IMAX(eol - bol, 1))
		    updateCaret:&final_location
		 alignToTabstop:YES
	       indentEmptyLines:YES];
	return YES;
}

- (BOOL)decrease_indent:(ViCommand *)command
{
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	final_location = start_location;
	[self changeIndentation:-1
			inRange:NSMakeRange(bol, eol - bol)
		    updateCaret:&final_location
		 alignToTabstop:YES
	       indentEmptyLines:YES];
	return YES;
}

#pragma mark -
#pragma mark Undo support

- (IBAction)undo:(id)sender
{
	[self endUndoGroup];
	[self cancelSnippet];
	[self setNormalMode];
	[[self textStorage] beginEditing];
	[_undoManager undo];
	[[self textStorage] endEditing];
	[self setCaret:final_location];
}

- (IBAction)redo:(id)sender
{
	[self endUndoGroup];
	[self cancelSnippet];
	[self setNormalMode];
	[[self textStorage] beginEditing];
	[_undoManager redo];
	[[self textStorage] endEditing];
	[self setCaret:final_location];
}

- (void)endUndoGroup
{
	if ([document undoManager])
		[document endUndoGroup];
	else if (hasUndoGroup) {
		DEBUG(@"%s", "====================> Ending undo-group");
		[_undoManager endUndoGrouping];
		hasUndoGroup = NO;
	}
}

- (void)beginUndoGroup
{
	if ([document undoManager])
		[document beginUndoGroup];
	else if (!hasUndoGroup) {
		DEBUG(@"%s", "====================> Beginning undo-group");
		[_undoManager beginUndoGrouping];
		hasUndoGroup = YES;
	}
}

- (void)undoReplacementOfString:(NSString *)aString inRange:(NSRange)aRange restoreMarks:(NSSet *)marks
{
	DEBUG(@"undoing replacement of string %@ in range %@", aString, NSStringFromRange(aRange));
	[self replaceCharactersInRange:aRange withString:aString undoGroup:NO];
	final_location = aRange.location;

	NSUInteger bol, eol, end;
	[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:final_location];
	if (final_location >= eol && final_location > bol)
		final_location = eol - 1;

	for (ViMark *m in marks) {
		DEBUG(@"restore local mark %@", m);
		[[self document].localMarks.list addMark:m];
		[[self document] registerMark:m];
		if ([m.name isUppercase])
			[[[ViMarkManager sharedManager] stackWithName:@"Global Marks"].list addMark:m];
		m.recentlyRestored = YES;
	}
}

- (void)recordReplacementOfRange:(NSRange)aRange withLength:(NSUInteger)aLength
{
	NSRange newRange = NSMakeRange(aRange.location, aLength);

	NSMutableSet *deletedMarks = nil;
	if (aLength < aRange.length) {
		/* If we're deleting text, check if we're deleting a mark. */
		NSRange delRange = NSMakeRange(aRange.location + aLength, aRange.length - aLength);
		for (ViMark *m in [self document].localMarks.list.marks) {
			if (!m.persistent &&
			    m.range.location >= delRange.location &&
			    NSMaxRange(m.range) <= NSMaxRange(delRange)) {
				DEBUG(@"deleted range %@ contains mark %@", NSStringFromRange(delRange), m);
				if (deletedMarks == nil)
					deletedMarks = [NSMutableSet set];
				[deletedMarks addObject:m];
			}
		}
	}

	NSString *s = [[[self textStorage] string] substringWithRange:aRange];
	DEBUG(@"pushing replacement of range %@ (string [%@]) with %@ onto undo stack",
	    NSStringFromRange(aRange), s, NSStringFromRange(newRange));
	[[_undoManager prepareWithInvocationTarget:self] undoReplacementOfString:s
					   inRange:newRange
				      restoreMarks:deletedMarks];
	[_undoManager setActionName:@"replace text"];
}

#pragma mark -
#pragma mark Register

- (void)yankToRegister:(unichar)regName
                 range:(NSRange)yankRange
{
	NSString *content = [[[self textStorage] string] substringWithRange:yankRange];
	[[ViRegisterManager sharedManager] setContent:content ofRegister:regName];
	[[self document] setMark:'[' atLocation:yankRange.location];
	[[self document] setMark:']' atLocation:IMAX(yankRange.location, NSMaxRange(yankRange) - 1)];
}

- (void)cutToRegister:(unichar)regName
                range:(NSRange)cutRange
{
	NSString *content = [[[self textStorage] string] substringWithRange:cutRange];
	[[ViRegisterManager sharedManager] setContent:content ofRegister:regName];
	[self deleteRange:cutRange];
	[[self document] setMark:'[' toRange:NSMakeRange(cutRange.location, 0)];
	[[self document] setMark:']' atLocation:cutRange.location];
}

#pragma mark -
#pragma mark Convenience methods

- (void)gotoScreenColumn:(NSUInteger)column fromGlyphIndex:(NSUInteger)glyphIndex
{
	NSRange lineRange;
	[[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineRange];
	end_location =  [[self layoutManager] characterIndexForGlyphAtIndex:lineRange.location];
	if (column > 1)
		end_location += column - 1;

	NSUInteger endOfScreenLine = [[self layoutManager] characterIndexForGlyphAtIndex:IMAX(lineRange.location, NSMaxRange(lineRange) - 1)];
	if (end_location >= endOfScreenLine) {
		end_location = endOfScreenLine;

		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:end_location];
		if (end_location >= eol)
			end_location = IMAX(bol, eol - (mode == ViInsertMode ? 0 : 1));
	}

	final_location = end_location;
}

- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation
{
	end_location = [[self textStorage] locationForColumn:column
	                                        fromLocation:aLocation
	                                           acceptEOL:(mode == ViInsertMode)];
	final_location = end_location;
}

- (BOOL)gotoLine:(NSUInteger)line column:(NSUInteger)column
{
	if (document && ![document isEntireFileLoaded]) {
		initial_line = line;
		initial_column = column;
		return YES;
	}

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

- (NSRange)rangeOfPattern:(NSString *)pattern
	     fromLocation:(NSUInteger)start
		  forward:(BOOL)forwardSearch
		    error:(NSError **)outError
{
	if ([pattern length] == 0) {
		if (outError)
			*outError = [ViError message:@"Empty search pattern"];
		return NSMakeRange(NSNotFound, 0);
	}

	NSInteger rx_options = [ViRegexp defaultOptionsForString:pattern] | ONIG_OPTION_NOTBOL | ONIG_OPTION_NOTEOL;

	NSError *error = nil;
	ViRegexp *rx = [ViRegexp regexpWithString:pattern
					  options:rx_options
					    error:&error];
	if (error) {
		if (outError)
			*outError = error;
		return NSMakeRange(NSNotFound, 0);
	}

	[[ViRegisterManager sharedManager] setContent:pattern ofRegister:'/'];

	NSArray *foundMatches = [rx allMatchesInString:[[self textStorage] string]
					       options:rx_options];

	if ([foundMatches count] > 0) {
		ViRegexpMatch *match, *nextMatch = nil;
		for (match in foundMatches) {
			NSRange r = [match rangeOfMatchedString];
			if (forwardSearch) {
				if (r.location > start) {
					nextMatch = match;
					break;
				}
			} else if (r.location < start) {
				nextMatch = match;
			} else if (r.location >= start)
				break;
		}

		if (nextMatch == nil && [[NSUserDefaults standardUserDefaults] boolForKey:@"wrapscan"]) {
			if (forwardSearch)
				nextMatch = [foundMatches objectAtIndex:0];
			else
				nextMatch = [foundMatches lastObject];
			MESSAGE(@"Search wrapped");
		}

		if (nextMatch)
			return [nextMatch rangeOfMatchedString];
	}

	return NSMakeRange(NSNotFound, 0);
}

- (BOOL)findPattern:(NSString *)pattern options:(unsigned)find_options
{
	if (document && ![document isEntireFileLoaded]) {
		[self setInitialFindPattern:pattern];
		initial_find_options = find_options;
		return YES;
	}

	NSError *error = nil;
	NSRange r = [self rangeOfPattern:pattern
			    fromLocation:start_location
				 forward:find_options == 0
				   error:&error];
	if (error) {
		MESSAGE(@"Invalid search pattern: %@", [error localizedDescription]);
		return NO;
	}

	if (r.location == NSNotFound) {
		MESSAGE(@"Pattern not found");
		return NO;
	}

	[self pushLocationOnJumpList:start_location];
	[self scrollRangeToVisible:r];
	final_location = end_location = r.location;
	[self setCaret:final_location];
	[[self nextRunloop] showFindIndicatorForRange:r];

	return YES;
}

/* syntax: /regexp */
- (BOOL)find:(ViCommand *)command
{
	NSString *pattern = nil;
	if (command.text)
		pattern = command.text;
	else {
		pattern = [self getExStringForCommand:command];
		command.text = pattern;
	}

	if ([pattern length] == 0)
		pattern = [[ViRegisterManager sharedManager] contentOfRegister:'/'];
	if ([pattern length] == 0) {
		// return [ViError message:@"No previous search pattern"];
		MESSAGE(@"No previous search pattern");
		return NO;
	}

	_keyManager.parser.lastSearchOptions = 0;
	if ([self findPattern:pattern options:0]) {
		[self setCaret:final_location];
		return YES;
	}

	return NO;
}

/* syntax: ?regexp */
- (BOOL)find_backwards:(ViCommand *)command
{
	NSString *pattern = nil;
	if (command.text)
		pattern = command.text;
	else {
		pattern = [self getExStringForCommand:command];
		command.text = pattern;
	}

	if ([pattern length] == 0)
		pattern = [[ViRegisterManager sharedManager] contentOfRegister:'/'];
	if ([pattern length] == 0) {
		// return [ViError message:@"No previous search pattern"];
		MESSAGE(@"No previous search pattern");
		return NO;
	}

	_keyManager.parser.lastSearchOptions = ViSearchOptionBackwards;
	if ([self findPattern:pattern options:ViSearchOptionBackwards]) {
		[self setCaret:final_location];
		return YES;
	}

	return NO;
}

/* syntax: n */
- (BOOL)repeat_find:(ViCommand *)command
{
	NSString *pattern = [[ViRegisterManager sharedManager] contentOfRegister:'/'];
	if ([pattern length] == 0) {
		MESSAGE(@"No previous search pattern");
		return NO;
	}

	return [self findPattern:pattern options:_keyManager.parser.lastSearchOptions];
}

/* syntax: N */
- (BOOL)repeat_find_backward:(ViCommand *)command
{
	NSString *pattern = [[ViRegisterManager sharedManager] contentOfRegister:'/'];
	if ([pattern length] == 0) {
		MESSAGE(@"No previous search pattern");
		return NO;
	}

	int options = _keyManager.parser.lastSearchOptions;
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
	BOOL atEOL = ([self caret] >= [[self textStorage] length]);

	NSUInteger rectCount = 0;
	NSRectArray rects = [layoutManager rectArrayForCharacterRange:NSMakeRange(caret, atEOL ? 0 : 1)
					 withinSelectedCharacterRange:NSMakeRange(NSNotFound, 0)
						      inTextContainer:[self textContainer]
							    rectCount:&rectCount];
	if (rectCount == 0)
		return;

	NSRect rect = rects[0];

	if (atEOL)
		rect.size.width = 1;
	else {
		unichar c = [[[self textStorage] string] characterAtIndex:[self caret]];
		if (c == '\t' || c == '\n' || c == '\r' || c == 0x0C)
			rect.size.width = _characterSize.width;
	}

	NSPoint topPoint;
	CGFloat topY = visibleRect.origin.y;
	CGFloat topX = visibleRect.origin.x;

	if (NSMinY(rect) < NSMinY(visibleRect))
		topY = NSMinY(rect);
	else if (NSMaxY(rect) > NSMaxY(visibleRect))
		topY = NSMaxY(rect) - NSHeight(visibleRect);

	CGFloat jumpX = 20*rect.size.width;

	DEBUG(@"rect = %@, visible rect = %@", NSStringFromRect(rect), NSStringFromRect(visibleRect));
	if (NSMinX(rect) < NSMinX(visibleRect))
		topX = NSMinX(rect) > jumpX ? NSMinX(rect) - jumpX : 0;
	else if (NSMaxX(rect) > NSMaxX(visibleRect))
		topX = NSMaxX(rect) - NSWidth(visibleRect) + jumpX;

	if (topX < jumpX)
		topX = 0;

	topPoint = NSMakePoint(topX, topY);

	if (topPoint.x != visibleRect.origin.x || topPoint.y != visibleRect.origin.y) {
		DEBUG(@"scrolling to point %@", NSStringFromPoint(topPoint));
		[clipView scrollToPoint:topPoint];
		[scrollView reflectScrolledClipView:clipView];
	}
}

- (void)setCaret:(NSUInteger)location updateSelection:(BOOL)updateSelection
{
	if (location == NSNotFound)
		return;

	NSInteger length = [[self textStorage] length];
	if (mode != ViInsertMode)
		length--;
	if (location > length)
		location = IMAX(0, length);
	caret = location;
	if (updateSelection && mode != ViVisualMode)
		[self setSelectedRange:NSMakeRange(location, 0)];
	if (!replayingInput) {
		if (updateSelection)
			[self updateCaret];
		else
			[[self nextRunloop] updateCaret];
	}

	initial_line = -1;
	[self setInitialFindPattern:nil];
}

- (void)setCaret:(NSUInteger)location
{
	[self setCaret:location updateSelection:YES];
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
	if (_showingContextMenu) /* XXX: not used anymore? */
		return;

	[super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelectingFlag];

	NSRange firstRange = [[ranges objectAtIndex:0] rangeValue];
	if ([self hasMarkedText] && [ranges count] == 1 && !stillSelectingFlag &&
	    firstRange.length == 0 && firstRange.location != caret)
		[self setCaret:firstRange.location updateSelection:NO];
	else if (mode == ViInsertMode)
		[self setCaret:firstRange.location updateSelection:NO];
}

- (void)setVisualSelection
{
	NSUInteger l1 = visual_start_location, l2 = [self caret];
	if (l2 < l1) {
		/* swap if end < start */
		NSUInteger tmp = l2;
		l2 = l1;
		l1 = tmp;
	}

	if (visual_line_mode) {
		NSUInteger bol, end;
		[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:l1];
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:l2];
		l1 = bol;
		l2 = end;
	} else
		l2++;

	[[self document] setMark:'<' toRange:NSMakeRange(l1, 0)];
	[[self document] setMark:'>' atLocation:IMAX(l1, l2 - 1)];

	NSRange sel = NSMakeRange(l1, l2 - l1);
	[self setSelectedRange:sel];
}

#pragma mark -

- (void)postModeChangedNotification
{
	NSNotification *notification = [NSNotification notificationWithName:ViModeChangedNotification object:self];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
}


- (void)setNormalMode
{
	DEBUG(@"setting normal mode, caret = %u, final_location = %u, length = %u",
	    caret, final_location, [[self textStorage] length]);
	[self switchToNormalInputSourceAndRemember:YES];
	if (mode == ViInsertMode)
		[[self document] setMark:']' atLocation:end_location];
	mode = ViNormalMode;
	[self endUndoGroup];

	[self postModeChangedNotification];
}

- (void)resetSelection
{
	DEBUG(@"resetting selection, caret = %u", [self caret]);
	[self setSelectedRange:NSMakeRange([self caret], 0)];
}

- (void)setVisualMode
{
	mode = ViVisualMode;

	[self postModeChangedNotification];
}

- (void)setInsertMode:(ViCommand *)command
{
	DEBUG(@"entering insert mode at location %u (final location is %u), length is %u",
		end_location, final_location, [[self textStorage] length]);
	[self switchToInsertInputSource];
	mode = ViInsertMode;

	[[self document] setMark:'[' toRange:NSMakeRange(end_location, 0)];
	[[self document] setMark:']' atLocation:end_location];

	/*
	 * Remember the command that entered insert mode. When leaving insert mode,
	 * we update this command with the inserted text (or keys, actually). This
	 * is used for repeating the insertion with the dot command.
	 */
	[self setLastEditCommand:command];

	if (command) {
		if (command.text) {
			replayingInput = YES;
			[self setCaret:end_location];
			int count = IMAX(1, command.count);
			int i;
			for (i = 0; i < count; i++)
				[_keyManager handleKeys:command.text
						inScope:[document scopeAtLocation:end_location]];
			[self normal_mode:command];
			replayingInput = NO;
		}
	}

	[self postModeChangedNotification];
}

- (void)setInsertMode
{
	[self setInsertMode:nil];
}

#pragma mark -
#pragma mark Input handling and command evaluation

/*
 * Helper for deciding if we should insert a smart typing pair or not.
 * If we're inserting a double or single qoute, check if we're inside
 * a (double or single) quoted string already. In that case, assume we
 * just want to end the string.
 *
 * This assumes that quotes generates string scopes.
 */
- (BOOL)shouldEndString:(NSArray *)pair atLocation:(NSUInteger)location
{
	NSString *pair0 = [pair objectAtIndex:0];
	NSString *pair1 = [pair objectAtIndex:1];

	if ([pair0 isEqualToString:pair1]) {
		ViScope *scope = [document scopeAtLocation:location];
		if ([pair0 isEqualToString:@"\""])
			return [@"string.quoted.double$|string.quoted.double>invalid.illegal.unclosed-string$" match:scope] > 0;
		else if ([pair0 isEqualToString:@"'"])
			return [@"string.quoted.single$|string.quoted.single>invalid.illegal.unclosed-string$" match:scope] > 0;
	}

	return NO;
}

- (void)highlightCharacter:(unichar)matchChar
                atLocation:(NSUInteger)location
             withCharacter:(unichar)otherChar
                   forward:(BOOL)forward
{
	NSInteger matchLocation = [self matchCharacter:matchChar
					    atLocation:location
					 withCharacter:otherChar
					restrictScopes:YES
					       forward:forward];
	if (matchLocation < 0)
		return;

	NSRange r = NSMakeRange(matchLocation, 1);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"flashparen"])
		[self showFindIndicatorForRange:r];
	else
		document.matchingParenRange = r;
}

- (void)highlightSmartPairAtLocation:(NSUInteger)location
{
	document.matchingParenRange = NSMakeRange(NSNotFound, 0);
	if (mode == ViInsertMode && location > 0)
		location--;
	if (location >= [[self textStorage] length])
		return;

	unichar ch = [self characterAtIndex:location];

	NSArray *smartTypingPairs = [self smartTypingPairsAtLocation:location];
	for (NSArray *pair in smartTypingPairs) {
		unichar pair0 = [[pair objectAtIndex:0] characterAtIndex:0];
		unichar pair1 = [[pair objectAtIndex:1] characterAtIndex:0];

		if (pair0 == pair1)
			continue;

		if (pair0 == ch) {
			[self highlightCharacter:pair0 atLocation:location withCharacter:pair1 forward:YES];
			break;
		} else if (pair1 == ch) {
			[self highlightCharacter:pair1 atLocation:location withCharacter:pair0 forward:NO];
			break;
		}
	}
}

- (BOOL)handleSmartPair:(NSString *)characters
{
	if ([[self preference:@"smartpair"] integerValue] == 0)
		return NO;

	BOOL foundSmartTypingPair = NO;

	ViTextStorage *ts = [self textStorage];
	NSString *string = [ts string];
	NSUInteger length = [ts length];
	NSArray *pair = nil;

	DEBUG(@"testing %@ for smart pair", characters);

	/*
	 * Check if we're inserting the end character of a smart typing pair.
	 * If so, just overwrite the end character.
	 * Note: start and end characters might be the same (eg, "").
	 */

	if (start_location < length)
		pair = [[self textStorage] attribute:ViSmartPairAttributeName
					     atIndex:start_location
				      effectiveRange:NULL];
	if ([pair isKindOfClass:[NSArray class]]) {
		// NSString *pair0 = [pair objectAtIndex:0];
		NSString *pair1 = [pair objectAtIndex:1];
		if (/*[pair0 isEqualToString:characters] ||*/ [pair1 isEqualToString:characters]) {
			final_location = start_location + [characters length];
			return YES;
		}
	}

	/*
	 * Check for the start character of a smart typing pair.
	 */
	NSArray *smartTypingPairs = [self smartTypingPairsAtLocation:IMIN(start_location, length - 1)];
	for (pair in smartTypingPairs) {
		NSString *pair0 = [pair objectAtIndex:0];
		if ([characters isEqualToString:pair0] && ![self shouldEndString:pair atLocation:start_location]) {
			NSString *pair1 = [pair objectAtIndex:1];
			DEBUG(@"got pairs %@ and %@ at %lu < %lu", pair0, pair1, start_location, length);
			/*
			 * Only use if next character is not alphanumeric.
			 */
			if (start_location >= length ||
			    ![[NSCharacterSet alphanumericCharacterSet] characterIsMember:
					    [string characterAtIndex:start_location]])
			{
				foundSmartTypingPair = YES;
				[self insertString:[NSString stringWithFormat:@"%@%@",
					pair0,
					pair1] atLocation:start_location];

				NSRange r = NSMakeRange(start_location, [pair0 length] + [pair1 length]);
				DEBUG(@"adding smart pair attr to %@", NSStringFromRange(r));
				[[self textStorage] addAttribute:ViSmartPairAttributeName
							   value:pair
							   range:r];

				final_location = start_location + [pair1 length];
				break;
			}
		}
	}

	return foundSmartTypingPair;
}

/* Input a character from the user (in insert mode). Handle smart typing pairs.
 * FIXME: assumes smart typing pairs are single characters.
 */
- (void)handle_input:(unichar)character literal:(BOOL)literal
{
	DEBUG(@"insert character %C at %i", character, start_location);

	NSString *s = [NSString stringWithFormat:@"%C", character];
	if (literal || ![self handleSmartPair:s]) {
		DEBUG(@"%s", "no smart typing pairs triggered");
		[self insertString:s
			atLocation:start_location];
		final_location = modify_start_location + 1;
		DEBUG(@"setting final location to %lu", final_location);
	}

	if ([[self preference:@"smartindent" atLocation:start_location] integerValue]) {
		DEBUG(@"checking for auto-dedent at %lu", start_location);
		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:start_location];
		NSRange r;
		if ([[self textStorage] attribute:ViAutoIndentAttributeName
					  atIndex:bol
				   effectiveRange:&r]) {
			DEBUG(@"got auto-indent whitespace in range %@ for line between %lu and %lu",
			    NSStringFromRange(r), bol, eol);
			NSString *indent = [self suggestedIndentAtLocation:bol];
			NSRange curIndent = [[self textStorage] rangeOfLeadingWhitespaceForLineAtLocation:bol];
			if (curIndent.length != [indent length]) {
				[[self textStorage] removeAttribute:ViAutoIndentAttributeName
							      range:r];
				[self replaceCharactersInRange:curIndent withString:indent];
				final_location += [indent length] - curIndent.length;
			}
		}
	}
}

- (BOOL)literal_next:(ViCommand *)command
{
	[self handle_input:command.argument literal:YES];
	return YES;
}

- (BOOL)input_character:(ViCommand *)command
{
	for (NSNumber *n in command.mapping.keySequence) {
		NSInteger keyCode = [n integerValue];

		if ((keyCode & 0xFFFF0000) != 0) {
			MESSAGE(@"Can't insert key equivalent: %@.",
			    [NSString stringWithKeyCode:keyCode]);
			return NO;
		}

		if (keyCode < 0x20) {
			MESSAGE(@"Illegal character: %@; quote to enter",
			    [NSString stringWithKeyCode:keyCode]);
			return NO;
		}

		[self handle_input:keyCode literal:NO];
		start_location = final_location;
	}

	return YES;
}

- (BOOL)input_newline:(ViCommand *)command
{
	final_location = [self insertNewlineAtLocation:start_location
					 indentForward:YES];
	return YES;
}

- (BOOL)input_tab:(ViCommand *)command
{
	// check if we're inside a snippet
	ViSnippet *snippet = document.snippet;
	if (snippet) {
		[[self layoutManager] invalidateDisplayForCharacterRange:snippet.selectedRange];
		if ([snippet advance]) {
			[self endUndoGroup];
			final_location = snippet.caret;
			[[self layoutManager] invalidateDisplayForCharacterRange:snippet.selectedRange];
			return YES;
		} else
			[self cancelSnippet];
	}

	/* Check for a tab trigger before the caret.
	 */
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol];
	NSString *prefix = [[[self textStorage] string] substringWithRange:NSMakeRange(bol, start_location - bol)];
	if ([prefix length] > 0) {
		ViScope *scope = [document scopeAtLocation:eol];
		NSUInteger triggerLength;
		NSArray *matches = [[ViBundleStore defaultStore] itemsWithTabTrigger:prefix
                                                                       matchingScope:scope
                                                                              inMode:mode
                                                                       matchedLength:&triggerLength];
		if ([matches count] > 0) {
			snippetMatchRange = NSMakeRange(start_location - triggerLength, triggerLength);
			[self performBundleItems:matches];
			return NO;
		}
	}

	if ([[self preference:@"smarttab" atLocation:start_location] integerValue] == NSOnState) {
		/* Check if we're in leading whitespace. */
		NSUInteger firstNonBlank = [[self textStorage] firstNonBlankForLineAtLocation:start_location];
		if (firstNonBlank == NSNotFound || firstNonBlank >= start_location) {
			/* Do smart tab, behaves as ctrl-t. */
			return [self increase_indent:command];
		}
	}

	// otherwise just insert a tab
	NSString *tabString = @"\t";
	if ([[self preference:@"expandtab" atLocation:start_location] integerValue] == NSOnState) {
		NSInteger tabstop = [[self preference:@"tabstop" atLocation:start_location] integerValue];
		NSInteger nspaces = tabstop - (([self currentColumn] - 1) % tabstop);
		tabString = [@"" stringByPaddingToLength:nspaces withString:@" " startingAtIndex:0];
	}

	[self insertString:tabString atLocation:start_location];
	final_location = start_location + [tabString length];

	return YES;
}

- (NSArray *)smartTypingPairsAtLocation:(NSUInteger)aLocation
{
	NSDictionary *smartTypingPairs = [[ViBundleStore defaultStore] preferenceItem:@"smartTypingPairs"];
	NSString *bestMatchingScope = [document bestMatchingScope:[smartTypingPairs allKeys] atLocation:aLocation];

	if (bestMatchingScope) {
		DEBUG(@"found smart typing pair scope selector [%@] at location %i", bestMatchingScope, aLocation);
		return [smartTypingPairs objectForKey:bestMatchingScope];
	}

	return nil;
}

- (BOOL)input_backspace:(ViCommand *)command
{
	// If there is a selected snippet range, remove it first.
	ViSnippet *snippet = document.snippet;
	NSRange sel = snippet.selectedRange;
	if (sel.length > 0) {
		if ([snippet activeInRange:NSMakeRange(start_location, 0)]) {
			[self deleteRange:sel];
			start_location = modify_start_location;
			DEBUG(@"setting start location to %lu", modify_start_location);
			return YES;
		} else
			[self deselectSnippet];
	}

	if (start_location == 0) {
		MESSAGE(@"Already at the beginning of the document");
		return YES;
	}

	/* check if we're deleting the first character in a smart pair */
	NSRange r;
	if ([[self textStorage] attribute:ViSmartPairAttributeName
				  atIndex:start_location
			   effectiveRange:&r]) {
		DEBUG(@"found smart pair in range %@", NSStringFromRange(r));
		if (r.location == start_location - 1 && r.length == 2) {
			[self deleteRange:NSMakeRange(start_location - 1, 2)];
			final_location = modify_start_location;
			return YES;
		}
	}

	if ([[self preference:@"smarttab" atLocation:start_location] integerValue] == NSOnState) {
		/* Check if we're in leading whitespace and not at BOL. */
		NSUInteger bol;
		[self getLineStart:&bol end:NULL contentsEnd:NULL forLocation:start_location];
		if (start_location > bol) {
			NSUInteger firstNonBlank = [[self textStorage]
			    firstNonBlankForLineAtLocation:start_location];
			if (firstNonBlank == NSNotFound || firstNonBlank >= start_location) {
				/* Do smart backspace, behaves as ctrl-d. */
				return [self decrease_indent:command];
			}
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

	NSString *s = [[self textStorage] string];
	if (start_location >= [s length]) {
		MESSAGE(@"No characters to delete");
		return NO;
	}

	[self deleteRange:NSMakeRange(start_location, 1)];
	final_location = start_location;
	return YES;
}

- (NSUInteger)removeTrailingAutoIndentForLineAtLocation:(NSUInteger)aLocation
{
	DEBUG(@"checking for auto-indent at %lu", aLocation);
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:aLocation];
	NSRange r;
	if ([[self textStorage] attribute:ViAutoIndentAttributeName
				  atIndex:bol
			   effectiveRange:&r]) {
		DEBUG(@"got auto-indent whitespace in range %@ for line between %lu and %lu",
		    NSStringFromRange(r), bol, eol);
		[[self textStorage] removeAttribute:ViAutoIndentAttributeName
					      range:r];
		if (r.location == bol && NSMaxRange(r) == eol) {
			[self replaceCharactersInRange:NSMakeRange(bol, eol - bol) withString:@""];
			return bol;
		}
	}

	return aLocation;
}

- (BOOL)normal_mode:(ViCommand *)command
{
	if (mode == ViInsertMode) {
		if (!replayingInput) {
			/*
			 * Remember the typed keys so we can repeat it
			 * with the dot command.
			 */
			[_lastEditCommand setText:_inputKeys];

			/*
			 * A count given to the command that started insert
			 * mode (i, I, a or A) means we should multiply the
			 * inserted text.
			 */
			DEBUG(@"last edit command is %@, got %lu input keys",
			    _lastEditCommand, [_inputKeys count]);
			int count = IMAX(1, _lastEditCommand.count);
			if (count > 1) {
				replayingInput = YES;
				for (int i = 1; i < count; i++)
					[_keyManager handleKeys:_inputKeys
							inScope:[document scopeAtLocation:[self caret]]];
				replayingInput = NO;
			}
		}

		[_inputKeys removeAllObjects];
		start_location = end_location = [self caret];
		[[self document] setMark:'^' atLocation:start_location];
		[self move_left:nil];
	}

	final_location = [self removeTrailingAutoIndentForLineAtLocation:end_location];

	[self deselectSnippet];

	[self setNormalMode];
	[self setCaret:final_location];
	[self resetSelection];

	return YES;
}

- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command
{
	DEBUG(@"eval command %@ from key sequence %@", command, [NSString stringWithKeySequence:command.keySequence]);
	if (mode == ViInsertMode && !replayingInput && command.action != @selector(normal_mode:)) {
		/* Add the key to the input replay queue. */
		[_inputKeys addObjectsFromArray:command.keySequence];
	}

	id target = [self targetForSelector:command.action];
	if (target == nil) {
		MESSAGE(@"Command %@ not implemented.",
		    command.mapping.keyString);
		return NO;
	}

	if (document.busy && !command.isMotion) {
		MESSAGE(@"Document is busy");
		return NO;
	}

	id motion_target = nil;
	if (command.motion) {
		motion_target = [self targetForSelector:command.motion.action];
		if (motion_target == nil) {
			MESSAGE(@"Motion command %@ not implemented.",
			    command.motion.mapping.keyString);
			return NO;
		}
	}

	/* Default start- and end-location is the current location. */
	start_location = [self caret];
	end_location = start_location;
	final_location = NSNotFound;
	affectedRange = NSMakeRange(start_location, 0);
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
	} else if (command.motion.action == @selector(move_down_soft:) ||
	    command.motion.action == @selector(move_up_soft:) ||
	    command.action == @selector(move_down_soft:) ||
	    command.action == @selector(move_up_soft:)) {
		if (saved_column < 0)
			saved_column = [self currentScreenColumn];
	} else
		saved_column = -1;

	/* nvi-style undo direction toggling */
	if (command.action != @selector(vi_undo:) && !command.fromDot)
		undo_direction = 0;

	if (command.motion) {
		/* The command has an associated motion component.
		 * Run the motion command and record the start and end locations.
		 */
		DEBUG(@"perform motion command %@", command.motion);
		if (![command.motion performWithTarget:motion_target])
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

	if (command.isLineMode && !command.isMotion && (mode != ViVisualMode || !visual_line_mode)) {
		/*
		 * If this command is line oriented, extend the
		 * affectedRange to whole lines. However, don't
		 * do this for Visual-Line mode, this is done in
		 * setVisualSelection.
		 */
		NSUInteger bol, end, eol;
		[self getLineStart:&bol end:&end contentsEnd:&eol forLocation:l1];

		if (command.motion == nil && mode != ViVisualMode) {
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
		DEBUG(@"after line mode correction (count %i): %u -> %u (%u chars)",
		    command.count, l1, l2, l2 - l1);
	}
	affectedRange = NSMakeRange(l1, l2 - l1);

	int affected_lines = 0;
	if (!command.isMotion && mode == ViVisualMode)
		affected_lines = (int)([[self textStorage] lineNumberAtLocation:IMAX(l1,l2-1)] - [[self textStorage] lineNumberAtLocation:l1] + 1);

	BOOL leaveVisualMode = NO;
	if (mode == ViVisualMode && !command.isMotion &&
	    command.action != @selector(visual:) &&
	    command.action != @selector(visual_other:) &&
	    command.action != @selector(visual_line:)) {
		/* If in visual mode, edit commands leave visual mode. */
		leaveVisualMode = YES;
	}

	DEBUG(@"perform command %@", command);
	DEBUG(@"start_location = %u", start_location);
	BOOL ok = [command performWithTarget:target];

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
		final_location = [[self textStorage] firstNonBlankForLineAtLocation:final_location];
	}

	if (ok && command.isLineMode && !command.isMotion && mode == ViVisualMode) {
		// FIXME: should set motion to emulate line mode if operator is not line mode but visual_line_mode is set
		command.saved_count = affected_lines;
		// else {
		//	command.motion = [ViCommand commandWithMapping:move_down count:affected_lines];
		// }
		DEBUG(@"set saved_count to %lu", command.saved_count);
	}

	if (leaveVisualMode && mode == ViVisualMode) {
		/* If the command didn't itself leave visual mode, do it now. */
		[self setNormalMode];
		[self resetSelection];
	}

	DEBUG(@"final_location is %u", final_location);
	if (final_location != NSNotFound) {
		[self setCaret:final_location];
		ViSnippet *snippet = document.snippet;
		if (snippet) {
			NSRange sel = snippet.selectedRange;
			if (!NSLocationInRange(final_location, sel))
				[self deselectSnippet];
		}

		if (!replayingInput)
			[self scrollToCaret];
	} else
		[self updateCaret];

	if (mode == ViVisualMode)
		[self setVisualSelection];

	if (mode != ViInsertMode)
		[self endUndoGroup];

	/* TODO hm?
	if (ok && !keepMessagesHack)
		[self updateStatus];
	keepMessagesHack = NO;
	*/

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"matchparen"])
		[self highlightSmartPairAtLocation:[self caret]];

	return ok;
}

- (void)insertText:(id)aString replacementRange:(NSRange)replacementRange
{
	NSString *string;

	if ([aString isMemberOfClass:[NSAttributedString class]])
		string = [aString string];
	else
		string = aString;

	DEBUG(@"string = [%@], len %i, replacementRange = %@, hasMarkedText %s",
	    string, [string length], NSStringFromRange(replacementRange), [self hasMarkedText] ? "YES" : "NO");

	if ([self hasMarkedText]) {
		DEBUG(@"unmarking marked text in range %@", NSStringFromRange([self markedRange]));
		[self setMarkedText:@"" selectedRange:NSMakeRange(0, 0)];
	}

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
			[_keyManager handleKey:[string characterAtIndex:i]
				       inScope:[document scopeAtLocation:[self caret]]];
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
	MESSAGE(@"%@", [error localizedDescription]);
}

- (void)keyManager:(ViKeyManager *)aKeyManager
  partialKeyString:(NSString *)keyString
{
	MESSAGE(@"%@", keyString);
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	DEBUG(@"got key equivalent event %p = %@", theEvent, theEvent);

	if ([[self window] firstResponder] != self)
		return NO;

	if ([self hasMarkedText])
		return [super performKeyEquivalent:theEvent];

	return [_keyManager performKeyEquivalent:theEvent
					 inScope:[document scopeAtLocation:[self caret]]];
}

- (void)keyDown:(NSEvent *)theEvent
{
	DEBUG(@"got keyDown event: %p = %@", theEvent, theEvent);

	BOOL hadMarkedText = [self hasMarkedText];
	handlingKey = YES;
	[super keyDown:theEvent];
	handlingKey = NO;
	DEBUG(@"done interpreting key events, inserted key = %s",
	    insertedKey ? "YES" : "NO");

	if (!insertedKey && !hadMarkedText && ![self hasMarkedText]) {
		DEBUG(@"decoding event %@", theEvent);
		[_keyManager keyDown:theEvent inScope:[document scopeAtLocation:[self caret]]];
	}
	insertedKey = NO;
}

- (NSNumber *)keyManager:(ViKeyManager *)aKeyManager
	  shouldParseKey:(NSNumber *)keyNum
		 inScope:(ViScope *)scope
{
	NSInteger keyCode = [keyNum integerValue];

	/*
	 * Find and perform bundle commands. Show a menu with commands
	 * if multiple matches found.
	 */
	if (!_keyManager.parser.partial && ![self isFieldEditor]) {
		NSArray *matches = [[ViBundleStore defaultStore] itemsWithKeyCode:keyCode
								    matchingScope:scope
									   inMode:mode];
		DEBUG(@"key %@ in scope %@ matched bundle items %@",
		    [NSString stringWithKeyCode:keyCode], scope, matches);
		if ([matches count] > 0) {
			[self performBundleItems:matches];
			return [NSNumber numberWithBool:NO]; /* We already handled the key */
		}

		if (mode == ViVisualMode)
			[_keyManager.parser setVisualMap];
		else if (mode == ViInsertMode)
			[_keyManager.parser setInsertMap];
	}

	return [NSNumber numberWithBool:YES];
}

- (void)swipeWithEvent:(NSEvent *)event
{
	BOOL rc = NO, keep_message = NO;

	DEBUG(@"got swipe event %@", event);

	if ([event deltaX] != 0) {
		if (mode == ViInsertMode) {
			MESSAGE(@"Swipe event interrupted text insert mode.");
			[self normal_mode:_lastEditCommand];
		} else if (_keyManager.parser.partial)
			MESSAGE(@"Vi command interrupted.");
		keep_message = YES;
		[_keyManager.parser reset];
	}

	start_location = [self caret];

	if ([event deltaX] > 0)
		rc = [self jumplist_backward:nil];
	else if ([event deltaX] < 0)
		rc = [self jumplist_forward:nil];

	if (rc == YES && !keep_message)
		MESSAGE(@""); // erase any previous message
}

/* Takes a string of characters and creates a macro of it.
 * Then feeds it into the key manager.
 */
- (BOOL)input:(NSString *)inputString
{
	NSArray *keys = [inputString keyCodes];
	if (keys == nil) {
		INFO(@"invalid key sequence: %@", inputString);
		return NO;
	}

	BOOL interactive = ([self window] != nil || [self isFieldEditor]);
	return [_keyManager runAsMacro:inputString interactively:interactive];
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
		NSDictionary *sizeAttribute = [[NSDictionary alloc] initWithObjectsAndKeys:[ViThemeStore font], NSFontAttributeName, nil];
		CGFloat sizeOfCharacter = [@" " sizeWithAttributes:sizeAttribute].width;
		[sizeAttribute release];
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
	[self setCaretColor:[aTheme caretColor]];
	[self setLineHighlightColor:[aTheme lineHighlightColor]];
	[self setBackgroundColor:[aTheme backgroundColor]];
	[[self enclosingScrollView] setBackgroundColor:[aTheme backgroundColor]];
	[self setInsertionPointColor:[aTheme caretColor]];
	[self setSelectedTextAttributes:[NSDictionary dictionaryWithObject:[aTheme selectionColor]
								    forKey:NSBackgroundColorAttributeName]];

	backgroundIsDark = [aTheme hasDarkBackground];
	[self setCursorColor];
}

- (NSFont *)font
{
	if ([self isFieldEditor])
		return [super font];
	return [ViThemeStore font];
}

- (void)setTypingAttributes:(NSDictionary *)attributes
{
	if ([self isFieldEditor]) {
		[super setTypingAttributes:attributes];
		[self updateFont];
	}
}

- (NSDictionary *)typingAttributes
{
	if ([self isFieldEditor])
		return [super typingAttributes];
	return [document typingAttributes];
}

- (NSUInteger)currentLine
{
	return [[self textStorage] lineNumberAtLocation:[self caret]];
}

- (NSUInteger)currentColumn
{
	return [[self textStorage] columnAtLocation:[self caret]];
}

- (NSUInteger)currentScreenColumn
{
	NSRange lineRange;
	NSUInteger length = [[self textStorage] length];
	if (length == 0)
		return 0;
	NSUInteger glyphIndex = [[self layoutManager] glyphIndexForCharacterAtIndex:IMIN(start_location, length - 1)];
	[[self layoutManager] lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineRange];
	return glyphIndex - lineRange.location + 1; /* XXX: mixing glyphs and characters? */
}

/* syntax: ctrl-P */
- (BOOL)show_scope:(ViCommand *)command
{
	MESSAGE(@"%@", [[[document scopeAtLocation:[self caret]] scopes] componentsJoinedByString:@" "]);
	return NO;
}

- (void)pushLocationOnJumpList:(NSUInteger)aLocation
{
	ViJumpList *jumplist = [[[self window] windowController] jumpList];
	[jumplist push:[self markAtLocation:aLocation]];

	[[self document] setMark:'\'' atLocation:aLocation];
	[[self document] setMark:'`' atLocation:aLocation];
}

- (void)pushCurrentLocationOnJumpList
{
	[self pushLocationOnJumpList:[self caret]];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	visual_start_location = [self characterIndexForInsertionAtPoint:point];
	if (visual_start_location >= [[self textStorage] length])
		visual_start_location = IMAX(0, [[self textStorage] length] - 1);
	NSUInteger bol, eol;
	[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:visual_start_location];
	if (visual_start_location >= eol && bol < eol)
		visual_start_location = eol - 1;
	DEBUG(@"clicked %li times at location %lu", [theEvent clickCount], visual_start_location);

	_selection_affinity = (int)[theEvent clickCount];
	if (_selection_affinity <= 1)
		_selection_affinity = 1;
	else if (_selection_affinity > 3)
		_selection_affinity = 3;

	if (_selection_affinity == 2) {
		/* align to word boundaries */
		NSRange wordRange = [[self textStorage] rangeOfWordAtLocation:visual_start_location
								  acceptAfter:NO];
		if (wordRange.location != NSNotFound) {
			visual_start_location = wordRange.location;
			[self setCaret:NSMaxRange(wordRange) - 1];
		} else
			[self setCaret:visual_start_location];
	} else if (visual_start_location != [self caret])
		[self setCaret:visual_start_location];

	if (_selection_affinity > 1) {
		visual_line_mode = (_selection_affinity == 3);
		[self setVisualMode];
		[self setVisualSelection];
	} else {
		[self setNormalMode];
		[self resetSelection];
	}

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"matchparen"])
		[self highlightSmartPairAtLocation:[self caret]];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSUInteger location = [self characterIndexForInsertionAtPoint:point];
	DEBUG(@"dragged from location %lu -> %lu", visual_start_location, location);

	if (mode != ViVisualMode) {
		visual_line_mode = (_selection_affinity == 3);
		[self setVisualMode];
	}

	if (_selection_affinity == 2) {
		/* align to word boundaries */
		NSRange wordRange = [[self textStorage] rangeOfWordAtLocation:visual_start_location
								  acceptAfter:NO];
		if (wordRange.location != NSNotFound) {
			if (location > visual_start_location)
				visual_start_location = wordRange.location;
			else
				visual_start_location = NSMaxRange(wordRange) - 1;
		}

		wordRange = [[self textStorage] rangeOfWordAtLocation:location
							  acceptAfter:NO];
		if (wordRange.location != NSNotFound) {
			if (location > visual_start_location)
				[self setCaret:NSMaxRange(wordRange) - 1];
			else
				[self setCaret:wordRange.location];
		} else
			[self setCaret:location];
	} else
		[self setCaret:location];

	[self scrollToCaret];
	[self setVisualSelection];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
	NSMenu *menu = [self menuForEvent:theEvent];
	NSString *title = [[document language] displayName];
	NSMenuItem *item = title ? [menu itemWithTitle:title] : nil;
	if (item) {
		NSPoint event_location = [theEvent locationInWindow];
		NSPoint local_point = [self convertPoint:event_location fromView:nil];
		[menu popUpMenuPositioningItem:item atLocation:local_point inView:self];
	} else
		[NSMenu popUpContextMenu:menu withEvent:theEvent forView:self];

	/*
	 * Must remove the bundle menu items, otherwise the key equivalents
	 * remain active and interfere with the handling in keyDown:.
	 */
	[menu removeAllItems];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent atLocation:(NSUInteger)location
{
	NSMenu *menu = [super menuForEvent:theEvent];
	int n = 0;

	ViScope *scope = [document scopeAtLocation:location];
	NSRange sel = [self selectedRange];
	NSMenuItem *item;
	NSMenu *submenu;

	for (ViBundle *bundle in [[ViBundleStore defaultStore] allBundles]) {
		submenu = [bundle menuForScope:scope
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

	ViLanguage *curLang = [document language];

	submenu = [[[NSMenu alloc] initWithTitle:@"Language syntax"] autorelease];
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

	NSArray *sortedLanguages = [[ViBundleStore defaultStore] sortedLanguages];
	for (ViLanguage *lang in sortedLanguages) {
		item = [submenu addItemWithTitle:[lang displayName]
					  action:@selector(setLanguageAction:)
				   keyEquivalent:@""];
		[item setRepresentedObject:lang];
		if (curLang == lang)
			[item setState:NSOnState];
	}

	if ([sortedLanguages count] > 0)
		[submenu addItem:[NSMenuItem separatorItem]];
	[submenu addItemWithTitle:@"Get more bundles..."
			   action:@selector(getMoreBundles:)
		    keyEquivalent:@""];

	[menu insertItem:[NSMenuItem separatorItem] atIndex:n];
	[menu setFont:[NSFont menuFontOfSize:0]];

	return menu;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSInteger charIndex = [self characterIndexForInsertionAtPoint:point];
	if (charIndex == NSNotFound)
		return [super menuForEvent:theEvent];

	[self setCaret:charIndex];
	return [self menuForEvent:theEvent atLocation:charIndex];
}

- (IBAction)performNormalModeMenuItem:(id)sender
{
	if ([self isFieldEditor]) {
		return;
	}

	if (_keyManager.parser.partial) {
		[[[[self window] windowController] nextRunloop] message:@"Vi command interrupted."];
		[_keyManager.parser reset];
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
	_showingContextMenu = YES;	/* XXX: this disables the selection caused by NSMenu. */
	[self rightMouseDown:[self popUpContextEvent]];
	_showingContextMenu = NO;
	return YES;
}

- (NSEvent *)popUpContextEvent
{
	NSPoint point = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange([self caret], 0)
							inTextContainer:[self textContainer]].origin;

	NSSize inset = [self textContainerInset];
	NSPoint origin = [self textContainerOrigin];
	point.x += origin.x;
	point.y += origin.y;
	point.x += inset.width;
	point.y += inset.height;

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
	_showingContextMenu = YES;	/* XXX: this disables the selection caused by NSMenu. */
	[NSMenu popUpContextMenu:menu withEvent:[self popUpContextEvent] forView:self];
	_showingContextMenu = NO;
}

- (NSDictionary *)environment
{
	NSMutableDictionary *env = [NSMutableDictionary dictionary];
	[ViBundle setupEnvironment:env forTextView:self window:[self window] bundle:nil];
	return env;
}

- (void)rememberNormalModeInputSource
{
	if (mode != ViInsertMode) {
		TISInputSourceRef input = TISCopyCurrentKeyboardInputSource();
		DEBUG(@"%p: remembering original normal input: %@", self,
			TISGetInputSourceProperty(input, kTISPropertyLocalizedName));
		original_normal_source = input;
	}
}

/*
 * Called just before the mode is changed from ViInsertMode.
 */
- (void)switchToNormalInputSourceAndRemember:(BOOL)rememberFlag
{
	TISInputSourceRef input = TISCopyCurrentKeyboardInputSource();

	if (original_insert_source != input && mode == ViInsertMode) {
		DEBUG(@"%p: remembering original insert input: %@", self,
		    TISGetInputSourceProperty(input, kTISPropertyLocalizedName));
		original_insert_source = input;
	}

	if (mode != ViInsertMode) {
		if (rememberFlag) {
			DEBUG(@"%p: remembering original normal input: %@", self,
			    TISGetInputSourceProperty(input, kTISPropertyLocalizedName));
			original_normal_source = input;
		}
	}

	if (input != original_normal_source &&
	    original_normal_source &&
	    CFBooleanGetValue(TISGetInputSourceProperty(original_normal_source, kTISPropertyInputSourceIsASCIICapable))) {
		DEBUG(@"%p: switching to original normal input: %@", self,
		    TISGetInputSourceProperty(original_normal_source, kTISPropertyLocalizedName));
		TISSelectInputSource(original_normal_source);
		return;
	}

	if (!CFBooleanGetValue(TISGetInputSourceProperty(input, kTISPropertyInputSourceIsASCIICapable))) {

		/* Get an ASCII compatible input source. Try the users language first.
		 */
		 TISInputSourceRef ascii_input = NULL;

		NSString *locale = [[NSLocale currentLocale] localeIdentifier];
		if (locale)
			ascii_input = TISCopyInputSourceForLanguage((CFStringRef)locale);

		/* Otherwise let the system provide an ASCII compatible input source.
		 */
		if (ascii_input == NULL ||
		    !CFBooleanGetValue(TISGetInputSourceProperty(ascii_input, kTISPropertyInputSourceIsASCIICapable)))
			ascii_input = TISCopyCurrentASCIICapableKeyboardInputSource();

		DEBUG(@"%p: switching to ascii input: %@", self,
		    TISGetInputSourceProperty(ascii_input, kTISPropertyLocalizedName));
		TISSelectInputSource(ascii_input);
	}
}

/*
 * Called just before the mode is changed to ViInsertMode.
 */
- (void)switchToInsertInputSource
{
	TISInputSourceRef input = TISCopyCurrentKeyboardInputSource();

	if (mode != ViInsertMode) {
		DEBUG(@"%p: remembering original normal input: %@", self,
		    TISGetInputSourceProperty(input, kTISPropertyLocalizedName));
		original_normal_source = input;
	}

	if (input != original_insert_source) {
		DEBUG(@"%p: switching to original insert input: %@", self,
		    TISGetInputSourceProperty(original_insert_source, kTISPropertyLocalizedName));
		TISSelectInputSource(original_insert_source);
	}
}

- (void)resetInputSource
{
	if (mode == ViInsertMode)
		[self switchToInsertInputSource];
	else
		[self switchToNormalInputSourceAndRemember:NO];
}

@end

