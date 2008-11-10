#import <Cocoa/Cocoa.h>

@class ViRegexp;

@interface ViAppController : NSObject
{
	IBOutlet NSMenu *themeMenu;
	NSMutableDictionary *sharedBuffers;
	NSString *lastSearchPattern;
	ViRegexp *lastSearchRegexp;
}

@property(copy, readwrite) NSString *lastSearchPattern;
@property(copy, readwrite) ViRegexp *lastSearchRegexp;

- (IBAction)setTheme:(id)sender;
- (IBAction)setPageGuide:(id)sender;

- (NSMutableDictionary *)sharedBuffers;

@end
