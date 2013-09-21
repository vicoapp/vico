//
//  PSMTabBarControl.m
//  PSMTabBarControl
//
//  Created by John Pannell on 10/13/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import "PSMTabBarControl.h"
#import "PSMTabBarCell.h"
#import "PSMOverflowPopUpButton.h"
#import "PSMRolloverButton.h"
#import "PSMTabStyle.h"
#import "PSMMetalTabStyle.h"
#import "PSMTabDragAssistant.h"
#import "ViTabController.h"
#include "logging.h"

@interface PSMTabBarControl (Private)
// characteristics
- (float)availableCellWidth;
- (NSRect)genericCellRect;

    // constructor/destructor
- (void)initAddedProperties;

    // accessors
- (NSEvent *)lastMouseDownEvent;
- (void)setLastMouseDownEvent:(NSEvent *)event;

    // contents
- (void)addTabViewItem:(NSTabViewItem *)item;
- (void)removeTabForCell:(PSMTabBarCell *)cell;

    // draw
- (void)update;

    // actions
- (void)overflowMenuAction:(id)sender;
- (void)closeTabClick:(id)sender;
- (void)tabClick:(id)sender;
- (void)tabNothing:(id)sender;
- (void)frameDidChange:(NSNotification *)notification;
- (void)windowDidMove:(NSNotification *)aNotification;
- (void)windowStatusDidChange:(NSNotification *)notification;

    // NSTabView delegate
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem;
- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)tabView;

    // convenience
- (id)cellForPoint:(NSPoint)point cellFrame:(NSRectPointer)outFrame;
- (PSMTabBarCell *)lastVisibleTab;
- (int)numberOfVisibleTabs;

- (void)animateShowHide:(NSTimer *)timer;

@end

@implementation PSMTabBarControl

@synthesize tabView;
@synthesize delegate;
@synthesize partnerView;

#pragma mark -
#pragma mark Characteristics

+ (NSBundle *)bundle
{
    static NSBundle *__bundle = nil;
    if (!__bundle)
	    __bundle = [NSBundle bundleForClass:[PSMTabBarControl class]];
    return __bundle;
}

- (float)availableCellWidth
{
    float width = [self frame].size.width;
    width = width - [style leftMarginForTabBarControl] - [style rightMarginForTabBarControl];
    return width;
}

- (NSRect)genericCellRect
{
    NSRect aRect=[self frame];
    aRect.origin.x = [style leftMarginForTabBarControl];
    aRect.origin.y = 0.0;
    aRect.size.width = [self availableCellWidth];
    aRect.size.height = kPSMTabBarControlHeight;
    return aRect;
}

#pragma mark -
#pragma mark Constructor/destructor

- (void)initAddedProperties
{
	_cells = [[NSMutableArray alloc] initWithCapacity:10];

	// default config
	_allowsDragBetweenWindows = YES;
	_canCloseOnlyTab = NO;
	_showAddTabButton = NO;
	_hideForSingleTab = NO;
	_sizeCellsToFit = NO;
	_isHidden = NO;
	_hideIndicators = NO;
	_awakenedFromNib = NO;
	_cellMinWidth = 100;
	_cellMaxWidth = 280;
	_cellOptimumWidth = 130;
	style = [[PSMMetalTabStyle alloc] init];
	_animate = NO;

	// the overflow button/menu
	NSRect overflowButtonRect = NSMakeRect([self frame].size.width - [style rightMarginForTabBarControl] + 1, 0, [style rightMarginForTabBarControl] - 1, [self frame].size.height);
	_overflowPopUpButton = [[PSMOverflowPopUpButton alloc] initWithFrame:overflowButtonRect pullsDown:YES];
	if(_overflowPopUpButton){
		// configure
		[_overflowPopUpButton setAutoresizingMask:NSViewNotSizable|NSViewMinXMargin];
	}

	// new tab button
	NSRect addTabButtonRect = NSMakeRect([self frame].size.width - [style rightMarginForTabBarControl] + 1, 3.0, 16.0, 16.0);
	_addTabButton = [[PSMRolloverButton alloc] initWithFrame:addTabButtonRect];
	if(_addTabButton){
		NSImage *newButtonImage = [style addTabButtonImage];
		if(newButtonImage)
			[_addTabButton setUsualImage:newButtonImage];
		newButtonImage = [style addTabButtonPressedImage];
		if(newButtonImage)
			[_addTabButton setAlternateImage:newButtonImage];
		newButtonImage = [style addTabButtonRolloverImage];
		if(newButtonImage)
			[_addTabButton setRolloverImage:newButtonImage];
		[_addTabButton setTitle:@""];
		[_addTabButton setImagePosition:NSImageOnly];
		[_addTabButton setButtonType:NSMomentaryChangeButton];
		[_addTabButton setBordered:NO];
		[_addTabButton setBezelStyle:NSShadowlessSquareBezelStyle];
		if(_showAddTabButton){
			[_addTabButton setHidden:NO];
		} else {
			[_addTabButton setHidden:YES];
		}
		[_addTabButton setNeedsDisplay:YES];
	}
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization
        [self initAddedProperties];
        [self registerForDraggedTypes:[NSArray arrayWithObjects: @"PSMTabBarControlItemPBType", nil]];
    }
    [self setTarget:self];
    DEBUG_INIT();
    return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	for (PSMTabBarCell *cell in _cells)
		[self removeTabForCell:cell];
}

