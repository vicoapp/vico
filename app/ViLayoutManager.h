@interface ViLayoutManager : NSLayoutManager
{
	BOOL		 _showInvisibles;
	NSDictionary	*_invisiblesAttributes;
	NSString	*_newlineChar;
	NSString	*_tabChar;
	NSString	*_spaceChar;
}

@property(nonatomic,readwrite,copy) NSDictionary *invisiblesAttributes;

- (void)setShowsInvisibleCharacters:(BOOL)flag;
- (BOOL)showsInvisibleCharacters;

@end
