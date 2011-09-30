#import "ViDocumentView.h"
#import "ViScope.h"
#import "ViThemeStore.h"

@implementation ViDocumentView

@synthesize innerView = _innerView;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument
{
	if ((self = [super initWithNibName:@"ViDocument" bundle:nil]) != nil) {
		MEMDEBUG(@"init %p", self);
		[self loadView]; // Force loading of NIB
		[self setDocument:aDocument];
	}
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	if ([self representedObject] != nil)
		[self setDocument:nil];
	[super dealloc];
}

- (ViDocument *)document
{
	return [self representedObject];
}

- (void)setDocument:(ViDocument *)document
{
	DEBUG(@"set document %@ -> %@", [self representedObject], document);
	[self unbind:@"processing"];
	[self unbind:@"modified"];
	[self unbind:@"title"];

	[self setRepresentedObject:document];

	if (document) {
		[self bind:@"processing" toObject:document withKeyPath:@"busy" options:nil];
		[self bind:@"modified" toObject:document withKeyPath:@"modified" options:nil];
		[self bind:@"title" toObject:document withKeyPath:@"title" options:nil];
	}
}

- (void)setTabController:(ViTabController *)tabController
{
	[super setTabController:tabController];
	if (tabController)
		[[self document] addView:self];
	else
		[[self document] removeView:self];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocumentView %p: %@>",
	    self, [self representedObject]];
}

- (ViTextView *)textView
{
	return (ViTextView *)_innerView;
}

- (void)replaceTextView:(ViTextView *)textView
{
	[_innerView removeFromSuperview];
	_innerView = textView;
	[_scrollView setDocumentView:_innerView];
	[textView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
	[textView setMinSize:NSMakeSize(83, 0)];
	[textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	[textView setVerticallyResizable:YES];
	[textView setHorizontallyResizable:YES];
}

@end
