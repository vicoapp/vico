#import "ViDocumentView.h"
#import "ViScope.h"
#import "ViThemeStore.h"

@implementation ViDocumentView

@synthesize view;
@synthesize textView;
@synthesize document;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument
{
	self = [super init];
	if (self)
		document = aDocument;
	return self;
}

@end
