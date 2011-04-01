#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViSymbol.h"
#import "ViTextStorage.h"
#import "ViScriptProxy.h"

@interface ViDocument : NSDocument <ViTextViewDelegate, NSTextViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate>
{
	NSMutableSet *views;

	ViBundle *bundle;
	ViLanguage *language;
	ViTheme *theme;
	ViScriptProxy *proxy;

	dispatch_queue_t sym_q;

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

	ViSnippet *snippet;
}

@property(readwrite, assign) ViSnippet *snippet;
@property(readonly) NSSet *views;
@property(readonly) ViBundle *bundle;
@property(readwrite, assign) NSArray *symbols;
@property(readwrite, assign) NSArray *filteredSymbols;
@property(readonly) NSStringEncoding encoding;
@property(readwrite, assign) BOOL isTemporary;
@property(readonly) ViScriptProxy *proxy;

- (IBAction)toggleLineNumbers:(id)sender;
- (ViLanguage *)language;
- (IBAction)setLanguageAction:(id)sender;
- (void)setLanguage:(ViLanguage *)lang;
- (void)configureForURL:(NSURL *)aURL;
- (void)configureSyntax;
- (void)changeTheme:(ViTheme *)aTheme;
- (void)updatePageGuide;
- (NSUInteger)filterSymbols:(ViRegexp *)rx;
- (void)dispatchSyntaxParserWithRange:(NSRange)aRange restarting:(BOOL)flag;
- (ViDocumentView *)makeView;
- (void)removeView:(ViDocumentView *)aDocumentView;
- (void)addView:(ViDocumentView *)aDocumentView;
- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView;
- (ViWindowController *)windowController;
- (NSString *)title;
- (void)setString:(NSString *)aString;

@end
