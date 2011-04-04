#import "ViCommand.h"

@interface ExTextField : NSTextField
{
	NSMutableArray		*history;
	int			 historyIndex;
	BOOL			 running;
}

- (BOOL)ex_cancel:(ViCommand *)command;
- (BOOL)ex_execute:(ViCommand *)command;

@end
