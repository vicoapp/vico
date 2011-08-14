#import "ViParser.h"
#import "ViCommand.h"
#import "ViTheme.h"
#import "ViLanguage.h"
#import "ViBundle.h"
#import "logging.h"
#import "ViSyntaxParser.h"
#import "ViSnippet.h"
#import "ExEnvironment.h"
#import "ViCommon.h"
#import "ViTextStorage.h"
#import "ViKeyManager.h"
#import "ViDocument.h"
#import "ViCompletionController.h"
#import "ViMark.h"
#import "ExCommand.h"

#include <Carbon/carbon.h>

#define MESSAGE(fmt, ...)	[(ViWindowController *)[[self window] windowController] message:fmt, ## __VA_ARGS__]

@class ViDocumentView;
@class ViWindowController;
@class ViTextView;
@class ViJumpList;

/** A text edit view.
 *
 */
@interface ViTextView : NSTextView <ViSnippetDelegate, ViCompletionDelegate, ViKeyManagerTarget>
{
	ViDocument		*document;

	TISInputSourceRef	 original_insert_source;
	TISInputSourceRef	 original_normal_source;

	ViMode			 mode;
	ViKeyManager		*keyManager;

	/* Command that entered insert mode. Used to set the inserted
	 * text for the dot command. */
	ViCommand		*lastEditCommand;

	BOOL			 insertedKey; // true if insertText: called
	BOOL			 handlingKey; // true while inside keyDown: method
	BOOL			 replayingInput;  // true when dot command replays input
	NSMutableArray		*inputKeys; // used for replaying input

	// FIXME: move these to the ViCommand as properties
	NSRange			 affectedRange;
	NSUInteger		 start_location, end_location, final_location;
	NSUInteger		 modify_start_location;
	BOOL			 keepMessagesHack;

	NSRange			 snippetMatchRange;

	NSUndoManager		*undoManager;

	// block cursor
	NSUInteger		 caret;
	NSRect			 caretRect;
	NSRect			 lineHighlightRect;
	NSRect			 oldCaretRect;
	NSRect			 oldLineHighlightRect;
	NSColor			*caretColor;
	NSColor			*lineHighlightColor;
	BOOL			 highlightCursorLine;

	NSInteger		 saved_column;
	NSString		*initial_ex_command;
	NSInteger		 initial_line, initial_column;
	NSString		*initial_find_pattern;
	unsigned		 initial_find_options;

	// visual mode
	NSUInteger		 visual_start_location;
	BOOL			 visual_line_mode;
	int			 selection_affinity; /* 1 = char, 2 = word, 3 = line */

	BOOL			 showingContextMenu;

	NSMutableCharacterSet	*wordSet;
	NSMutableCharacterSet	*nonWordSet;
	NSCharacterSet		*whitespace;

	NSMutableDictionary	*marks; // XXX: move to document

	CGFloat			 pageGuideX;
	BOOL			 antialias;
	BOOL			 hasUndoGroup;
	int			 undo_direction;	// 0 = none, 1 = backward (normal undo), 2 = forward (redo)
}

/** Associated key manager.
 */
@property(nonatomic,readwrite,assign) ViKeyManager *keyManager;

/** Associated document.
 */
@property(nonatomic,readonly) ViDocument *document;

/** Vi mode (insert, normal or visual).
 */
@property(nonatomic,readonly) ViMode mode;

/** YES if in visual line mode.
 * Only valid if in visual mode.
 */
@property(nonatomic,readwrite) BOOL visual_line_mode;

+ (ViTextView *)makeFieldEditor;

- (void)initWithDocument:(ViDocument *)aDocument
                viParser:(ViParser *)aParser;

/**
 * @returns The associated ViTextStorage object.
 */
- (ViTextStorage *)textStorage;

- (void)documentDidLoad:(ViDocument *)aDocument;
- (void)beginUndoGroup;
- (void)endUndoGroup;
- (void)getLineStart:(NSUInteger *)bol_ptr
                 end:(NSUInteger *)end_ptr
         contentsEnd:(NSUInteger *)eol_ptr
         forLocation:(NSUInteger)aLocation;
- (void)getLineStart:(NSUInteger *)bol_ptr
                 end:(NSUInteger *)end_ptr
         contentsEnd:(NSUInteger *)eol_ptr;
- (NSString *)indentStringOfLength:(NSInteger)length;
- (NSUInteger)lengthOfIndentString:(NSString *)indent;
- (NSUInteger)lengthOfIndentAtLocation:(NSUInteger)aLocation;
- (NSInteger)calculatedIndentLengthAtLocation:(NSUInteger)aLocation;
- (BOOL)shouldDecreaseIndentAtLocation:(NSUInteger)aLocation;
- (BOOL)shouldIncreaseIndentAtLocation:(NSUInteger)aLocation;
- (BOOL)shouldIncreaseIndentOnceAtLocation:(NSUInteger)aLocation;
- (BOOL)shouldIgnoreIndentAtLocation:(NSUInteger)aLocation;
- (NSString*)suggestedIndentAtLocation:(NSUInteger)location
                      forceSmartIndent:(BOOL)smartFlag;
