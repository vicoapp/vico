#import "ViTagStack.h"
#import "ViTagsDatabase.h"
#import "ViBgView.h"
#import "ViJumpList.h"
#import "ExEnvironment.h"
#import "ViToolbarPopUpButtonCell.h"
#import "ViSplitView.h"
#import "ViScriptProxy.h"
#import "ViSymbol.h"
#import "ViSymbolController.h"

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
	IBOutlet ViSplitView *splitView; // Split between explorer, main and symbol views
	IBOutlet NSView *mainView;
	IBOutlet ViBgView *explorerView;
	IBOutlet ViToolbarPopUpButtonCell *bookmarksButtonCell;
	IBOutlet NSTextField *messageField;
	IBOutlet NSTextField *statusbar;

	IBOutlet NSPopUpButton *openFilesButton;
	IBOutlet ViToolbarPopUpButtonCell *bundleButtonCell;
	IBOutlet NSPopUpButton *bundleButton;

	IBOutlet ExEnvironment *environment;

	ViTextView *viFieldEditor;

	ViTagStack *tagStack;
	ViTagsDatabase *tagsDatabase;

	BOOL isLoaded;
	ViDocument *initialDocument;
	id<ViViewController> initialViewController;
	NSMutableArray *documents;
	ViDocument *previousDocument;
	__weak ViDocumentView *previousDocumentView;
	ViParser *parser;
	ViProject *project;
	ViScriptProxy *proxy;

	// project list
	IBOutlet ProjectDelegate *projectDelegate;
	IBOutlet NSImageView *projectResizeView;

	// symbol list
	IBOutlet ViSymbolController *symbolController;
	IBOutlet NSImageView *symbolsResizeView;
	IBOutlet ViBgView *symbolsView;

	ViJumpList *jumpList;
	BOOL jumping;
	IBOutlet NSSegmentedControl *jumplistNavigator;

	ViDocumentView *currentView;
}

@property(nonatomic,readwrite, assign) NSMutableArray *documents;
@property(nonatomic,readonly) ExEnvironment *environment;
@property(nonatomic,readonly) ViJumpList *jumpList;
@property(nonatomic,readwrite, assign) ViProject *project;
@property(nonatomic,readonly) ViScriptProxy *proxy;
@property(nonatomic,readonly) ProjectDelegate *explorer;
@property(nonatomic,readonly) ViTagStack *tagStack;
@property(nonatomic,readonly) ViTagsDatabase *tagsDatabase;
@property(nonatomic,readwrite) BOOL jumping; /* XXX: need better API! */
@property(nonatomic,readonly) ViDocument *previousDocument;

+ (ViWindowController *)currentWindowController;
+ (NSWindow *)currentMainWindow;

- (void)showMessage:(NSString *)string;
- (void)message:(NSString *)fmt, ...;
- (void)message:(NSString *)fmt arguments:(va_list)ap;
- (void)focusEditor;

- (ViParser *)parser;
- (id<ViViewController>)viewControllerForView:(NSView *)aView;
- (id<ViViewController>)selectDocumentView:(id<ViViewController>)viewController;
- (ViDocumentView *)viewForDocument:(ViDocument *)document;
- (ViDocumentView *)selectDocument:(ViDocument *)aDocument;
- (void)createTabWithViewController:(id<ViViewController>)viewController;
- (ViDocumentView *)createTabForDocument:(ViDocument *)document;

- (void)closeDocument:(ViDocument *)document andWindow:(BOOL)canCloseWindow;
- (void)closeCurrentDocumentAndWindow:(BOOL)canCloseWindow;
- (BOOL)closeCurrentViewUnlessLast;
- (BOOL)closeOtherViews;
- (IBAction)closeCurrentDocument:(id)sender;
- (IBAction)closeCurrent:(id)sender;

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

- (id<ViViewController>)switchToDocument:(ViDocument *)doc;
- (void)switchToLastDocument;
- (void)switchToDocumentAction:(id)sender;
- (BOOL)gotoURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column;
- (BOOL)gotoURL:(NSURL *)url;
- (BOOL)gotoURL:(NSURL *)url lineNumber:(NSNumber *)lineNumber;

- (IBAction)searchSymbol:(id)sender;
- (void)gotoSymbol:(ViSymbol *)aSymbol;
- (void)gotoSymbol:(ViSymbol *)aSymbol inView:(ViDocumentView *)docView;
- (NSMutableArray *)symbolsFilteredByPattern:(NSString *)pattern;
- (IBAction)toggleSymbolList:(id)sender;
- (IBAction)focusSymbols:(id)sender;

- (IBAction)splitViewHorizontally:(id)sender;
- (IBAction)splitViewVertically:(id)sender;
- (IBAction)moveCurrentViewToNewTabAction:(id)sender;
- (BOOL)moveCurrentViewToNewTab;
- (BOOL)normalizeSplitViewSizesInCurrentTab;
- (BOOL)selectViewAtPosition:(ViViewOrderingMode)position
                  relativeTo:(id)aView;
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

- (void)browseURL:(NSURL *)url;

@end

