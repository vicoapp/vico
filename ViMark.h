#import <Cocoa/Cocoa.h>

@interface ViMark : NSObject
{
	NSUInteger line, column;
}
@property(readonly) NSUInteger line;
@property(readonly) NSUInteger column;

- (ViMark *)initWithLine:(NSUInteger)aLine column:(NSUInteger)aColumn;

@end
