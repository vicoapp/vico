#import "Nu/Nu.h"
#import <Carbon/Carbon.h>

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
- (NSError *)openURL:(NSString *)pathOrURL
             andWait:(BOOL)waitFlag
         backChannel:(NSString *)channelName;
- (NSError *)openURL:(NSString *)pathOrURL;

@end

@interface ViAppController : NSObject <ViShellCommandProtocol>
{
	IBOutlet NSMenu *encodingMenu;
	IBOutlet NSTextField *scriptInput;
	IBOutlet NSTextView *scriptOutput;
	IBOutlet NSMenuItem *closeDocumentMenuItem;
	IBOutlet NSMenuItem *closeWindowMenuItem;
	IBOutlet NSMenuItem *closeTabMenuItem;
	IBOutlet NSMenuItem *showFileExplorerMenuItem;
	IBOutlet NSMenuItem *showSymbolListMenuItem;
	NSConnection *shellConn;

	TISInputSourceRef original_input_source;
	BOOL recently_launched;
	NSWindow *menuTrackedKeyWindow;
}

@property(nonatomic,readonly) NSMenu *encodingMenu;
@property (nonatomic, readonly) TISInputSourceRef original_input_source;

- (void)exportGlobals:(NSMutableDictionary *)context;
- (void)loadStandardModules:(NSMutableDictionary *)context;
- (id)eval:(NSString *)script
withParser:(NuParser *)parser
  bindings:(NSDictionary *)bindings
     error:(NSError **)outError;
- (id)eval:(NSString *)script
     error:(NSError **)outError;

+ (NSString *)supportDirectory;
- (IBAction)showPreferences:(id)sender;
- (IBAction)visitWebsite:(id)sender;
- (IBAction)editSiteScript:(id)sender;

@end
