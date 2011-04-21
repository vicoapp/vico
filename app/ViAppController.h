#import "Nu/Nu.h"

@class ViRegexp;

@protocol ViShellThingProtocol <NSObject>

- (void)exit;
- (void)exitWithObject:(id)obj;
- (void)exitWithError:(int)code;
- (void)log:(NSString *)message;

@end

@protocol ViShellCommandProtocol <NSObject>

- (id)eval:(NSString *)script
     error:(NSError **)outError;
- (NSString *)eval:(NSString *)script
additionalBindings:(NSDictionary *)bindings
       errorString:(NSString **)errorString
       backChannel:(NSString *)channelName;
- (NSError *)openURL:(NSString *)pathOrURL;

@end

@interface ViAppController : NSObject <ViShellCommandProtocol>
{
	IBOutlet NSMenu *encodingMenu;
	IBOutlet NSTextField *scriptInput;
	IBOutlet NSTextView *scriptOutput;
	NSConnection *shellConn;
}

@property(readonly) NSMenu *encodingMenu;

- (void)exportGlobals:(id)parser;
- (void)loadStandardModules:(id<NuParsing>)parser;
- (id)eval:(NSString *)script
withParser:(id<NuParsing>)parser
     error:(NSError **)outError;
- (id)eval:(NSString *)script
     error:(NSError **)outError;

+ (NSString *)supportDirectory;
- (IBAction)showPreferences:(id)sender;
- (IBAction)visitWebsite:(id)sender;

@end
