#import "ViRegexp.h"

@protocol ViPreferencePane <NSObject>
- (NSString *)name;
- (NSImage *)icon;
- (NSView *)view;
@end

@interface ViPreferencesController : NSWindowController <NSToolbarDelegate>
{
	NSView *blankView;
	NSString *forceSwitchToItem;
	NSMutableArray *panes;
	NSMutableDictionary *toolbarItems;

#if 0
	IBOutlet NSPopUpButton *insertModeInputSources;
	IBOutlet NSPopUpButton *normalModeInputSources;
#endif
}

+ (ViPreferencesController *)sharedPreferences;
- (void)registerPane:(id<ViPreferencePane>)pane;

- (IBAction)switchToItem:(id)sender;

- (void)show;
- (void)showItem:(NSString *)item;

@end
