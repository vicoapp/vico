#import "ViCommand.h"

@interface NSTableView (vimotions)

- (BOOL)move_down:(ViCommand *)command;
- (BOOL)move_up:(ViCommand *)command;
- (BOOL)move_high:(ViCommand *)command;
- (BOOL)move_middle:(ViCommand *)command;
- (BOOL)move_low:(ViCommand *)command;
- (BOOL)move_home:(ViCommand *)command;
- (BOOL)move_end:(ViCommand *)command;
- (BOOL)scroll_up_by_line:(ViCommand *)command;
- (BOOL)scroll_down_by_line:(ViCommand *)command;
- (BOOL)backward_screen:(ViCommand *)command;
- (BOOL)forward_screen:(ViCommand *)command;
- (BOOL)goto_line:(ViCommand *)command;

@end
