#import "ViOutlineView.h"

@interface ViMarkInspector : NSWindowController
{
	IBOutlet NSTreeController *markListController;
	IBOutlet NSArrayController *markStackController;
	IBOutlet ViOutlineView *outlineView;
}

+ (ViMarkInspector *)sharedInspector;
- (void)show;

- (IBAction)changeList:(id)sender;
- (IBAction)gotoMark:(id)sender;

@end
