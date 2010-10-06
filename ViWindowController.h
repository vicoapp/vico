#import "ViTagStack.h"
#import "ViBgView.h"

@class PSMTabBarControl;
@class ViDocument;
@class ViDocumentView;
@class ProjectDelegate;
@class ViResizeView;
@class ViJumpList;
@class ViProject;

@interface ViWindowController : NSWindowController // disabled, only for 10.6: <NSTextFieldDelegate, NSWindowDelegate, NSToolbarDelegate>
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSSplitView *splitView;
	IBOutlet NSView *mainView;
	IBOutlet ViBgView *explorerView;
	IBOutlet NSView *documentView;

	IBOutlet NSPopUpButton *languageButton;
	IBOutlet NSTextField *messageField;
	IBOutlet NSPopUpButton *openFilesButton;

	ViTagStack *tagStack;
	BOOL isLoaded;
	ViDocument *initialDocument;
	ViDocument *lastDocument;
	ViDocumentView *lastDocumentView;
	ViDocument *selectedDocument;
	ViDocument *mostRecentDocument;
	ViDocumentView *mostRecentView;

	ViProject *project;

	// command output view
	IBOutlet NSTextField *statusbar;
	IBOutlet NSSplitView *commandSplit;
	IBOutlet NSTextView *commandOutput;

	// project list
	IBOutlet ProjectDelegate *projectDelegate;
	IBOutlet NSImageView *projectResizeView;
	NSString *currentDirectory;

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
}

@property(readwrite, assign) NSMutableArray *documents;
@property(readwrite, assign) ViDocument *selectedDocument;
@property(readonly) NSTextField *statusbar;
@property(readonly) NSTextField *messageField;
@property(readwrite, assign) ViProject *project;

@property(readonly) NSString *currentDirectory;
- (BOOL)changeCurrentDirectory:(NSString *)path;

+ (id)currentWindowController;
+ (NSWindow *)currentMainWindow;

- (void)setSelectedLanguage:(NSString *)aLanguage;
- (void)setMostRecentDocument:(ViDocument *)document view:(ViDocumentView *)docView;
- (void)selectDocument:(ViDocument *)aDocument;
- (void)focusEditor;
- (void)closeDocumentViews:(ViDocument *)aDocument;
- (void)addNewTab:(ViDocument *)document;
- (ViDocument *)currentDocument;
- (void)closeDocument:(ViDocument *)document;

- (IBAction)saveProject:(id)sender;

- (ViTagStack *)sharedTagStack;

- (IBAction)selectNextTab:(id)sender;
- (IBAction)selectPreviousTab:(id)sender;

- (void)switchToDocument:(ViDocument *)doc view:(ViDocumentView *)view;
- (void)switchToDocument:(ViDocument *)doc;
- (void)switchToDocumentAtIndex:(NSInteger)anIndex;
- (void)switchToLastDocument;
- (void)switchToDocumentAction:(id)sender;
- (void)gotoURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column;
- (void)goToURL:(NSURL *)url;

- (IBAction)searchSymbol:(id)sender;
- (IBAction)filterSymbols:(id)sender;
- (IBAction)toggleSymbolList:(id)sender;
- (IBAction)splitViewHorizontally:(id)sender;

// proxies to the project delegate
- (IBAction)searchFiles:(id)sender;
- (IBAction)toggleExplorer:(id)sender;

- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation;

@end

