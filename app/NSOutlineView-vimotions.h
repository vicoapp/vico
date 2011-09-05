#import "ViCommand.h"

@interface NSOutlineView (vimotions)

- (BOOL)move_right:(ViCommand *)command;
- (BOOL)move_left:(ViCommand *)command;

@end
