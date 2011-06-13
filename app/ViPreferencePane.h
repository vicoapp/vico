#import "ViPreferencesController.h"

@interface ViPreferencePane : NSObject <ViPreferencePane>
{
	NSString *paneName;
	NSImage *icon;
	IBOutlet NSView *view;
}

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSImage *icon;
@property (nonatomic, readonly) NSView *view;

- (id)initWithNib:(NSNib *)nib
             name:(NSString *)aName
             icon:(NSImage *)anIcon;

- (id)initWithNibName:(NSString *)nibPath
                 name:(NSString *)aName
                 icon:(NSImage *)anIcon;

@end

