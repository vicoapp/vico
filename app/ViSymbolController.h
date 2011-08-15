#import "ViOutlineView.h"

@class ViDocument;
@class ViWindowController;
@class ViBgView;

@interface ViSymbolController : NSObject <NSOutlineViewDataSource, ViKeyManagerTarget>
{
	IBOutlet NSWindow *window;
	IBOutlet ViWindowController *windowController;
	IBOutlet ViOutlineView *symbolView;
	IBOutlet NSSearchField *symbolFilterField;
	IBOutlet NSSearchField *altFilterField;
	IBOutlet NSSplitView *splitView; // Split between explorer, main and symbol views
	IBOutlet ViBgView *symbolsView;
	IBOutlet NSToolbarItem *searchToolbarItem;
	IBOutlet NSScrollView *scrollView;

	CGFloat width;
	NSCell *separatorCell;
	NSMutableArray *filteredDocuments;
	NSMutableDictionary *symbolFilterCache;
	BOOL closeSymbolListAfterUse;
	NSInteger lastSelectedRow;
	BOOL isFiltered;

	NSTimer *reloadTimer;
	BOOL dirty;
}

- (void)filterSymbols;
- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation;
- (void)didSelectDocument:(ViDocument *)document;
- (IBAction)searchSymbol:(id)sender;
- (IBAction)filterSymbols:(id)sender;
- (IBAction)toggleSymbolList:(id)sender;
- (IBAction)focusSymbols:(id)sender;
- (void)openSymbolListTemporarily:(BOOL)temporary;
- (void)closeSymbolList;
- (BOOL)symbolListVisible;
- (void)symbolsUpdate:(NSTimer *)aTimer;

@end
