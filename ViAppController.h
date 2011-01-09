@class ViRegexp;

@interface ViAppController : NSObject
{
	IBOutlet NSMenu *commandMenu;
	IBOutlet NSMenu *encodingMenu;
	NSMutableDictionary *sharedBuffers;
	NSString *lastSearchPattern;
}

@property(copy, readwrite) NSString *lastSearchPattern;
@property(readonly) NSMenu *encodingMenu;

+ (NSString *)supportDirectory;
- (IBAction)showPreferences:(id)sender;

- (NSMutableDictionary *)sharedBuffers;

@end
