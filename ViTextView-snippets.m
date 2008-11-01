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
                                       NSMutableDictionary *d = [tabstops objectForKey:tabStop];
                                       if (d)
                                       {
                                                /* merge tabstops, especially default value */
                                                if ([meta objectForKey:@"defaultValue"])
                                                        [d setObject:[meta objectForKey:@"defaultValue"] forKey:@"defaultValue"];
                                                if ([meta objectForKey:@"transformation"])
                                                        [d setObject:[meta objectForKey:@"transformation"] forKey:@"transformation"];
                                                // FIXME: sort locations
                                                [[d objectForKey:@"locations"] addObject:[NSNumber numberWithInteger:i]];
                                        }
                                        else
                                        {
                                                [tabstops setObject:meta forKey:tabStop];
                                                NSMutableArray *locations = [[NSMutableArray alloc] init];
                                                [locations addObject:[NSNumber numberWithInteger:i]];
                                                [meta setObject:locations forKey:@"locations"];
                                        }

                                        INFO(@"parsed tabstop: %@", [tabstops objectForKey:tabStop]);
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
                        insert_end_location++;
                        loc++;
                }
        }

        NSDictionary *firstTabStop = [tabstops objectForKey:[NSNumber numberWithInt:1]];
        if (firstTabStop)
        {
                INFO(@"placing cursor at first tabstop %@", firstTabStop);
                loc = [[[firstTabStop objectForKey:@"locations"] objectAtIndex:0] integerValue] + aLocation;
                NSUInteger len = [[firstTabStop objectForKey:@"defaultValue"] length];
                [self setSelectedRange:NSMakeRange(loc, len)];
        }
}

@end

