#import <Cocoa/Cocoa.h>
#import "ViCommand.h"
#import "ViTheme.h"
#import "ViLanguage.h"
#import "ViTagsDatabase.h"
#import "ViBundle.h"
#import "logging.h"
#import "ViSyntaxParser.h"
#import "ViSnippet.h"

@class ViDocumentView;
@class ViDocument;
@class ViWindowController;
@class ViTextView;

#ifdef IMAX
# undef IMAX
#endif
#define IMAX(a, b)  (((NSInteger)a) > ((NSInteger)b) ? (a) : (b))

#ifdef IMIN
# undef IMIN
#endif
#define IMIN(a, b)  (((NSInteger)a) < ((NSInteger)b) ? (a) : (b))

typedef enum { ViCommandMode, ViNormalMode = ViCommandMode, ViInsertMode, ViVisualMode } ViMode;

@protocol ViTextViewDelegate
- (void)message:(NSString *)fmt, ...;
- (NSURL *)fileURL;
- (ViWindowController *)windowController;
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector prompt:(NSString *)aPrompt;
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector;
- (void)pushLine:(NSUInteger)aLine column:(NSUInteger)aColumn;
- (void)popTag;
- (void)enableLineNumbers:(BOOL)flag;
- (void)saveDocument:(id)sender;
- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation;
- (NSUndoManager *)undoManager;
- (NSArray *)scopesAtLocation:(NSUInteger)aLocation;
- (void)setMostRecentDocumentView:(ViDocumentView *)docView;
@end

@interface ViTextView : NSTextView
{
	ViDocumentView		*documentView;

	// vi command parser
	ViMode			 mode;
	ViCommand		*parser;
	BOOL			 insertedKey; // true if insertText: called
	BOOL			 replayingInput;  // true when dot command replays input
	NSMutableArray		*inputKeys; // used for replaying input

	NSRange			 affectedRange;
	NSUInteger		 start_location, end_location, final_location;

	NSUndoManager		*undoManager;
	NSDictionary		*typingAttributes;

	ViTagsDatabase		*tags; // XXX: doesn't belong here!? Move to the document or window controller.

	// block cursor
	NSUInteger		 caret;
	NSRect			 caretRect;
	NSRect			 oldCaretRect;

	NSMutableDictionary	*buffers; // XXX: points into [[NSApp delegate] sharedBuffers]

	NSInteger		 saved_column;

	// visual mode
	NSUInteger		 visual_start_location;
	BOOL			 visual_line_mode;

	NSMutableCharacterSet	*wordSet;
	NSMutableCharacterSet	*nonWordSet;
	NSCharacterSet		*whitespace;

	NSMutableDictionary	*marks; // XXX: move to document
	ViSnippet		*activeSnippet; // XXX: move to document ?

	CGFloat			 pageGuideX;
	BOOL			 hasUndoGroup;
	int			 undo_direction;	// 0 = none, 1 = backward (normal undo), 2 = forward (redo)
}

- (id <ViTextViewDelegate>)delegate;
- (void)initEditorWithDelegate:(id <ViTextViewDelegate>)aDelegate documentView:(ViDocumentView *)docView;
- (void)setString:(NSString *)aString;
- (void)beginUndoGroup;
- (void)endUndoGroup;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr forLocation:(NSUInteger)aLocation;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr;
- (NSString *)indentStringOfLength:(int)length;
- (NSString *)indentStringForLevel:(int)level;
- (int)lengthOfIndentString:(NSString *)indent;
- (int)lenghtOfIndentAtLine:(NSUInteger)lineLocation;
- (NSString *)lineForLocation:(NSUInteger)aLocation;
- (NSString *)leadingWhitespaceForLineAtLocation:(NSUInteger)aLocation;
- (NSRange)changeIndentation:(int)delta inRange:(NSRange)aRange updateCaret:(NSUInteger *)updatedCaret;
- (NSRange)changeIndentation:(int)delta inRange:(NSRange)aRange;
- (BOOL)isBlankLineAtLocation:(NSUInteger)aLocation;
- (NSArray *)scopesAtLocation:(NSUInteger)aLocation;
- (NSString *)wordAtLocation:(NSUInteger)aLocation range:(NSRange *)returnRange;
- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;
- (void)gotoLine:(NSUInteger)line column:(NSUInteger)column;
- (void)setNormalMode;
- (void)setVisualMode;
- (void)setInsertMode:(ViCommand *)command;
- (void)input:(NSString *)inputString;
- (void)setCaret:(NSUInteger)location;
- (void)scrollToCaret;
- (NSUInteger)caret;
- (NSFont *)font;
- (void)setTheme:(ViTheme *)aTheme;
- (void)resetTypingAttributes;
- (NSUndoManager *)undoManager;
- (void)cutToBuffer:(unichar)bufferName append:(BOOL)appendFlag range:(NSRange)cutRange;
- (NSString *)wordAtLocation:(NSUInteger)aLocation;
- (void)setPageGuide:(int)pageGuideValue;
- (void)drawPageGuideInRect:(NSRect)rect;
- (ViDocument *)document;

- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(int)regexpSyntax;
- (BOOL)findPattern:(NSString *)pattern options:(unsigned)find_options;

- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation;
- (void)deleteRange:(NSRange)aRange;
- (void)replaceRange:(NSRange)aRange withString:(NSString *)aString undoGroup:(BOOL)undoGroup;
- (void)replaceRange:(NSRange)aRange withString:(NSString *)aString;

- (int)insertNewlineAtLocation:(NSUInteger)aLocation indentForward:(BOOL)indentForward;

- (void)yankToBuffer:(unichar)bufferName append:(BOOL)appendFlag range:(NSRange)yankRange;
- (void)cutToBuffer:(unichar)bufferName append:(BOOL)appendFlag range:(NSRange)cutRange;

- (NSUInteger)locationForColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;
- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet from:(NSUInteger)startLocation to:(NSUInteger)toLocation backward:(BOOL)backwardFlag;
- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet fromLocation:(NSUInteger)startLocation backward:(BOOL)backwardFlag;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation toLocation:(NSUInteger)toLocation;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation;

- (NSUInteger)columnAtLocation:(NSUInteger)aLocation;

- (NSUInteger)currentLine;
- (NSUInteger)currentColumn;
- (void)pushLocationOnJumpList:(NSUInteger)aLocation;
- (void)pushCurrentLocationOnJumpList;
@end

@interface ViTextView (snippets)
- (void)cancelSnippet:(ViSnippet *)snippet;
- (ViSnippet *)insertSnippet:(NSString *)snippetString atLocation:(NSUInteger)aLocation;
- (void)handleSnippetTab:(id)snippetState atLocation:(NSUInteger)aLocation;
@end

@interface ViTextView (cursor)
- (void)updateCaret;
@end

@interface ViTextView (syntax)
@end

@interface ViTextView (vi_commands)
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
- (NSRange)trackScopes:(NSArray *)scopes atLocation:(NSUInteger)aLocation;
- (NSRange)trackScopeSelector:(NSString *)scopeSelector atLocation:(NSUInteger)aLocation;
- (NSRange)trackScopes:(NSArray *)scopes forward:(BOOL)forward fromLocation:(NSUInteger)aLocation;
- (NSRange)trackScopeSelector:(NSString *)scopeSelector forward:(BOOL)forward fromLocation:(NSUInteger)aLocation;
- (void)performBundleCommand:(id)sender;
@end

