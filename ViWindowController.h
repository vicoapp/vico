#import "ViTagStack.h"
#import "ViBgView.h"
#import "ViJumpList.h"
#import "ExEnvironment.h"

@class PSMTabBarControl;
@class ViDocument;
@class ViDocumentView;
@class ProjectDelegate;
@class ViResizeView;
@class ViProject;
@class ViCommand;

@interface ViWindowController : NSWindowController <ViJumpListDelegate, NSTextFieldDelegate, NSWindowDelegate, NSToolbarDelegate>
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSTabView *tabView;
	IBOutlet NSSplitView *splitView;	// Split between explorer, main and symbol views
	IBOutlet NSView *mainView;
	IBOutlet ViBgView *explorerView;

	IBOutlet NSView *documentView;

	IBOutlet NSPopUpButton *languageButton;
	IBOutlet NSPopUpButton *openFilesButton;

	IBOutlet ExEnvironment *environment;

	ViTagStack *tagStack;
	BOOL isLoaded;
	ViDocument *initialDocument;
	ViDocumentView *lastDocumentView;
	ViCommand *parser;
	ViProject *project;

	// project list
	IBOutlet ProjectDelegate *projectDelegate;
	IBOutlet NSImageView *projectResizeView;

	// symbol list
	IBOutlet NSImageView *symbolsResizeView;
	IBOutlet ViBgView *symbolsView;
	IBOutlet NSSearchField *symbolFilterField;
	IBOutlet NSOutlineView *symbolsOutline;
	NSCell *separatorCell;
	NSMutableArray *documents;
	NSMutableArray *filteredDocuments;
	NSMutableDictionary *symbolFilterCache;
	BOOL closeSymbolListAfterUse;

	ViJumpList *jumpList;
	IBOutlet NSSegmentedControl *jumplistNavigator;

	ViDocumentView *currentView;
}

@property(readwrite, assign) NSMutableArray *documents;
@property(readonly) ExEnvironment *environment;
@property(readwrite, assign) ViProject *project;

+ (id)currentWindowController;
+ (NSWindow *)currentMainWindow;

- (void)setSelectedLanguage:(NSString *)aLanguage;
- (void)focusEditor;

- (ViCommand *)parser;
- (ViDocumentView *)documentViewForView:(NSView *)aView;
- (ViDocumentView *)selectDocumentView:(ViDocumentView *)docView;
- (ViDocumentView *)selectDocument:(ViDocument *)aDocument;

- (void)closeDocument:(ViDocument *)aDocument;

- (void)closeCurrentView;
- (BOOL)closeCurrentViewUnlessLast;

- (void)addDocument:(ViDocument *)document;
- (void)addNewTab:(ViDocument *)document;
- (ViDocument *)currentDocument;

- (ViTagStack *)sharedTagStack;

- (IBAction)selectNextTab:(id)sender;
- (IBAction)selectPreviousTab:(id)sender;
- (void)selectTabAtIndex:(NSInteger)anIndex;
- (void)selectLastDocument;

- (IBAction)navigateJumplist:(id)sender;

- (void)switchToDocument:(ViDocument *)doc;
- (void)switchToLastDocument;
- (void)switchToDocumentAction:(id)sender;
- (void)gotoURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column;
- (void)goToURL:(NSURL *)url;

- (IBAction)searchSymbol:(id)sender;
- (IBAction)filterSymbols:(id)sender;
- (IBAction)toggleSymbolList:(id)sender;

- (IBAction)splitViewHorizontally:(id)sender;
- (IBAction)splitViewVertically:(id)sender;

// proxies to the project delegate
- (IBAction)searchFiles:(id)sender;
- (IBAction)toggleExplorer:(id)sender;

- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation;

@end

