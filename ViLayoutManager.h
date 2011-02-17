@interface ViLayoutManager : NSLayoutManager
{
	BOOL showInvisibles;
	NSDictionary *invisiblesAttributes;
}

@property(readwrite,copy) NSDictionary *invisiblesAttributes;

- (void)setShowsInvisibleCharacters:(BOOL)flag;
- (BOOL)showsInvisibleCharacters;

@end
