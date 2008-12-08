#import <Cocoa/Cocoa.h>
#import "ViTextView.h"
#import "ViDocument.h"

@interface ViDocumentView : NSObject
{
	IBOutlet NSView *view;
	IBOutlet ViTextView *textView;
	ViDocument *document;
}

@property(readonly) ViDocument *document;
@property(readonly) NSView *view;
@property(readonly) ViTextView *textView;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument;
- (void)applySyntaxResult:(ViSyntaxContext *)context;
- (void)reapplyTheme;
- (void)resetAttributesInRange:(NSRange)aRange;

@end
