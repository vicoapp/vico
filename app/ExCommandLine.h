#import "ExTextField.h"

#define CommandLineBaseHeight 63

@interface ExCommandLine : NSView
{
	IBOutlet ExTextField *exField;
	IBOutlet NSScrollView *completionScrollView;
	IBOutlet NSTableView *completionView;
	IBOutlet NSArrayController *commandCompletionController;
}

@property (nonatomic,readwrite,assign) NSArray *completionCandidates;

- (void)awakeFromNib;

- (void)drawRect:(NSRect)dirtyRect;

- (void)exFieldDidChange:(NSNotification *)notification;

@end
