#import <Cocoa/Cocoa.h>
#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViSymbol.h"

@class NoodleLineNumberView;

@interface ViDocument : NSDocument
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
	NSMutableArray *lineIndices;

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
@property(readonly) NSMutableArray *lineIndices;

- (void)enableLineNumbers:(BOOL)flag;
- (IBAction)toggleLineNumbers:(id)sender;
- (IBAction)finishedExCommand:(id)sender;
- (IBAction)setLanguage:(id)sender;
- (void)configureForURL:(NSURL *)aURL;
- (void)configureSyntax;
- (void)message:(NSString *)fmt, ...;
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector prompt:(NSString *)aPrompt;
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector;
- (void)changeTheme:(ViTheme *)theme;
- (void)setPageGuide:(int)pageGuideValue;
- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(int)regexpSyntax;
- (void)pushLine:(NSUInteger)aLine column:(NSUInteger)aColumn;
- (void)popTag;
- (void)goToSymbol:(ViSymbol *)aSymbol inView:(ViDocumentView *)aView;
- (void)goToSymbol:(ViSymbol *)aSymbol;
- (NSUInteger)filterSymbols:(ViRegexp *)rx;
- (void)setLanguageFromString:(NSString *)aLanguage;
- (void)pushContinuationsFromLocation:(NSUInteger)aLocation string:(NSString *)aString forward:(BOOL)flag;
- (void)dispatchSyntaxParserWithRange:(NSRange)aRange restarting:(BOOL)flag;
- (void)setMostRecentDocumentView:(ViDocumentView *)docView;
- (ViDocumentView *)makeView;
- (void)removeView:(ViDocumentView *)aDocumentView;
- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView;
- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation;
- (NSArray *)scopesAtLocation:(NSUInteger)aLocation;

- (NSUInteger)lineNumberForLocation:(NSUInteger)aLocation;

@end
