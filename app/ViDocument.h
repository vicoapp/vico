#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViSymbol.h"
#import "ViTextStorage.h"
#import "ViURLManager.h"
#import "ViScope.h"

@interface ViDocument : NSDocument <NSTextViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate, ViDeferredDelegate>
{
	NSMutableSet *views;
	ViDocumentView *hiddenView;
	ViTextView *scriptView;

	ViBundle *bundle;
	ViLanguage *language;
	ViTheme *theme;

	NSInteger tabSize; /* scope-specific */
	BOOL wrap; /* scope-specific */

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

	/* Called when the document closes. code is 0 if document saved successfully. */
	void (^closeCallback)(int code);
}

@property(nonatomic,readwrite, assign) ViSnippet *snippet;
@property(nonatomic,readonly) NSSet *views;
@property(nonatomic,readonly) ViBundle *bundle;
@property(nonatomic,readonly) NSArray *symbols;
@property(nonatomic,readwrite, assign) NSArray *filteredSymbols;
@property(nonatomic,readonly) NSStringEncoding encoding;
@property(nonatomic,readwrite, assign) BOOL isTemporary;
@property(nonatomic,readwrite) BOOL busy;
@property(nonatomic,readwrite,copy) void (^closeCallback)(int);
@property(nonatomic,readonly) id<ViDeferred> loader;

- (void)message:(NSString *)fmt, ...;
- (ExEnvironment *)environment;
- (NSDictionary *)typingAttributes;

- (IBAction)toggleLineNumbers:(id)sender;
- (ViLanguage *)language;
- (IBAction)setLanguageAction:(id)sender;
- (void)setLanguageAndRemember:(ViLanguage *)lang;
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

- (ViScope *)scopeAtLocation:(NSUInteger)aLocation;
- (NSString *)bestMatchingScope:(NSArray *)scopeSelectors
                     atLocation:(NSUInteger)aLocation;
- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                     atLocation:(NSUInteger)aLocation;
- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                        forward:(BOOL)forward
                   fromLocation:(NSUInteger)aLocation;

- (BOOL)ex_write:(ExCommand *)command;
- (BOOL)ex_setfiletype:(ExCommand *)command;

@end
