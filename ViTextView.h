#import <Cocoa/Cocoa.h>
#import <OgreKit/OgreKit.h>
#import "ViCommand.h"
#import "ViTheme.h"
#import "ViLanguage.h"

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

	NSMutableDictionary *buffers;
	NSRect oldCaretRect;
	NSRange affectedRange;
	NSUInteger start_location, end_location;
	BOOL need_scroll;

	/* syntax highlighting */
	ViTheme *theme;
	ViLanguage *language;

	CGFloat pageGuideX;

	int indent;
}

- (void)initEditor;
- (void)setFilename:(NSURL *)aURL;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr forLocation:(NSUInteger)aLocation;
- (void)getLineStart:(NSUInteger *)bol_ptr end:(NSUInteger *)end_ptr contentsEnd:(NSUInteger *)eol_ptr;
- (void)gotoColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation;
- (void)setCommandMode;
- (void)setInsertMode;
- (void)input:(NSString *)inputString;
- (void)setCaret:(NSUInteger)location;
- (NSUInteger)caret;
- (void)setTheme:(ViTheme *)aTheme;
@end

@interface ViTextView (cursor)
- (void)updateInsertionPoint;
@end

@interface ViTextView (syntax)
- (void)highlightEverything;
@end
