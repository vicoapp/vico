#import "ViTagStack.h"
#import "ViTagsDatabase.h"
#import "ViJumpList.h"
#import "ExEnvironment.h"
#import "ViToolbarPopUpButtonCell.h"
#import "ViSymbol.h"
#import "ViSymbolController.h"
#import "ViURLManager.h"
#import "ViTabController.h"
#import "ViTextView.h"

@class PSMTabBarControl;
@class ViDocument;
@class ViDocumentView;
@class ProjectDelegate;
@class ViResizeView;
@class ViProject;
@class ViParser;
@class ExCommand;

/** A ViWindowController object manages a document window.
 */
@interface ViWindowController : NSWindowController <ViJumpListDelegate, NSTextFieldDelegate, NSWindowDelegate, NSToolbarDelegate, ViDeferredDelegate>
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSTabView *tabView;
	IBOutlet NSSplitView *splitView; // Split between explorer, main and symbol views
	IBOutlet NSView *mainView;
	IBOutlet NSView *explorerView;
	IBOutlet ViToolbarPopUpButtonCell *bookmarksButtonCell;
	IBOutlet NSTextField *messageField;
#ifdef TRIAL_VERSION
	NSTextField *nagTitle;
#endif

	IBOutlet NSPopUpButton *openFilesButton;
	IBOutlet ViToolbarPopUpButtonCell *bundleButtonCell;
	IBOutlet NSPopUpButton *bundleButton;

	IBOutlet ExEnvironment *environment;
	NSURL			*baseURL;

	ViTextView *viFieldEditor;

	ViTagStack *tagStack;
	ViTagsDatabase *tagsDatabase;

	BOOL isLoaded;
	ViDocument *initialDocument;
	id<ViViewController> initialViewController;
	NSMutableArray *documents;
	__weak ViDocument *previousDocument;
	__weak ViDocumentView *previousDocumentView;
	ViParser *parser;
	ViProject *project;

	// ex command line
	IBOutlet NSTextField	*statusbar;
	BOOL			 ex_busy;
	BOOL			 ex_modal;
	NSString		*exString;

	// project list
	IBOutlet ProjectDelegate *projectDelegate;
	IBOutlet NSImageView *projectResizeView;

	// symbol list
	IBOutlet ViSymbolController *symbolController;
	IBOutlet NSImageView *symbolsResizeView;
	IBOutlet NSView *symbolsView;

	ViJumpList *jumpList;
	BOOL jumping;
	IBOutlet NSSegmentedControl *jumplistNavigator;

	ViDocumentView *currentView;
}

@property(nonatomic,readwrite, assign) NSMutableArray *documents;
@property(nonatomic,readonly) ExEnvironment *environment;
@property(nonatomic,readonly) ViJumpList *jumpList;
@property(nonatomic,readwrite, assign) ViProject *project;
@property(nonatomic,readonly) ProjectDelegate *explorer;
@property(nonatomic,readonly) ViTagStack *tagStack;
@property(nonatomic,readonly) ViTagsDatabase *tagsDatabase;
@property(nonatomic,readwrite) BOOL jumping; /* XXX: need better API! */
@property(nonatomic,readonly) __weak ViDocument *previousDocument;
@property(nonatomic,readwrite,assign) NSURL *baseURL;
@property(nonatomic,readonly) ViSymbolController *symbolController;

/**
 * @returns The currently active window controller.
 */
+ (ViWindowController *)currentWindowController;

+ (NSWindow *)currentMainWindow;

- (void)showMessage:(NSString *)string;
- (void)message:(NSString *)fmt, ...;
- (void)message:(NSString *)fmt arguments:(va_list)ap;

- (void)focusEditorDelayed:(id)sender;
- (void)focusEditor;

- (ViParser *)parser;
- (id<ViViewController>)viewControllerForView:(NSView *)aView;

/*? Selects the tab holding the given document view and focuses the view.
 * @param viewController The view controller to focus.
 * @returns The selected view controller.
 */
- (id<ViViewController>)selectDocumentView:(id<ViViewController>)viewController;

- (ViDocumentView *)viewForDocument:(ViDocument *)document;

/*? Selects the most appropriate view for the given document.
 *
 * Will change current tab if no view of the document is visible in the current tab.
 *
 * @param aDocument The document to select.
 *
 * @returns The view of the selected document.
 */
- (ViDocumentView *)selectDocument:(ViDocument *)aDocument;

