@interface ViScope : NSObject <NSCopying>
{
	NSRange range;
	NSArray *scopes;
	NSDictionary *attributes;
}

@property(nonatomic,readwrite) NSRange range;
@property(nonatomic,readwrite,assign) NSArray *scopes;
@property(nonatomic,readwrite,assign) NSDictionary *attributes;

- (ViScope *)initWithScopes:(NSArray *)scopesArray range:(NSRange)aRange;
- (u_int64_t)match:(NSString *)scopeSelector;
- (int)compareBegin:(ViScope *)otherContext;
- (id)copyWithZone:(NSZone *)zone;

@end
