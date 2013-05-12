#import "ExTextField.h"

#define CommandLineBaseHeight 63

@interface ExCommandLine : NSView <NSTableViewDelegate>
{
	IBOutlet ExTextField *exField;
	IBOutlet NSScrollView *completionScrollView;
	IBOutlet NSTableView *completionView;
	IBOutlet NSArrayController *commandCompletionController;
}

@property (nonatomic,readwrite,assign) NSArray *completionCandidates;
@property (nonatomic,readwrite,assign) BOOL closeOnResponderChange;

- (void)awakeFromNib;

- (void)drawRect:(NSRect)dirtyRect;

- (void)focusCompletions;

@end
