#import <Cocoa/Cocoa.h>
#import "ViTextView.h"

@interface ViDocumentView : NSObject
{
	IBOutlet NSView *view;
	IBOutlet ViTextView *textView;
	NSTimer *updateSymbolsTimer;
}

@property(readonly) NSView *view;
@property(readonly) ViTextView *textView;

- (void)applySyntaxResult:(ViSyntaxContext *)context;
- (void)reapplyTheme;
- (void)resetAttributesInRange:(NSRange)aRange;

@end
