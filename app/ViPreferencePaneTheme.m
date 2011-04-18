#import "ViPreferencePaneTheme.h"
#import "ViThemeStore.h"
#include "logging.h"

@implementation ViPreferencePaneTheme

- (id)init
{
	self = [super initWithNibName:@"ThemePrefs"
				 name:@"Fonts & Colors"
				 icon:[NSImage imageNamed:NSImageNameColorPanel]];

	ViThemeStore *ts = [ViThemeStore defaultStore];
	NSArray *themes = [ts availableThemes];
	for (NSString *theme in [themes sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)])
		[themeButton addItemWithTitle:theme];
	[themeButton selectItem:[themeButton itemWithTitle:[[ts defaultTheme] name]]];

	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"fontsize"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"fontname"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];

	[self setSelectedFont];

	return self;
}

#pragma mark -
#pragma mark Font selection

- (void)setSelectedFont
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	[currentFont setStringValue:[NSString stringWithFormat:@"%@ %.1fpt",
	    [defs stringForKey:@"fontname"],
	    [defs floatForKey:@"fontsize"]]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context
{
//	if ([keyPath isEqualToString:@"fontsize"] || [keyPath isEqualToString:@"fontname"])
	[self setSelectedFont];
}

- (IBAction)selectFont:(id)sender
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFont *font = [NSFont fontWithName:[defs stringForKey:@"fontname"]
				       size:[defs floatForKey:@"fontsize"]];
	[fontManager setTarget:self];
	[fontManager setSelectedFont:font isMultiple:NO];
	[fontManager orderFrontFontPanel:nil];
}

- (void)changeAttributes:(id)sender
{
	DEBUG(@"sender is %@", sender);
}

- (void)changeFont:(id)sender
{
	DEBUG(@"sender is %@", sender);
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFont *font = [fontManager convertFont:[fontManager selectedFont]];
	[[NSUserDefaults standardUserDefaults] setObject:[font fontName]
						  forKey:@"fontname"];
	NSNumber *fontSize = [NSNumber numberWithFloat:[font pointSize]];
	[[NSUserDefaults standardUserDefaults] setObject:fontSize
						  forKey:@"fontsize"];
}

@end
