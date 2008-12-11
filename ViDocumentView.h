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
- (void)applyScopes:(NSArray *)scopeArray inRange:(NSRange)range;
- (void)reapplyThemeWithScopes:(NSArray *)scopeArray;
- (void)resetAttributesInRange:(NSRange)aRange;

@end
