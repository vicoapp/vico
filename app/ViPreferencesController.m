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

#import "ViPreferencesController.h"
#import "ViBundleStore.h"
#import "ViAppController.h"

/* this code is from the apple documentation... */
static float
ToolbarHeightForWindow(NSWindow *window)
{
	NSToolbar *toolbar = [window toolbar];
	float toolbarHeight = 0.0;
	NSRect windowFrame;

	if (toolbar && [toolbar isVisible]) {
		windowFrame = [NSWindow contentRectForFrameRect:[window frame]
						      styleMask:[window styleMask]];
		toolbarHeight = NSHeight(windowFrame) - NSHeight([[window contentView] frame]);
	}

	return toolbarHeight;
}

@implementation ViPreferencesController

+ (ViPreferencesController *)sharedPreferences
{
	static ViPreferencesController *__sharedPreferencesController = nil;
	if (__sharedPreferencesController == nil)
		__sharedPreferencesController = [[ViPreferencesController alloc] init];
	return __sharedPreferencesController;
}

- (id<ViPreferencePane>)paneWithName:(NSString *)name
{
	for (id<ViPreferencePane> pane in _panes)
		if ([name isEqualToString:[pane name]])
			return pane;
	return nil;
}

- (void)registerPane:(id<ViPreferencePane>)pane
{
	NSString *name = [pane name];
	if ([self paneWithName:name] == nil) {
		[_panes addObject:pane];
		NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:name];
		[item setLabel:name];
		[item setTarget:self];
		[item setAction:@selector(switchToItem:)];
		[item setImage:[pane icon]];
		[_toolbarItems setObject:item forKey:name];

		[[[self window] toolbar] insertItemWithItemIdentifier:name
							      atIndex:[_panes count] - 1];

		NSString *lastPrefPane = [[NSUserDefaults standardUserDefaults]
		    objectForKey:@"lastPrefPane"];
		if ([lastPrefPane isEqualToString:name])
			[self switchToItem:name];
	}
}

- (id)init
{
	if ((self = [super initWithWindowNibName:@"PreferenceWindow"])) {
		_blankView = [[NSView alloc] init];
		_panes = [[NSMutableArray alloc] init];
		_toolbarItems = [[NSMutableDictionary alloc] init];
	}

	return self;
}


- (void)windowDidLoad
{
	/* We want the preference window to move to the active space. */
	[[self window] setCollectionBehavior:NSWindowCollectionBehaviorMoveToActiveSpace];
	[self setWindowFrameAutosaveName:@"PreferenceWindow"];

	/* Load last viewed pane. */
	NSString *lastPrefPane = [[NSUserDefaults standardUserDefaults]
	    objectForKey:@"lastPrefPane"];
	if (lastPrefPane == nil)
		lastPrefPane = @"General";
	[self switchToItem:lastPrefPane];
}

- (void)show
{
	[[self window] makeKeyAndOrderFront:self];
}

- (BOOL)windowShouldClose:(id)sender
{
	[[self window] orderOut:sender];
	return NO;
}

#pragma mark -
#pragma mark Toolbar and preference panes

- (void)resizeWindowToSize:(NSSize)newSize
{
	NSRect aFrame;

	float newHeight = newSize.height + ToolbarHeightForWindow([self window]);
	float newWidth = newSize.width;

	aFrame = [NSWindow contentRectForFrameRect:[[self window] frame]
					 styleMask:[[self window] styleMask]];

	aFrame.origin.y += aFrame.size.height;
	aFrame.origin.y -= newHeight;
	aFrame.size.height = newHeight;
	aFrame.size.width = newWidth;

	aFrame = [NSWindow frameRectForContentRect:aFrame styleMask:[[self window] styleMask]];

	[[self window] setFrame:aFrame display:YES animate:YES];
}

- (void)switchToView:(NSView *)view
{
	NSSize newSize = [view frame].size;

	[[self window] setContentView:_blankView];
	[self resizeWindowToSize:newSize];
	[[self window] setContentView:view];
}

- (IBAction)switchToItem:(id)sender
{
	NSView *view = nil;
	NSString *identifier;

	/*
	 * If the call is from a toolbar button, the sender will be an
	 * NSToolbarItem and we will need to fetch its itemIdentifier.
	 * If we want to call this method by hand, we can send it an NSString
	 * which will be used instead.
	 */
	if ([sender respondsToSelector:@selector(itemIdentifier)])
		identifier = [sender itemIdentifier];
	else
		identifier = sender;
	if (identifier == nil)
		return;

	id<ViPreferencePane> pane = [self paneWithName:identifier];
	view = [pane view];
	if (view == nil || view == [[self window] contentView])
		return;

	[self switchToView:view];
	[[[self window] toolbar] setSelectedItemIdentifier:identifier];
	[[NSUserDefaults standardUserDefaults] setObject:identifier
						  forKey:@"lastPrefPane"];
}

- (void)showItem:(NSString *)item
{
	[self show];
	[self switchToItem:item];
}

#pragma mark -
#pragma mark Toolbar delegate methods

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [_toolbarItems allKeys];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
	return [_toolbarItems objectForKey:itemIdentifier];
}


@end

