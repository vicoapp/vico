#import "ViTextView.h"

@implementation ViTextView (snippets)

- (BOOL)parseSnippetPlaceholder:(NSString *)s length:(size_t *)length_ptr meta:(NSMutableDictionary *)meta
{
        NSScanner *scan = [NSScanner scannerWithString:s];

	NSMutableCharacterSet *shellVariableSet = [[NSMutableCharacterSet alloc] init];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange('a', 'z' - 'a')]];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange('A', 'Z' - 'A')]];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"_"]];

	BOOL bracedExpression = NO;
	if ([scan scanString:@"{" intoString:nil])
		bracedExpression = YES;
                
        int tabStop;
        if ([scan scanInt:&tabStop])
        {
                [meta setObject:[NSNumber numberWithInt:tabStop] forKey:@"tabStop"];
        }
        else
        {
                NSString *var;
                [scan scanCharactersFromSet:shellVariableSet intoString:&var];
                [meta setObject:var forKey:@"variable"];
        }

	if (bracedExpression)
	{
                if ([scan scanString:@":" intoString:nil])
                {
                        // got a default value
                        NSString *defval;
                        [scan scanUpToString:@"}" intoString:&defval];
                        [meta setObject:defval forKey:@"defaultValue"];
                }
                else if ([scan scanString:@"/" intoString:nil])
                {
                        // got a regular expression transformation
                        NSString *regexp;
                        [scan scanUpToString:@"}" intoString:&regexp];
                        [meta setObject:regexp forKey:@"transformation"];
                }

                if (![scan scanString:@"}" intoString:nil])
                {
                        // parse error
                        return NO;
                }
	}

	*length_ptr = [scan scanLocation];
	
	return YES;
}

- (void)gotoTabstop:(NSDictionary *)tabStop inSnippet:(NSMutableDictionary *)state
{
	INFO(@"placing cursor at tabstop %@", tabStop);
	NSUInteger loc = [[tabStop objectForKey:@"location"] integerValue] + [[state objectForKey:@"start"] integerValue];
	NSUInteger len = [[tabStop objectForKey:@"defaultValue"] length];
	[self setSelectedRange:NSMakeRange(loc, len)];
	[state setObject:[NSNumber numberWithInt:1] forKey:@"currentTab"];
}

- (void)insertSnippet:(NSString *)snippet atLocation:(NSUInteger)aLocation
{
        NSMutableString *s = [[NSMutableString alloc] initWithString:snippet];

	NSMutableDictionary *tabstops = [[NSMutableDictionary alloc] init];

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
                                size_t len;
                                NSMutableDictionary *meta = [[NSMutableDictionary alloc] init];
                                if (![self parseSnippetPlaceholder:[s substringFromIndex:i + 1] length:&len meta:meta])
                                	break;
                                
                                if ([meta objectForKey:@"defaultValue"])
                                        [s replaceCharactersInRange:NSMakeRange(i, len + 1) withString:[meta objectForKey:@"defaultValue"]];
                                else
                                        [s deleteCharactersInRange:NSMakeRange(i, len + 1)];

				NSNumber *tabStop = [meta objectForKey:@"tabStop"];
				if (tabStop)
                        	{
                                        NSMutableArray *a = [tabstops objectForKey:tabStop];
                                        if (a == nil)
                                        {
					        a = [[NSMutableArray alloc] init];
                                                [tabstops setObject:a forKey:tabStop];
                                        }

					[a addObject:meta];
					[meta setObject:[NSNumber numberWithInteger:i] forKey:@"location"];

                                        INFO(@"parsed tabstop: %@", [tabstops objectForKey:tabStop]);
                        	}
                        	else if ([meta objectForKey:@"variable"])
                        	{
					// lookup variable, apply transformation and insert value
                        	}

                                foundMarker = YES;
                                break;
                        }
                }
        } while (foundMarker);

        // FIXME: inefficient(?)
        NSUInteger loc = aLocation;
        for (i = 0; i < [s length]; i++)
        {
                if ([s characterAtIndex:i] == '\n')
                {
                        loc += [self insertNewlineAtLocation:loc indentForward:YES];
                }
                else
                {
                        [self insertString:[s substringWithRange:NSMakeRange(i, 1)] atLocation:loc];
                        loc++;
                }
        }

	[self performSelector:@selector(addTemporaryAttribute:) withObject:[NSDictionary dictionaryWithObjectsAndKeys:
		ViSnippetAttributeName, @"attributeName",
		tabstops, @"value",
		[NSValue valueWithRange:NSMakeRange(aLocation, loc - aLocation)], @"range",
		nil] afterDelay:0];

	[tabstops setObject:[NSNumber numberWithInteger:aLocation] forKey:@"start"];

        // FIXME: sort tabstops, go to tabstop 1 first, then 2, 3, 4, ... and last to 0
        NSDictionary *firstTabStop = [[tabstops objectForKey:[NSNumber numberWithInt:1]] objectAtIndex:0];
        if (firstTabStop)
		[self gotoTabstop:firstTabStop inSnippet:tabstops];
}

- (void)handleSnippetTab:(id)snippetState
{
	NSMutableDictionary *state = snippetState;
	
	int currentTab = [[state objectForKey:@"currentTab"] intValue];
	INFO(@"current tab index is %i", currentTab);
        NSDictionary *tabStop = [[state objectForKey:[NSNumber numberWithInt:currentTab + 1]] objectAtIndex:0];
	if (tabStop == nil)
		tabStop = [[state objectForKey:[NSNumber numberWithInt:0]] objectAtIndex:0];
	
	if (tabStop)
		[self gotoTabstop:tabStop inSnippet:state];
}

@end

