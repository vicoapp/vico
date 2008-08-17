#import <Cocoa/Cocoa.h>
#import "ViCommand.h"

typedef enum { ViCommandMode, ViInsertMode } ViMode;

@interface ViTextView : NSTextView
{
	ViMode mode;
	ViCommand *parser;

	NSMutableDictionary *buffers;
	NSRect oldCaretRect;
	NSRange affectedRange;
	NSUInteger final_location;
}

+ (void)initKeymaps;
- (void)initEditor;
- (void)gotoColumn:(NSUInteger)column fromRange:(NSRange)aRange;
- (void)setCommandMode;
- (void)setInsertMode;
- (void)input:(NSString *)inputString;
- (void)setCaret:(NSUInteger)location;
- (NSUInteger)caret;
@end

@interface ViTextView (cursor)
- (void)updateInsertionPoint;
@end
