#import "ViProject.h"
#import "logging.h"

@implementation ViProject

- (id)init
{
	self = [super init];
	return self;
}

- (NSString *)windowNibName
{
	return @"ViDocument";
}

- (void)makeWindowControllers
{
	windowController = [[ViWindowController alloc] init];
	INFO(@"created window controller %@", windowController);
	[self addWindowController:windowController];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
	INFO(@"window controller %@ loaded nib", aController);
}

@end
