#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViSymbol.h"

@class NoodleLineNumberView;

@interface ViDocument : NSDocument <ViTextViewDelegate, NSTextViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate>
{
	NSMutableArray *views;
	int visibleViews;

	ViBundle *bundle;
	ViLanguage *language;

	NSTextStorage *textStorage;
	ViWindowController *windowController;
	NSString *readContent;
	NSArray *symbols;
	NSArray *filteredSymbols;

	// ex commands
	SEL exCommandSelector;
	ViTextView *exCommandView;
	NSMutableArray *exCommandHistory;

	// language parsing and highlighting
	BOOL ignoreEditing;
	ViSyntaxParser *syntaxParser;
	ViSyntaxContext *nextContext;

	// symbol list
	NSDictionary *symbolSettings;
	NSMutableArray *symbolScopes;
	NSTimer *updateSymbolsTimer;
}

@property(readonly) NSArray *views;
@property(readonly) int visibleViews;
@property(readwrite, assign) NSArray *symbols;
@property(readwrite, assign) NSArray *filteredSymbols;

- (IBAction)toggleLineNumbers:(id)sender;
- (IBAction)finishedExCommand:(id)sender;
- (IBAction)setLanguage:(id)sender;
- (void)configureForURL:(NSURL *)aURL;
- (void)configureSyntax;
- (void)changeTheme:(ViTheme *)theme;
- (void)setPageGuide:(int)pageGuideValue;
- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(int)regexpSyntax;
- (void)goToSymbol:(ViSymbol *)aSymbol inView:(ViDocumentView *)aView;
- (void)goToSymbol:(ViSymbol *)aSymbol;
- (NSUInteger)filterSymbols:(ViRegexp *)rx;
- (void)setLanguageFromString:(NSString *)aLanguage;
- (void)pushContinuationsFromLocation:(NSUInteger)aLocation string:(NSString *)aString forward:(BOOL)flag;
- (void)dispatchSyntaxParserWithRange:(NSRange)aRange restarting:(BOOL)flag;
- (ViDocumentView *)makeView;
- (void)removeView:(ViDocumentView *)aDocumentView;
- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView;
- (ViWindowController *)windowController;

@end
