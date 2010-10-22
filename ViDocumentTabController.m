#import "ViDocumentTabController.h"
#import "ViDocumentView.h"

@implementation ViDocumentTabController

@synthesize views;

- (id)initWithDocumentView:(ViDocumentView *)initialDocumentView
{
	self = [super init];
	if (self) {
		views = [[NSMutableArray alloc] init];
		[self setObjectClass:[ViDocument class]];

		NSRect frame = NSMakeRect(0, 0, 100, 100);
		splitView = [[NSSplitView alloc] initWithFrame:frame];
		[splitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

		[splitView setIsPaneSplitter:YES];
		[splitView addSubview:[initialDocumentView view]];
		[splitView adjustSubviews];

		[self addView:initialDocumentView];
	}
	return self;
}

- (void)addView:(ViDocumentView *)docView
{
	[docView setTabController:self];
	[views addObject:docView];
	[self setContent:[docView document]];
}

- (void)removeView:(ViDocumentView *)docView
{
	[[docView document] removeView:docView];
	[views removeObject:docView];
}

- (NSSet *)documents
{
	NSMutableSet *set = [[NSMutableSet alloc] init];

	for (ViDocumentView *docView in views)
		if (![set containsObject:[docView document]])
			[set addObject:[docView document]];

	return set;
}

- (NSView *)view
{
	return splitView;
}

- (ViDocumentView *)splitView:(ViDocumentView *)docView vertically:(BOOL)isVertical
{
	NSView *view = [docView view];

	NSSplitView *split = (NSSplitView *)[view superview];
	if (![split isKindOfClass:[NSSplitView class]]) {
		INFO(@"***** superview not an NSSplitView!? %@", split);
		return nil;
	}

	if ([[split subviews] count] == 1 && [split isVertical] != isVertical)
		[split setVertical:isVertical];

	ViDocumentView *newDocView = [[docView document] makeView];
	[self addView:newDocView];

	if ([split isVertical] == isVertical) {
		// Just add another view to this split
		[split addSubview:[newDocView view]];
		[split adjustSubviews];
	} else {
		// Need to create a new horizontal split view and replace
		// the current view with the split and two subviews
		NSRect frame = [view frame];
		frame.origin = NSMakePoint(0, 0);
		NSSplitView *newSplit = [[NSSplitView alloc] initWithFrame:frame];
		[newSplit setVertical:isVertical];
		[newSplit setIsPaneSplitter:YES];
		[newSplit setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[split replaceSubview:view with:newSplit];
		[newSplit addSubview:view];
		[newSplit addSubview:[newDocView view]];
		[newSplit adjustSubviews];
	}

	return newDocView;
}

- (ViDocumentView *)replaceDocumentView:(ViDocumentView *)docView withDocument:(ViDocument *)document
{
	ViDocumentView *newDocView = [document makeView];

	[self addView:newDocView];
	[self removeView:docView];

	[[[docView view] superview] replaceSubview:[docView view] with:[newDocView view]];

	return newDocView;
}

- (void)closeDocumentView:(ViDocumentView *)docView
{
	[self removeView:docView];

	id split = [[docView view] superview];
	[[docView view] removeFromSuperview];

	if ([[split subviews] count] == 1) {
		id superSplit = [split superview];
		if ([superSplit isMemberOfClass:[NSSplitView class]])
			[superSplit replaceSubview:split with:[[split subviews] objectAtIndex:0]];
	}
}

@end

