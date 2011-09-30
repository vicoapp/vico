#import "ViWindowController.h"
#import "ViTextStorage.h"
#import "ViURLManager.h"
#import "ViScope.h"
#import "ViDocumentView.h"
#import "ViMarkManager.h"

@class ViTextView;
@class ExCommand;

/** A document.
 */
@interface ViDocument : NSDocument <NSTextViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate, ViDeferredDelegate, ViViewDocument>
{
	NSMutableSet		*_views;
	ViDocumentView		*_hiddenView;
	ViTextView		*_scriptView;

	ViBundle		*_bundle;
	ViLanguage		*_language;
	ViTheme			*_theme;

	NSInteger		 _tabSize; /* scope-specific */
	BOOL			 _wrap; /* scope-specific */

	/* Set when opening a new file from the ex command line. */
	BOOL			 _isTemporary;

	BOOL			 _hasUndoGroup;
	BOOL			 _ignoreChangeCountNotification; // XXX: this is a hack

	id<ViDeferred>		 _loader;
	BOOL			 _busy;
	BOOL			 _modified;

	ViTextStorage		*_textStorage;
	NSDictionary		*_typingAttributes;
	ViWindowController	*_windowController;
	NSString		*_readContent;
	NSStringEncoding	 _encoding;
	NSStringEncoding	 _forcedEncoding;
	BOOL			 _retrySaveOperation;

	// language parsing and highlighting
	BOOL			 _ignoreEditing;
	BOOL			 _closed;
	ViSyntaxParser		*_syntaxParser;
	ViSyntaxContext		*_nextContext;

	// standard character marks
	ViMarkStack		*_localMarks;
	NSMutableSet		*_marks; // All marks associated with this document

	// symbol list
	NSMutableArray		*_symbols;
	NSArray			*_filteredSymbols;
	NSDictionary		*_symbolScopes;
	NSDictionary		*_symbolTransforms;
	NSDictionary		*_symbolIcons;

	NSRange			 _matchingParenRange;
	ViSnippet		*_snippet;

	id			 _didSaveDelegate;
	SEL			 _didSaveSelector;
	void			*_didSaveContext;

	/* Called when the document closes. code is 0 if document saved successfully. */
	void (^_closeCallback)(int code);
}

@property(nonatomic,readwrite,retain) ViSnippet *snippet;
@property(nonatomic,readonly) NSSet *views;
@property(nonatomic,readwrite,retain) ViBundle *bundle;
@property(nonatomic,readwrite,retain) ViTheme *theme;
@property(nonatomic,readonly) ViLanguage *language;
@property(nonatomic,readwrite,retain) NSArray *symbols;
@property(nonatomic,readwrite,retain) NSArray *filteredSymbols;
@property(nonatomic,readwrite,retain) NSDictionary *symbolScopes;
@property(nonatomic,readwrite,retain) NSDictionary *symbolTransforms;
@property(nonatomic,readonly) NSStringEncoding encoding;
@property(nonatomic,readwrite) BOOL isTemporary;
@property(nonatomic,readwrite) BOOL busy;
@property(nonatomic,readwrite,getter=isModified) BOOL modified;
@property(nonatomic,readwrite,copy) void (^closeCallback)(int);
@property(nonatomic,readwrite,retain) id<ViDeferred> loader;
@property(nonatomic,readwrite) BOOL ignoreChangeCountNotification;
@property(nonatomic,readwrite) NSRange matchingParenRange;
@property(nonatomic,readwrite,retain) ViDocumentView *hiddenView;
@property(nonatomic,readwrite,retain) ViSyntaxParser *syntaxParser;
@property(nonatomic,readonly) NSSet *marks;

/** Return the ViTextStorage object. */
@property(nonatomic,readonly) ViTextStorage *textStorage;

- (void)message:(NSString *)fmt, ...;
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

/** @name Setting marks */

/** Lookup a marked location.
 * @param markName The name of the mark.
 * @returns The named mark, or `nil` if not set.
 */
- (ViMark *)markNamed:(unichar)markName;

/** Set a mark.
 * @param name The name of the mark.
 * @param aLocation The location to mark.
 */
- (void)setMark:(unichar)name atLocation:(NSUInteger)aLocation;
- (void)setMark:(unichar)key toRange:(NSRange)range;

- (void)registerMark:(ViMark *)mark;
- (void)unregisterMark:(ViMark *)mark;

@end
