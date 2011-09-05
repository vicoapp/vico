#import "ViKeyManager.h"

@interface ViOutlineView : NSOutlineView
{
	ViKeyManager *keyManager;
	BOOL strictIndentation;
}

@property (nonatomic, readwrite, assign) ViKeyManager *keyManager;
@property (nonatomic, readwrite) BOOL strictIndentation;

@end
