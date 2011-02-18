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

- (void)replaceTextView:(ViTextView *)textView
{
	[innerView removeFromSuperview];
	[scrollView setDocumentView:textView];
	[textView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
	[textView setMinSize:NSMakeSize(83, 0)];
	[textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	[textView setVerticallyResizable:YES];
	[textView setHorizontallyResizable:YES];
	innerView = textView;
}

@end
