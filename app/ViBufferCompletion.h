#import "ViCompletionController.h"
#import "ViWindowController.h"

@interface ViBufferCompletion : NSObject <ViCompletionProvider>
{
	ViWindowController *windowController;
}

- (id)initWithWindowController:(ViWindowController *)aWindowController;

@end
