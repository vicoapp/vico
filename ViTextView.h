#import <Cocoa/Cocoa.h>
#import <OgreKit/OgreKit.h>
#import "ViCommand.h"
#import "ViTheme.h"
#import "ViLanguage.h"
#import "ViTagsDatabase.h"

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

	/* syntax highlighting */
	ViTheme *theme;
	NSDictionary *bundle;
	ViLanguage *language;

	NSString *lastSearchPattern;
	OGRegularExpression *lastSearchRegexp;

	CGFloat pageGuideX;

	int indent;
	unsigned regexps_tried;
	unsigned regexps_overlapped;
	unsigned regexps_matched;

	BOOL hasBeginUndoGroup;
}

- (void)initEditor;
- (void)setFilename:(NSURL *)aURL;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr forLocation:(NSUInteger)aLocation;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr;
- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;
- (void)setCommandMode;
- (void)setInsertMode:(ViCommand *)command;
- (void)input:(NSString *)inputString;
- (void)setCaret:(NSUInteger)location;
- (NSUInteger)caret;
- (void)setTheme:(ViTheme *)aTheme;
- (void)setTabSize:(int)tabSize;
- (NSUndoManager *)undoManager;
- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(OgreSyntax)regexpSyntax
   ignoreLastRegexp:(BOOL)ignoreLastRegexp;
@end

@interface ViTextView (cursor)
- (void)updateInsertionPoint;
@end

@interface ViTextView (syntax)
- (void)highlightEverything;
@end
