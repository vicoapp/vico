/** A scope covering a range of characters.
 *
 */

@interface ViScope : NSObject <NSCopying>
{
	NSRange		 _range;
	NSArray		*_scopes;
	NSDictionary	*_attributes;
}

/** The range of characters this scope covers. */
@property(nonatomic,readwrite) NSRange range;

@property(nonatomic,readwrite,retain) NSArray *scopes;
@property(nonatomic,readwrite,retain) NSDictionary *attributes;

+ (ViScope *)scopeWithScopes:(NSArray *)scopesArray range:(NSRange)aRange;
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

- (BOOL)addScopeComponent:(NSString *)scopeComponent;

@end
