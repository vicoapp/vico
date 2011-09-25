#import "ViOutlineView.h"

@class ViDocument;
@class ViWindowController;
@class ViBgView;

@interface ViSymbolController : NSObject <NSOutlineViewDataSource, ViKeyManagerTarget>
{
	IBOutlet NSWindow		*window;
	IBOutlet ViWindowController	*windowController;
	IBOutlet ViOutlineView		*symbolView;
	IBOutlet NSSearchField		*symbolFilterField;
	IBOutlet NSSearchField		*altSymbolFilterField;
	IBOutlet NSSplitView		*splitView; // Split between explorer, main and symbol views
	IBOutlet ViBgView		*symbolsView;
	IBOutlet NSToolbarItem		*searchToolbarItem;
	IBOutlet NSScrollView		*scrollView;

	CGFloat				 _width;
	NSCell				*_separatorCell;
	NSMutableArray			*_filteredDocuments;
	NSMutableDictionary		*_symbolFilterCache;
	BOOL				 _closeSymbolListAfterUse;
	NSInteger			 _lastSelectedRow;
	BOOL				 _isFiltered;
	BOOL				 _symbolUpdateDuringFiltering;

	NSTimer				*_reloadTimer;
	BOOL				 _dirty;
	// BOOL				 _isHidingAltFilterField;
}

- (void)filterSymbols;
- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation;
- (void)didSelectDocument:(ViDocument *)document;
- (IBAction)searchSymbol:(id)sender;
- (IBAction)filterSymbols:(id)sender;
- (IBAction)toggleSymbolList:(id)sender;
- (IBAction)focusSymbols:(id)sender;
- (void)openSymbolListTemporarily:(BOOL)temporary;
- (void)closeSymbolListAndFocusEditor:(BOOL)focusEditor;
- (BOOL)symbolListIsOpen;
- (void)symbolsUpdate:(NSTimer *)aTimer;

- (void)closeSymbolListAndFocusEditor:(BOOL)focusEditor;
- (BOOL)symbolListIsOpen;
- (void)showAltFilterField;
- (void)hideAltFilterField;
- (BOOL)isSeparatorItem:(id)item;

@end
