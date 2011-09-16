/** A scope covering a range of characters.
 *
 */

@interface ViScope : NSObject <NSCopying>
{
	NSRange range;
	NSArray *scopes;
	NSDictionary *attributes;
}

/** The range of characters this scope covers. */
@property(nonatomic,readwrite) NSRange range;

@property(nonatomic,readwrite,assign) NSArray *scopes;
@property(nonatomic,readwrite,assign) NSDictionary *attributes;

- (ViScope *)initWithScopes:(NSArray *)scopesArray range:(NSRange)aRange;

/** @name Matching scope selectors */

/** Match against a scope selector.
 * @param scopeSelector The scope selector.
 */
- (u_int64_t)match:(NSString *)scopeSelector;

/** Returns the best matching scope selector.
 * @param scopeSelectors An array of scope selectors to match.
 * @returns The scope selector with the highest matching rank.
 */
- (NSString *)bestMatch:(NSArray *)scopeSelectors;

- (int)compareBegin:(ViScope *)otherContext;
- (id)copyWithZone:(NSZone *)zone;

- (BOOL)addScopeComponent:(NSString *)scopeComponent;

@end
