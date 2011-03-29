#import "ViCommon.h"
#import "ViParser.h"

@interface ViOutlineView : NSOutlineView
{
	ViMode mode;
	ViParser *parser;
}
@end

@interface NSObject (ViOutlineViewDelegateMethods)
- (void)outlineView:(ViOutlineView *)outlineView
    evaluateCommand:(ViParser *)command;
@end
