#import "ViBufferedStream.h"

@interface ViTaskRunner : NSObject <NSStreamDelegate>
{
	NSTask			*_task;
	NSWindow		*_window;
	ViBufferedStream	*_stream;
	NSMutableData		*_stdout;
	NSMutableData		*_stderr;
	int			 _status;
	BOOL			 _done;
	BOOL			 _failed;
	BOOL			 _cancelled;
	id			 _target;
	SEL			 _selector;
	id			 _contextInfo;

	/* Blocking for completion. */
	IBOutlet NSWindow	*waitWindow; // Top-level nib object
	IBOutlet NSButton	*cancelButton;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField	*waitLabel;
}

@property (nonatomic, readwrite, retain) NSTask *task;
@property (nonatomic, readwrite, retain) NSWindow *window;
@property (nonatomic, readwrite, retain) ViBufferedStream *stream;
@property (nonatomic, readwrite, retain) NSMutableData *standardOutput;
@property (nonatomic, readwrite, retain) NSMutableData *standardError;
@property (nonatomic, readwrite, retain) id contextInfo;
@property (nonatomic, readwrite, retain) id target;
@property (nonatomic, readonly) int status;
@property (nonatomic, readonly) BOOL cancelled;

- (NSString *)stdoutString;

- (void)launchTask:(NSTask *)aTask
 withStandardInput:(NSData *)stdin
asynchronouslyInWindow:(NSWindow *)aWindow
	     title:(NSString *)displayTitle
	    target:(id)aTarget
	  selector:(SEL)aSelector
       contextInfo:(id)contextObject;

- (BOOL)launchShellCommand:(NSString *)shellCommand
	 withStandardInput:(NSData *)stdin
	       environment:(NSDictionary *)environment
	  currentDirectory:(NSString *)currentDirectory
    asynchronouslyInWindow:(NSWindow *)aWindow
		     title:(NSString *)displayTitle
		    target:(id)aTarget
		  selector:(SEL)aSelector
	       contextInfo:(id)contextObject
		     error:(NSError **)outError;

- (IBAction)cancelTask:(id)sender;

@end

