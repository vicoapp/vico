#import <Cocoa/Cocoa.h>
#import "ViRegexp.h"

@interface ProjectDelegate : NSObject
{
	IBOutlet NSWindow *window;
	IBOutlet NSOutlineView *explorer;
	IBOutlet NSMenu *actionMenu;
	IBOutlet NSSearchField *filterField;
	IBOutlet NSSplitView *splitView;
	IBOutlet NSView *explorerView;

	BOOL closeExplorerAfterUse;
	IBOutlet id delegate;
	NSMutableArray *rootItems;
	ViRegexp *skipRegex;
}

@property(readwrite,assign) id delegate;

- (void)addURL:(NSURL *)aURL;
- (IBAction)addLocation:(id)sender;
- (IBAction)actionMenu:(id)sender;

- (IBAction)filterFiles:(id)sender;
- (IBAction)searchFiles:(id)sender;
- (IBAction)toggleExplorer:(id)sender;

@end
