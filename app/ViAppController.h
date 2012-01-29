#import "ViTextView.h"
#import "Nu/Nu.h"
#import <Carbon/Carbon.h>

@interface NuParser (fix)
- (void)close;
@end

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
- (IBAction)newProject:(id)sender;

@end

#ifdef TRIAL_VERSION
int updateMeta(void);
#endif

@interface ViAppController : NSObject <ViShellCommandProtocol, NSTextViewDelegate>
{
	IBOutlet NSMenu		*encodingMenu;
	IBOutlet NSMenu		*viewMenu;
	IBOutlet NSTextField	*scriptInput;
	IBOutlet NSTextView	*scriptOutput;
	IBOutlet NSMenuItem	*closeDocumentMenuItem;
	IBOutlet NSMenuItem	*closeWindowMenuItem;
	IBOutlet NSMenuItem	*closeTabMenuItem;
	IBOutlet NSMenuItem	*showFileExplorerMenuItem;
	IBOutlet NSMenuItem	*showSymbolListMenuItem;
	NSConnection		*shellConn;

	TISInputSourceRef	 original_input_source;
	BOOL			 _recently_launched;
	NSWindow		*_menuTrackedKeyWindow;
	BOOL			 _trackingMainMenu;

	// input of scripted ex commands
	// XXX: in search of a better place (refugees from ExEnvironment)
	BOOL			 _busy;
	NSString		*_exString;
	ViTextStorage		*_fieldEditorStorage;
	ViTextView		*_fieldEditor;

#ifdef TRIAL_VERSION
	NSTimer			*mTimer;
#endif
}

@property(nonatomic,readonly) NSMenu *encodingMenu;
@property(nonatomic,readonly) TISInputSourceRef original_input_source;

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
- (IBAction)installTerminalHelper:(id)sender;
- (IBAction)showMarkInspector:(id)sender;

- (NSString *)getExStringForCommand:(ViCommand *)command prefix:(NSString *)prefix;
- (NSString *)getExStringForCommand:(ViCommand *)command;

- (NSWindow *)keyWindowBeforeMainMenuTracking;
- (void)forceUpdateMenu:(NSMenu *)menu;

@end
