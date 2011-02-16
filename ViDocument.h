#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViSymbol.h"
#import "ViSnippet.h"
#import "ViTextStorage.h"

@interface ViDocument : NSDocument <ViTextViewDelegate, NSTextViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate>
{
	NSMutableArray *views;

	ViBundle *bundle;
	ViLanguage *language;
	ViTheme *theme;

	/* Set when opening a new file from the ex command line. */
	BOOL isTemporary;

	ViTextStorage *textStorage;
	NSDictionary *typingAttributes;
	ViWindowController *windowController;
	NSString *readContent;
	NSStringEncoding encoding;
	NSStringEncoding forcedEncoding;
	BOOL retrySaveOperation;

	// language parsing and highlighting
	BOOL ignoreEditing, closed;
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
@property(readonly) ViBundle *bundle;
@property(readwrite, assign) NSArray *symbols;
@property(readwrite, assign) NSArray *filteredSymbols;
@property(readwrite, assign) ViSnippet *activeSnippet;
@property(readwrite, assign) ViJumpList *jumpList;
@property(readonly) NSStringEncoding encoding;
@property(readwrite, assign) BOOL isTemporary;

- (void)setString:(NSString *)aString;
- (IBAction)toggleLineNumbers:(id)sender;
- (ViLanguage *)language;
- (IBAction)setLanguageAction:(id)sender;
- (void)setLanguage:(ViLanguage *)lang;
- (void)configureForURL:(NSURL *)aURL;
- (void)configureSyntax;
- (void)changeTheme:(ViTheme *)aTheme;
- (void)updatePageGuide;
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
- (NSString *)title;

@end
