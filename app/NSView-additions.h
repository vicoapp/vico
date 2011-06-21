@class ViCommand;

@interface NSView (additions)
- (id)targetForSelector:(SEL)action;
- (NSString *)getExStringForCommand:(ViCommand *)command;
@end
