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

#import "ViTagsDatabase.h"
#import "ViJumpList.h"
#import "ViToolbarPopUpButtonCell.h"
#import "ViSymbolController.h"
#import "ViStatusView.h"
#import "ViURLManager.h"
#import "ViTabController.h"
#import "ViTextView.h"
#import "ViMarkManager.h"

@class PSMTabBarControl;
@class ViDocument;
@class ViDocumentView;
@class ViFileExplorer;
@class ViResizeView;
@class ViProject;
@class ViParser;
@class ExCommand;
@class ViBgView;
@class ViMark;

/** A ViWindowController object manages a document window.
 */
@interface ViWindowController : NSWindowController <ViJumpListDelegate, NSTextFieldDelegate, NSWindowDelegate, NSToolbarDelegate, ViDeferredDelegate>
{
	IBOutlet PSMTabBarControl	*tabBar;
	IBOutlet NSTabView		*tabView;
	IBOutlet NSSplitView		*splitView; // Split between explorer, main and symbol views
	IBOutlet NSView			*mainView;
	IBOutlet ViBgView		*explorerView;		// Top-level nib object
	IBOutlet NSWindow		*sftpConnectView;	// Top-level nib object
	IBOutlet ViToolbarPopUpButtonCell *bookmarksButtonCell;
	IBOutlet ViStatusView		*messageView;

	IBOutlet NSPopUpButton		*openFilesButton;
	IBOutlet ViToolbarPopUpButtonCell *bundleButtonCell;
	IBOutlet NSPopUpButton		*bundleButton;

	NSURL				*_baseURL;

	ViTextStorage			*_viFieldEditorStorage;
	ViTextView			*_viFieldEditor;

	ViMarkStack			*_tagStack;
	ViTagsDatabase			*_tagsDatabase;

	BOOL				 _isLoaded;
	BOOL				 _isClosing;
	ViDocument			*_initialDocument;
	ViViewController		*_initialViewController;
	NSMutableSet			*_documents;
	ViParser			*_parser;
	ViProject			*_project;

	ViMark				*_alternateMarkCandidate;
	ViMark				*_alternateMark;

	// ex command line
	IBOutlet NSTextField		*exField;
	IBOutlet NSView				*exWindow;
	BOOL				 _exBusy;
	BOOL				 _exModal;
	NSString			*_exString;

	// project list
	IBOutlet ViFileExplorer		*explorer;		// Top-level nib object
	IBOutlet NSImageView		*projectResizeView;
	IBOutlet NSMenu			*explorerActionMenu;	// Top-level nib object

	// symbol list
	IBOutlet ViSymbolController	*symbolController;	// Top-level nib object
	IBOutlet NSImageView		*symbolsResizeView;
	IBOutlet NSView			*symbolsView;		// Top-level nib object

	ViJumpList			*_jumpList;
	BOOL				 _jumping;
	IBOutlet NSSegmentedControl	*jumplistNavigator;

	ViViewController		*_currentView;

	NSMutableSet			*_modifiedSet;

	id<ViDeferred>			 _checkURLDeferred;
}

@property(nonatomic,readwrite,retain) NSMutableSet *documents;
@property(nonatomic,readonly) ViJumpList *jumpList;
@property(nonatomic,readwrite,retain) ViProject *project;
@property(nonatomic,readonly) ViFileExplorer *explorer;
@property(nonatomic,readonly) ViMarkList *tagStack;
@property(nonatomic,readonly) ViTagsDatabase *tagsDatabase;
@property(nonatomic,readwrite) BOOL jumping; /* XXX: need better API! */
@property(nonatomic,readwrite,retain) NSURL *baseURL;
@property(nonatomic,readonly) ViSymbolController *symbolController;
@property(nonatomic,readonly) ViParser *parser;
@property(nonatomic,readwrite,retain) ViMark *alternateMarkCandidate;
@property(nonatomic,readwrite,retain) ViMark *alternateMark;

/**
 * @returns The currently active window controller.
 */
+ (ViWindowController *)currentWindowController;

- (void)showMessage:(NSString *)string;
- (void)message:(NSString *)fmt, ...;
- (void)message:(NSString *)fmt arguments:(va_list)ap;

- (void)focusEditorDelayed;
- (void)focusEditor;

- (void)checkDocumentsChanged;

/**
 * @returns Bundle environment variables. No text-related variables will be set.
 * @see [ViTextView environment]
 */
- (NSDictionary *)environment;

- (ViViewController *)viewControllerForView:(NSView *)aView;

/*? Selects the tab holding the given document view and focuses the view.
 * @param viewController The view controller to focus.
 * @returns The selected view controller.
 */
- (ViViewController *)selectDocumentView:(ViViewController *)viewController;

/* Return a view for a document.
 * @param document The document to find a view for.
 * @returns The most appropriate view for the given document.
 * Returns nil if no view of the document is currently open.
 */
- (ViDocumentView *)viewForDocument:(ViDocument *)document;

/**
 * @returns The documents open in the window.
 */
- (NSSet *)documents;

/** Create a new tab.
 * @param viewController The view to display in the new tab.
 * @returns a ViTabController object managing the new tab.
 */
- (ViTabController *)createTabWithViewController:(ViViewController *)viewController;

/** Create a new tab.
 * @param document The document to display in the new tab.
 * @returns A new view of the document.
 */
- (ViDocumentView *)createTabForDocument:(ViDocument *)document;

- (void)didCloseDocument:(ViDocument *)document andWindow:(BOOL)canCloseWindow;

/** Close a document, and optionally the window.
 * @param document The document to close.
 * @param canCloseWindow YES if the window should be closed if there are no more documents in the window.
 */
