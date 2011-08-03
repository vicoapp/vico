#import "ViPreferencesController.h"

/** Base class for preference panes.
 */
@interface ViPreferencePane : NSObject <ViPreferencePane>
{
	NSString *paneName;
	NSImage *icon;
	IBOutlet NSView *view;
}

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSImage *icon;
@property (nonatomic, readonly) NSView *view;

/** Initialize a preference pane.
 * @param nib A Nib object. The Nib will be instantiated with the receiver as owner.
 * @param aName The name of the preference pane.
 * @param anIcon The icon of the preference pane.
 */
- (id)initWithNib:(NSNib *)nib
             name:(NSString *)aName
             icon:(NSImage *)anIcon;

- (id)initWithNibName:(NSString *)nibPath
                 name:(NSString *)aName
                 icon:(NSImage *)anIcon;

@end

