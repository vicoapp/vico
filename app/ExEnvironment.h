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

	BOOL			 busy;
	NSString		*exString;
}

@property(nonatomic,readonly) NSWindow *window;

- (NSString *)getExStringForCommand:(ViCommand *)command;

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

@end