- (void)closeDocument:(ViDocument *)document andWindow:(BOOL)canCloseWindow;

- (void)closeCurrentDocumentAndWindow:(BOOL)canCloseWindow;
- (BOOL)closeCurrentViewUnlessLast;
- (BOOL)closeOtherViews;
- (IBAction)closeCurrentDocument:(id)sender;
- (IBAction)closeCurrent:(id)sender;
- (BOOL)windowShouldClose:(id)window;

- (void)addDocument:(ViDocument *)document;
- (void)addNewTab:(ViDocument *)document;

/**
 * @returns The currently focused view.
 */
- (ViViewController *)currentView;

- (void)setCurrentView:(ViViewController *)viewController;

/**
 * @returns The currently focused view, or `nil` if the view is not a document view.
 */
- (ViDocumentView *)currentDocumentView;

/**
 * @returns The currently focused document, or `nil` if no document is focused.
 */
- (ViDocument *)currentDocument;

- (ViDocument *)alternateDocument;
- (NSURL *)alternateURL;

/**
 * @returns The currently selected tab controller.
 */
- (ViTabController *)selectedTabController;

- (ViDocument *)documentForURL:(NSURL *)url;

- (IBAction)selectNextTab:(id)sender;
- (IBAction)selectPreviousTab:(id)sender;
- (void)selectTabAtIndex:(NSInteger)anIndex;

- (IBAction)navigateJumplist:(id)sender;

- (void)switchToDocumentAction:(id)sender;

/* FIXME: document -displayDocument:positioned: */
- (ViDocumentView *)displayDocument:(ViDocument *)doc positioned:(ViViewPosition)position;
- (ViDocumentView *)displayDocument:(ViDocument *)doc;

/** Open a document and go to a specific point in the file.
 * @param url The URL of the document to open. The document may already be opened.
 * @param line The line number to jump to, or `0` to not jump to any line.
 * @param column The column to jump to.
 * @returns YES if the document could be opened.
 */
- (BOOL)gotoURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column;

/** Open a document.
 * @param url The URL of the document to open. The document may already be opened.
 * @returns YES if the document could be opened.
 */
- (BOOL)gotoURL:(NSURL *)url;

- (BOOL)gotoMark:(ViMark *)mark positioned:(ViViewPosition)viewPosition recordJump:(BOOL)isJump;
- (BOOL)gotoMark:(ViMark *)mark positioned:(ViViewPosition)viewPosition;
- (BOOL)gotoMark:(ViMark *)mark;

- (IBAction)searchSymbol:(id)sender;
- (NSMutableArray *)symbolsFilteredByPattern:(NSString *)pattern;
- (IBAction)toggleSymbolList:(id)sender;
- (IBAction)focusSymbols:(id)sender;

- (IBAction)splitViewHorizontally:(id)sender;
- (IBAction)splitViewVertically:(id)sender;
- (IBAction)moveCurrentViewToNewTabAction:(id)sender;
- (BOOL)moveCurrentViewToNewTab;
- (BOOL)normalizeSplitViewSizesInCurrentTab;
- (BOOL)selectViewAtPosition:(ViViewOrderingMode)position
                  relativeTo:(id)aView;

/** Split the current view and display another document.
 * @param isVertical YES to split vertically, NO for a horizontal split.
 * @param filenameOrURL A path (as an NSString) or a URL pointing to a document to open. The document may already be open.
 * @param doc An already open document that should be displayed in the split view.
 * @param allowReusedView YES to focus an already visible view for the given document. NO to always create a new split view.
 * @returns The new split view.
 */
- (ViDocumentView *)splitVertically:(BOOL)isVertical
			    andOpen:(id)filenameOrURL
		 orSwitchToDocument:(ViDocument *)doc
		    allowReusedView:(BOOL)allowReusedView;

/** Split the current view and display another document.
 * @param isVertical YES to split vertically, NO for a horizontal split.
 * @param filenameOrURL A path (as an NSString) or a URL pointing to a document to open. The document may already be open.
 * @returns The new split view, or an existing view if `filenameOrURL` is already open and visible in the same tab.
 */
- (ViDocumentView *)splitVertically:(BOOL)isVertical
			    andOpen:(id)filenameOrURL;
- (ViDocumentView *)splitVertically:(BOOL)isVertical
			    andOpen:(id)filenameOrURL
		 orSwitchToDocument:(ViDocument *)doc;

// proxies to the project delegate
- (IBAction)searchFiles:(id)sender;
- (IBAction)toggleExplorer:(id)sender;

- (IBAction)increaseFontsizeAction:(id)sender;
- (IBAction)decreaseFontsizeAction:(id)sender;

- (IBAction)revealCurrentDocument:(id)sender;

- (void)browseURL:(NSURL *)url;

- (void)setBaseURL:(NSURL *)url;
- (void)checkBaseURL:(NSURL *)url
	onCompletion:(void (^)(NSURL *url, NSError *error))aBlock;
- (NSString *)displayBaseURL;

- (NSString *)getExStringInteractivelyForCommand:(ViCommand *)command prefix:(NSString *)prefix;
- (NSString *)getExStringInteractivelyForCommand:(ViCommand *)command;

- (id)ex_pwd:(ExCommand *)command;
- (id)ex_quit:(ExCommand *)command;
- (id)ex_close:(ExCommand *)command;
- (id)ex_edit:(ExCommand *)command;
- (id)ex_tabedit:(ExCommand *)command;
- (id)ex_new:(ExCommand *)command;
- (id)ex_vnew:(ExCommand *)command;
- (id)ex_split:(ExCommand *)command;
- (id)ex_vsplit:(ExCommand *)command;

@end

