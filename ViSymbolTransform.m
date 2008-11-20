#import "ViSymbolTransform.h"
#import "ViRegexp.h"
#import "logging.h"

@implementation ViSymbolTransform

- (ViSymbolTransform *)initWithTransformationString:(NSString *)aString
{
	self = [super init];
	if (self)
	{
		transformations = [[NSMutableArray alloc] init];
		
		int i = 0;
		while (i < [aString length])
		{
			unichar c = [aString characterAtIndex:i++];
			if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
				/* skip whitespace */ ;
			else if (c == 's')
			{
				// substitute command
				unichar delim = [aString characterAtIndex:i++];
				NSMutableString *regexp = [[NSMutableString alloc] init];
				NSMutableString *replacement = [[NSMutableString alloc] init];
				int ndelim = 1;
				while (i < [aString length])
				{
					c = [aString characterAtIndex:i++];
					if (c == delim)
					{
						ndelim++;
					}
					else if (c == ';' && ndelim == 3)
					{
						break;
					}
					else
					{
						if (ndelim == 1)
							[regexp appendFormat:@"%C", c];
						else if (ndelim == 2)
							[replacement appendFormat:@"%C", c];
					}
				}
	
				if (ndelim != 3)
				{
					INFO(@"failed to parse transformation, i = %i", i);
					return nil;
				}
				
				ViRegexp *rx = [ViRegexp regularExpressionWithString:regexp];
				if (rx == nil)
				{
					INFO(@"invalid regexp: %@", regexp);
					return nil;
				}
				[transformations addObject:[NSArray arrayWithObjects:rx, replacement, regexp, nil]];
			}
			else if (c == '#')
			{
				// skip comments
				while (i < [aString length])
				{
					c = [aString characterAtIndex:i++];
					if (c == '\n')
						break;
				}
			}
			else
			{
				INFO(@"unknown transformation '%C'", c);
				return nil;
			}
		}
	}
	return self;
}

- (NSString *)transformSymbol:(NSString *)aSymbol
{
	NSMutableString *trSymbol = [aSymbol mutableCopy];
	NSArray *tr;
	for (tr in transformations)
	{
		ViRegexp *rx = [tr objectAtIndex:0];
		for (;;)
		{
			ViRegexpMatch *m = [rx matchInString:trSymbol];
			if (m == nil)
				break;
	
			NSRange range = [m rangeOfMatchedString];
			if (range.length == 0)
				break;
	
			NSMutableString *repl = [[tr objectAtIndex:1] mutableCopy];
			for (;;)
			{
				NSRange r = [repl rangeOfString:@"$"];
				if (r.location == NSNotFound)
					break;
				int n = [repl characterAtIndex:r.location + 1] - '0';
				NSString *groupMatch = [trSymbol substringWithRange:[m rangeOfSubstringAtIndex:n]];
				[repl replaceCharactersInRange:NSMakeRange(r.location, 2) withString:groupMatch];
			}
	
			[trSymbol replaceCharactersInRange:range withString:repl];
		}
	}

	return trSymbol;
}

@end

