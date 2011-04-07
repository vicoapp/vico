#import "ViKeyManager.h"

@interface ViCompletionView : NSTableView
{
	ViKeyManager *keyManager;
}

@property (readwrite, assign) ViKeyManager *keyManager;

@end
