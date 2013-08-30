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

#import "ViRegexp.h"
#import "ViToolbarPopUpButtonCell.h"
#import "ViOutlineView.h"
#import "ViJumpList.h"
#import "ViFile.h"

#include <CoreServices/CoreServices.h>

@class ViWindowController;
@class ViBgView;

@interface ViFileExplorer : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate, ViJumpListDelegate, ViKeyManagerTarget, NSMenuDelegate>
{
	IBOutlet NSWindow		*window;
	IBOutlet ViWindowController	*windowController;
	IBOutlet ViOutlineView		*__weak explorer;
	IBOutlet NSMenu			*actionMenu;
	IBOutlet NSSearchField		*filterField;
	IBOutlet NSSearchField		*altFilterField;
	IBOutlet NSSplitView		*splitView;
	IBOutlet ViBgView		*explorerView;
	IBOutlet NSWindow		*sftpConnectView;
	IBOutlet NSForm			*sftpConnectForm;
	IBOutlet NSScrollView		*scrollView;
	IBOutlet ViToolbarPopUpButtonCell *actionButtonCell;
	IBOutlet NSPopUpButton		*actionButton;
	IBOutlet NSProgressIndicator	*progressIndicator;
	IBOutlet NSToolbarItem		*searchToolbarItem;
	IBOutlet NSPathControl		*pathControl;
	IBOutlet id			 __unsafe_unretained delegate;

	NSURL				*__weak _rootURL;
	CGFloat				 _width;
	NSFont				*_font;

	// remembering expanded state
	NSMutableSet			*_expandedSet;
	BOOL				 _isExpandingTree;

	NSInteger			 _lastSelectedRow;

	// incremental file filtering
	NSMutableArray			*_filteredItems;
	NSMutableArray			*_itemsToFilter;
	ViRegexp			*_rx;

	BOOL				 _closeExplorerAfterUse;
	NSMutableArray			*_rootItems;
	ViRegexp			*_skipRegex;

	BOOL				 _isFiltered;
	BOOL				 _isFiltering;
	// BOOL				 _isHidingAltFilterField;

	ViJumpList			*_history;

	NSMutableDictionary		*_statusImages;

        /*
         * Since we can't pass an object through a void* contextInfo and
         * expect the object to survive garbage collection, store a strong
         * reference here.
         */
	NSMutableSet			*_contextObjects; // XXX: not needed without GC (but maybe with ARC in the future?)
}

@property(nonatomic,readwrite,unsafe_unretained) id delegate;
@property(weak, nonatomic,readonly) ViOutlineView *outlineView;
@property(weak, nonatomic,readonly) NSURL *rootURL;

- (void)browseURL:(NSURL *)aURL andDisplay:(BOOL)display;
- (void)browseURL:(NSURL *)aURL;
- (IBAction)addSFTPLocation:(id)sender;
- (IBAction)actionMenu:(id)sender;

- (IBAction)openInTab:(id)sender;
- (IBAction)openInCurrentView:(id)sender;
- (IBAction)openInSplit:(id)sender;
- (IBAction)openInVerticalSplit:(id)sender;
- (IBAction)renameFile:(id)sender;
- (IBAction)removeFiles:(id)sender;
- (IBAction)rescan:(id)sender;
- (IBAction)revealInFinder:(id)sender;
- (IBAction)openWithFinder:(id)sender;
- (IBAction)newFolder:(id)sender;
- (IBAction)newDocument:(id)sender;
- (IBAction)bookmarkFolder:(id)sender;
- (IBAction)gotoBookmark:(id)sender;
- (IBAction)flushCache:(id)sender;

- (IBAction)acceptSftpSheet:(id)sender;
- (IBAction)cancelSftpSheet:(id)sender;

- (IBAction)filterFiles:(id)sender;
- (IBAction)searchFiles:(id)sender;
- (BOOL)explorerIsOpen;
- (void)openExplorerTemporarily:(BOOL)temporarily;
- (void)closeExplorerAndFocusEditor:(BOOL)focusEditor;
- (IBAction)focusExplorer:(id)sender;
- (IBAction)toggleExplorer:(id)sender;
- (void)cancelExplorer;
- (BOOL)isEditing;
- (BOOL)displaysURL:(NSURL *)aURL;
- (BOOL)selectItemWithURL:(NSURL *)aURL;

- (NSSet *)clickedURLs;
- (NSSet *)clickedFolderURLs;
- (NSSet *)clickedFiles;

@end
