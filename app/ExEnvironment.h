#import "ViBufferedStream.h"

@interface ExEnvironment : NSObject <NSStreamDelegate>
{
	IBOutlet NSWindow	*window;

	// command filtering
	NSTask				*filterTask;
	ViBufferedStream		*filterStream;

	NSMutableData			*filterOutput;
	IBOutlet NSWindow		*filterSheet;
	IBOutlet NSProgressIndicator	*filterIndicator;
	IBOutlet NSTextField		*filterLabel;
	BOOL				 filterDone;
	BOOL				 filterFailed;

	id				 filterTarget;
	SEL				 filterSelector;
	id				 filterContextInfo;
}

@property(nonatomic,readonly) NSWindow *window;

- (void)filterText:(NSString*)inputText
       throughTask:(NSTask *)task
            target:(id)target
          selector:(SEL)selector
       contextInfo:(id)contextInfo
      displayTitle:(NSString *)displayTitle;

- (IBAction)filterCancel:(id)sender;

@end

