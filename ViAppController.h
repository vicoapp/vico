@class ViRegexp;

@interface ViAppController : NSObject
{
	IBOutlet NSMenu *commandMenu;
	IBOutlet NSTextField *licenseOwner;
	IBOutlet NSTextField *licenseKey;
	IBOutlet NSTextField *licenseEmail;
	IBOutlet NSWindow *registrationWindow;
	IBOutlet NSMenu *encodingMenu;
	NSMutableDictionary *sharedBuffers;
	NSString *lastSearchPattern;
}

@property(copy, readwrite) NSString *lastSearchPattern;
@property(readonly) NSMenu *encodingMenu;

- (IBAction)showPreferences:(id)sender;
- (IBAction)registerLicense:(id)sender;
- (IBAction)dismissRegistrationWindow:(id)sender;

- (NSMutableDictionary *)sharedBuffers;

@end
