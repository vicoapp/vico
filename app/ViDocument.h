/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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

	NSMutableDictionary	*_associatedViews;

	ViBundle		*_bundle;
	ViLanguage		*__weak _language;
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
	NSMutableSet		*_marks; // All marks associated with this document. XXX: don't retain!?

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

@property(nonatomic,readwrite,strong) ViSnippet *snippet;
@property(nonatomic,readonly) NSSet *views;
@property(nonatomic,readwrite,strong) ViBundle *bundle;
@property(nonatomic,readwrite,strong) ViTheme *theme;
@property(weak, nonatomic,readonly) ViLanguage *language;
@property(nonatomic,readwrite,strong) NSArray *symbols;
@property(nonatomic,readwrite,strong) NSArray *filteredSymbols;
@property(nonatomic,readwrite,strong) NSDictionary *symbolScopes;
@property(nonatomic,readwrite,strong) NSDictionary *symbolTransforms;
@property(nonatomic,readonly) NSStringEncoding encoding;
@property(nonatomic,readwrite) BOOL isTemporary;
@property(nonatomic,readwrite) BOOL busy;
@property(nonatomic,readwrite,getter=isModified) BOOL modified;
@property(nonatomic,readwrite,copy) void (^closeCallback)(int);
@property(nonatomic,readwrite,strong) id<ViDeferred> loader;
@property(nonatomic,readwrite) BOOL ignoreChangeCountNotification;
@property(nonatomic,readwrite) NSRange matchingParenRange;
@property(nonatomic,readwrite,strong) ViDocumentView *hiddenView;
@property(nonatomic,readwrite,strong) ViSyntaxParser *syntaxParser;
@property(nonatomic,readonly) NSSet *marks;
@property(nonatomic,readonly) ViMarkStack *localMarks;

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
- (ViDocumentView *)makeViewWithParser:(ViParser *)aParser;
- (ViDocumentView *)makeView;
- (ViDocumentView *)cloneView:(ViDocumentView *)oldView;
- (void)removeView:(ViDocumentView *)aDocumentView;
- (void)addView:(ViDocumentView *)aDocumentView;
- (void)enableLineNumbers:(BOOL)flag relative:(BOOL)relative forScrollView:(NSScrollView *)aScrollView;
- (ViWindowController *)windowController;
- (void)closeWindowController:(ViWindowController *)aController;
- (NSString *)title;
- (void)setString:(NSString *)aString;
- (void)setData:(NSData *)data;
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
- (ViMark *)setMark:(unichar)name atLocation:(NSUInteger)aLocation;
- (ViMark *)setMark:(unichar)key toRange:(NSRange)range;

- (void)registerMark:(ViMark *)mark;
- (void)unregisterMark:(ViMark *)mark;

- (void)associateView:(ViViewController *)viewController forKey:(NSString *)key;
- (NSSet *)associatedViewsForKey:(NSString *)key;

@end
