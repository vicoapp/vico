#import "ViBundle.h"
#import "ViCommon.h"

@interface ViBundleItem : NSObject
{
	__weak ViBundle	*_bundle;	// XXX: not retained!
	NSString	*_uuid;
	NSString	*_name;
	NSString	*_scopeSelector;
	ViMode		 _mode;

	/* used in menus */
	NSString	*_tabTrigger;
	NSString	*_keyEquivalent;
	NSUInteger	 _modifierMask;

	/* used when matching keys */
	NSInteger	 _keyCode;
}

@property(nonatomic,readonly) __weak ViBundle *bundle;
@property(nonatomic,readonly) NSString *uuid;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSString *scopeSelector;
@property(nonatomic,readonly) ViMode mode;
@property(nonatomic,readonly) NSString *keyEquivalent;
@property(nonatomic,readonly) NSUInteger modifierMask;
@property(nonatomic,readonly) NSInteger keyCode;
@property(nonatomic,readonly) NSString *tabTrigger;

- (ViBundleItem *)initFromDictionary:(NSDictionary *)dict
                            inBundle:(ViBundle *)aBundle;

@end
