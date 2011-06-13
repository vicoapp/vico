#import "ViKeyManager.h"

@interface ViCompletionView : NSTableView
{
	ViKeyManager *keyManager;
}

@property (nonatomic, readwrite, assign) ViKeyManager *keyManager;

@end
