#import <Cocoa/Cocoa.h>

@interface ViAppController : NSObject
{
	IBOutlet NSMenu *themeMenu;
}

- (IBAction)setTheme:(id)sender;
- (IBAction)setPageGuide:(id)sender;

@end
