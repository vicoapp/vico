#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViSymbol.h"
#import "ViSnippet.h"

@class NoodleLineNumberView;

@interface ViDocument : NSDocument <ViTextViewDelegate> // disabled, only for 10.6: <NSTextViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate>
{
	NSMutableArray *views;

	ViBundle *bundle;
	ViLanguage *language;
	ViTheme *theme;

	NSTextStorage *textStorage;
	NSDictionary *typingAttributes;
	ViWindowController *windowController;
	NSString *readContent;
	NSStringEncoding encoding;
	NSStringEncoding forcedEncoding;
	BOOL retrySaveOperation;

	// ex commands
	SEL exCommandSelector;
	ViTextView *exCommandView;
	NSMutableArray *exCommandHistory;

	// language parsing and highlighting
	BOOL ignoreEditing;
	ViSyntaxParser *syntaxParser;
	ViSyntaxContext *nextContext;

	// symbol list
	NSArray *symbols;
	NSArray *filteredSymbols;
	NSDictionary *symbolScopes;
	NSDictionary *symbolTransforms;
	NSDictionary *symbolIcons;
	NSTimer *updateSymbolsTimer;

	ViSnippet *activeSnippet;
	ViJumpList *jumpList;
}

@property(readonly) NSArray *views;
@property(readwrite, assign) NSArray *symbols;
@property(readwrite, assign) NSArray *filteredSymbols;
@property(readwrite, assign) ViSnippet *activeSnippet;
@property(readwrite, assign) ViJumpList *jumpList;
@property(readonly) NSStringEncoding encoding;

- (IBAction)toggleLineNumbers:(id)sender;
- (IBAction)finishedExCommand:(id)sender;
- (ViLanguage *)language;
- (IBAction)setLanguage:(id)sender;
- (void)configureForURL:(NSURL *)aURL;
- (void)configureSyntax;
- (void)changeTheme:(ViTheme *)aTheme;
- (void)updatePageGuide;
- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(int)regexpSyntax;
- (NSUInteger)filterSymbols:(ViRegexp *)rx;
- (void)pushContinuationsInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;
- (void)dispatchSyntaxParserWithRange:(NSRange)aRange restarting:(BOOL)flag;
- (ViDocumentView *)makeView;
- (void)removeView:(ViDocumentView *)aDocumentView;
- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView;
- (ViWindowController *)windowController;

- (void)setTypingAttributes;
- (NSDictionary *)typingAttributes;
- (void)resetTypingAttributes;

@end
