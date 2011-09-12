@interface MHTextIconCell : NSTextFieldCell
{
	NSImage *image;
	NSImage *modImage;
	NSImage *statusImage;
	NSSize modImageSize;
	BOOL modified;
}
@property(nonatomic,readwrite,assign) NSImage *image;
@property(nonatomic,readwrite,assign) NSImage *statusImage;
@property(nonatomic,readwrite) BOOL modified;

@end
