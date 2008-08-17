#import "ViTheme.h"
#import "NSString-scopeSelector.h"
#import <OgreKit/OgreKit.h>

@implementation ViTheme

- (NSColor *)hashRGBToColor:(NSString *)hashRGB
{
	int r, g, b, a;
	int rc = sscanf([hashRGB UTF8String], "#%02X%02X%02X%02X", &r, &g, &b, &a);
	if(rc != 3 && rc != 4)
		return nil;
	if(rc == 3)
		a = 255;
	//NSLog(@"%@ rgb = %02X%02X%02X%02X", hashRGB, r, g, b, a);
	return [NSColor colorWithCalibratedRed:(float)r/255.0 green:(float)g/255.0 blue:(float)b/255.0 alpha:(float)a/255.0];
}

- (id)initWithPath:(NSString *)aPath
{
	self = [super init];
	if(self == nil)
		return nil;

	scopeSelectorCache = [[NSMutableDictionary alloc] init];	
	theme = [NSDictionary dictionaryWithContentsOfFile:aPath];

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

		NSString *scopeSelector = [setting objectForKey:@"scope"];
		if(scopeSelector == nil)
			continue;

		// split up grouped selectors
		NSArray *scopeSelectors = [scopeSelector componentsSeparatedByRegularExpressionString:@"\\s*,\\s*"];

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
		
		for(scopeSelector in scopeSelectors)
		{
			[themeAttributes setObject:attrs forKey:scopeSelector];
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

/* Return attributes (fore/background colors, underline, oblique) that are specified
 * by the theme by matching against the scope selectors.
 *
 * Returns nil if no attributes are applicable.
 */
- (NSDictionary *)attributesForScopes:(NSArray *)scopes
{
	// FIXME: is it ok to key on an NSArray ?
	NSMutableDictionary *attributes = [scopeSelectorCache objectForKey:scopes];
	if(attributes)
	{
		return [attributes count] == 0 ? nil : attributes;
	}

	NSString *foundScopeSelector = nil;
	NSString *scopeSelector;
	u_int64_t highest_rank = 0;
	for(scopeSelector in [themeAttributes allKeys])
	{
		u_int64_t rank = [scopeSelector matchesScopes:scopes];
		if(rank > highest_rank)
		{
			foundScopeSelector = scopeSelector;
			highest_rank = rank;
		}
	}

	// FIXME: merge multiple attributes using the same scope selector
	// From the textmate manual:
	// "For themes and preference items, the winner is undefined when
	//  multiple items use the same scope selector, though this is on
	//  a per-property basis. So for example if one theme item sets the
	//  background to blue for string.quoted and another theme item sets
	//  the foreground to white, again for string.quoted, the result
	//  would be that the foreground was taken from the latter item and
	//  background from the former."

	if(foundScopeSelector)
	{
		//NSLog(@"     using scope selector [%@] for scopes [%@]", foundScopeSelector, [scopes componentsJoinedByString:@" "]);
		attributes = [themeAttributes objectForKey:foundScopeSelector];

		NSColor *bg = [attributes objectForKey:NSBackgroundColorAttributeName];
		if(bg)
		{
			NSColor *new_bg = [[self backgroundColor] blendedColorWithFraction:[bg alphaComponent] ofColor:bg];
			[attributes setObject:new_bg forKey:NSBackgroundColorAttributeName];
		}
		
		// cache it
		[scopeSelectorCache setObject:attributes forKey:scopes];
	}
	else
	{
		//NSLog(@"     scopes [%@] has no attributes", [scopes componentsJoinedByString:@" "]);
		// also cache non-hits
		[scopeSelectorCache setObject:[NSDictionary dictionary] forKey:scopes];
	}

	return attributes;
}

- (NSColor *)colorWithName:(NSString *)colorName orDefault:(NSColor *)defaultColor
{
	NSString *rgb = [defaultSettings objectForKey:colorName];
	NSColor *color;
	if(rgb)
		color = [self hashRGBToColor:rgb];
	else
		color = defaultColor;
	return color;
}

- (NSColor *)backgroundColor
{
	if(backgroundColor == nil)
		backgroundColor = [self colorWithName:@"background" orDefault:[[NSColor whiteColor] colorWithAlphaComponent:1.0]];
	return backgroundColor;
}

- (NSColor *)foregroundColor
{
	if(foregroundColor == nil)
		foregroundColor = [self colorWithName:@"foreground" orDefault:[[NSColor blackColor] colorWithAlphaComponent:1.0]];
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
		caretColor = [self colorWithName:@"caret" orDefault:defaultCaretColor];
		caretColor = [caretColor colorWithAlphaComponent:0.5];
	}
	return caretColor;
}

- (NSColor *)selectionColor
{
	if(selectionColor == nil)
	{
		NSColor *bg = [self colorWithName:@"selection" orDefault:[[NSColor blueColor] colorWithAlphaComponent:0.5]];
		selectionColor = [[self backgroundColor] blendedColorWithFraction:[bg alphaComponent] ofColor:bg];
	}
	return selectionColor;
}

- (NSString *)description
{
	return [theme description];
}

@end
