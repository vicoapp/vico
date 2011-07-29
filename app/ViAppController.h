#import "ViTextView.h"
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

#ifdef TRIAL_VERSION
int updateMeta(void);
#endif

@interface ViAppController : NSObject <ViShellCommandProtocol, NSTextViewDelegate>
{
	IBOutlet NSMenu *encodingMenu;
	IBOutlet NSMenu *viewMenu;
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

	// input of scripted ex commands
	// XXX: in search of a better place (refugees from ExEnvironment)
	BOOL				 busy;
	NSString			*exString;
	ViTextView			*fieldEditor;

#ifdef TRIAL_VERSION
	NSTimer *mTimer;
#endif
}

@property(nonatomic,readonly) NSMenu *encodingMenu;
@property (nonatomic, readonly) TISInputSourceRef original_input_source;

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

- (NSString *)getExStringForCommand:(ViCommand *)command;

@end
