#import "ViDocument.h"
#import "ViTextView.h"
#import "ViLanguageStore.h"
#import "ViScope.h"
#import "MHSysTree.h"
#import "logging.h"
#import "NSString-scopeSelector.h"

#include <sys/time.h>

@implementation ViTextView (syntax)

/*
 * Update syntax colors for the affected lines.
 */
#if 0
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	NSTextStorage *ts = [notification object];
	NSLayoutManager *lm;
	for (lm in [ts layoutManagers])
	{
		NSTextContainer *tc;
		for (tc in [lm textContainers])
		{
			ViTextView *tv = (ViTextView *)[tc textView];
			[tv updateSyntaxForEditedRange:[ts editedRange]];
		}
	}
}
#endif

@end

