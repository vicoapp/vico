#import "ViCompletionController.h"

@interface ViFileCompletion : NSObject <ViCompletionProvider>
{
	NSURL *relURL;
}

- (ViFileCompletion *)initWithRelativeURL:(NSURL *)aURL;

@end
