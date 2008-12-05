#import <Cocoa/Cocoa.h>
#import "ViTagStack.h"

@class PSMTabBarControl;
@class ViDocument;
@class ViDocumentView;
@class ProjectDelegate;
@class ViResizeView;

@interface ViWindowController : NSWindowController
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSSplitView *splitView;
	IBOutlet NSView *documentView;
	IBOutlet NSToolbar *toolbar;
	IBOutlet NSTextField *statusbar;
	ViTagStack *tagStack;
	BOOL isLoaded;
	ViDocument *initialDocument;
	ViDocument *lastDocument;
	ViDocument *selectedDocument;

	ViDocument *mostRecentDocument;
	ViDocumentView *mostRecentView;

	// project list
	IBOutlet NSOutlineView *projectOutline;
	IBOutlet ProjectDelegate *projectDelegate;
	IBOutlet NSImageView *projectResizeView;

	// symbol list
	IBOutlet NSImageView *symbolsResizeView;
	IBOutlet NSView *symbolsView;
	IBOutlet NSSearchField *symbolFilterField;
	IBOutlet NSOutlineView *symbolsOutline;
	NSCell *separatorCell;
	NSMutableArray *documents;
	NSMutableArray *filteredDocuments;
	NSMutableDictionary *symbolFilterCache;
	BOOL closeSymbolListAfterUse;
}

@property(readwrite, assign) NSMutableArray *documents;
@property(readwrite, assign) ViDocument *selectedDocument;
@property(readonly) NSTextField *statusbar;

+ (id)currentWindowController;
+ (NSWindow *)currentMainWindow;

- (void)setMostRecentDocument:(ViDocument *)document view:(ViDocumentView *)docView;
- (void)selectDocument:(ViDocument *)aDocument;

- (IBAction)saveProject:(id)sender;
- (void)addNewTab:(ViDocument *)document;
- (ViDocument *)currentDocument;
- (void)selectDocument:(ViDocument *)document;

- (ViTagStack *)sharedTagStack;

- (IBAction)selectNextTab:(id)sender;
- (IBAction)selectPreviousTab:(id)sender;

- (void)switchToLastFile;

- (IBAction)searchSymbol:(id)sender;
- (IBAction)filterSymbols:(id)sender;
- (IBAction)toggleSymbolList:(id)sender;

- (IBAction)splitViewHorizontally:(id)sender;

- (BOOL)searchField:(NSSearchField *)aSearchField doCommandBySelector:(SEL)aSelector;

@end

