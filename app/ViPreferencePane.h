#import "ViPreferencesController.h"

@interface ViPreferencePane : NSObject <ViPreferencePane>
{
	NSString *paneName;
	NSImage *icon;
	IBOutlet NSView *view;
}

@property (readonly) NSString *name;
@property (readonly) NSImage *icon;
@property (readonly) NSView *view;

- (id)initWithNib:(NSNib *)nib
             name:(NSString *)aName
             icon:(NSImage *)anIcon;

- (id)initWithNibName:(NSString *)nibPath
                 name:(NSString *)aName
                 icon:(NSImage *)anIcon;

@end

