#import <Cocoa/Cocoa.h>

@interface ViSyntaxResult : NSObject
{
	NSArray *scopes;
	NSRange range;
}

@property(readonly) NSArray *scopes;
@property(readonly) NSRange range;

- (ViSyntaxResult *)initWithScopes:(NSArray *)scopeArray range:(NSRange)aRange;

@end
