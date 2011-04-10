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

	NSCell *separatorCell;
	NSMutableArray *filteredDocuments;
	NSMutableDictionary *symbolFilterCache;
	BOOL closeSymbolListAfterUse;
	NSInteger lastSelectedRow;
	BOOL isFiltered;
}

- (void)filterSymbols;
- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation;
- (void)didSelectDocument:(ViDocument *)document;
- (IBAction)searchSymbol:(id)sender;
- (IBAction)filterSymbols:(id)sender;
- (IBAction)toggleSymbolList:(id)sender;
- (IBAction)focusSymbols:(id)sender;

@end