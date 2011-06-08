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

@property(nonatomic,readonly) ViBundle *bundle;
@property(nonatomic,readonly) NSString *uuid;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSString *scope;
@property(nonatomic,readonly) ViMode mode;
@property(nonatomic,readonly) NSString *keyEquivalent;
@property(nonatomic,readonly) NSUInteger modifierMask;
@property(nonatomic,readonly) NSInteger keyCode;
@property(nonatomic,readonly) NSString *tabTrigger;

- (ViBundleItem *)initFromDictionary:(NSDictionary *)dict
                            inBundle:(ViBundle *)aBundle;

@end
