#import <Cocoa/Cocoa.h>
#import <OgreKit/OgreKit.h>
#import "ViCommand.h"
#import "ViTheme.h"
#import "ViLanguage.h"
#import "ViTagsDatabase.h"
#import "ViBundle.h"
#import "logging.h"

#ifdef IMAX
# undef IMAX
#endif
#define IMAX(a, b)  (((NSInteger)a) > ((NSInteger)b) ? (a) : (b))

typedef enum { ViCommandMode, ViInsertMode } ViMode;

@interface ViTextView : NSTextView
{
	ViMode mode;
	ViCommand *parser;
	NSTextStorage *storage;
	NSUndoManager *undoManager;
	ViTagsDatabase *tags;

	//NSMutableString *insertedText;
	NSUInteger insert_start_location, insert_end_location;

	NSMutableDictionary *buffers;
	NSRect oldCaretRect;
	NSRange affectedRange;
	NSUInteger start_location, end_location, final_location;
	BOOL need_scroll;

	NSMutableCharacterSet *wordSet;
	NSMutableCharacterSet *nonWordSet;
	NSCharacterSet *whitespace;

	NSDictionary *inputCommands;
	NSDictionary *normalCommands;

	/* syntax highlighting */
	ViTheme *theme;
	ViBundle *bundle;
	ViLanguage *language;

	CGFloat pageGuideX;

	// statistics
	unsigned regexps_tried;
	unsigned regexps_overlapped;
	unsigned regexps_matched;

	BOOL hasBeginUndoGroup;
}

- (void)initEditorWithDelegate:(id)aDelegate;
- (void)setLanguage:(NSString *)aLanguage;
- (ViLanguage *)language;
- (void)configureForURL:(NSURL *)aURL;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr forLocation:(NSUInteger)aLocation;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr;
- (BOOL)isBlankLineAtLocation:(NSUInteger)aLocation;
- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;
- (void)gotoLine:(NSUInteger)line column:(NSUInteger)column;
- (void)setCommandMode;
- (void)setInsertMode:(ViCommand *)command;
- (void)input:(NSString *)inputString;
- (void)setCaret:(NSUInteger)location;
- (NSUInteger)caret;
- (void)setTheme:(ViTheme *)aTheme;
- (void)setTabSize:(int)tabSize;
- (NSUndoManager *)undoManager;
- (void)cutToBuffer:(unichar)bufferName append:(BOOL)appendFlag range:(NSRange)cutRange;
- (NSString *)wordAtLocation:(NSUInteger)aLocation;
- (void)setPageGuide:(int)pageGuideValue;

- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(OgreSyntax)regexpSyntax
   ignoreLastRegexp:(BOOL)ignoreLastRegexp;
- (BOOL)findPattern:(NSString *)pattern options:(unsigned)find_options;

- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation;
- (int)insertNewlineAtLocation:(NSUInteger)aLocation indentForward:(BOOL)indentForward;

- (void)undoDeleteOfString:(NSString *)aString atLocation:(NSUInteger)aLocation;
- (void)undoInsertInRange:(NSRange)aRange;
- (void)recordInsertInRange:(NSRange)aRange;
- (void)recordDeleteOfString:(NSString *)aString atLocation:(NSUInteger)aLocation;
- (void)recordDeleteOfRange:(NSRange)aRange;
- (void)recordReplacementOfRange:(NSRange)aRange withLength:(NSUInteger)aLength;

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

@end

@interface ViTextView (cursor)
- (void)updateInsertionPoint;
@end

@interface ViTextView (syntax)
- (void)highlightEverything;
@end

@interface ViTextView (vi_commands)
- (BOOL)move_left:(ViCommand *)command;
@end
