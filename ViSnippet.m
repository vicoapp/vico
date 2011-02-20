#import "ViSnippet.h"
#import "ViBundle.h"
#import "logging.h"

@implementation ViSnippet

@synthesize currentTab;
@synthesize tabstops;
@synthesize currentPlaceholder;
@synthesize lastPlaceholder;
@synthesize string;
@synthesize range;

- (void)addPlaceholder:(ViSnippetPlaceholder *)placeHolder
{
	// extend the tabstops array to hold enough indices
	while ([placeHolder tabStop] >= [tabstops count]) {
		// insert empty placeholder arrays
		[tabstops addObject:[NSMutableArray array]];
	}

	// add the placeholder to the array
	[[tabstops objectAtIndex:[placeHolder tabStop]] addObject:placeHolder];
}

- (ViSnippet *)initWithString:(NSString *)aString
                   atLocation:(NSUInteger)aLocation
                   environment:(NSDictionary *)environment
{
	tabstops = [[NSMutableArray alloc] init];

	DEBUG(@"snippet string = %@ at location %llu", aString, aLocation);

        NSMutableString *s = [aString mutableCopy];
	BOOL foundMarker;
	NSUInteger i;
	do {
                foundMarker = NO;
                for (i = 0; i < [s length]; i++) {
                        // FIXME: handle escapes
                        if ([s characterAtIndex:i] == '$') {
                                ViSnippetPlaceholder *placeHolder;
                                placeHolder = [[ViSnippetPlaceholder alloc] initWithString:[s substringFromIndex:i + 1]
                                                                               environment:environment];
                                if (placeHolder == nil)
					break;
                                unsigned len = placeHolder.length;
				DEBUG(@"got placeholder %@ at %lu", placeHolder, i);

                                /*
                                 * Update the snippet string with any default value
                                 */
                                NSRange r = NSMakeRange(i + aLocation, 0);
                                NSString *defaultValue = placeHolder.defaultValue;
                                if (defaultValue == nil && placeHolder.tabStop > 0 && placeHolder.tabStop < [tabstops count] &&
                                    [tabstops objectAtIndex:placeHolder.tabStop]) {
                                	/* This is a mirror. Use default value from first placeholder. */
                                	DEBUG(@"got mirror of %li", placeHolder.tabStop);
                                	defaultValue = [[[tabstops objectAtIndex:placeHolder.tabStop] objectAtIndex:0] defaultValue];
				}

                                if (defaultValue) {
                                        // replace placeholder text, including dollar sign, with the default value
                                        [s replaceCharactersInRange:NSMakeRange(i, len + 1) withString:defaultValue];
					r.length = [defaultValue length];
					[placeHolder updateValue:defaultValue];
                                } else {
                                        // delete placeholder text, including dollar sign
                                        [s deleteCharactersInRange:NSMakeRange(i, len + 1)];
					[placeHolder updateValue:@""];
                                }

                        	if (placeHolder.variable) {
					INFO(@"lookup variable %@", placeHolder.variable);
					// lookup variable, apply transformation and insert value
                        	} else {
					// tabstop, add it to the array at the correct index

					int num = placeHolder.tabStop;
					if (num == 0)
						lastPlaceholder = placeHolder;

					[self addPlaceholder:placeHolder];

					// update the range
					[placeHolder setRange:r];
                        	}

                                foundMarker = YES;
                                break;
                        }
                }
        } while (foundMarker);

	DEBUG(@"parsed tabstops %@", tabstops);
	DEBUG(@"last tabstop %@", lastPlaceholder);

	range = NSMakeRange(aLocation, [s length]);
	string = s;

	return self;
}

- (void)updateLength:(NSInteger)aLength fromLocation:(NSUInteger)aLocation
{
	// update the location of all following placeholders
	NSArray *a;
	for (a in tabstops) {
		ViSnippetPlaceholder *ph;
		for (ph in a)
			[ph updateLength:aLength fromLocation:aLocation];
	}
	range.length += aLength;
}

