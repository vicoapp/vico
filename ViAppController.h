#import <Cocoa/Cocoa.h>

@interface ViAppController : NSObject
{
	IBOutlet NSMenu *themeMenu;
}

- (IBAction)closeCurrentTab:(id)sender;
- (IBAction)setPageGuide:(id)sender;

@end
