#import "ViDocumentTabController.h"
#import "ProjectDelegate.h"
#import "ViBufferedStream.h"
#import "ViURLManager.h"

@class ViTextView;
@class ViDocument;
@class ViWindowController;
@class ExCommand;

@interface ExEnvironment : NSObject <NSTextFieldDelegate, NSStreamDelegate, ViDeferredDelegate>
{
	IBOutlet NSTextField	*messageField;
	IBOutlet NSTextField	*statusbar;
	IBOutlet NSWindow	*window;
	IBOutlet ViWindowController *windowController;
	IBOutlet ProjectDelegate *projectDelegate;

	// command filtering
	NSTask				*filterTask;
	ViBufferedStream		*filterStream;

	NSMutableData			*filterOutput;
	IBOutlet NSWindow		*filterSheet;
	IBOutlet NSProgressIndicator	*filterIndicator;
	IBOutlet NSTextField		*filterLabel;
	BOOL				 filterDone;
	BOOL				 filterFailed;
	NSString			*filterCommand;

	id				 filterTarget;
	SEL				 filterSelector;
	id				 filterContextInfo;

	NSURL			*baseURL;

	SEL			 exCommandSelector;
	ViTextView		*exTextView;
	id			 exDelegate;
	void			*exContextInfo;
}

@property(nonatomic,readonly) NSURL *baseURL;
@property(nonatomic,readonly) NSWindow *window;

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