- (NSString *)suggestedIndentAtLocation:(NSUInteger)location;
- (NSRange)changeIndentation:(int)delta
		     inRange:(NSRange)aRange
		 updateCaret:(NSUInteger *)updatedCaret
	      alignToTabstop:(BOOL)alignToTabstop
	    indentEmptyLines:(BOOL)indentEmptyLines;
- (void)gotoScreenColumn:(NSUInteger)column fromGlyphIndex:(NSUInteger)glyphIndex;

- (void)resetSelection;
- (void)updateStatus;

/** Set normal mode.
 */
- (void)setNormalMode;

/** Set visual mode.
 */
- (void)setVisualMode;

- (void)setInsertMode:(ViCommand *)command;
- (void)setInsertMode;

/** Input a string of keys as a macro.
 * @param inputString A key sequence, can include special keys, see ViMap.
 * @returns YES if the macro evaluated successfully.
 */
- (BOOL)input:(NSString *)inputString;

/** @name Caret handling */

/** Set the location of the caret.
 * @param location The location of the caret. Zero-based.
 */
- (void)setCaret:(NSUInteger)location;

/** Scroll the view to the caret.
 *
 * Makes sure the caret is visible.
 */
- (void)scrollToCaret;

/**
 * @returns The location of the caret.
 */
- (NSUInteger)caret;

/**
 * @returns The current line number.
 */
- (NSUInteger)currentLine;

/**
 * @returns The current column.
 */
- (NSUInteger)currentColumn;

/**
 * @returns The current screen column. This may be different from currentColumn if line wrapping is in effect.
 */
- (NSUInteger)currentScreenColumn;

/** Go to a specific column.
 * @param column The column to go to. Zero-based.
 * @param aLocation A location on the line.
 */
- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;

/** Go to a specific line and column.
 * @param line The line number to go to. One-based.
 * @param column The column to go to. Zero-based.
 * @returns YES if the position was valid.
 */
- (BOOL)gotoLine:(NSUInteger)line column:(NSUInteger)column;

/** Get the character at a location.
 * @param location The location to check.
 * @returns The character at the given location, or 0 if location is invalid.
 */
- (unichar)characterAtIndex:(NSUInteger)location;

/**
 * @returns The character under the caret.
 */
- (unichar)currentCharacter;

/**
 * @returns The content of the current line.
 */
- (NSString *)line;

- (NSFont *)font;
- (void)setTheme:(ViTheme *)aTheme;
- (void)setWrapping:(BOOL)flag;
- (void)setPageGuide:(NSInteger)pageGuideValue;
- (void)drawPageGuideInRect:(NSRect)rect;
- (void)rulerView:(NSRulerView *)aRulerView
  selectFromPoint:(NSPoint)fromPoint
          toPoint:(NSPoint)toPoint;

/** @name Setting marks */

/** Lookup a marked location.
 * @param markName The name of the mark.
 * @returns The named mark, or `nil` if not set.
 */
- (ViMark *)markNamed:(unichar)markName;
/** Set a mark.
 * @param name The name of the mark.
 * @param aLocation The location to mark.
 */
- (void)setMark:(unichar)name atLocation:(NSUInteger)aLocation;

- (NSRange)rangeOfPattern:(NSString *)pattern
	     fromLocation:(NSUInteger)start
		  forward:(BOOL)forwardSearch
		    error:(NSError **)outError;
- (BOOL)findPattern:(NSString *)pattern options:(unsigned)find_options;

/** @name Manipulating text */

/** Insert a string at a location.
 * @param aString The string to insert.
 * @param aLocation The location where the string will be inserted. Zero-based.
 */
- (void)insertString:(NSString *)aString
          atLocation:(NSUInteger)aLocation;
/** Insert a string at the current location.
 * @param aString The string to insert.
 */
- (void)insertString:(NSString *)aString;
/** Delete a range of text.
 * @param aRange The range to delete.
 */
- (void)deleteRange:(NSRange)aRange;
/** Replace a range of text with a string.
 * @param aRange The range to replace.
 * @param aString The replacement string.
 */
- (void)replaceRange:(NSRange)aRange
          withString:(NSString *)aString;

- (NSUInteger)insertNewlineAtLocation:(NSUInteger)aLocation
                        indentForward:(BOOL)indentForward;

/** @name Working with registers */
/** Copying text to a register.
 * @param regName The name of the register to copy to.
 * @param yankRange The range of text to copy.
 * @see ViRegisterManager
 */
