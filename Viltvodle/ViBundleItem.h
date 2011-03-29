#import "ViBundle.h"
#import "ViCommon.h"

@interface ViBundleItem : NSObject
{
	ViBundle	*bundle;
	NSString	*uuid;
	NSString	*name;
	NSString	*scope;
	ViMode		 mode;

	/* used in menus */
	NSString	*tabTrigger;
	NSString	*keyEquivalent;
	NSUInteger	 modifierMask;

	/* used when matching keys */
	NSInteger	 keyCode;
}

@property(readonly) ViBundle *bundle;
@property(readonly) NSString *uuid;
@property(readonly) NSString *name;
@property(readonly) NSString *scope;
@property(readonly) ViMode mode;
@property(readonly) NSString *keyEquivalent;
@property(readonly) NSUInteger modifierMask;
@property(readonly) NSInteger keyCode;
@property(readonly) NSString *tabTrigger;

- (ViBundleItem *)initFromDictionary:(NSDictionary *)dict
                            inBundle:(ViBundle *)aBundle;

@end
