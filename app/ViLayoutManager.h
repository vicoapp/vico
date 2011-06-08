@interface ViLayoutManager : NSLayoutManager
{
	BOOL showInvisibles;
	NSDictionary *invisiblesAttributes;

	NSString *newlineChar;
	NSString *tabChar;
	NSString *spaceChar;
}

@property(nonatomic,readwrite,copy) NSDictionary *invisiblesAttributes;

- (void)setShowsInvisibleCharacters:(BOOL)flag;
- (BOOL)showsInvisibleCharacters;

@end
