#import "ViTagStack.h"
#import "ViTagsDatabase.h"
#import "ViBgView.h"
#import "ViJumpList.h"
#import "ExEnvironment.h"
#import "ViToolbarPopUpButtonCell.h"
#import "ViSplitView.h"
#import "ViSymbol.h"
#import "ViSymbolController.h"
#import "ViURLManager.h"
#import "ViDocumentTabController.h"
#import "ViTextView.h"

@class PSMTabBarControl;
@class ViDocument;
@class ViDocumentView;
@class ProjectDelegate;
@class ViResizeView;
@class ViProject;
@class ViParser;
@class ExCommand;

@interface ViWindowController : NSWindowController <ViJumpListDelegate, NSTextFieldDelegate, NSWindowDelegate, NSToolbarDelegate, ViDeferredDelegate>
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSTabView *tabView;
	IBOutlet ViSplitView *splitView; // Split between explorer, main and symbol views
	IBOutlet NSView *mainView;
	IBOutlet ViBgView *explorerView;
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
@property(nonatomic,readonly) ProjectDelegate *explorer;
@property(nonatomic,readonly) ViTagStack *tagStack;
@property(nonatomic,readonly) ViTagsDatabase *tagsDatabase;
@property(nonatomic,readwrite) BOOL jumping; /* XXX: need better API! */
@property(nonatomic,readonly) __weak ViDocument *previousDocument;
@property(nonatomic,readwrite,assign) NSURL *baseURL;
@property(nonatomic,readonly) ViSymbolController *symbolController;

+ (ViWindowController *)currentWindowController;
+ (NSWindow *)currentMainWindow;

- (void)showMessage:(NSString *)string;
- (void)message:(NSString *)fmt, ...;
- (void)message:(NSString *)fmt arguments:(va_list)ap;

- (void)focusEditorDelayed:(id)sender;
- (void)focusEditor;

- (ViParser *)parser;
- (id<ViViewController>)viewControllerForView:(NSView *)aView;
- (id<ViViewController>)selectDocumentView:(id<ViViewController>)viewController;
- (ViDocumentView *)viewForDocument:(ViDocument *)document;
- (ViDocumentView *)selectDocument:(ViDocument *)aDocument;
- (void)createTabWithViewController:(id<ViViewController>)viewController;
- (ViDocumentView *)createTabForDocument:(ViDocument *)document;

- (void)didCloseDocument:(ViDocument *)document andWindow:(BOOL)canCloseWindow;
- (void)closeDocument:(ViDocument *)document andWindow:(BOOL)canCloseWindow;
- (void)closeCurrentDocumentAndWindow:(BOOL)canCloseWindow;
- (BOOL)closeCurrentViewUnlessLast;
- (BOOL)closeOtherViews;
- (IBAction)closeCurrentDocument:(id)sender;
- (IBAction)closeCurrent:(id)sender;
- (BOOL)windowShouldClose:(id)window;

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

- (void)browseURL:(NSURL *)url;

- (void)setBaseURL:(NSURL *)url;
- (void)checkBaseURL:(NSURL *)url
	onCompletion:(void (^)(NSURL *url, NSError *error))aBlock;
- (NSString *)displayBaseURL;

- (NSString *)getExStringInteractivelyForCommand:(ViCommand *)command;

- (BOOL)ex_cd:(ExCommand *)command;
- (BOOL)ex_pwd:(ExCommand *)command;
- (BOOL)ex_close:(ExCommand *)command;
- (BOOL)ex_edit:(ExCommand *)command;
- (BOOL)ex_tabedit:(ExCommand *)command;
- (BOOL)ex_new:(ExCommand *)command;
- (BOOL)ex_tabnew:(ExCommand *)command;
- (BOOL)ex_vnew:(ExCommand *)command;
- (BOOL)ex_split:(ExCommand *)command;
- (BOOL)ex_vsplit:(ExCommand *)command;
- (BOOL)ex_buffer:(ExCommand *)command;
- (BOOL)ex_export:(ExCommand *)command;
- (void)ex_quit:(ExCommand *)command;

@end

