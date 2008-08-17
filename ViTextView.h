#import <Cocoa/Cocoa.h>
#import <OgreKit/OgreKit.h>
#import "ViCommand.h"

typedef enum { ViCommandMode, ViInsertMode } ViMode;

@interface ViTextView : NSTextView
{
	ViMode mode;
	ViCommand *parser;
	NSTextStorage *storage;

	NSMutableDictionary *buffers;
	NSRect oldCaretRect;
	NSRange affectedRange;
	NSUInteger start_location, end_location;
	BOOL need_scroll;

	/* syntax highlighting */
	OGRegularExpression *keywordRegex;
	OGRegularExpression *storageRegex;
	OGRegularExpression *storageModifierRegex;
	NSColor *commentColor;
	NSColor *stringColor;
	NSColor *numberColor;
	NSColor *keywordColor;
	BOOL syntax_initialized;

	CGFloat pageGuideX;
}

- (void)initEditor;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr forLocation:(NSUInteger)aLocation;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr;
- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;
- (void)setCommandMode;
- (void)setInsertMode;
- (void)input:(NSString *)inputString;
- (void)setCaret:(NSUInteger)location;
- (NSUInteger)caret;
@end

@interface ViTextView (cursor)
- (void)updateInsertionPoint;
@end

@interface ViTextView (syntax)
- (void)highlightInRange:(NSRange)aRange;
- (void)highlightEverything;
@end
