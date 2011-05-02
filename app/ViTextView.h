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
#import "ViScriptProxy.h"
#import "ViKeyManager.h"
#import "ViDocument.h"
#import "ViCompletionController.h"

#define MESSAGE(fmt, ...)	[[[self window] windowController] message:fmt, ## __VA_ARGS__]

@class ViDocumentView;
@class ViWindowController;
@class ViTextView;
@class ViJumpList;

@interface ViTextView : NSTextView <ViSnippetDelegate, ViCompletionDelegate>
{
	ViDocument		*document;

	ViMode			 mode;
	ViKeyManager		*keyManager;

	/* Command that entered insert mode. Used to set the inserted
	 * text for the dot command. */
	ViCommand		*lastEditCommand;

	BOOL			 insertedKey; // true if insertText: called
	BOOL			 handlingKey; // true while inside keyDown: method
	BOOL			 replayingInput;  // true when dot command replays input
	NSMutableArray		*inputKeys; // used for replaying input

	ViScriptProxy		*proxy;

	NSRange			 affectedRange;
	NSUInteger		 start_location, end_location, final_location;
	NSUInteger		 modify_start_location;

	NSRange			 snippetMatchRange;

	NSUndoManager		*undoManager;

	// block cursor
	NSUInteger		 caret;
	NSRect			 caretRect;
	NSRect			 oldCaretRect;
	NSColor			*caretColor;

	NSInteger		 saved_column;
	NSInteger		 initial_line, initial_column;
	NSString		*initial_find_pattern;
	unsigned		 initial_find_options;

	// visual mode
	NSUInteger		 visual_start_location;
	BOOL			 visual_line_mode;

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

@property(readonly) ViScriptProxy *proxy;
@property(readonly) ViKeyManager *keyManager;
@property(readonly) ViDocument *document;

- (void)initWithDocument:(ViDocument *)aDocument
                viParser:(ViParser *)aParser;
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
                 updateCaret:(NSUInteger *)updatedCaret;
- (NSRange)changeIndentation:(int)delta inRange:(NSRange)aRange;
- (NSArray *)scopesAtLocation:(NSUInteger)aLocation;
- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;
- (BOOL)gotoLine:(NSUInteger)line column:(NSUInteger)column;
- (void)resetSelection;
- (void)updateStatus;
- (void)setNormalMode;
- (void)setVisualMode;
- (void)setInsertMode:(ViCommand *)command;
- (void)input:(NSString *)inputString;
- (void)setCaret:(NSUInteger)location;
- (void)scrollToCaret;
- (NSUInteger)caret;
- (NSFont *)font;
- (void)setTheme:(ViTheme *)aTheme;
- (void)setWrapping:(BOOL)flag;
- (void)setPageGuide:(NSInteger)pageGuideValue;
- (void)drawPageGuideInRect:(NSRect)rect;
- (void)rulerView:(NSRulerView *)aRulerView
  selectFromPoint:(NSPoint)fromPoint
          toPoint:(NSPoint)toPoint;

- (void)setMark:(unichar)name atLocation:(NSUInteger)aLocation;
- (BOOL)findPattern:(NSString *)pattern options:(unsigned)find_options;

- (void)insertString:(NSString *)aString
          atLocation:(NSUInteger)aLocation
           undoGroup:(BOOL)undoGroup;
- (void)insertString:(NSString *)aString
          atLocation:(NSUInteger)aLocation;
- (void)insertString:(NSString *)aString;
- (void)deleteRange:(NSRange)aRange;
- (void)replaceRange:(NSRange)aRange
          withString:(NSString *)aString
           undoGroup:(BOOL)undoGroup;
- (void)replaceRange:(NSRange)aRange
          withString:(NSString *)aString;

- (NSUInteger)insertNewlineAtLocation:(NSUInteger)aLocation
                        indentForward:(BOOL)indentForward;

- (void)yankToRegister:(unichar)regName
                 range:(NSRange)yankRange;
- (void)cutToRegister:(unichar)regName
                range:(NSRange)cutRange;

- (void)gotoColumn:(NSUInteger)column
      fromLocation:(NSUInteger)aLocation;

- (NSUInteger)currentLine;
- (NSUInteger)currentColumn;
- (void)pushLocationOnJumpList:(NSUInteger)aLocation;
- (void)pushCurrentLocationOnJumpList;
- (IBAction)performNormalModeMenuItem:(id)sender;

- (NSEvent *)popUpContextEvent;
- (void)popUpContextMenu:(NSMenu *)menu;
- (NSMenu *)menuForEvent:(NSEvent *)theEvent
              atLocation:(NSUInteger)location;

- (NSDictionary *)environment;

- (id)preference:(NSString *)name forScope:(NSArray *)scopeArray;
- (id)preference:(NSString *)name atLocation:(NSUInteger)aLocation;
- (id)preference:(NSString *)name;
@end

@interface ViTextView (snippets)
- (void)cancelSnippet:(ViSnippet *)snippet;
- (ViSnippet *)insertSnippet:(NSString *)snippetString
                  fromBundle:(ViBundle *)bundle
                     inRange:(NSRange)aRange;
- (ViSnippet *)insertSnippet:(NSString *)snippetString
                     inRange:(NSRange)aRange;
- (ViSnippet *)insertSnippet:(NSString *)snippetString
                  atLocation:(NSUInteger)aLocation;
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
- (BOOL)insert:(ViCommand *)command;
- (BOOL)move_left:(ViCommand *)command;
- (BOOL)move_right:(ViCommand *)command;
- (BOOL)move_down:(ViCommand *)command;
- (BOOL)move_up:(ViCommand *)command;
- (BOOL)delete:(ViCommand *)command;
- (BOOL)yank:(ViCommand *)command;
- (BOOL)jumplist_forward:(ViCommand *)command;
- (BOOL)jumplist_backward:(ViCommand *)command;
@end

@interface ViTextView (bundleCommands)
- (NSString *)bestMatchingScope:(NSArray *)scopeSelectors
                     atLocation:(NSUInteger)aLocation;
- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                     atLocation:(NSUInteger)aLocation;
- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                        forward:(BOOL)forward
                   fromLocation:(NSUInteger)aLocation;
- (void)performBundleCommand:(ViBundleCommand *)command;
- (void)performBundleItem:(id)bundleItem;
- (void)performBundleItems:(NSArray *)matches;
@end

