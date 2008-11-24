#import <Cocoa/Cocoa.h>
#import "ViCommand.h"
#import "ViTheme.h"
#import "ViLanguage.h"
#import "ViTagsDatabase.h"
#import "ViBundle.h"
#import "logging.h"
#import "ViSyntaxParser.h"
#import "ViSnippet.h"

#ifdef IMAX
# undef IMAX
#endif
#define IMAX(a, b)  (((NSInteger)a) > ((NSInteger)b) ? (a) : (b))

#ifdef IMIN
# undef IMIN
#endif
#define IMIN(a, b)  (((NSInteger)a) < ((NSInteger)b) ? (a) : (b))

typedef enum { ViCommandMode, ViNormalMode = ViCommandMode, ViInsertMode, ViVisualMode } ViMode;

@interface ViTextView : NSTextView
{
	ViMode mode;
	ViCommand *parser;
	NSTextStorage *storage;
	NSUndoManager *undoManager;
	ViTagsDatabase *tags;

	NSMutableArray *inputKeys;

	// block cursor
	NSUInteger caret;
	NSRect oldCaretRect;

	NSMutableDictionary *buffers; // points into [[NSApp delegate] sharedBuffers]
	NSRange affectedRange;
	NSUInteger start_location, end_location, final_location;

	// visual mode
	NSUInteger visual_start_location;
	BOOL visual_line_mode;

	NSMutableCharacterSet *wordSet;
	NSMutableCharacterSet *nonWordSet;
	NSCharacterSet *whitespace;

	NSDictionary *inputCommands;
	NSDictionary *normalCommands;

	NSMutableDictionary *marks;

	ViSnippet *activeSnippet;

	// language parsing and highlighting
	BOOL ignoreEditing;
	ViSyntaxParser *syntaxParser;
	ViSyntaxContext *nextContext;
	ViTheme *theme;
	ViBundle *bundle;
	ViLanguage *language;
	BOOL resetFont;

	// symbol list
	NSDictionary *symbolSettings;
	NSMutableArray *symbolScopes;
	NSTimer *updateSymbolsTimer;

	CGFloat pageGuideX;

	BOOL hasUndoGroup;
}

- (void)initEditorWithDelegate:(id)aDelegate;
- (void)setString:(NSString *)aString;
- (void)beginUndoGroup;
- (void)endUndoGroup;
- (void)setLanguageFromString:(NSString *)aLanguage;
- (ViLanguage *)language;
- (void)configureForURL:(NSURL *)aURL;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr forLocation:(NSUInteger)aLocation;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr;
- (NSString *)indentStringOfLength:(int)length;
- (NSString *)indentStringForLevel:(int)level;
- (int)lengthOfIndentString:(NSString *)indent;
- (int)lenghtOfIndentAtLine:(NSUInteger)lineLocation;
- (NSString *)lineForLocation:(NSUInteger)aLocation;
- (NSString *)leadingWhitespaceForLineAtLocation:(NSUInteger)aLocation;
- (int)changeIndentation:(int)delta inRange:(NSRange)aRange;
- (BOOL)isBlankLineAtLocation:(NSUInteger)aLocation;
- (NSArray *)scopesAtLocation:(NSUInteger)aLocation;
- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;
- (void)gotoLine:(NSUInteger)line column:(NSUInteger)column;
- (void)setNormalMode;
- (void)setVisualMode;
- (void)setInsertMode:(ViCommand *)command;
- (void)input:(NSString *)inputString;
- (void)setCaret:(NSUInteger)location;
- (NSUInteger)caret;
- (NSFont *)font;
- (void)setTheme:(ViTheme *)aTheme;
- (void)setTabSize:(int)tabSize;
- (NSUndoManager *)undoManager;
- (void)cutToBuffer:(unichar)bufferName append:(BOOL)appendFlag range:(NSRange)cutRange;
- (NSString *)wordAtLocation:(NSUInteger)aLocation;
- (void)setPageGuide:(int)pageGuideValue;

- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(int)regexpSyntax;
- (BOOL)findPattern:(NSString *)pattern options:(unsigned)find_options;

- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation;
- (void)deleteRange:(NSRange)aRange;
- (void)replaceRange:(NSRange)aRange withString:(NSString *)aString;

- (int)insertNewlineAtLocation:(NSUInteger)aLocation indentForward:(BOOL)indentForward;

- (void)yankToBuffer:(unichar)bufferName append:(BOOL)appendFlag range:(NSRange)yankRange;
- (void)cutToBuffer:(unichar)bufferName append:(BOOL)appendFlag range:(NSRange)cutRange;

- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet from:(NSUInteger)startLocation to:(NSUInteger)toLocation backward:(BOOL)backwardFlag;
- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet fromLocation:(NSUInteger)startLocation backward:(BOOL)backwardFlag;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation toLocation:(NSUInteger)toLocation;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation;

- (NSInteger)locationForStartOfLine:(NSUInteger)aLineNumber;
- (NSUInteger)lineNumberAtLocation:(NSUInteger)aLocation;
- (NSUInteger)currentLine;
- (NSUInteger)currentColumn;

- (void)updateSymbolList:(NSTimer *)timer;

@end

@interface ViTextView (snippets)
- (void)cancelSnippet:(ViSnippet *)snippet;
- (ViSnippet *)insertSnippet:(NSString *)snippetString atLocation:(NSUInteger)aLocation;
- (void)handleSnippetTab:(id)snippetState atLocation:(NSUInteger)aLocation;
@end

@interface ViTextView (cursor)
@end

@interface ViTextView (syntax)
- (void)reapplyTheme;
- (void)highlightEverything;
- (void)pushContinuationsFromLocation:(NSUInteger)aLocation string:(NSString *)aString forward:(BOOL)flag;
@end

@interface ViTextView (vi_commands)
- (BOOL)move_left:(ViCommand *)command;
- (BOOL)delete:(ViCommand *)command;
- (BOOL)yank:(ViCommand *)command;
@end
