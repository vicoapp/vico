#import "ViSnippet.h"
#import "logging.h"

@implementation ViSnippet

@synthesize currentTab;
@synthesize tabstops;
@synthesize currentPlaceholder;
@synthesize lastPlaceholder;
@synthesize string;
@synthesize range;

- (ViSnippet *)initWithString:(NSString *)aString atLocation:(NSUInteger)aLocation
{
	tabstops = [[NSMutableArray alloc] init];

	INFO(@"snippet string = %@", aString);

        NSMutableString *s = [aString mutableCopy];
	BOOL foundMarker;
	NSUInteger i;
	do
        {
                foundMarker = NO;
                for (i = 0; i < [s length]; i++)
                {
                        // FIXME: handle escapes
                        if ([s characterAtIndex:i] == '$')
                        {
                                ViSnippetPlaceholder *placeHolder;
                                placeHolder = [[ViSnippetPlaceholder alloc] initWithString:[s substringFromIndex:i + 1]];
                                if (placeHolder == nil)
					break;
                                unsigned len = placeHolder.length;

                                /* Update the snippet string with any default value
                                 */
                                NSRange r = NSMakeRange(i + aLocation, 0);
                                if (placeHolder.defaultValue)
                                {
                                        // replace placeholder text, including dollar sign, with the default value
                                        [s replaceCharactersInRange:NSMakeRange(i, len + 1) withString:placeHolder.defaultValue];
					r.length = [placeHolder.defaultValue length];
                                }
                                else
                                {
                                        // delete placeholder text, including dollar sign
                                        [s deleteCharactersInRange:NSMakeRange(i, len + 1)];
                                }

                        	if (placeHolder.variable)
                        	{
					// lookup variable, apply transformation and insert value
                        	}
				else
                        	{
					// tabstop, add it to the array at the correct index

					int num = placeHolder.tabStop;
					if (num == 0)
					{
						lastPlaceholder = placeHolder;
					}
					else
					{
						// extend the tabstops array to hold enough indices
						while (num > [tabstops count])
						{
							// insert empty placeholder arrays
							[tabstops addObject:[NSMutableArray array]];
						}
	
						// add the placeholder to the array (at index num-1)
						int ndx = num - 1;
						[[tabstops objectAtIndex:ndx] addObject:placeHolder];
					}
					
					// update the range
					[placeHolder setRange:r];
                        	}

                                foundMarker = YES;
                                break;
                        }
                }
        } while (foundMarker);

	INFO(@"parsed tabstops %@", tabstops);

	range = NSMakeRange(aLocation, [s length]);
	string = s;

	return self;
}

/* Called by the ViTextView when inserting a string inside the snippet.
 * Extends the snippet temporary attribute over the inserted text.
 * If inside a place holder range, updates the range. Also handles mirror
 * place holders.
 */
- (void)insertString:(NSString *)aString atLocation:(NSUInteger)aLocation
{
	NSRange affectedRange = NSMakeRange(aLocation, [aString length]);

	NSArray *a;
	for (a in tabstops)
	{
		ViSnippetPlaceholder *ph;
		for (ph in a)
		{
			[ph pushLength:[aString length] ifAffectedByRange:affectedRange];
		}
	}
			
	[lastPlaceholder pushLength:[aString length] ifAffectedByRange:affectedRange];
	range.length += [aString length];
}

- (void)deleteRange:(NSRange)affectedRange
{
	NSArray *a;
	for (a in tabstops)
	{
		ViSnippetPlaceholder *ph;
		for (ph in a)
		{
			[ph pushLength:-affectedRange.length ifAffectedByRange:affectedRange];
		}
	}
	
	[lastPlaceholder pushLength:-affectedRange.length ifAffectedByRange:affectedRange];
	range.length -= affectedRange.length;
}

@end

@implementation ViSnippetPlaceholder

@synthesize length;
@synthesize tabStop;
@synthesize range;
@synthesize variable;
@synthesize defaultValue;
@synthesize transformation;

- (void)pushLength:(int)aLength ifAffectedByRange:(NSRange)affectedRange
{
	if (range.location > NSMaxRange(affectedRange))
	{
		range.location += aLength;
	}
}

- (ViSnippetPlaceholder *)initWithString:(NSString *)s
{
        self = [super init];
        if (!self)
		return nil;

        NSScanner *scan = [NSScanner scannerWithString:s];

	NSMutableCharacterSet *shellVariableSet = [[NSMutableCharacterSet alloc] init];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange('a', 'z' - 'a')]];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange('A', 'Z' - 'A')]];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"_"]];

	BOOL bracedExpression = NO;
	if ([scan scanString:@"{" intoString:nil])
		bracedExpression = YES;
                
        if (![scan scanInt:&tabStop])
        {
                [scan scanCharactersFromSet:shellVariableSet intoString:&variable];
        }

	if (bracedExpression)
	{
                if ([scan scanString:@":" intoString:nil])
                {
                        // got a default value
                        [scan scanUpToString:@"}" intoString:&defaultValue];
                }
                else if ([scan scanString:@"/" intoString:nil])
                {
                        // got a regular expression transformation
                        [scan scanUpToString:@"}" intoString:&transformation];
                }

                if (![scan scanString:@"}" intoString:nil])
                {
                        // parse error
                        return nil;
                }
	}

	length = [scan scanLocation];
	
	return self;
}

@end

