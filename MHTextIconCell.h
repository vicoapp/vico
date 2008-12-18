#import <Cocoa/Cocoa.h>

@interface MHTextIconCell : NSTextFieldCell
{
	NSImage *image;
}
@property(readwrite,assign) NSImage *image;

@end
