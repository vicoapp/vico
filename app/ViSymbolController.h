#import "ViOutlineView.h"

@class ViDocument;
@class ViWindowController;

@interface ViSymbolController : NSObject <NSOutlineViewDataSource>
{
	IBOutlet NSWindow *window;
	IBOutlet ViWindowController *windowController;
	IBOutlet ViOutlineView *symbolView;
	IBOutlet NSSearchField *symbolFilterField;
	IBOutlet NSSplitView *splitView; // Split between explorer, main and symbol views
	IBOutlet NSView *symbolsView;
	IBOutlet NSToolbarItem *searchToolbarItem;

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

@end