- (void)awakeFromNib
{
    // build cells from existing tab view items
    for (NSTabViewItem *item in [tabView tabViewItems])
        if(![[self representedTabViewItems] containsObject:item])
            [self addTabViewItem:item];

    // resize
    [self setPostsFrameChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameDidChange:) name:NSViewFrameDidChangeNotification object:self];

    // window status
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowStatusDidChange:) name:NSWindowDidBecomeKeyNotification object:[self window]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowStatusDidChange:) name:NSWindowDidResignKeyNotification object:[self window]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidMove:) name:NSWindowDidMoveNotification object:[self window]];
}


#pragma mark -
#pragma mark Accessors

- (NSMutableArray *)cells
{
    return _cells;
}

- (NSEvent *)lastMouseDownEvent
{
    return _lastMouseDownEvent;
}

- (void)setLastMouseDownEvent:(NSEvent *)event
{
	_lastMouseDownEvent = event;
}

- (id<PSMTabStyle>)style
{
    return style;
}

- (NSString *)styleName
{
    return [style name];
}

- (void)setStyleNamed:(NSString *)name
{
	style = [[PSMMetalTabStyle alloc] init];

	// restyle add tab button
	if(_addTabButton){
		NSImage *newButtonImage = [style addTabButtonImage];
		if(newButtonImage)
			[_addTabButton setUsualImage:newButtonImage];
		newButtonImage = [style addTabButtonPressedImage];
		if(newButtonImage)
			[_addTabButton setAlternateImage:newButtonImage];
		newButtonImage = [style addTabButtonRolloverImage];
		if(newButtonImage)
			[_addTabButton setRolloverImage:newButtonImage];
	}

	[self update];
}

- (BOOL)canCloseOnlyTab
{
    return _canCloseOnlyTab;
}

- (void)setCanCloseOnlyTab:(BOOL)value
{
    _canCloseOnlyTab = value;
    if ([_cells count] == 1) {
        [self update];
    }
}

- (BOOL)allowsDragBetweenWindows
{
	return _allowsDragBetweenWindows;
}

- (void)setAllowsDragBetweenWindows:(BOOL)flag
{
	_allowsDragBetweenWindows = flag;
}

- (BOOL)hideForSingleTab
{
    return _hideForSingleTab;
}

- (void)setHideForSingleTab:(BOOL)value
{
    _hideForSingleTab = value;
    [self update];
}

- (BOOL)showAddTabButton
{
    return _showAddTabButton;
}

- (void)setShowAddTabButton:(BOOL)value
{
    _showAddTabButton = value;
    [self update];
}

- (int)cellMinWidth
{
    return _cellMinWidth;
}

- (void)setCellMinWidth:(int)value
{
    _cellMinWidth = value;
    [self update];
}

- (int)cellMaxWidth
{
    return _cellMaxWidth;
}

- (void)setCellMaxWidth:(int)value
{
    _cellMaxWidth = value;
    [self update];
}

- (int)cellOptimumWidth
{
    return _cellOptimumWidth;
}

- (void)setCellOptimumWidth:(int)value
{
    _cellOptimumWidth = value;
    [self update];
}

- (BOOL)sizeCellsToFit
{
    return _sizeCellsToFit;
}

- (void)setSizeCellsToFit:(BOOL)value
{
    _sizeCellsToFit = value;
    [self update];
}

- (PSMRolloverButton *)addTabButton
{
    return _addTabButton;
}

- (PSMOverflowPopUpButton *)overflowPopUpButton
{
    return _overflowPopUpButton;
}

#pragma mark -
#pragma mark Functionality

- (void)addTabViewItem:(NSTabViewItem *)item
{
	// create cell
	PSMTabBarCell *cell = [[PSMTabBarCell alloc] initWithControlView:self];
	[cell setRepresentedObject:item];

	// bind the indicator to the represented object's status (if it exists)
	[[cell indicator] setHidden:NO];
	ViTabController *tabController = [item identifier];
	if (tabController != nil) {
		NSMutableDictionary *bindingOptions = [NSMutableDictionary dictionary];
		[bindingOptions setObject:NSNegateBooleanTransformerName forKey:@"NSValueTransformerName"];
		[[cell indicator] bind:@"animate" toObject:tabController withKeyPath:@"selectedView.processing" options:nil];
		[[cell indicator] bind:@"hidden" toObject:tabController withKeyPath:@"selectedView.processing" options:bindingOptions];
		[tabController addObserver:self forKeyPath:@"selectedView.processing" options:0 context:nil];

#if 0
		// bind for the existence of an icon
		[cell setHasIcon:NO];
		NSMutableDictionary *bindingOptions = [NSMutableDictionary dictionary];
		[bindingOptions setObject:NSIsNotNilTransformerName forKey:@"NSValueTransformerName"];
		[cell bind:@"hasIcon" toObject:tabController withKeyPath:@"selectedView.icon" options:bindingOptions];
		[tabController addObserver:self forKeyPath:@"selectedView.icon" options:0 context:nil];

		// bind for the existence of a counter
		[cell setCount:0];
		[cell bind:@"count" toObject:tabController withKeyPath:@"selection.objectCount" options:nil];
		[tabController addObserver:self forKeyPath:@"selection.objectCount" options:0 context:nil];
#endif

		// bind for modified state
		[cell setModified:NO];
		[cell bind:@"modified" toObject:tabController withKeyPath:@"selectedView.modified" options:nil];
		[tabController addObserver:self forKeyPath:@"selectedView.modified" options:0 context:nil];
	}

	// bind my string value to the label on the represented tab
	[cell bind:@"title" toObject:item withKeyPath:@"label" options:nil];

	// add to collection
	[_cells addObject:cell];
	if([_cells count] == [tabView numberOfTabViewItems]){
		[self update]; // don't update unless all are accounted for!
	}
}

