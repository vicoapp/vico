@interface MHTextIconCell : NSTextFieldCell
{
	NSImage *image;
	NSImage *modImage;
	NSSize modImageSize;
	BOOL modified;
}
@property(nonatomic,readwrite,assign) NSImage *image;
@property(nonatomic,readwrite) BOOL modified;

@end
