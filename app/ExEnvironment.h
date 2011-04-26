#import "ViDocumentTabController.h"
#import "ProjectDelegate.h"

@class ViTextView;
@class ViDocument;
@class ViWindowController;
@class ExCommand;

@interface ExEnvironment : NSObject <NSTextFieldDelegate>
{
	IBOutlet NSTextField	*messageField;
	IBOutlet NSTextField	*statusbar;
	IBOutlet NSWindow	*window;
	IBOutlet ViWindowController *windowController;
	IBOutlet ProjectDelegate *projectDelegate;

	// command filtering
	NSTask				*filterTask;
	size_t				 filterLeft;
	const void			*filterPtr;
	NSMutableData			*filterOutput;
	NSData				*filterInput;
	IBOutlet NSWindow		*filterSheet;
	IBOutlet NSProgressIndicator	*filterIndicator;
	IBOutlet NSTextField		*filterLabel;
	BOOL				 filterDone;
	BOOL				 filterReadFailed;
	BOOL				 filterWriteFailed;
	NSString			*filterCommand;

	CFSocketRef			 inputSocket, outputSocket;
	CFRunLoopSourceRef		 inputSource , outputSource;
	CFSocketContext			 inputContext, outputContext;

	id				 filterTarget;
	SEL				 filterSelector;
	id				 filterContextInfo;

	NSURL			*baseURL;

	SEL			 exCommandSelector;
	ViTextView		*exTextView;
	id			 exDelegate;
	void			*exContextInfo;
}

@property(readonly) NSURL *baseURL;
@property(readonly) NSMutableData *filterOutput;
@property(readonly) NSData *filterInput;
@property(readonly) NSWindow *window;
@property(readonly) NSWindow *filterSheet;
@property(readwrite, assign) size_t filterLeft;
@property(readwrite, assign) const void *filterPtr;
@property(readwrite, assign) BOOL filterDone;
@property(readwrite, assign) BOOL filterReadFailed;
@property(readwrite, assign) BOOL filterWriteFailed;

- (void)message:(NSString *)fmt, ...;

- (void)execute_ex_command:(NSString *)exCommand;
- (void)cancel_ex_command;

- (void)getExCommandWithDelegate:(id)aDelegate selector:(SEL)aSelector prompt:(NSString *)aPrompt contextInfo:(void *)contextInfo;
- (void)executeForTextView:(ViTextView *)aTextView;

- (void)setBaseURL:(NSURL *)url;
- (void)checkBaseURL:(NSURL *)url
	onCompletion:(void (^)(NSURL *url, NSError *error))aBlock;
- (NSString *)displayBaseURL;

- (void)filterText:(NSString*)inputText
       throughTask:(NSTask *)task
            target:(id)target
          selector:(SEL)selector
       contextInfo:(id)contextInfo
      displayTitle:(NSString *)displayTitle;

- (void)filterText:(NSString*)inputText
    throughCommand:(NSString*)shellCommand
            target:(id)target
          selector:(SEL)selector
       contextInfo:(id)contextInfo;

- (IBAction)filterCancel:(id)sender;

- (void)ex_write:(ExCommand *)command;
- (void)ex_quit:(ExCommand *)command;
- (void)ex_wq:(ExCommand *)command;
- (void)ex_xit:(ExCommand *)command;
- (void)ex_cd:(ExCommand *)command;
- (void)ex_pwd:(ExCommand *)command;
- (void)ex_edit:(ExCommand *)command;
- (void)ex_bang:(ExCommand *)command;
- (void)ex_number:(ExCommand *)command;
- (void)ex_set:(ExCommand *)command;
- (BOOL)ex_split:(ExCommand *)command;
- (BOOL)ex_vsplit:(ExCommand *)command;
- (BOOL)ex_close:(ExCommand *)command;
- (BOOL)ex_new:(ExCommand *)command;
- (BOOL)ex_vnew:(ExCommand *)command;

@end

