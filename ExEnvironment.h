#import "ViDocumentTabController.h"

@class ViTextView;
@class ViDocument;
@class ViWindowController;
@class ExCommand;

@interface ExEnvironment : NSObject <NSTextFieldDelegate>
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
	id			 exDelegate;
	void			*exContextInfo;

	NSMutableArray		*exCommandHistory;
}

@property(readonly) NSString *currentDirectory;

- (void)message:(NSString *)fmt, ...;
- (void)message:(NSString *)fmt arguments:(va_list)ap;

- (void)getExCommandWithDelegate:(id)aDelegate selector:(SEL)aSelector prompt:(NSString *)aPrompt contextInfo:(void *)contextInfo;
- (void)executeForTextView:(ViTextView *)aTextView;

- (BOOL)changeCurrentDirectory:(NSString *)path;

- (void)switchToLastDocument;
- (void)selectLastDocument;
- (void)selectTabAtIndex:(NSInteger)anIndex;
- (BOOL)selectViewAtPosition:(ViViewOrderingMode)position relativeTo:(ViTextView *)aTextView;

- (void)ex_write:(ExCommand *)command;
- (void)ex_quit:(ExCommand *)command;
- (void)ex_wq:(ExCommand *)command;
- (void)ex_xit:(ExCommand *)command;
- (void)ex_cd:(ExCommand *)command;
- (void)ex_pwd:(ExCommand *)command;
- (void)ex_edit:(ExCommand *)command;
- (void)ex_bang:(ExCommand *)command;
- (void)ex_number:(ExCommand *)command;
- (void)ex_set:(ExCommand *)command;
- (BOOL)ex_split:(ExCommand *)command;
- (BOOL)ex_vsplit:(ExCommand *)command;
- (BOOL)ex_close:(ExCommand *)command;
- (BOOL)ex_new:(ExCommand *)command;
- (BOOL)ex_vnew:(ExCommand *)command;

@end

