#import <Cocoa/Cocoa.h>
#import "ViTagStack.h"

@class PSMTabBarControl;
@class ViDocument;
@class ProjectDelegate;
@class ViResizeView;

@interface ViWindowController : NSWindowController
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSTabView *tabView;
	IBOutlet NSSplitView *splitView;
	IBOutlet NSOutlineView *projectOutline;
	IBOutlet NSToolbar *toolbar;
	IBOutlet ProjectDelegate *projectDelegate;
	IBOutlet NSImageView *projectResizeView;
	IBOutlet NSImageView *symbolsResizeView;
	IBOutlet NSView *symbolsView;
	IBOutlet NSSearchField *symbolFilterField;
	IBOutlet NSOutlineView *symbolsOutline;
	NSCell *separatorCell;
	ViTagStack *tagStack;
	BOOL isLoaded;
	ViDocument *initialDocument;
	ViDocument *lastDocument;
	NSMutableArray *documents;
	NSMutableArray *filteredDocuments;
	NSTextView *symbolFieldEditor;
}

@property(readwrite, assign) NSMutableArray *documents;

+ (id)currentWindowController;
+ (NSWindow *)currentMainWindow;

- (IBAction)saveProject:(id)sender;

- (void)addNewTab:(ViDocument *)document;

- (int)numberOfTabViewItems;
- (void)removeTabViewItemContainingDocument:(ViDocument *)doc;
- (NSTabViewItem *)tabViewItemForDocument:(ViDocument *)doc;
- (ViDocument *)currentDocument;
- (void)selectDocument:(ViDocument *)document;

- (ViTagStack *)sharedTagStack;

- (IBAction)selectTab:(id)sender;
- (IBAction)selectNextTab:(id)sender;
- (IBAction)selectPreviousTab:(id)sender;

- (void)switchToLastFile;

- (IBAction)searchSymbol:(id)sender;
- (IBAction)filterSymbols:(id)sender;
- (IBAction)toggleSymbolList:(id)sender;

- (BOOL)searchField:(NSSearchField *)aSearchField doCommandBySelector:(SEL)aSelector;

@end

