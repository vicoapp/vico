#import <Cocoa/Cocoa.h>

@class OGRegularExpression;

@interface ViAppController : NSObject
{
	IBOutlet NSMenu *themeMenu;
	NSMutableDictionary *sharedBuffers;
	NSString *lastSearchPattern;
	OGRegularExpression *lastSearchRegexp;
}

@property(copy, readwrite) NSString *lastSearchPattern;
@property(copy, readwrite) OGRegularExpression *lastSearchRegexp;

- (IBAction)setTheme:(id)sender;
- (IBAction)setPageGuide:(id)sender;

- (NSMutableDictionary *)sharedBuffers;

@end
