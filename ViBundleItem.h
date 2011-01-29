#import "ViBundle.h"

@interface ViBundleItem : NSObject
{
	ViBundle	*bundle;
	NSString	*uuid;
	NSString	*name;
	NSString	*scope;

	/* used in menus */
	NSString	*keyEquivalent;
	NSUInteger	 modifierMask;

	/* used when matching keys */
	unichar		 keycode;
	unsigned int	 keyflags;
}

@property(readonly) ViBundle *bundle;
@property(readonly) NSString *uuid;
@property(readonly) NSString *name;
@property(readonly) NSString *scope;
@property(readonly) NSString *keyEquivalent;
@property(readonly) NSUInteger modifierMask;
@property(readonly) unichar keycode;
@property(readonly) unsigned int keyflags;

- (ViBundleItem *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle;

@end
