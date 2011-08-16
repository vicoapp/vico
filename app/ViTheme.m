#import "ViTheme.h"
#import "NSString-scopeSelector.h"
#import "logging.h"

@implementation ViTheme

- (id)initWithPath:(NSString *)aPath
{
	self = [super init];
	if(self == nil)
		return nil;

	scopeSelectorCache = [[NSMutableDictionary alloc] init];	
	theme = [NSDictionary dictionaryWithContentsOfFile:aPath];
	if (![theme isKindOfClass:[NSDictionary class]]) {
		INFO(@"failed to parse theme %@", aPath);
		return nil;
	}

	if ([[self name] length] == 0) {
		INFO(@"Missing 'name' in theme %@", aPath);
		return nil;
	}

	themeAttributes = [[NSMutableDictionary alloc] init];
	NSArray *preferences = [theme objectForKey:@"settings"];
	NSDictionary *preference;
	for (preference in preferences) {
		if ([preference objectForKey:@"name"] == nil) {
			/* Settings for the default scope. */
			defaultSettings = [preference objectForKey:@"settings"];
			[ViBundle normalizePreference:preference intoDictionary:defaultSettings];
			continue;
		}

		NSString *scopeSelector = [preference objectForKey:@"scope"];
		if (scopeSelector == nil)
			continue;

		NSMutableDictionary *attrs = [[NSMutableDictionary alloc] init];	
		[ViBundle normalizePreference:preference intoDictionary:attrs];

		[themeAttributes setObject:attrs forKey:scopeSelector];
	}

	return self;
}

- (NSString *)name
{
	return [theme objectForKey:@"name"];
}


/*
 * From the textmate manual:
 * "For themes and preference items, the winner is undefined when
 *  multiple items use the same scope selector, though this is on
 *  a per-property basis. So for example if one theme item sets the
 *  background to blue for string.quoted and another theme item sets
 *  the foreground to white, again for string.quoted, the result
 *  would be that the foreground was taken from the latter item and
 *  background from the former."
 */
- (void)matchAttributes:(NSDictionary *)matchAttributes
               forScope:(ViScope *)scope
         intoDictionary:(NSMutableDictionary *)attributes
              rankState:(NSMutableDictionary *)attributesRank
{
	NSString *scopeSelector;
	for (scopeSelector in matchAttributes) {
		u_int64_t rank = [scopeSelector match:scope];
		if (rank > 0) {
			NSDictionary *attrs = [matchAttributes objectForKey:scopeSelector];
			NSString *attrKey;
			for (attrKey in attrs) {
				u_int64_t prevRank = [[attributesRank objectForKey:attrKey] unsignedLongLongValue];
				if (rank > prevRank) {
					DEBUG(@"scope selector [%@] matches scope %@ with rank %llu > %llu, setting %@", scopeSelector, scope, rank, prevRank, attrKey);
					[attributes setObject:[attrs objectForKey:attrKey] forKey:attrKey];
					[attributesRank setObject:[NSNumber numberWithUnsignedLongLong:rank] forKey:attrKey];
				}
			}
		}
	}
}

/* Return attributes (fore/background colors, underline, oblique) that are specified
 * by the theme by matching against the scope selectors.
 *
 * Returns nil if no attributes are applicable.
 */
- (NSDictionary *)attributesForScope:(ViScope *)scope inBundle:(ViBundle *)bundle
{
	NSString *key = [[scope scopes] componentsJoinedByString:@" "];
	NSMutableDictionary *attributes = [scopeSelectorCache objectForKey:key];
	if (attributes)
		return [attributes count] == 0 ? nil : attributes;

	attributes = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *attributesRank = [[NSMutableDictionary alloc] init];

	// Set default colors
	[attributes setObject:[self foregroundColor] forKey:NSForegroundColorAttributeName];
	[attributes setObject:[self backgroundColor] forKey:NSBackgroundColorAttributeName];

	[self matchAttributes:themeAttributes
		     forScope:scope
	       intoDictionary:attributes
		    rankState:attributesRank];

	/*
	 * Bundle preferences can override/add theme attributes for certain scopes.
	 * The Diff bundle does this for example.
	 */
	if (bundle != nil) {
		NSArray *prefs = [NSArray arrayWithObjects:NSBackgroundColorAttributeName,
		    NSForegroundColorAttributeName,
		    NSUnderlineStyleAttributeName,
		    NSObliquenessAttributeName,
		    NSStrokeWidthAttributeName,
		    nil];
		NSDictionary *bundlePrefs = [bundle preferenceItems:prefs];
		if (bundlePrefs)
			[self matchAttributes:bundlePrefs forScope:scope intoDictionary:attributes rankState:attributesRank];
	}

	// Backgrounds with alpha is not supported, so blend the background colors together.
	NSColor *bg = [attributes objectForKey:NSBackgroundColorAttributeName];
	if (bg) {
		NSColor *new_bg = [[self backgroundColor] blendedColorWithFraction:[bg alphaComponent] ofColor:bg];
		[attributes setObject:new_bg forKey:NSBackgroundColorAttributeName];
	}

	// cache it
	[scopeSelectorCache setObject:attributes forKey:key];

	return attributes;
}

- (NSColor *)colorWithName:(NSString *)colorName orDefault:(NSColor *)defaultColor
{
	NSString *rgb = [defaultSettings objectForKey:colorName];
	NSColor *color;
	if (rgb)
		color = [ViBundle hashRGBToColor:rgb];
	else
		color = defaultColor;
	return color;
}

- (NSColor *)backgroundColor
{
	if (backgroundColor == nil) {
		backgroundColor = [defaultSettings objectForKey:NSBackgroundColorAttributeName];
		if (backgroundColor == nil)
			backgroundColor = [[NSColor whiteColor] colorWithAlphaComponent:1.0];
	}
	return backgroundColor;
}

- (NSColor *)foregroundColor
{
	if (foregroundColor == nil) {
		foregroundColor = [defaultSettings objectForKey:NSForegroundColorAttributeName];
		if (foregroundColor == nil)
			foregroundColor = [[NSColor blackColor] colorWithAlphaComponent:1.0];
	}
	return foregroundColor;
}

- (NSColor *)lineHighlightColor
{
	if (lineHighlightColor == nil) {
		lineHighlightColor = [self colorWithName:@"lineHighlight" orDefault:nil];
		lineHighlightColor = [caretColor colorWithAlphaComponent:0.1];
	}
	return lineHighlightColor;
}

- (NSColor *)caretColor
{
	if (caretColor == nil) {
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
	if (selectionColor == nil) {
		NSColor *bg = [self colorWithName:@"selection" orDefault:[[NSColor blueColor] colorWithAlphaComponent:0.5]];
		selectionColor = [[self backgroundColor] blendedColorWithFraction:[bg alphaComponent] ofColor:bg];
	}
	return selectionColor;
}

- (NSColor *)invisiblesColor
{
	if (invisiblesColor == nil) {
		NSColor *defaultInvisiblesColor = [NSColor colorWithCalibratedRed:0.2
								            green:0.2
									     blue:0.2
								            alpha:0.5];
		invisiblesColor = [self colorWithName:@"invisibles" orDefault:defaultInvisiblesColor];
		invisiblesColor = [invisiblesColor colorWithAlphaComponent:0.5];
	}
	return invisiblesColor;
}

- (NSDictionary *)invisiblesAttributes
{
	return [NSDictionary dictionaryWithObject:[self invisiblesColor]
	                                   forKey:NSForegroundColorAttributeName];
}

- (NSString *)description
{
	return [theme description];
}

@end
