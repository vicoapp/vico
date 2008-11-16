#import <Cocoa/Cocoa.h>

#define DEPTH_RANK 1000000000000000000ULL /* 10^18 */

@interface NSString (scopeSelector)
- (u_int64_t)matchesScopes:(NSArray *)scopes;
- (u_int64_t)scopePartRankAtDepth:(int)depth;
@end
