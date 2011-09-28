#import "ViMarkInspector.h"
#import "ViMarkManager.h"
#import "ViWindowController.h"
#include "logging.h"

@implementation ViMarkInspector

+ (ViMarkInspector *)sharedInspector
{
	static ViMarkInspector *__sharedInspector = nil;
	if (__sharedInspector == nil)
		__sharedInspector = [[ViMarkInspector alloc] init];
	return __sharedInspector;
}

- (id)init
{
	if ((self = [super initWithWindowNibName:@"MarkInspector"])) {
	}
	return self;
}

- (void)dealloc
{
	[markListController release];
	[markStackController release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[outlineView setTarget:self];
	[outlineView setDoubleAction:@selector(gotoMark:)];
}

- (void)show
{
	[[self window] makeKeyAndOrderFront:self];
}

- (IBAction)changeList:(id)sender
{
	DEBUG(@"sender is %@, tag %lu", sender, [sender tag]);
	ViMarkStack *stack = [[markStackController selectedObjects] lastObject];
	if ([sender selectedSegment] == 0)
		[stack previous];
	else
		[stack next];
}

- (IBAction)gotoMark:(id)sender
{
	DEBUG(@"sender is %@", sender);
	NSArray *objects = [markListController selectedObjects];
	if ([objects count] == 1) {
		id object = [objects lastObject];
		DEBUG(@"selected object is %@ (row is %li)", object, [outlineView rowForItem:object]);
		if ([object isKindOfClass:[ViMark class]]) {
			ViMark *mark = object;
			ViWindowController *windowController = [ViWindowController currentWindowController];
			[windowController gotoMark:mark];
			[windowController showWindow:nil];
		} else {
			NSArray *nodes = [markListController selectedNodes];
			DEBUG(@"got selected nodes %@", nodes);
			id node = [nodes lastObject];
			if ([outlineView isItemExpanded:node])
				[outlineView collapseItem:node];
			else
				[outlineView expandItem:node];
		}
	}
}

@end
