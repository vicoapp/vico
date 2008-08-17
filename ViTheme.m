#import "ViTheme.h"

@implementation ViTheme

- (NSColor *)hashRGBToColor:(NSString *)hashRGB
{
	//NSLog(@"%s saving foreground color %@", _cmd, foreground);
	int r, g, b;
	if(sscanf([hashRGB UTF8String], "#%02X%02X%02X", &r, &g, &b) != 3)
		return nil;
	return [NSColor colorWithDeviceRed:(float)r/256.0 green:(float)g/256.0 blue:(float)b/256.0 alpha:1.0];
}

- (id)initWithPath:(NSString *)aPath
{
	self = [super init];
	if(self == nil)
		return nil;

	scopeSelectorCache = [[NSMutableDictionary alloc] init];	
	theme = [NSDictionary dictionaryWithContentsOfFile:aPath];
	//NSLog(@"theme = %@", theme);

	themeAttributes = [[NSMutableDictionary alloc] init];
	NSArray *settings = [theme objectForKey:@"settings"];
	NSDictionary *setting;
	for(setting in settings)
	{
		if([setting objectForKey:@"name"] == nil)
		{
			/* settings for the default scope */
			defaultSettings = [setting objectForKey:@"settings"];
			continue;
		}

		NSString *scope = [setting objectForKey:@"scope"];
		if(scope == nil)
			continue;

		// FIXME: should parse the scope selector appropriately:
		NSArray *scope_selectors = [scope componentsSeparatedByString:@", "];

		NSMutableDictionary *attrs = [[NSMutableDictionary alloc] init];	

		NSString *foreground = [[setting objectForKey:@"settings"] objectForKey:@"foreground"];
		if(foreground)
			[attrs setObject:[self hashRGBToColor:foreground] forKey:NSForegroundColorAttributeName];

		NSString *background = [[setting objectForKey:@"settings"] objectForKey:@"background"];
		if(background)
			[attrs setObject:[self hashRGBToColor:background] forKey:NSBackgroundColorAttributeName];

		NSString *fontStyle = [[setting objectForKey:@"settings"] objectForKey:@"fontStyle"];
		if(fontStyle)
		{
			if([fontStyle rangeOfString:@"underline"].location != NSNotFound)
				[attrs setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
			if([fontStyle rangeOfString:@"italic"].location != NSNotFound)
				[attrs setObject:[NSNumber numberWithFloat:0.3] forKey:NSObliquenessAttributeName];
		}

		for(scope in scope_selectors)
		{
			[themeAttributes setObject:attrs forKey:scope];
			//NSLog(@"%s  %@ = %@", _cmd, scope, attrs);
		}
	}

	return self;
}

- (id)initWithBundle:(NSString *)aBundleName
{
	NSString *path = [[NSBundle mainBundle] pathForResource:aBundleName ofType:@"tmTheme"];
	return [self initWithPath:path];
}

- (NSString *)name
{
	return [theme objectForKey:@"name"];
}

- (NSDictionary *)attributeForScopeSelector:(NSString *)aScopeSelector
{
	if(aScopeSelector == nil)
		return nil;

	NSMutableDictionary *attributes = [scopeSelectorCache objectForKey:aScopeSelector];
	if(attributes)
		return attributes;

	BOOL found = NO;
	NSString *scope;
	for(scope in [themeAttributes allKeys])
	{
		if([aScopeSelector hasPrefix:scope])
		{
			found = YES;
			break;
		}
	}

	// merge scope selector attribute with theme (color) attributes
	attributes = [[NSMutableDictionary alloc] init];
	[attributes setObject:aScopeSelector forKey:ViScopeAttributeName];
	if(found && scope)
		[attributes addEntriesFromDictionary:[themeAttributes objectForKey:scope]];
	else
		NSLog(@"scope [%@] has no attributes", aScopeSelector);

	// cache it
	[scopeSelectorCache setObject:attributes forKey:aScopeSelector];

	return attributes;
}

- (NSColor *)colorWithName:(NSString *)colorName orDefault:(NSColor *)defaultColor alpha:(float)alpha
{
	NSString *rgb = [defaultSettings objectForKey:colorName];
	NSLog(@"%@ rgb = %@", colorName, rgb);
	NSColor *color;
	if(rgb)
		color = [self hashRGBToColor:rgb];
	else
		color = defaultColor;
	return [color colorWithAlphaComponent:alpha];
}

- (NSColor *)backgroundColor
{
	if(backgroundColor == nil)
		backgroundColor = [self colorWithName:@"background" orDefault:[NSColor whiteColor] alpha:1.0];
	return backgroundColor;
}

- (NSColor *)foregroundColor
{
	if(foregroundColor == nil)
		foregroundColor = [self colorWithName:@"foreground" orDefault:[NSColor blackColor] alpha:1.0];
	return foregroundColor;
}

- (NSColor *)caretColor
{
	if(caretColor == nil)
	{
		NSColor *defaultCaretColor = [NSColor colorWithCalibratedRed:0.2
								       green:0.2
									blue:0.2
								       alpha:0.5];
		caretColor = [self colorWithName:@"caret" orDefault:defaultCaretColor alpha:0.6];
	}
	return caretColor;
}

- (NSColor *)selectionColor
{
	if(selectionColor == nil)
		selectionColor = [self colorWithName:@"selection" orDefault:[NSColor blueColor] alpha:0.5];
	return selectionColor;
}

@end