/**
 * @returns The documents open in the window.
 */
- (NSArray *)documents;

- (void)createTabWithViewController:(id<ViViewController>)viewController;

- (ViDocumentView *)createTabForDocument:(ViDocument *)document;

- (void)didCloseDocument:(ViDocument *)document andWindow:(BOOL)canCloseWindow;

/** Close a document, and optionally the window.
 * @param document The document to close.
 * @param canCloseWindow YES if the window should be closed if there are no more documents in the window.
 */
- (void)closeDocument:(ViDocument *)document andWindow:(BOOL)canCloseWindow;

- (void)closeCurrentDocumentAndWindow:(BOOL)canCloseWindow;
- (BOOL)closeCurrentViewUnlessLast;
- (BOOL)closeOtherViews;
- (IBAction)closeCurrentDocument:(id)sender;
- (IBAction)closeCurrent:(id)sender;
- (BOOL)windowShouldClose:(id)window;

- (void)addDocument:(ViDocument *)document;
- (void)addNewTab:(ViDocument *)document;

/**
 * @returns The currently focused view.
 */
- (id<ViViewController>)currentView;

- (void)setCurrentView:(id<ViViewController>)viewController;

/**
 * @returns The currently focused document, or `nil` if no document is focused.
 */
- (ViDocument *)currentDocument;

/*?
 * @returns The currently selected tab controller.
 */
- (ViTabController *)selectedTabController;

- (ViDocument *)documentForURL:(NSURL *)url;

- (IBAction)selectNextTab:(id)sender;
- (IBAction)selectPreviousTab:(id)sender;
- (void)selectTabAtIndex:(NSInteger)anIndex;
- (void)selectLastDocument;

- (IBAction)navigateJumplist:(id)sender;

/*? Switch to another document.
 * @param doc The document to display.
 * @returns The new view of the document.
 */
- (id<ViViewController>)switchToDocument:(ViDocument *)doc;

- (void)switchToLastDocument;
- (void)switchToDocumentAction:(id)sender;

/** Open a document and go to a specific point in the file.
 * @param url The URL of the document to open. The document may already be opened.
 * @param line The line number to jump to, or `0` to not jump to any line.
 * @param column The column to jump to.
 * @returns YES if the document could be opened.
 */
- (BOOL)gotoURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column;

/** Open a document.
 * @param url The URL of the document to open. The document may already be opened.
 * @returns YES if the document could be opened.
 */
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

/** Split the current view and display another document.
 * @param isVertical YES to split vertically, NO for a horizontal split.
 * @param filenameOrURL A path (as an NSString) or a URL pointing to a document to open. The document may already be open.
 * @param doc An already open document that should be displayed in the split view.
 * @param allowReusedView YES to focus an already visible view for the given document. NO to always create a new split view.
 * @returns The new split view.
 */
- (id<ViViewController>)splitVertically:(BOOL)isVertical
                                andOpen:(id)filenameOrURL
                     orSwitchToDocument:(ViDocument *)doc
                        allowReusedView:(BOOL)allowReusedView;
- (id<ViViewController>)splitVertically:(BOOL)isVertical
                                andOpen:(id)filenameOrURL
                     orSwitchToDocument:(ViDocument *)doc;

// proxies to the project delegate
- (IBAction)searchFiles:(id)sender;
- (IBAction)toggleExplorer:(id)sender;

- (IBAction)increaseFontsizeAction:(id)sender;
- (IBAction)decreaseFontsizeAction:(id)sender;

- (void)browseURL:(NSURL *)url;

- (void)setBaseURL:(NSURL *)url;
- (void)checkBaseURL:(NSURL *)url
	onCompletion:(void (^)(NSURL *url, NSError *error))aBlock;
- (NSString *)displayBaseURL;

- (NSString *)getExStringInteractivelyForCommand:(ViCommand *)command prefix:(NSString *)prefix;
- (NSString *)getExStringInteractivelyForCommand:(ViCommand *)command;

- (id)ex_pwd:(ExCommand *)command;
- (id)ex_quit:(ExCommand *)command;
- (id)ex_close:(ExCommand *)command;
- (id)ex_edit:(ExCommand *)command;
- (id)ex_tabedit:(ExCommand *)command;
- (id)ex_new:(ExCommand *)command;
- (id)ex_vnew:(ExCommand *)command;
- (id)ex_split:(ExCommand *)command;
- (id)ex_vsplit:(ExCommand *)command;

@end

