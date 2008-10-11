#import <Cocoa/Cocoa.h>

@interface ViAppController : NSObject
{
	IBOutlet NSMenu *themeMenu;
	NSMutableDictionary *sharedBuffers;
}

- (IBAction)setTheme:(id)sender;
- (IBAction)setPageGuide:(id)sender;

- (NSMutableDictionary *)sharedBuffers;

@end
