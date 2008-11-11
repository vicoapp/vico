#import <Cocoa/Cocoa.h>

@class ViRegexp;

@interface ViAppController : NSObject
{
	IBOutlet NSMenu *themeMenu;
	NSMutableDictionary *sharedBuffers;
	NSString *lastSearchPattern;
}

@property(copy, readwrite) NSString *lastSearchPattern;

- (IBAction)setTheme:(id)sender;
- (IBAction)setPageGuide:(id)sender;

- (NSMutableDictionary *)sharedBuffers;

@end
