#import "ViDocumentView.h"
#import "ViScope.h"
#import "ViThemeStore.h"

@implementation ViDocumentView

@synthesize view;
@synthesize innerView;
@synthesize document;
@synthesize tabController;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument
{
	self = [super init];
	if (self)
		document = aDocument;
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocumentView %p: %@>", self, [document fileURL]];
}

- (ViTextView *)textView
{
	return (ViTextView *)innerView;
}

- (NSString *)title
{
	return [document title];
}

@end
