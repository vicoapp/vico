@interface ViCommandMenuItemView : NSView
{
	NSMutableDictionary	*_attributes;
	NSString		*_title;
	NSSize			 _titleSize;
	NSString		*_command;
	NSString		*_commandTitle;
	NSSize			 _commandSize;
	NSColor			*_disabledColor;
	NSColor			*_highlightColor;
	NSColor			*_normalColor;
}

@property (nonatomic, readonly) NSString *command;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readwrite, retain) NSMutableDictionary *attributes;

- (id)initWithTitle:(NSString *)aTitle
	    command:(NSString *)aCommand
	       font:(NSFont *)aFont;
- (id)initWithTitle:(NSString *)aTitle
	 tabTrigger:(NSString *)aTabTrigger
	       font:(NSFont *)aFont;

- (void)setCommand:(NSString *)aCommand;
- (void)setTabTrigger:(NSString *)aTabTrigger;
- (void)setTitle:(NSString *)aTitle;

@end
