@interface ViTabTriggerMenuItemView : NSView
{
	NSMutableDictionary	*attributes;
	NSString		*title;
	NSString		*tabTrigger;
	NSSize			 titleSize, triggerSize;
}

- (id)initWithTitle:(NSString *)aTitle tabTrigger:(NSString *)aTabTrigger;

@end