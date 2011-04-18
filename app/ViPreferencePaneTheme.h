#import "ViPreferencePane.h"

@interface ViPreferencePaneTheme : ViPreferencePane
{
	IBOutlet NSPopUpButton *themeButton;
	IBOutlet NSTextField *currentFont;
}

- (IBAction)selectFont:(id)sender;
- (void)setSelectedFont;

@end

