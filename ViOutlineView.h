#import "ViCommon.h"
#import "ViCommand.h"

@interface ViOutlineView : NSOutlineView
{
	ViMode mode;
	ViCommand *parser;
}
@end

@interface NSObject (ViOutlineViewDelegateMethods)
- (void)outlineView:(ViOutlineView *)outlineView
    evaluateCommand:(ViCommand *)command;
@end
