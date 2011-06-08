#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViSymbol.h"
#import "ViTextStorage.h"
#import "ViScriptProxy.h"
#import "ViURLManager.h"
#import "ViScope.h"

@interface ViDocument : NSDocument <NSTextViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate, ViDeferredDelegate>
{
	NSMutableSet *views;
	ViDocumentView *hiddenView;

	ViBundle *bundle;
	ViLanguage *language;
	ViTheme *theme;
	ViScriptProxy *proxy;

	dispatch_queue_t sym_q;

	/* Set when opening a new file from the ex command line. */
	BOOL isTemporary;

	id<ViDeferred> loader;
	BOOL busy;

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
	NSMutableArray *symbols;
	NSArray *filteredSymbols;
	NSDictionary *symbolScopes;
	NSDictionary *symbolTransforms;
	NSDictionary *symbolIcons;

	ViSnippet *snippet;

	id didSaveDelegate;
	SEL didSaveSelector;
	void *didSaveContext;
}

@property(nonatomic,readwrite, assign) ViSnippet *snippet;
@property(nonatomic,readonly) NSSet *views;
@property(nonatomic,readonly) ViBundle *bundle;
@property(nonatomic,readonly) NSArray *symbols;
@property(nonatomic,readwrite, assign) NSArray *filteredSymbols;
@property(nonatomic,readonly) NSStringEncoding encoding;
@property(nonatomic,readwrite, assign) BOOL isTemporary;
@property(nonatomic,readonly) ViScriptProxy *proxy;
@property(nonatomic,readwrite) BOOL busy;
@property (readonly) id<ViDeferred> loader;

- (void)message:(NSString *)fmt, ...;
- (ExEnvironment *)environment;
- (NSDictionary *)typingAttributes;

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
- (ViDocumentView *)makeViewInWindow:(NSWindow *)aWindow;
- (void)removeView:(ViDocumentView *)aDocumentView;
- (void)addView:(ViDocumentView *)aDocumentView;
- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView;
- (ViWindowController *)windowController;
- (NSString *)title;
- (void)setString:(NSString *)aString;
- (void)closeAndWindow:(BOOL)canCloseWindow;

- (NSArray *)scopesAtLocation:(NSUInteger)aLocation;
- (ViScope *)scopeAtLocation:(NSUInteger)aLocation;
- (NSString *)bestMatchingScope:(NSArray *)scopeSelectors
                     atLocation:(NSUInteger)aLocation;
- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                     atLocation:(NSUInteger)aLocation;
- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                        forward:(BOOL)forward
                   fromLocation:(NSUInteger)aLocation;

@end
