@interface ViLayoutManager : NSLayoutManager
{
	BOOL			 _showInvisibles;
	NSMutableDictionary	*_invisiblesAttributes;
	NSImage			*_newlineImage;
	NSImage			*_tabImage;
	NSImage			*_spaceImage;
}

@property(nonatomic,readwrite,copy) NSDictionary *invisiblesAttributes;

- (void)setShowsInvisibleCharacters:(BOOL)flag;
- (BOOL)showsInvisibleCharacters;

@end
