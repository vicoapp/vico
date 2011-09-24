#import "ViKeyManager.h"

@interface ViOutlineView : NSOutlineView <ViKeyManagerTarget>
{
	ViKeyManager	*_keyManager;
	BOOL		 _strictIndentation;
}

@property (nonatomic, readwrite, retain) ViKeyManager *keyManager;
@property (nonatomic, readwrite) BOOL strictIndentation;

@end
