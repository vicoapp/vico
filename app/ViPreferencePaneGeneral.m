#import "ViPreferencePaneGeneral.h"
#import "ViBundleStore.h"

@implementation undoStyleTagTransformer
+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return YES; }
- (id)init { return [super init]; }
- (id)transformedValue:(id)value
{
	if ([value isKindOfClass:[NSNumber class]]) {
		switch ([value integerValue]) {
		case 2:
			return @"nvi";
		case 1:
		default:
			return @"vim";
		}
	} else if ([value isKindOfClass:[NSString class]]) {
		int tag = 1;
		if ([value isEqualToString:@"nvi"])
			tag = 2;
		return [NSNumber numberWithInt:tag];
	}

	return nil;
}
@end

@implementation ViPreferencePaneGeneral

- (id)init
{
	self = [super initWithNibName:@"GeneralPrefs"
				 name:@"General"
				 icon:[NSImage imageNamed:NSImageNamePreferencesGeneral]];

	/* Convert between tags and undo style strings (vim and nvi). */
	[NSValueTransformer setValueTransformer:[[undoStyleTagTransformer alloc] init]
					forName:@"undoStyleTagTransformer"];

	[defaultSyntaxButton removeAllItems];
	NSArray *sortedLanguages = [[ViBundleStore defaultStore] sortedLanguages];
	for (ViLanguage *lang in sortedLanguages) {
		NSMenuItem *item;
		item = [[defaultSyntaxButton menu] addItemWithTitle:[lang displayName] action:nil keyEquivalent:@""];
		[item setRepresentedObject:[lang name]];
	}

	NSString *defaultName = [[[ViBundleStore defaultStore] defaultLanguage] displayName];
	if (defaultName)
		[defaultSyntaxButton selectItemWithTitle:defaultName];

	return self;
}

@end
