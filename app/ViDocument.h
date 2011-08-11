#import "ViWindowController.h"
#import "ViSymbol.h"
#import "ViTextStorage.h"
#import "ViURLManager.h"
#import "ViScope.h"
#import "ViDocumentView.h"

@class ViTextView;
@class ExCommand;

/** A document.
 */
@interface ViDocument : NSDocument <NSTextViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate, ViDeferredDelegate, ViViewDocument>
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

	BOOL hasUndoGroup;
	BOOL ignoreChangeCountNotification; // XXX: this is a hack

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
@property(nonatomic,readwrite) BOOL ignoreChangeCountNotification;

/** Return the ViTextStorage object. */
@property(nonatomic,readonly) ViTextStorage *textStorage;

- (void)message:(NSString *)fmt, ...;
- (ExEnvironment *)environment;
- (NSDictionary *)typingAttributes;

/** Return a scriptable text view.
 *
 * The returned text view is not visible.
 *
 * @returns A scriptable text view.
 */
- (ViTextView *)text;

- (IBAction)toggleLineNumbers:(id)sender;

/** Get the language syntax.
 * @returns The language syntax currently in use, or `nil` if no language configured.
 */
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
- (ViDocumentView *)makeView;
- (ViDocumentView *)cloneView:(ViDocumentView *)oldView;
- (void)removeView:(ViDocumentView *)aDocumentView;
- (void)addView:(ViDocumentView *)aDocumentView;
- (void)enableLineNumbers:(BOOL)flag forScrollView:(NSScrollView *)aScrollView;
- (ViWindowController *)windowController;
- (void)closeWindowController:(ViWindowController *)aController;
- (NSString *)title;
- (void)setString:(NSString *)aString;
- (void)closeAndWindow:(BOOL)canCloseWindow;
- (BOOL)isEntireFileLoaded;

/** @name Working with scopes */

/** Return the scope at a given location.
 * @param aLocation The location of the scope.
 * @returns The scope at the given location, or nil of aLocation is not valid or no language syntax available.
 */
- (ViScope *)scopeAtLocation:(NSUInteger)aLocation;

/** Find the best matching scope selector.
 * @param scopeSelectors Scope selectors to test.
 * @param aLocation The location of the scope.
 * @returns The scope selector with the highest matching rank at the given location.
 */
- (NSString *)bestMatchingScope:(NSArray *)scopeSelectors
                     atLocation:(NSUInteger)aLocation;

/** Find the range where a scope selector matches.
 * @param scopeSelector Scope selectors to test.
 * @param aLocation A location where the scope selector matches.
 * @returns The whole range where the scope selector matches, possibly with different ranks.
 */
- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                     atLocation:(NSUInteger)aLocation;
- (NSRange)rangeOfScopeSelector:(NSString *)scopeSelector
                        forward:(BOOL)forward
                   fromLocation:(NSUInteger)aLocation;

- (void)endUndoGroup;
- (void)beginUndoGroup;

@end