- (void)removeTabForCell:(PSMTabBarCell *)cell
{
	DEBUG(@"remove cell %@", cell);

	// unbind
	[[cell indicator] unbind:@"animate"];
	[[cell indicator] unbind:@"hidden"];
	[cell unbind:@"hasIcon"];
	[cell unbind:@"title"];
	[cell unbind:@"count"];
	[cell unbind:@"modified"];

	[[(NSTabViewItem *)[cell representedObject] identifier] removeObserver:self forKeyPath:@"selectedView.modified"];
	[[(NSTabViewItem *)[cell representedObject] identifier] removeObserver:self forKeyPath:@"selectedView.processing"];

	// remove indicator
	if ([[self subviews] containsObject:[cell indicator]])
		[[cell indicator] removeFromSuperview];

	// remove tracking
	[[NSNotificationCenter defaultCenter] removeObserver:cell];
	if ([cell closeButtonTrackingTag] != 0)
		[self removeTrackingRect:[cell closeButtonTrackingTag]];

	if ([cell cellTrackingTag] != 0)
		[self removeTrackingRect:[cell cellTrackingTag]];

	// pull from collection
	[_cells removeObject:cell];

	[self update];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// the progress indicator, label, icon, count or modified state has changed - must redraw
	[self update];
}

#pragma mark -
#pragma mark Hide/Show

- (void)hideTabBar:(BOOL)hide animate:(BOOL)animate
{
    if(!_awakenedFromNib)
        return;
    if(_isHidden && hide)
        return;
    if(!_isHidden && !hide)
        return;

    [[[self subviews] copy] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    _hideIndicators = YES;

    _isHidden = hide;
    _currentStep = 0;
    if (!animate)
        _currentStep = (int)kPSMHideAnimationSteps;

    float partnerOriginalHeight, partnerOriginalY, myOriginalHeight, myOriginalY, partnerTargetHeight, partnerTargetY, myTargetHeight, myTargetY;

    // current (original) values
    myOriginalHeight = [self frame].size.height;
    myOriginalY = [self frame].origin.y;
    if(partnerView){
        partnerOriginalHeight = [partnerView frame].size.height;
        partnerOriginalY = [partnerView frame].origin.y;
    } else {
        partnerOriginalHeight = [[self window] frame].size.height;
        partnerOriginalY = [[self window] frame].origin.y;
    }

    // target values for partner
    if(partnerView){
            if(_isHidden){
                // I'm shrinking
                myTargetY = myOriginalY + 21;
                myTargetHeight = myOriginalHeight - 21;
                partnerTargetY = partnerOriginalY;
                partnerTargetHeight = partnerOriginalHeight + 21;
            } else {
                // I'm growing
                myTargetY = myOriginalY - 21;
                myTargetHeight = myOriginalHeight + 21;
                partnerTargetY = partnerOriginalY;
                partnerTargetHeight = partnerOriginalHeight - 21;
            }
    } else {
        // for window movement
        if(_isHidden){
            // I'm shrinking
            myTargetY = myOriginalY;
            myTargetHeight = myOriginalHeight - 21;
            partnerTargetY = partnerOriginalY + 21;
            partnerTargetHeight = partnerOriginalHeight - 21;
        } else {
            // I'm growing
            myTargetY = myOriginalY;
            myTargetHeight = myOriginalHeight + 21;
            partnerTargetY = partnerOriginalY - 21;
            partnerTargetHeight = partnerOriginalHeight + 21;
        }
    }

#ifndef NO_DEBUG
    NSRect frame = [self frame];
    frame.origin.y = myTargetY;
    frame.size.height = myTargetHeight;
    DEBUG(@"my frame: %@ -> %@", NSStringFromRect([self frame]), NSStringFromRect(frame));
    frame = [partnerView frame];
    frame.origin.y = partnerTargetY;
    frame.size.height = partnerTargetHeight;
    //DEBUG(@"partner frame: %@ -> %@", NSStringFromRect([partnerView frame]), NSStringFromRect(frame));
#endif

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:myOriginalY], @"myOriginalY", [NSNumber numberWithFloat:partnerOriginalY], @"partnerOriginalY", [NSNumber numberWithFloat:myOriginalHeight], @"myOriginalHeight", [NSNumber numberWithFloat:partnerOriginalHeight], @"partnerOriginalHeight", [NSNumber numberWithFloat:myTargetY], @"myTargetY", [NSNumber numberWithFloat:partnerTargetY], @"partnerTargetY", [NSNumber numberWithFloat:myTargetHeight], @"myTargetHeight", [NSNumber numberWithFloat:partnerTargetHeight], @"partnerTargetHeight", nil];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:(1.0/20.0) target:self selector:@selector(animateShowHide:) userInfo:userInfo repeats:YES];
    if (!animate) {
	    [self animateShowHide:timer];
	    [timer invalidate];
    }
}

