@interface ViCommandMenuItemView : NSView
{
	NSMutableDictionary	*attributes;
	NSString		*title;
	NSString		*command;
	NSSize			 titleSize, commandSize;
}

@property (readonly) NSString *command;
@property (readonly) NSString *title;

- (void)setCommand:(NSString *)aCommand;
- (void)setTabTrigger:(NSString *)aTabTrigger;
- (void)setTitle:(NSString *)aTitle;
- (id)initWithTitle:(NSString *)aTitle command:(NSString *)aCommand;
- (id)initWithTitle:(NSString *)aTitle tabTrigger:(NSString *)aTabTrigger;

@end