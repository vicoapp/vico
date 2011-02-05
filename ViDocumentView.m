#import "ViDocumentView.h"
#import "ViScope.h"
#import "ViThemeStore.h"

@implementation ViDocumentView

@synthesize view;
@synthesize textView;
@synthesize document;
@synthesize tabController;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument
{
	self = [super init];
	if (self)
		document = aDocument;
	return self;
}

- (void)close
{
	[[self tabController] closeDocumentView:self];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocumentView %p: %@>", self, [document fileURL]];
}

@end
