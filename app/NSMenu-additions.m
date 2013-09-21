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
#import "ViCommandMenuItemView.h"
#include "logging.h"

@implementation NSMenu (additions)

static ViRegexp *__rx = nil;

- (void)updateNormalModeMenuItemsWithSelection:(BOOL)hasSelection
{
	if (__rx == nil)
		__rx = [[ViRegexp alloc] initWithString:@" +\\((.*?)\\)( *\\((.*?)\\))?$"];

	for (NSMenuItem *item in [self itemArray]) {
		if ([item isHidden])
			continue;

		NSString *title = nil;
		if ([item tag] == 4000) {
			title = [item title];
			[item setRepresentedObject:title];
		} else if ([item tag] == 4001)
			title = [item representedObject];

		if (title) {
			DEBUG(@"updating menuitem %@, title %@", item, title);
			ViRegexpMatch *m = [__rx matchInString:title];
			if (m && [m count] == 4) {
				NSMutableString *newTitle = [title mutableCopy];
				[newTitle replaceCharactersInRange:[m rangeOfMatchedString]
							withString:@""];
				DEBUG(@"title %@ -> %@, got %lu matches", title, newTitle, [m count]);

				NSRange nrange = [m rangeOfSubstringAtIndex:1];	/* normal range */
				NSRange vrange = [m rangeOfSubstringAtIndex:3]; /* visual range */
				if (vrange.location == NSNotFound)
					vrange = nrange;

				DEBUG(@"nrange = %@, vrange = %@", NSStringFromRange(nrange), NSStringFromRange(vrange));

				DEBUG(@"hasSelection = %s", hasSelection ? "YES" : "NO");

				/* Replace "Thing / Selection" depending on hasSelection.
				 */
				NSRange r = [newTitle rangeOfString:@" / Selection"];
				if (r.location != NSNotFound) {
					if (hasSelection) {
						NSCharacterSet *set = [NSCharacterSet letterCharacterSet];
						NSInteger l;
						for (l = r.location; l > 0; l--)
							if (![set characterIsMember:[newTitle characterAtIndex:l - 1]])
								break;
						NSRange altr = NSMakeRange(l, r.location - l + 3);
						if (altr.length > 3)
							[newTitle deleteCharactersInRange:altr];
					} else
						[newTitle deleteCharactersInRange:r];
				}

				NSString *command = [title substringWithRange:(hasSelection ? vrange : nrange)];
				DEBUG(@"command is [%@]", command);

				if ([command length] == 0) {
					/* use the other match, but disable the menu item */
					command = [title substringWithRange:(hasSelection ? nrange : vrange)];
					DEBUG(@"disabled command is [%@]", command);
					[item setEnabled:NO];
				} else {
					[item setEnabled:YES];
					if ([item action] == NULL)
						[item setAction:@selector(performNormalModeMenuItem:)];
				}

				ViCommandMenuItemView *view = (ViCommandMenuItemView *)[item view];
				if (view == nil) {
					view = [[ViCommandMenuItemView alloc] initWithTitle:newTitle
										    command:command
										       font:[self font]];
				} else {
					view.title = newTitle;
					view.command = command;
				}
				[item setView:view];
				DEBUG(@"setting title [%@], action is %@", newTitle, NSStringFromSelector([item action]));
				[item setTitle:newTitle];
			}

			[item setTag:4001];	/* mark as already updated */
		}
	}
}

@end
