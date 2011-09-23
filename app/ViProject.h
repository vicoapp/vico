#import "ViWindowController.h"

@interface ViProject : NSDocument
{
	ViWindowController	*_windowController;
	NSURL			*_initialURL;
}

@property(nonatomic,readonly) NSURL *initialURL;
@property(nonatomic,readonly) ViWindowController *windowController;

@end
