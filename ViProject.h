#import "ViWindowController.h"

@interface ViProject : NSDocument
{
	ViWindowController *windowController;
	NSURL *initialURL;
}

@property(readonly) NSURL *initialURL;

@end
