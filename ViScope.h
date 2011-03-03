@interface ViScope : NSObject <NSCopying>
{
	NSRange range;
	NSArray *scopes;
	NSDictionary *attributes;
}

@property(readwrite) NSRange range;
@property(readwrite,assign) NSArray *scopes;
@property(readwrite,assign) NSDictionary *attributes;

- (ViScope *)initWithScopes:(NSArray *)scopesArray range:(NSRange)aRange;
- (int)compareBegin:(ViScope *)otherContext;
- (id)copyWithZone:(NSZone *)zone;

@end
