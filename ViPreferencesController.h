#import <Cocoa/Cocoa.h>

@interface ViPreferencesController : NSWindowController
{
	NSView *blankView;
	IBOutlet NSView *generalView;
	IBOutlet NSView *editingView;
	IBOutlet NSView *fontsColorsView;
	IBOutlet NSPopUpButton *themeButton;
	IBOutlet NSTextField *currentFont;
#if 0
	IBOutlet NSPopUpButton *insertModeInputSources;
	IBOutlet NSPopUpButton *normalModeInputSources;
#endif
}

+ (ViPreferencesController *)sharedPreferences;
- (IBAction)switchToItem:(id)sender;
- (IBAction)selectFont:(id)sender;
- (void)show;

@end
