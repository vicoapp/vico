#import "ViTagStack.h"
#import "ViTagsDatabase.h"
#import "ViBgView.h"
#import "ViJumpList.h"
#import "ExEnvironment.h"
#import "ViToolbarPopUpButtonCell.h"
#import "ViSplitView.h"
#import "ViScriptProxy.h"

@class PSMTabBarControl;
@class ViDocument;
@class ViDocumentView;
@class ProjectDelegate;
@class ViResizeView;
@class ViProject;
@class ViParser;

@interface ViWindowController : NSWindowController <ViJumpListDelegate, NSTextFieldDelegate, NSWindowDelegate, NSToolbarDelegate>
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSTabView *tabView;
	IBOutlet ViSplitView *splitView;	// Split between explorer, main and symbol views
	IBOutlet NSView *mainView;
	IBOutlet ViBgView *explorerView;
	IBOutlet ViToolbarPopUpButtonCell *bookmarksButtonCell;
	IBOutlet NSTextField *messageField;
	IBOutlet NSTextField *statusbar;

	IBOutlet NSPopUpButton *languageButton;
	IBOutlet NSPopUpButton *openFilesButton;
	IBOutlet ViToolbarPopUpButtonCell *bundleButtonCell;
	IBOutlet NSPopUpButton *bundleButton;

	IBOutlet ExEnvironment *environment;

	ViTagStack *tagStack;
	ViTagsDatabase *tagsDatabase;

	BOOL isLoaded;
	ViDocument *initialDocument;
	ViDocument *previousDocument;
	ViDocumentView *previousDocumentView;
	ViParser *parser;
	ViProject *project;
	ViScriptProxy *proxy;

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
	BOOL jumping;
	IBOutlet NSSegmentedControl *jumplistNavigator;

	ViDocumentView *currentView;
}

@property(readwrite, assign) NSMutableArray *documents;
@property(readonly) ExEnvironment *environment;
@property(readonly) ViJumpList *jumpList;
@property(readwrite, assign) ViProject *project;
@property(readonly) ViScriptProxy *proxy;
@property(readonly) ProjectDelegate *explorer;
@property(readonly) ViTagStack *tagStack;
@property(readonly) ViTagsDatabase *tagsDatabase;

+ (ViWindowController *)currentWindowController;
+ (NSWindow *)currentMainWindow;

- (void)message:(NSString *)fmt, ...;
- (void)message:(NSString *)fmt arguments:(va_list)ap;

- (void)setSelectedLanguage:(NSString *)aLanguage;
- (void)focusEditor;

- (ViParser *)parser;
- (id<ViViewController>)viewControllerForView:(NSView *)aView;
- (id<ViViewController>)selectDocumentView:(id<ViViewController>)viewController;
- (ViDocumentView *)viewForDocument:(ViDocument *)document;
- (ViDocumentView *)selectDocument:(ViDocument *)aDocument;
- (ViDocumentView *)createTabForDocument:(ViDocument *)document;

- (void)closeDocument:(ViDocument *)aDocument;
- (void)closeCurrentView;
- (BOOL)closeCurrentViewUnlessLast;

- (void)addDocument:(ViDocument *)document;
- (void)addNewTab:(ViDocument *)document;

- (id<ViViewController>)currentView;
- (void)setCurrentView:(id<ViViewController>)viewController;
- (ViDocument *)currentDocument;

- (ViDocument *)documentForURL:(NSURL *)url;

- (IBAction)selectNextTab:(id)sender;
- (IBAction)selectPreviousTab:(id)sender;
- (void)selectTabAtIndex:(NSInteger)anIndex;
- (void)selectLastDocument;

- (IBAction)navigateJumplist:(id)sender;

- (void)switchToDocument:(ViDocument *)doc;
- (void)switchToLastDocument;
- (void)switchToDocumentAction:(id)sender;
- (BOOL)gotoURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column;
- (BOOL)gotoURL:(NSURL *)url;
- (BOOL)gotoURL:(NSURL *)url lineNumber:(NSNumber *)lineNumber;

- (IBAction)searchSymbol:(id)sender;
- (IBAction)filterSymbols:(id)sender;
- (IBAction)toggleSymbolList:(id)sender;

- (IBAction)splitViewHorizontally:(id)sender;
- (IBAction)splitViewVertically:(id)sender;
- (IBAction)moveCurrentViewToNewTabAction:(id)sender;
- (BOOL)moveCurrentViewToNewTab;
- (BOOL)normalizeSplitViewSizesInCurrentTab;
- (BOOL)closeOtherViews;
- (BOOL)selectViewAtPosition:(ViViewOrderingMode)position
                  relativeTo:(NSView *)aView;
- (ViDocument *)splitVertically:(BOOL)isVertical
                        andOpen:(id)filenameOrURL
             orSwitchToDocument:(ViDocument *)doc
		allowReusedView:(BOOL)allowReusedView;
- (ViDocument *)splitVertically:(BOOL)isVertical
                        andOpen:(id)filenameOrURL
             orSwitchToDocument:(ViDocument *)doc;

// proxies to the project delegate
- (IBAction)searchFiles:(id)sender;
- (IBAction)toggleExplorer:(id)sender;

- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation;

- (void)browseURL:(NSURL *)url;

@end

