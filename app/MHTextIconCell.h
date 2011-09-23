@interface MHTextIconCell : NSTextFieldCell
{
	NSImage	*_image;
	NSImage	*_modImage;
	NSImage	*_statusImage;
	BOOL	 _modified;
}

@property(nonatomic,readwrite,retain) NSImage *image;
@property(nonatomic,readwrite,retain) NSImage *statusImage;
@property(nonatomic,readwrite,retain) NSImage *modImage;
@property(nonatomic,readwrite) BOOL modified;

@end