- (void)animateShowHide:(NSTimer *)timer
{
    // moves the frame of the tab bar and window (or partner view) linearly to hide or show the tab bar
    NSRect myFrame = [self frame];
    float myCurrentY = ([[[timer userInfo] objectForKey:@"myOriginalY"] floatValue] + (([[[timer userInfo] objectForKey:@"myTargetY"] floatValue] - [[[timer userInfo] objectForKey:@"myOriginalY"] floatValue]) * (_currentStep/kPSMHideAnimationSteps)));
    float myCurrentHeight = ([[[timer userInfo] objectForKey:@"myOriginalHeight"] floatValue] + (([[[timer userInfo] objectForKey:@"myTargetHeight"] floatValue] - [[[timer userInfo] objectForKey:@"myOriginalHeight"] floatValue]) * (_currentStep/kPSMHideAnimationSteps)));
    float partnerCurrentY = ([[[timer userInfo] objectForKey:@"partnerOriginalY"] floatValue] + (([[[timer userInfo] objectForKey:@"partnerTargetY"] floatValue] - [[[timer userInfo] objectForKey:@"partnerOriginalY"] floatValue]) * (_currentStep/kPSMHideAnimationSteps)));
    float partnerCurrentHeight = ([[[timer userInfo] objectForKey:@"partnerOriginalHeight"] floatValue] + (([[[timer userInfo] objectForKey:@"partnerTargetHeight"] floatValue] - [[[timer userInfo] objectForKey:@"partnerOriginalHeight"] floatValue]) * (_currentStep/kPSMHideAnimationSteps)));

    NSRect myNewFrame = NSMakeRect(myFrame.origin.x, myCurrentY, myFrame.size.width, myCurrentHeight);

    if(partnerView){
        // resize self and view
        [partnerView setFrame:NSMakeRect([partnerView frame].origin.x, partnerCurrentY, [partnerView frame].size.width, partnerCurrentHeight)];
        [partnerView setNeedsDisplay:YES];
	DEBUG(@"my frame: %@ -> %@", NSStringFromRect(myFrame), NSStringFromRect(myNewFrame));
        [self setFrame:myNewFrame];
    } else {
        // resize self and window
        [[self window] setFrame:NSMakeRect([[self window] frame].origin.x, partnerCurrentY, [[self window] frame].size.width, partnerCurrentHeight) display:YES];
        [self setFrame:myNewFrame];
    }

    // next
    _currentStep++;
    if(_currentStep == kPSMHideAnimationSteps + 1){
        [timer invalidate];
        [self viewDidEndLiveResize];
        _hideIndicators = NO;
        [self update];
    }
    [[self window] display];
}

- (void)disableAnimations
{
	_animate = NO;
}

- (void)enableAnimations
{
	// _animate = YES;
}

#pragma mark -
#pragma mark Drawing

- (BOOL)isFlipped
{
    return YES;
}

- (void)drawRect:(NSRect)rect
{
    [style drawTabBar:self inRect:rect];
}

