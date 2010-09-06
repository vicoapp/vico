#import "ViProject.h"
#import "logging.h"

@implementation ViProject

- (NSString *)windowNibName
{
	return @"ViDocument";
}

- (void)makeWindowControllers
{
	windowController = [[ViWindowController alloc] init];
	[self addWindowController:windowController];
}

@end
