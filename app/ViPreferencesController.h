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

/** Required methods for a preference pane.
 */
@protocol ViPreferencePane <NSObject>
/** @returns The name of the preference pane. */
- (NSString *)name;
/** @returns The icon of the preference pane. */
- (NSImage *)icon;
/** @returns The view to display in the preference pane. */
- (NSView *)view;
@end

/** The preferences controller manages the preferences window and allows
 * registering new preference panes.
 */
@interface ViPreferencesController : NSWindowController <NSToolbarDelegate>
{
	NSView			*_blankView;
	NSString		*_forceSwitchToItem;
	NSMutableArray		*_panes;
	NSMutableDictionary	*_toolbarItems;
}

/** @returns The globally shared preferences controller.
 */
+ (ViPreferencesController *)sharedPreferences;

/** Register a new preference pane.
 * @param pane The preference pane to add.
 */
- (void)registerPane:(id<ViPreferencePane>)pane;

- (IBAction)switchToItem:(id)sender;

/** Show the preferences window. */
- (void)show;

/** Show the preferences window and switch to a preference pane.
 * @param name The name of the preference pane.
 */
- (void)showItem:(NSString *)name;

@end