- (void)update
{
    // abandon hope, all ye who enter here :-)
    // this method handles all of the cell layout, and is called when something changes to require the refresh.  This method is not called during drag and drop; see the PSMTabDragAssistant's calculateDragAnimationForTabBar: method, which does layout in that case.

    // make sure all of our tabs are accounted for before updating
    if ([tabView numberOfTabViewItems] != [_cells count]) {
        return;
    }

    // hide/show? (these return if already in desired state)
    if (_animate || 1) {
        if((_hideForSingleTab) && ([_cells count] <= 1)){
            [self hideTabBar:YES animate:_animate];
        } else {
            [self hideTabBar:NO animate:_animate];
        }
    }

    // size all cells appropriately and create tracking rects
    // nuke old tracking rects
    int i, cellCount = (int)[_cells count];
    for(i = 0; i < cellCount; i++){
        id cell = [_cells objectAtIndex:i];
        [[NSNotificationCenter defaultCenter] removeObserver:cell];
        if([cell closeButtonTrackingTag] != 0){
            [self removeTrackingRect:[cell closeButtonTrackingTag]];
        }
        if([cell cellTrackingTag] != 0){
            [self removeTrackingRect:[cell cellTrackingTag]];
        }
    }

    // calculate number of cells to fit in control and cell widths
    float availableWidth = [self availableCellWidth];
    NSMutableArray *newWidths = [NSMutableArray arrayWithCapacity:cellCount];
    int numberOfVisibleCells = 1;
    float totalOccupiedWidth = 0.0;
    NSMenu *overflowMenu = nil;
    for(i = 0; i < cellCount; i++){
        PSMTabBarCell *cell = [_cells objectAtIndex:i];
        float width;

        // supress close button?
        if (cellCount == 1 && [self canCloseOnlyTab] == NO) {
            [cell setCloseButtonSuppressed:YES];
        } else {
            [cell setCloseButtonSuppressed:NO];
        }

        // Determine cell width
        if(_sizeCellsToFit){
            width = [cell desiredWidthOfCell];
            if (width > _cellMaxWidth) {
                width = _cellMaxWidth;
            }
        } else {
            width = _cellOptimumWidth;
        }

        // too much?
        totalOccupiedWidth += width;
        if (totalOccupiedWidth >= availableWidth) {
            numberOfVisibleCells = i;
            if(_sizeCellsToFit){
                int neededWidth = width - (totalOccupiedWidth - availableWidth);
                // can I squeeze it in without violating min cell width?
                int widthIfAllMin = (numberOfVisibleCells + 1) * _cellMinWidth;

                if ((width + widthIfAllMin) <= availableWidth) {
                    // squeeze - distribute needed sacrifice among all cells
                    int q;
                    for(q = (i - 1); q >= 0; q--){
                        int desiredReduction = (int)neededWidth/(q+1);
                        if(([[newWidths objectAtIndex:q] floatValue] - desiredReduction) < _cellMinWidth){
                            int actualReduction = (int)[[newWidths objectAtIndex:q] floatValue] - _cellMinWidth;
                            [newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithFloat:_cellMinWidth]];
                            neededWidth -= actualReduction;
                        } else {
                            int newCellWidth = (int)[[newWidths objectAtIndex:q] floatValue] - desiredReduction;
                            [newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithFloat:newCellWidth]];
                            neededWidth -= desiredReduction;
                        }
                    }
                    // one cell left!
                    int thisWidth = width - neededWidth;
                    [newWidths addObject:[NSNumber numberWithFloat:thisWidth]];
                    numberOfVisibleCells++;
                } else {
                    // stretch - distribute leftover room among cells
                    int leftoverWidth = availableWidth - totalOccupiedWidth + width;
                    int q;
                    for(q = (i - 1); q >= 0; q--){
                        int desiredAddition = (int)leftoverWidth/(q+1);
                        int newCellWidth = (int)[[newWidths objectAtIndex:q] floatValue] + desiredAddition;
                        [newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithFloat:newCellWidth]];
                        leftoverWidth -= desiredAddition;
                    }
                }
                break; // done assigning widths; remaining cells go in overflow menu
            } else {
                int revisedWidth = availableWidth/(i + 1);
                if(revisedWidth >= _cellMinWidth){
                    int q;
                    totalOccupiedWidth = 0;
                    for(q = 0; q < [newWidths count]; q++){
                        [newWidths replaceObjectAtIndex:q withObject:[NSNumber numberWithFloat:revisedWidth]];
                        totalOccupiedWidth += revisedWidth;
                    }
                    // just squeezed this one in...
                    [newWidths addObject:[NSNumber numberWithFloat:revisedWidth]];
                    totalOccupiedWidth += revisedWidth;
                    numberOfVisibleCells++;
                } else {
                    // couldn't fit that last one...
                    break;
                }
            }
        } else {
            numberOfVisibleCells = cellCount;
            [newWidths addObject:[NSNumber numberWithFloat:width]];
        }
    }

    // Set up cells with frames and rects
    NSRect cellRect = [self genericCellRect];
    for(i = 0; i < cellCount; i++){
        PSMTabBarCell *cell = [_cells objectAtIndex:i];
        int tabState = 0;
        if (i < numberOfVisibleCells) {
            // set cell frame
            cellRect.size.width = [[newWidths objectAtIndex:i] floatValue];
            [cell setFrame:cellRect];
            NSTrackingRectTag tag;

            // close button tracking rect
            if ([cell hasCloseButton]) {
                tag = [self addTrackingRect:[cell closeButtonRectForFrame:cellRect] owner:cell userData:nil assumeInside:NO];
                [cell setCloseButtonTrackingTag:tag];
            }

            // entire tab tracking rect
            tag = [self addTrackingRect:cellRect owner:cell userData:nil assumeInside:NO];
            [cell setCellTrackingTag:tag];
            [cell setEnabled:YES];

            // selected? set tab states...
            if([[cell representedObject] isEqualTo:[tabView selectedTabViewItem]]){
                [cell setState:NSOnState];
                tabState |= PSMTab_SelectedMask;
                // previous cell
                if(i > 0){
                    [[_cells objectAtIndex:i-1] setTabState:([(PSMTabBarCell *)[_cells objectAtIndex:i-1] tabState] | PSMTab_RightIsSelectedMask)];
                }
                // next cell - see below
            } else {
                [cell setState:NSOffState];
                // see if prev cell was selected
                if(i > 0){
                    if([[_cells objectAtIndex:i-1] state] == NSOnState){
                        tabState |= PSMTab_LeftIsSelectedMask;
                    }
                }
            }
            // more tab states
            if(cellCount == 1){
                tabState |= PSMTab_PositionLeftMask | PSMTab_PositionRightMask | PSMTab_PositionSingleMask;
            } else if(i == 0){
                tabState |= PSMTab_PositionLeftMask;
            } else if(i-1 == cellCount){
                tabState |= PSMTab_PositionRightMask;
            }
            [cell setTabState:tabState];
            [cell setIsInOverflowMenu:NO];

            // indicator
            if(![[cell indicator] isHidden] && !_hideIndicators && !_isHidden){
                [[cell indicator] setFrame:[cell indicatorRectForFrame:cellRect]];
                if(![[self subviews] containsObject:[cell indicator]]){
                    [self addSubview:[cell indicator]];
                    [[cell indicator] startAnimation:self];
                }
            }

            // next...
            cellRect.origin.x += [[newWidths objectAtIndex:i] floatValue];

        } else {
            // set up menu items
            NSMenuItem *menuItem;
            if(overflowMenu == nil){
                overflowMenu = [[NSMenu alloc] initWithTitle:@"TITLE"];
                [overflowMenu insertItemWithTitle:@"FIRST" action:nil keyEquivalent:@"" atIndex:0]; // Because the overflowPupUpButton is a pull down menu
            }
            menuItem = [[NSMenuItem alloc] initWithTitle:[[cell attributedStringValue] string] action:@selector(overflowMenuAction:) keyEquivalent:@""];
            [menuItem setTarget:self];
            [menuItem setRepresentedObject:[cell representedObject]];
            [cell setIsInOverflowMenu:YES];
            [[cell indicator] removeFromSuperview];
            if ([(NSTabViewItem *)[cell representedObject] isEqualTo:[tabView selectedTabViewItem]])
                [menuItem setState:NSOnState];
            if([cell hasIcon])
                [menuItem setImage:[[[(NSTabViewItem *)[cell representedObject] identifier] content] icon]];
            if([cell count] > 0)
                [menuItem setTitle:[[menuItem title] stringByAppendingFormat:@" (%d)",[cell count]]];
            [overflowMenu addItem:menuItem];
        }
    }

    // Overflow menu
    cellRect.origin.y = 0;
    cellRect.size.height = kPSMTabBarControlHeight;
    cellRect.size.width = [style rightMarginForTabBarControl];
    if (overflowMenu) {
        cellRect.origin.x = [self frame].size.width - [style rightMarginForTabBarControl] + 1;
        if(![[self subviews] containsObject:_overflowPopUpButton]){
            [self addSubview:_overflowPopUpButton];
        }
        [_overflowPopUpButton setFrame:cellRect];
        [_overflowPopUpButton setMenu:overflowMenu];
        if ([_overflowPopUpButton isHidden]) [_overflowPopUpButton setHidden:NO];
    } else {
        if (![_overflowPopUpButton isHidden]) [_overflowPopUpButton setHidden:YES];
    }

    // add tab button
    if(!overflowMenu && _showAddTabButton){
        if(![[self subviews] containsObject:_addTabButton])
            [self addSubview:_addTabButton];
        if([_addTabButton isHidden] && _showAddTabButton)
            [_addTabButton setHidden:NO];
        cellRect.size = [_addTabButton frame].size;
        cellRect.origin.y = MARGIN_Y;
        cellRect.origin.x += 2;
        [_addTabButton setImage:[style addTabButtonImage]];
        [_addTabButton setFrame:cellRect];
        [_addTabButton setNeedsDisplay:YES];
    } else {
        [_addTabButton setHidden:YES];
        [_addTabButton setNeedsDisplay:YES];
    }

    [self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Mouse Tracking

- (BOOL)mouseDownCanMoveWindow
{
    return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    // keep for dragging
    [self setLastMouseDownEvent:theEvent];
    // what cell?
    NSPoint mousePt = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSRect cellFrame;
    PSMTabBarCell *cell = [self cellForPoint:mousePt cellFrame:&cellFrame];
    if(cell){
        NSRect iconRect = [cell closeButtonRectForFrame:cellFrame];
        if(NSMouseInRect(mousePt, iconRect,[self isFlipped])){
            [cell setCloseButtonPressed:YES];
        } else {
            [cell setCloseButtonPressed:NO];
        }
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    if([self lastMouseDownEvent] == nil){
        return;
    }

    if ([_cells count] < 2) {
        return;
    }

    NSRect cellFrame;
    NSPoint trackingStartPoint = [self convertPoint:[[self lastMouseDownEvent] locationInWindow] fromView:nil];
    PSMTabBarCell *cell = [self cellForPoint:trackingStartPoint cellFrame:&cellFrame];
    if (!cell)
        return;

    NSPoint currentPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    float dx = fabs(currentPoint.x - trackingStartPoint.x);
    float dy = fabs(currentPoint.y - trackingStartPoint.y);
    float distance = sqrt(dx * dx + dy * dy);
    if (distance < 10)
        return;

    if(![[PSMTabDragAssistant sharedDragAssistant] isDragging])
        [[PSMTabDragAssistant sharedDragAssistant] startDraggingCell:cell fromTabBar:self withMouseDownEvent:[self lastMouseDownEvent]];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    // what cell?
    NSPoint mousePt = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSRect cellFrame, mouseDownCellFrame;
    PSMTabBarCell *cell = [self cellForPoint:mousePt cellFrame:&cellFrame];
    PSMTabBarCell *mouseDownCell = [self cellForPoint:[self convertPoint:[[self lastMouseDownEvent] locationInWindow] fromView:nil] cellFrame:&mouseDownCellFrame];
    if(cell){
        NSRect iconRect = [mouseDownCell closeButtonRectForFrame:mouseDownCellFrame];
        if((NSMouseInRect(mousePt, iconRect,[self isFlipped])) && [mouseDownCell closeButtonPressed]){
            [self performSelector:@selector(closeTabClick:) withObject:cell];
        } else if(NSMouseInRect(mousePt, mouseDownCellFrame,[self isFlipped])){
            [mouseDownCell setCloseButtonPressed:NO];
            [self performSelector:@selector(tabClick:) withObject:cell];
        } else {
            [mouseDownCell setCloseButtonPressed:NO];
            [self performSelector:@selector(tabNothing:) withObject:cell];
        }
    }
}

#pragma mark -
#pragma mark Drag and Drop

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent
{
    return YES;
}

// NSDraggingSource
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    return (isLocal ? NSDragOperationMove : NSDragOperationNone);
}

- (BOOL)ignoreModifierKeysWhileDragging
{
    return YES;
}

// NSDraggingDestination
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if([[[sender draggingPasteboard] types] indexOfObject:@"PSMTabBarControlItemPBType"] != NSNotFound) {

		if ([sender draggingSource] != self && ![self allowsDragBetweenWindows])
			return NSDragOperationNone;

        [[PSMTabDragAssistant sharedDragAssistant] draggingEnteredTabBar:self atPoint:[self convertPoint:[sender draggingLocation] fromView:nil]];
        return NSDragOperationMove;
    }

    return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    if ([[[sender draggingPasteboard] types] indexOfObject:@"PSMTabBarControlItemPBType"] != NSNotFound) {

		if ([sender draggingSource] != self && ![self allowsDragBetweenWindows])
			return NSDragOperationNone;

        [[PSMTabDragAssistant sharedDragAssistant] draggingUpdatedInTabBar:self atPoint:[self convertPoint:[sender draggingLocation] fromView:nil]];
        return NSDragOperationMove;
    }

    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    [[PSMTabDragAssistant sharedDragAssistant] draggingExitedTabBar:self];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    [[PSMTabDragAssistant sharedDragAssistant] performDragOperation];
    return YES;
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
    [[PSMTabDragAssistant sharedDragAssistant] draggedImageEndedAt:aPoint operation:operation];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{

}

#pragma mark -
#pragma mark Actions

- (void)overflowMenuAction:(id)sender
{
	[tabView selectTabViewItem:[sender representedObject]];
	[self update];
}

- (void)closeTabClick:(id)sender
{
	if ([_cells count] == 1 && ![self canCloseOnlyTab])
		return;

	if ([[self delegate] respondsToSelector:@selector(tabView:shouldCloseTabViewItem:)]) {
		if (![[self delegate] tabView:tabView shouldCloseTabViewItem:[sender representedObject]]) {
			// fix mouse downed close button
			[sender setCloseButtonPressed:NO];
			return;
		}
	}

	id representedObject = [sender representedObject];

	if ([[self delegate] respondsToSelector:@selector(tabView:willCloseTabViewItem:)])
		[[self delegate] tabView:tabView willCloseTabViewItem:representedObject];

	[tabView removeTabViewItem:representedObject];

	if ([[self delegate] respondsToSelector:@selector(tabView:didCloseTabViewItem:)])
		[[self delegate] tabView:tabView didCloseTabViewItem:representedObject];

}

- (void)tabClick:(id)sender
{
    [tabView selectTabViewItem:[sender representedObject]];
    [self update];
}

- (void)tabNothing:(id)sender
{
    [self update];  // takes care of highlighting based on state
}

- (void)frameDidChange:(NSNotification *)notification
{
    [self update];
#if 0
    // trying to address the drawing artifacts for the progress indicators - hackery follows
    // this one fixes the "blanking" effect when the control hides and shows itself
    NSEnumerator *e = [_cells objectEnumerator];
    PSMTabBarCell *cell;
    while ((cell = [e nextObject]) != nil) {
        [[cell indicator] stopAnimation:self];
        [[cell indicator] startAnimation:self];
    }
#endif
    [self setNeedsDisplay:YES];
}

- (void)viewWillStartLiveResize
{
    PSMTabBarCell *cell;
    for(cell in _cells)
        [[cell indicator] stopAnimation:self];
    [self setNeedsDisplay:YES];
}

-(void)viewDidEndLiveResize
{
    PSMTabBarCell *cell;
    for(cell in _cells)
        [[cell indicator] startAnimation:self];
    [self setNeedsDisplay:YES];
}

- (void)windowDidMove:(NSNotification *)aNotification
{
    [self setNeedsDisplay:YES];
}

- (void)windowStatusDidChange:(NSNotification *)notification
{
    // Hide? Must readjust things if I'm not supposed to be showing.
    // This block of code only runs when the app launches.
    if (1 && _hideForSingleTab && ([_cells count] <= 1) && !_awakenedFromNib){
        // must adjust frames now before display
        NSRect myFrame = [self frame];
        if (partnerView) {
            NSRect partnerFrame = [partnerView frame];
            NSRect newFrame = NSMakeRect(myFrame.origin.x, myFrame.origin.y + 21, myFrame.size.width, myFrame.size.height - 21);
            NSRect newPartnerFrame = NSMakeRect(partnerFrame.origin.x, partnerFrame.origin.y, partnerFrame.size.width, partnerFrame.size.height + 21);
            DEBUG(@"my frame: %@ -> %@", NSStringFromRect(myFrame), NSStringFromRect(newFrame));
            DEBUG(@"partner frame: %@ -> %@", NSStringFromRect(partnerFrame), NSStringFromRect(newPartnerFrame));
            [partnerView setFrame:newPartnerFrame];
            [self setFrame:newFrame];
            DEBUG(@"my frame is now %@", NSStringFromRect([self frame]));
            [partnerView setNeedsDisplay:YES];
        } else {
            // for window movement
            NSRect windowFrame = [[self window] frame];
            [[self window] setFrame:NSMakeRect(windowFrame.origin.x, windowFrame.origin.y + 21, windowFrame.size.width, windowFrame.size.height - 21) display:YES];
            [self setFrame:NSMakeRect(myFrame.origin.x, myFrame.origin.y, myFrame.size.width, myFrame.size.height - 21)];
        }
        _isHidden = YES;
        [self setNeedsDisplay:YES];
        //[[self window] display];
    }
     _awakenedFromNib = YES;
    [self update];
}

#pragma mark -
#pragma mark NSTabView Delegate

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	// here's a weird one - this message is sent before the "tabViewDidChangeNumberOfTabViewItems"
	// message, thus I can end up updating when there are no cells, if no tabs were (yet) present
	if ([_cells count] > 0)
		[self update];

	if ([[self delegate] respondsToSelector:@selector(tabView:didSelectTabViewItem:)])
		[[self delegate] performSelector:@selector(tabView:didSelectTabViewItem:) withObject:aTabView withObject:tabViewItem];
}

