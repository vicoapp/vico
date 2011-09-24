#import "ViPreferencePane.h"

@implementation ViPreferencePane

@synthesize name = _paneName;
@synthesize icon = _icon;
@synthesize view;

- (id)initWithNib:(NSNib *)nib
             name:(NSString *)aName
             icon:(NSImage *)anIcon
{
	if ((self = [super init]) != nil) {
		if (![nib instantiateNibWithOwner:self topLevelObjects:nil]) {
			[self release];
			return nil;
		}
		_paneName = [aName copy];
		_icon = [anIcon retain];
	}

	return self;
}

- (void)dealloc
{
	[_paneName release];
	[_icon release];
	[view release];
	[super dealloc];
}

- (id)initWithNibName:(NSString *)nibName
                 name:(NSString *)aName
                 icon:(NSImage *)anIcon
{
	return [self initWithNib:[[[NSNib alloc] initWithNibNamed:nibName bundle:nil] autorelease]
			    name:aName
			    icon:anIcon];
}

@end
