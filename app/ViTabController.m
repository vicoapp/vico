#import "ViTabController.h"
#import "ViDocumentView.h"
#import "ViEventManager.h"

@interface ViTabController (private)
- (void)normalizeViewsRecursively:(id)split;
@end

@implementation ViTabController

@synthesize window, views, selectedView, previousView;

- (id)initWithViewController:(id<ViViewController>)initialViewController
		      window:(NSWindow *)aWindow
{
	self = [super init];
	if (self) {
		views = [[NSMutableArray alloc] init];
		window = aWindow;

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
	[[ViEventManager defaultManager] emit:ViEventDidAddView for:viewController with:viewController, nil];
	if ([viewController respondsToSelector:@selector(document)])
		[[viewController document] addView:viewController];
}

- (void)removeView:(id<ViViewController>)viewController
{
	if ([viewController respondsToSelector:@selector(document)])
		[[viewController document] removeView:viewController];
	[views removeObject:viewController];
	[[ViEventManager defaultManager] emit:ViEventDidCloseView for:viewController with:viewController, nil];
	[[ViEventManager defaultManager] clearFor:viewController];
	if (viewController == previousView)
		previousView = nil;
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

- (void)normalizeSplitView:(NSSplitView *)split
{
	NSUInteger n = [[split subviews] count];
	CGFloat sz;

	if ([split isVertical])
		sz = [split bounds].size.width;
	else
		sz = [split bounds].size.height;

	sz -= [split dividerThickness] * (n - 1);
	sz /= n;

	int i;
	CGFloat pos = sz;
	for (i = 1; i < n; i++, pos += sz + [split dividerThickness])
		[split setPosition:pos ofDividerAtIndex:i - 1];
}

- (id<ViViewController>)splitView:(id<ViViewController>)viewController
                         withView:(id<ViViewController>)newViewController
                       vertically:(BOOL)isVertical
{
	NSView *view = [viewController view];

	NSSplitView *split = (NSSplitView *)[view superview];
	if (![split isKindOfClass:[NSSplitView class]]) {
		INFO(@"***** superview not an NSSplitView!? %@", split);
		return nil;
	}

	DEBUG(@"adding view %@ = %@", [newViewController view], newViewController);
	DEBUG(@"subviews = %@", [split subviews]);

	if ([[split subviews] count] == 1 && [split isVertical] != isVertical) {
		[split setVertical:isVertical];
		[splitView adjustSubviews];
	}

	[self addView:newViewController];

	DEBUG(@"subviews = %@", [split subviews]);
	if ([split isVertical] == isVertical) {
		// Just add another view to this split
		[split addSubview:[newViewController view] positioned:NSWindowBelow relativeTo:view];
		[split adjustSubviews];
		[self normalizeSplitView:split];
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
		[newSplit addSubview:[newViewController view] positioned:NSWindowBelow relativeTo:view];
		[newSplit adjustSubviews];
		[self normalizeSplitView:newSplit];
		DEBUG(@"newSplit subviews = %@", [newSplit subviews]);
	}

	DEBUG(@"subviews = %@", [split subviews]);
	return newViewController;
}

- (id<ViViewController>)splitView:(id<ViViewController>)viewController
                       vertically:(BOOL)isVertical
{
	if (![viewController respondsToSelector:@selector(document)])
		return nil;

	id<ViViewController> newView = [[viewController document] cloneView:viewController];
	if (![self splitView:viewController withView:newView vertically:isVertical])
		return nil;

	return newView;
}

- (id<ViViewController>)replaceView:(id<ViViewController>)viewController
                       withDocument:(id<ViViewDocument>)document
{
	id<ViViewController> newViewController = [document makeView];

	[self addView:newViewController];
	[self removeView:viewController];

	if (selectedView == viewController) {
		[self willChangeValueForKey:@"selectedView"];
		selectedView = newViewController;
		[self didChangeValueForKey:@"selectedView"];
	}

	DEBUG(@"replace view %@ with view %@ = %@", [viewController view], [newViewController view], newViewController);

	/*
	 * Remember all subview sizes so we can restore the position
	 * of the dividers after replacing the view.
	 */
	NSSplitView *split = (NSSplitView *)[[viewController view] superview];
	DEBUG(@"subviews = %@", [split subviews]);
	NSUInteger c = [[split subviews] count];
	NSMutableArray *sizes = [NSMutableArray arrayWithCapacity:c];
	for (NSView *view in [split subviews]) {
		if ([split isVertical])
			[sizes addObject:[NSNumber numberWithFloat:[view bounds].size.width]];
		else
			[sizes addObject:[NSNumber numberWithFloat:[view bounds].size.height]];
	}

	[split replaceSubview:[viewController view] with:[newViewController view]];
	DEBUG(@"subviews = %@", [split subviews]);

	/*
	 * Now restore the divider positions.
	 */
	CGFloat pos = 0;
	int i = 0;
	for (NSNumber *size in sizes) {
		if (i + 1 == c)
			break;
		pos += [size floatValue];
		[split setPosition:pos ofDividerAtIndex:i++];
		pos += [split dividerThickness];
	}
	[splitView adjustSubviews];

	return newViewController;
}

- (void)closeView:(id<ViViewController>)viewController
{
	[self removeView:viewController];

	DEBUG(@"close view %@ = %@", [viewController view], viewController);

	id split = [[viewController view] superview];
	DEBUG(@"subviews = %@", [split subviews]);
	NSUInteger ndx = [[split subviews] indexOfObject:[viewController view]];
	[[viewController view] removeFromSuperview];
	DEBUG(@"subviews = %@", [split subviews]);

	if ([[split subviews] count] == 1) {
		id superSplit = [split superview];
		if ([superSplit isMemberOfClass:[NSSplitView class]]) {
			id newSplit = [[split subviews] objectAtIndex:0];
			[superSplit replaceSubview:split with:newSplit];
			split = newSplit;
		}
	}

	if ([split isMemberOfClass:[NSSplitView class]]) {
		[split adjustSubviews];
		[self normalizeSplitView:split];
	}

	if (selectedView == viewController) {
		if ([split isMemberOfClass:[NSSplitView class]]) {
			NSUInteger c = [[split subviews] count];
			if (c > 0) {
				if (ndx >= c)
					ndx = c - 1;
				NSView *view = [[split subviews] objectAtIndex:ndx];
				while ([view isKindOfClass:[NSSplitView class]])
					view = [[(NSSplitView *)view subviews] objectAtIndex:0];
				[self setSelectedView:[self viewControllerForView:view]];
			} else
				[self setSelectedView:nil];
		} else
			[self setSelectedView:[self viewControllerForView:split]];
	}
}

- (void)closeViewsOtherThan:(id<ViViewController>)viewController
{
	BOOL closed = YES;

	while (closed) {
		closed = NO;
		for (id<ViViewController> otherView in views) {
			if (otherView != viewController) {
				[self closeView:otherView];
				closed = YES;
				break;
			}
		}
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

- (NSSplitView *)containingSplitViewRelativeTo:(NSView *)view
                                    isVertical:(BOOL)isVertical
                                         index:(NSInteger *)indexPtr
{
	NSView *sup;
	while (view != nil && ![view isMemberOfClass:[NSTabView class]]) {
		sup = [view superview];
		if ([sup isMemberOfClass:[NSSplitView class]] &&
		    [(NSSplitView *)sup isVertical] == isVertical) {
			if (indexPtr != NULL)
				*indexPtr = [[sup subviews] indexOfObject:view];
			return (NSSplitView *)sup;
		}
		view = sup;
	}
	return nil;
}

- (NSSplitView *)containingSplitViewRelativeTo:(NSView *)view
                                         index:(NSInteger *)indexPtr
{
	NSView *sup;
	while (view != nil && ![view isMemberOfClass:[NSTabView class]]) {
		sup = [view superview];
		DEBUG(@"%@ -> %@", view, sup);
		if ([sup isMemberOfClass:[NSSplitView class]]) {
			if (indexPtr != NULL)
				*indexPtr = [[sup subviews] indexOfObject:view];
			return (NSSplitView *)sup;
		}
		view = sup;
	}
	return nil;
}

- (NSView *)containedViewRelativeToView:(NSView *)view
                                 anchor:(ViViewOrderingMode)anchor
{
	if ([view isMemberOfClass:[NSSplitView class]]) {
		if (anchor == ViViewLast ||
		    (anchor == ViViewUp && ![(NSSplitView *)view isVertical]) ||
		    (anchor == ViViewLeft && [(NSSplitView *)view isVertical]))
			view = [[view subviews] lastObject];
		else
			view = [[view subviews] objectAtIndex:0];
		return [self containedViewRelativeToView:view anchor:anchor];
	} else
		return view;
}

- (id<ViViewController>)viewAtPosition:(ViViewOrderingMode)position
                            relativeTo:(NSView *)view
{
	if (view == nil)
		return nil;

	BOOL isVertical = (position == ViViewLeft || position == ViViewRight);

	NSInteger ndx;
	NSSplitView *split = [self containingSplitViewRelativeTo:view
	                                              isVertical:isVertical
	                                                   index:&ndx];
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

- (id<ViViewController>)nextViewClockwise:(BOOL)clockwise
			       relativeTo:(NSView *)view
{
	DEBUG(@"view = %@", view);
	NSInteger ndx;
	NSSplitView *split = [self containingSplitViewRelativeTo:view index:&ndx];
	if (split == nil) {
		DEBUG(@"%s", "no containing split view");
		return nil;
	}

	NSInteger newIndex = ndx;
	if (clockwise)
		newIndex++;
	else
		newIndex--;

	ViViewOrderingMode anchor = (clockwise ? ViViewRight : ViViewLast);

	NSArray *subviews = [split subviews];
	if (newIndex >= 0 && newIndex < [subviews count]) {
		view = [subviews objectAtIndex:newIndex];
		return [self viewControllerForView:[self containedViewRelativeToView:view anchor:anchor]];
	} else {
		id<ViViewController> nextView = [self nextViewClockwise:clockwise relativeTo:split];
		if (nextView)
			return nextView;

		if (clockwise)
			view = [subviews objectAtIndex:0];
		else
			view = [subviews lastObject];
		return [self viewControllerForView:[self containedViewRelativeToView:view anchor:anchor]];
	}
}

- (void)normalizeViewsRecursively:(id)split
{
	if (![split isKindOfClass:[NSSplitView class]])
		return;

	[self normalizeSplitView:split];
	for (NSView *view in [split subviews])
		[self normalizeViewsRecursively:view];
}

- (void)normalizeAllViews
{
	[self normalizeViewsRecursively:splitView];
}

@end