- (BOOL)tabView:(NSTabView *)aTabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[self delegate] respondsToSelector:@selector(tabView:shouldSelectTabViewItem:)])
		return (pointer_t)[[self delegate] performSelector:@selector(tabView:shouldSelectTabViewItem:) withObject:aTabView withObject:tabViewItem];
	else
		return YES;
}
- (void)tabView:(NSTabView *)aTabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[self delegate] respondsToSelector:@selector(tabView:willSelectTabViewItem:)])
		[[self delegate] performSelector:@selector(tabView:willSelectTabViewItem:) withObject:aTabView withObject:tabViewItem];
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)aTabView
{
    NSArray *tabItems = [tabView tabViewItems];
    // go through cells, remove any whose representedObjects are not in [tabView tabViewItems]
    PSMTabBarCell *cell;
    for(cell in [_cells copy])
    {
        if(![tabItems containsObject:[cell representedObject]]){
            [self removeTabForCell:cell];
        }
    }

    // go through tab view items, add cell for any not present
    NSMutableArray *cellItems = [self representedTabViewItems];
    for (NSTabViewItem *item in tabItems)
        if (![cellItems containsObject:item])
            [self addTabViewItem:item];

    // pass along for other delegate responses
    if([self delegate]){
        if([[self delegate] respondsToSelector:@selector(tabViewDidChangeNumberOfTabViewItems:)]){
            [[self delegate] performSelector:@selector(tabViewDidChangeNumberOfTabViewItems:) withObject:aTabView];
        }
    }
}

