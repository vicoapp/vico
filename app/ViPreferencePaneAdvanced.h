#import "ViPreferencePane.h"

@interface environmentVariableTransformer : NSValueTransformer
{
}
@end

@interface ViPreferencePaneAdvanced : ViPreferencePane
{
	IBOutlet NSArrayController *arrayController;
	IBOutlet NSTableView *tableView;
}

- (IBAction)addVariable:(id)sender;

@end

