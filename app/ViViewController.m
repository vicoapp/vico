#import "ViViewController.h"

@implementation ViViewController

@synthesize modified = _modified;
@synthesize processing = _processing;
@synthesize tabController = _tabController;

#if 0
- (ViViewController *)initWithNibPath:(NSString *)nibPath
{
	if ((self = [super initWithNibName:nil bundle:nil]) != nil) {

	}
}
#endif

- (NSView *)innerView
{
	return [self view];
}

- (void)attach
{
}

- (void)detach
{
}

@end
