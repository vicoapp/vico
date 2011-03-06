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
	if (self) {
		document = aDocument;
		[document addObserver:self
		           forKeyPath:@"title"
		              options:NSKeyValueObservingOptionNew
		              context:nil];
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocumentView %p: %@>", self, (id)[document fileURL] ?: (id)@"<Untitled>"];
}

- (ViTextView *)textView
{
	return (ViTextView *)innerView;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if ([keyPath isEqualToString:@"title"]) {
		[self willChangeValueForKey:@"title"];
		[self didChangeValueForKey:@"title"];
	}
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
