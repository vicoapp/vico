#import <Cocoa/Cocoa.h>

@class ViRegexp;

@interface ViAppController : NSObject
{
	IBOutlet NSMenu *commandMenu;
	IBOutlet NSTextField *licenseOwner;
	IBOutlet NSTextField *licenseKey;
	IBOutlet NSTextField *licenseEmail;
	IBOutlet NSWindow *registrationWindow;
	NSMutableDictionary *sharedBuffers;
	NSString *lastSearchPattern;
}

@property(copy, readwrite) NSString *lastSearchPattern;

- (IBAction)showPreferences:(id)sender;
- (IBAction)registerLicense:(id)sender;
- (IBAction)dismissRegistrationWindow:(id)sender;

- (NSMutableDictionary *)sharedBuffers;

@end