#pragma mark -
#pragma mark Convenience

- (NSMutableArray *)representedTabViewItems
{
    NSMutableArray *temp = [NSMutableArray arrayWithCapacity:[_cells count]];
    for (PSMTabBarCell *cell in _cells)
        [temp addObject:[cell representedObject]];

    return temp;
}

- (id)cellForPoint:(NSPoint)point cellFrame:(NSRectPointer)outFrame
{
    NSRect aRect = [self genericCellRect];

    if(!NSPointInRect(point,aRect)){
        return nil;
    }

    int i, cnt = (int)[_cells count];
    for(i = 0; i < cnt; i++){
        PSMTabBarCell *cell = [_cells objectAtIndex:i];
        float width = [cell width];
        aRect.size.width = width;

        if(NSPointInRect(point, aRect)){
            if(outFrame){
                *outFrame = aRect;
            }
            return cell;
        }
        aRect.origin.x += width;
    }
    return nil;
}

- (PSMTabBarCell *)lastVisibleTab
{
    int i, cellCount = (int)[_cells count];
    for(i = 0; i < cellCount; i++){
        if([[_cells objectAtIndex:i] isInOverflowMenu])
            return [_cells objectAtIndex:(i-1)];
    }
    return [_cells objectAtIndex:(cellCount - 1)];
}

- (int)numberOfVisibleTabs
{
    int i, cellCount = (int)[_cells count];
    for(i = 0; i < cellCount; i++){
        if([[_cells objectAtIndex:i] isInOverflowMenu])
            return i+1;
    }
    return cellCount;
}


@end
