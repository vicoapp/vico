@interface MHTextIconCell : NSTextFieldCell
{
	NSImage *image;
	NSImage *modImage;
	NSImage *badge;
	NSSize modImageSize;
	BOOL modified;
}
@property(nonatomic,readwrite,assign) NSImage *image;
@property(nonatomic,readwrite,assign) NSImage *badge;
@property(nonatomic,readwrite) BOOL modified;

@end
