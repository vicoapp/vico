#import "ViDocumentTabController.h"
#import "ViDocumentView.h"

@implementation ViDocumentTabController

@synthesize views, selectedView;

- (id)initWithViewController:(id<ViViewController>)initialViewController
{
	self = [super init];
	if (self) {
		views = [[NSMutableArray alloc] init];

		NSRect frame = NSMakeRect(0, 0, 100, 100);
		splitView = [[NSSplitView alloc] initWithFrame:frame];
		[splitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[splitView setDividerStyle:NSSplitViewDividerStylePaneSplitter];

		[splitView addSubview:[initialViewController view]];
		[splitView adjustSubviews];

		[self addView:initialViewController];

		selectedView = initialViewController;
	}
	return self;
}

- (void)addView:(id<ViViewController>)viewController
{
	[viewController setTabController:self];
	[views addObject:viewController];
}

- (void)removeView:(id<ViViewController>)viewController
{
	if ([viewController isKindOfClass:[ViDocumentView class]])
		[[(ViDocumentView *)viewController document] removeView:viewController];
	[views removeObject:viewController];
}

- (NSSet *)documents
{
	NSMutableSet *set = [[NSMutableSet alloc] init];

	for (id<ViViewController> viewController in views) {
		if ([viewController isKindOfClass:[ViDocumentView class]]) {
			ViDocumentView *docView = viewController;
			ViDocument *document = [docView document];
			if (![set containsObject:document])
				[set addObject:document];
		}
	}

	return set;
}

- (NSView *)view
{
	return splitView;
}

- (id<ViViewController>)splitView:(id<ViViewController>)viewController withView:(id<ViViewController>)newViewController vertically:(BOOL)isVertical
{
	NSView *view = [viewController view];

	NSSplitView *split = (NSSplitView *)[view superview];
	if (![split isKindOfClass:[NSSplitView class]]) {
		INFO(@"***** superview not an NSSplitView!? %@", split);
		return nil;
	}

	if ([[split subviews] count] == 1 && [split isVertical] != isVertical)
		[split setVertical:isVertical];

	[self addView:newViewController];

	if ([split isVertical] == isVertical) {
		// Just add another view to this split
		[split addSubview:[newViewController view]];
		[split adjustSubviews];
	} else {
		/*
		 * Create a new split view and replace
		 * the current view with the split and two subviews.
		 */
		NSRect frame = [view frame];
		frame.origin = NSMakePoint(0, 0);
		NSSplitView *newSplit = [[NSSplitView alloc] initWithFrame:frame];
		[newSplit setVertical:isVertical];
		[newSplit setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[newSplit setDividerStyle:NSSplitViewDividerStylePaneSplitter];
		[split replaceSubview:view with:newSplit];
		[newSplit addSubview:view];
		[newSplit addSubview:[newViewController view]];
		[newSplit adjustSubviews];
	}

	return newViewController;
}

- (id<ViViewController>)splitView:(id<ViViewController>)viewController vertically:(BOOL)isVertical
{
	if (![viewController isKindOfClass:[ViDocumentView class]])
		return nil;

	ViDocumentView *docView = viewController;
	ViDocumentView *newDocView = [[docView document] makeView];
	if (![self splitView:viewController withView:newDocView vertically:isVertical])
		return nil;

	[[newDocView textView] setCaret:[[docView textView] caret]];
	return newDocView;
}

- (id<ViViewController>)replaceView:(id<ViViewController>)viewController withDocument:(id)document
{
	id<ViViewController> newViewController = [document makeView];

	[self addView:newViewController];
	[self removeView:viewController];

	[[[viewController view] superview] replaceSubview:[viewController view] with:[newViewController view]];

	return newViewController;
}

- (void)closeView:(id<ViViewController>)viewController
{
	[self removeView:viewController];

	id split = [[viewController view] superview];
	[[viewController view] removeFromSuperview];

	if ([[split subviews] count] == 1) {
		id superSplit = [split superview];
		if ([superSplit isMemberOfClass:[NSSplitView class]]) {
			id newSplit = [[split subviews] objectAtIndex:0];
			[superSplit replaceSubview:split with:newSplit];
			split = newSplit;
		}
	}

	if (selectedView == viewController) {
		if ([split isMemberOfClass:[NSSplitView class]]) {
			if ([[split subviews] count] > 0)
				[self setSelectedView:[self viewControllerForView:[[split subviews] objectAtIndex:0]]];
		} else
			[self setSelectedView:[self viewControllerForView:split]];
	}
}

- (id<ViViewController>)viewControllerForView:(NSView *)aView
{
	for (id<ViViewController> viewController in [self views])
		if ([viewController view] == aView ||
		    [viewController innerView] == aView)
			return viewController;

	return nil;
}

- (NSSplitView *)containingSplitViewRelativeTo:(NSView *)view isVertical:(BOOL)isVertical index:(NSInteger *)indexPtr
{
	NSView *sup;
	while (view != nil && ![view isMemberOfClass:[NSTabView class]]) {
		sup = [view superview];
		if ([sup isMemberOfClass:[NSSplitView class]] && [(NSSplitView *)sup isVertical] == isVertical) {
			if (indexPtr != NULL)
				*indexPtr = [[sup subviews] indexOfObject:view];
			return (NSSplitView *)sup;
		}
		view = sup;
	}
	return nil;
}

- (NSView *)containedViewRelativeToView:(NSView *)view anchor:(ViViewOrderingMode)anchor
{
	if ([view isMemberOfClass:[NSSplitView class]]) {
		if ((anchor == ViViewUp && ![(NSSplitView *)view isVertical]) ||
		    (anchor == ViViewLeft && [(NSSplitView *)view isVertical]))
			view = [[view subviews] lastObject];
		else
			view = [[view subviews] objectAtIndex:0];
		return [self containedViewRelativeToView:view anchor:anchor];
	} else
		return view;
}

- (id<ViViewController>)viewAtPosition:(ViViewOrderingMode)position relativeTo:(NSView *)view
{
	if (view == nil)
		return nil;

	BOOL isVertical = (position == ViViewLeft || position == ViViewRight);

	NSInteger ndx;
	NSSplitView *split = [self containingSplitViewRelativeTo:view isVertical:isVertical index:&ndx];
	if (split == nil) {
		DEBUG(@"no containing split view for mode %i", position);
		return nil;
	}

	NSInteger newIndex = ndx;
	if (position == ViViewUp || position == ViViewLeft)
		newIndex--;
	else
		newIndex++;

	NSArray *subviews = [split subviews];
	if (newIndex >= 0 && newIndex < [subviews count]) {
		view = [subviews objectAtIndex:newIndex];
		return [self viewControllerForView:[self containedViewRelativeToView:view anchor:position]];
	} else
		return [self viewAtPosition:position relativeTo:split];

	return nil;
}

@end

