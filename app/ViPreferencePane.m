#import "ViPreferencePane.h"

@implementation ViPreferencePane

@synthesize name = paneName, icon, view;

- (id)initWithNib:(NSNib *)nib
             name:(NSString *)aName
             icon:(NSImage *)anIcon
{
	if ((self = [super init]) != nil) {
		paneName = aName;
		icon = anIcon;
		[nib instantiateNibWithOwner:self topLevelObjects:nil];
	}

	return self;
}

- (id)initWithNibName:(NSString *)nibName
                 name:(NSString *)aName
                 icon:(NSImage *)anIcon
{
	return [self initWithNib:[[NSNib alloc] initWithNibNamed:nibName bundle:nil]
			    name:aName
			    icon:anIcon];
}

@end
