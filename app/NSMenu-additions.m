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
				NSMutableString *newTitle = [[title mutableCopy] autorelease];
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
					[view autorelease];
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
