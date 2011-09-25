#import "ViOutlineView.h"

@interface ViMarkInspector : NSWindowController
{
	IBOutlet NSTreeController	*markListController; // Top-level nib object
	IBOutlet NSArrayController	*markStackController; // Top-level nibobj
	IBOutlet ViOutlineView		*outlineView;
}

+ (ViMarkInspector *)sharedInspector;
- (void)show;

- (IBAction)changeList:(id)sender;
- (IBAction)gotoMark:(id)sender;

@end
