#import "ViKeyManager.h"

@interface ViOutlineView : NSOutlineView <ViKeyManagerTarget>
{
	ViKeyManager *keyManager;
	BOOL strictIndentation;
}

@property (nonatomic, readwrite, assign) ViKeyManager *keyManager;
@property (nonatomic, readwrite) BOOL strictIndentation;

@end
