#import <Cocoa/Cocoa.h>

@interface ViScope : NSObject
{
	NSRange range;
	NSArray *scopes;
}

@property(readwrite) NSRange range;
@property(readwrite,copy) NSArray *scopes;
- (ViScope *)initWithScopes:(NSArray *)scopesArray range:(NSRange)aRange;
- (int)compareBegin:(ViScope *)otherContext;

@end

