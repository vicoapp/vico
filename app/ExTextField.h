#import "ViCommand.h"

@interface ExTextField : NSTextField
{
	NSMutableArray		*_history;
	int			 _historyIndex;
	NSString		*_current;
	BOOL			 _running;
}

- (BOOL)ex_cancel:(ViCommand *)command;
- (BOOL)ex_execute:(ViCommand *)command;

@end
