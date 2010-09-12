#import <Cocoa/Cocoa.h>

@class ViRegexp;

@interface ViAppController : NSObject
{
	IBOutlet NSMenu *commandMenu;
	NSMutableDictionary *sharedBuffers;
	NSString *lastSearchPattern;
}

@property(copy, readwrite) NSString *lastSearchPattern;

- (IBAction)showPreferences:(id)sender;

- (NSMutableDictionary *)sharedBuffers;

@end
