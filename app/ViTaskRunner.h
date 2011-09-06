#import "ViBufferedStream.h"

@interface ViTaskRunner : NSObject <NSStreamDelegate>
{
	NSTask			*task;
	NSWindow		*window;
	ViBufferedStream	*stream;
	NSMutableData		*stdout, *stderr;
	int			 status;
	BOOL			 done, failed, cancelled;
	id			 target;
	SEL			 selector;
	id			 contextInfo;

	/* Blocking for completion. */
	IBOutlet NSWindow	*waitWindow;
	IBOutlet NSButton	*cancelButton;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField	*waitLabel;
}

@property (nonatomic, readonly) NSTask *task;
@property (nonatomic, readonly) NSWindow *window;
@property (nonatomic, readonly) ViBufferedStream *stream;
@property (nonatomic, readonly) NSMutableData *stdout;
@property (nonatomic, readonly) NSMutableData *stderr;
@property (nonatomic, readonly) int status;
@property (nonatomic, readonly) BOOL cancelled;

- (NSString *)stdoutString;

- (void)launchTask:(NSTask *)aTask
 withStandardInput:(NSData *)stdin
synchronouslyInWindow:(NSWindow *)aWindow
	     title:(NSString *)displayTitle
	    target:(id)aTarget
	  selector:(SEL)aSelector
       contextInfo:(id)contextObject;

- (IBAction)cancelTask:(id)sender;

@end

