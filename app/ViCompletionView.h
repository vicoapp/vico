#import "ViKeyManager.h"

@interface ViCompletionView : NSTableView
{
	ViKeyManager *_keyManager;
}

@property (nonatomic, readwrite, retain) ViKeyManager *keyManager;

@end
