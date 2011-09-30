#import "ViDocumentView.h"
#import "ViScope.h"
#import "ViThemeStore.h"

@implementation ViDocumentView

@synthesize view = _view;
@synthesize innerView = _innerView;
@synthesize document = _document;
@synthesize tabController = _tabController;
@synthesize processing = _processing;
@synthesize modified = _modified;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument
{
	if ((self = [super init]) != nil) {
		if (![NSBundle loadNibNamed:@"ViDocument" owner:self]) {
			INFO(@"%s", "Failed to load nib \"ViDocument\"");
			return nil;
		}
		DEBUG(@"init document view %p", self);
		[self setDocument:aDocument];
	}
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	if (_document)
		[self setDocument:nil];
	[_view release]; // Top-level nib object
	[super dealloc];
}

- (void)setDocument:(ViDocument *)document
{
	DEBUG(@"set document %@ -> %@", _document, document);
	[self unbind:@"processing"];
	[self unbind:@"modified"];
	[_document removeObserver:self forKeyPath:@"title"];
	[document retain];
	[_document release];
	_document = document;
	if (_document) {
		[_document addObserver:self
			    forKeyPath:@"title"
			       options:NSKeyValueObservingOptionNew
			       context:nil];
		[self bind:@"processing" toObject:_document withKeyPath:@"busy" options:nil];
		[self bind:@"modified" toObject:_document withKeyPath:@"modified" options:nil];
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocumentView %p: %@>",
	    self, _document ? [_document description] : @"<Untitled>"];
}

- (ViTextView *)textView
{
	return (ViTextView *)_innerView;
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
	return [_document title];
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