- (void)yankToRegister:(unichar)regName
                 range:(NSRange)yankRange;
/** Cut text to a register.
 * @param regName The name of the register to cut to.
 * @param cutRange The range of text to cut.
 * @see ViRegisterManager
 */
- (void)cutToRegister:(unichar)regName
                range:(NSRange)cutRange;

- (void)pushLocationOnJumpList:(NSUInteger)aLocation;
- (void)pushCurrentLocationOnJumpList;
- (IBAction)performNormalModeMenuItem:(id)sender;

/** @name Popup menus */

- (NSEvent *)popUpContextEvent;

/** Show a popup menu at the carets location.
 * @param menu The menu to display.
 */
- (void)popUpContextMenu:(NSMenu *)menu;

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
              atLocation:(NSUInteger)location;

/** @name Working with TextMate Bundles */

/**
 * @returns Bundle environment variables.
 */
- (NSDictionary *)environment;

/**
 * @returns A bundle preference at a given location.
 * @param name The name of the Bundle Preference (eg, `shellVariables`)
 * @param aLocation The location where the preference should be valid.
 */
- (id)preference:(NSString *)name atLocation:(NSUInteger)aLocation;

/**
 * @returns A bundle preference at the current location.
 * @param name The name of the Bundle Preference (eg, `shellVariables`)
 */
- (id)preference:(NSString *)name;

- (void)rememberNormalModeInputSource;
- (void)resetInputSource;
- (void)switchToNormalInputSourceAndRemember:(BOOL)rememberFlag;
- (void)switchToInsertInputSource;
@end

/** @name Inserting snippets */
@interface ViTextView (snippets)
- (void)cancelSnippet;
- (ViSnippet *)insertSnippet:(NSString *)snippetString
                  fromBundle:(ViBundle *)bundle
                     inRange:(NSRange)aRange;
/** Insert a snippet, replacing the trigger word.
 * @param snippetString The snippet to insert.
 * @param aRange The range of the trigger word to replace.
 */
- (ViSnippet *)insertSnippet:(NSString *)snippetString
                     inRange:(NSRange)aRange;
/** Insert a snippet at a given location.
 * @param snippetString The snippet to insert.
 * @param aLocation The location to insert the snippet. Zero-based.
 */
- (ViSnippet *)insertSnippet:(NSString *)snippetString
                  atLocation:(NSUInteger)aLocation;
/** Insert a snippet at the current location.
 * @param snippetString The snippet to insert.
 */
- (ViSnippet *)insertSnippet:(NSString *)snippetString;
- (void)performBundleSnippet:(id)sender;
- (void)deselectSnippet;
@end

@interface ViTextView (cursor)
- (void)invalidateCaretRect;
- (void)updateCaret;
@end

@interface ViTextView (syntax)
@end

@interface ViTextView (vi_commands)
- (void)filterRange:(NSRange)range throughCommand:(NSString *)shellCommand;
- (BOOL)insert:(ViCommand *)command;
- (BOOL)move_left:(ViCommand *)command;
- (BOOL)move_right:(ViCommand *)command;
- (BOOL)move_down:(ViCommand *)command;
- (BOOL)move_up:(ViCommand *)command;
- (BOOL)delete:(ViCommand *)command;
- (BOOL)yank:(ViCommand *)command;
- (BOOL)jumplist_forward:(ViCommand *)command;
- (BOOL)jumplist_backward:(ViCommand *)command;
- (BOOL)evalExString:(NSString *)exline;
- (BOOL)presentCompletionsOf:(NSString *)string
		fromProvider:(id<ViCompletionProvider>)provider
		   fromRange:(NSRange)range
		     options:(NSString *)options;
- (BOOL)complete_keyword:(ViCommand *)command;
- (BOOL)complete_path:(ViCommand *)command;
- (BOOL)complete_buffer:(ViCommand *)command;
- (BOOL)complete_ex_command:(ViCommand *)command;
- (BOOL)complete_syntax:(ViCommand *)command;
@end

@interface ViTextView (ex_commands)
- (NSInteger)resolveExAddress:(ExAddress *)addr
		   relativeTo:(NSInteger)relline
			error:(NSError **)outError;
- (NSInteger)resolveExAddress:(ExAddress *)addr
			error:(NSError **)outError;
- (BOOL)resolveExAddresses:(ExCommand *)command
	     intoLineRange:(NSRange *)outRange
		     error:(NSError **)outError;
- (BOOL)resolveExAddresses:(ExCommand *)command
		 intoRange:(NSRange *)outRange
		     error:(NSError **)outError;
- (NSRange)characterRangeForLineRange:(NSRange)lineRange;
@end

@interface ViTextView (bundleCommands)
- (void)performBundleCommand:(ViBundleCommand *)command;
- (void)performBundleItem:(id)bundleItem;
- (void)performBundleItems:(NSArray *)matches;
@end

