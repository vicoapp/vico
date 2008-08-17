#import <Cocoa/Cocoa.h>
#import "ViCommand.h"

typedef enum { ViCommandMode, ViInsertMode } ViMode;

@interface ViTextView : NSTextView
{
	ViMode mode;
	ViCommand *parser;

	NSRect oldCaretRect;
}

+ (void)initKeymaps;
- (void)initEditor;
- (void)gotoColumn:(NSUInteger)column fromRange:(NSRange)aRange;
- (void)setCommandMode;
- (void)setInsertMode;
- (void)input:(NSString *)inputString;
@end

@interface ViTextView (cursor)
- (void)updateInsertionPoint;
@end
