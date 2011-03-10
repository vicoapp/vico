@class ViRegexp;

@protocol ViShellCommandProtocol <NSObject>

- (NSString *)eval:(NSString *)script
    withScriptPath:(NSString *)path
       errorString:(NSString **)errorString;
- (NSError *)openURL:(NSURL *)anURL;

@end

@interface ViAppController : NSObject <ViShellCommandProtocol>
{
	IBOutlet NSMenu *encodingMenu;
	IBOutlet NSTextField *scriptInput;
	IBOutlet NSTextView *scriptOutput;
	NSMutableDictionary *sharedBuffers;
	NSString *lastSearchPattern;

	BOOL evalFromShell;
	NSString *lastEvalError;
	NSConnection *shellConn;
}

@property(copy, readwrite) NSString *lastSearchPattern;
@property(readonly) NSMenu *encodingMenu;

- (IBAction)evalScript:(id)sender;
- (IBAction)clearConsole:(id)sender;

+ (NSString *)supportDirectory;
- (IBAction)showPreferences:(id)sender;

- (NSMutableDictionary *)sharedBuffers;

@end
