#import "ViWindowController.h"

@interface ViProject : NSDocument
{
	ViWindowController *windowController;
	NSURL *initialURL;
}

@property(nonatomic,readonly) NSURL *initialURL;
@property(nonatomic,readonly) ViWindowController *windowController;

@end
