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