- (void)setPlaceholder:(ViSnippetPlaceholder *)placeHolder toValue:(NSString *)value
{
	
}

- (BOOL)activeInRange:(NSRange)aRange
{
	if (NSIntersectionRange(aRange, range).length > 0 || aRange.location == NSMaxRange(range))
		return YES;
	return NO;
}

- (BOOL)done
{
	if (lastPlaceholder != nil)
		return currentPlaceholder == lastPlaceholder;
	return currentPlaceholder == [tabstops lastObject];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViSnippet at %@>", NSStringFromRange(range)];
}

@end

@implementation ViSnippetPlaceholder

@synthesize length;
@synthesize tabStop;
@synthesize range;
@synthesize variable;
@synthesize defaultValue;
@synthesize transformation;
@synthesize selected;
@synthesize value;

- (void)updateLength:(NSInteger)aLength fromLocation:(NSUInteger)aLocation
{
	if (range.location > aLocation)
		range.location += aLength;
}

- (BOOL)activeInRange:(NSRange)aRange
{
	if (aRange.location >= range.location && NSMaxRange(aRange) >= range.location && aRange.location <= NSMaxRange(range))
		return YES;
	return NO;
}

- (NSInteger)updateValue:(NSString *)newValue
{
	NSInteger delta = (NSInteger)[newValue length] - [value length];
	DEBUG(@"setting value [%@] in placeholder %@", newValue, self);
	range.length = [newValue length];
	value = newValue;
	return delta;
}

/*
 * FIXME: parse \-escaped characters!
 */

- (ViSnippetPlaceholder *)initWithString:(NSString *)s environment:(NSDictionary *)environment
{
        self = [super init];
        if (!self)
		return nil;

        NSScanner *scan = [NSScanner scannerWithString:s];
        [scan setCharactersToBeSkipped:nil];

	NSMutableCharacterSet *shellVariableSet = [[NSMutableCharacterSet alloc] init];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange('a', 'z' - 'a')]];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange('A', 'Z' - 'A')]];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"_"]];

	BOOL bracedExpression = NO;
	if ([scan scanString:@"{" intoString:nil])
		bracedExpression = YES;

        if (![scan scanInt:&tabStop]) {
                [scan scanCharactersFromSet:shellVariableSet intoString:&variable];
		DEBUG(@"got shell var %@", variable);
	} else
		DEBUG(@"got tabstop %i", tabStop);

	if (bracedExpression) {
                if ([scan scanString:@":" intoString:nil]) {
                        // got a default value
			if ([scan scanString:@"$" intoString:nil]) {
				// default value is a variable
				bracedExpression = NO;
				if ([scan scanString:@"{" intoString:nil])
					bracedExpression = YES;
				[scan scanCharactersFromSet:shellVariableSet intoString:&defaultVariable];
				DEBUG(@"got default variable %@", defaultVariable);
				
				defaultValue = [environment objectForKey:defaultVariable];

				if (bracedExpression) {
					if ([scan scanString:@"/" intoString:nil]) {
						// got a regular expression transformation
						[scan scanUpToString:@"}" intoString:&transformation];
						DEBUG(@"apply transformation %@ to default variable %@ => default value",
						    transformation, defaultVariable);
					}
					if (![scan scanString:@"}" intoString:nil]) {
						// parse error
						return nil;
					}
				}
			} else {
				// default value is a constant
				[scan scanUpToString:@"}" intoString:&defaultValue];
				DEBUG(@"got default value %@", defaultValue);
                        }
                } else if ([scan scanString:@"/" intoString:nil]) {
                        // got a regular expression transformation
                        [scan scanUpToString:@"}" intoString:&transformation];
                        DEBUG(@"got transformation %@", transformation);
                }

                if (![scan scanString:@"}" intoString:nil]) {
                        // parse error
                        return nil;
                }
	}

	length = [scan scanLocation];
	string = [s substringToIndex:length];

	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViSnippetPlaceholder %i: \"%@\" at %@>", tabStop, value, NSStringFromRange(range)];
}

@end

