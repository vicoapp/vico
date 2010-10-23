@class ViTextView;
@class ViDocument;
@class ViWindowController;

@interface ExEnvironment : NSObject
{
	IBOutlet NSTextField	*messageField;
	IBOutlet NSTextField	*statusbar;
	IBOutlet NSWindow	*window;
	IBOutlet ViWindowController *windowController;

	// command output view
	IBOutlet NSSplitView	*commandSplit;
	IBOutlet NSTextView	*commandOutput;

	NSString		*currentDirectory;

	SEL			 exCommandSelector;
	ViTextView		*exTextView;
	ViDocument		*exDocument;
	id			 exDelegate;
	void			*exContextInfo;

	NSMutableArray		*exCommandHistory;
}

@property(readonly) NSString *currentDirectory;

- (void)message:(NSString *)fmt, ...;
- (void)message:(NSString *)fmt arguments:(va_list)ap;

- (void)getExCommandWithDelegate:(id)aDelegate selector:(SEL)aSelector prompt:(NSString *)aPrompt contextInfo:(void *)contextInfo;
- (void)executeForDocument:(ViDocument *)aDocument textView:(ViTextView *)aTextView;

@end

