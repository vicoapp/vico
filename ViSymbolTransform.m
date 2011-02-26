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
	NSString *trSymbol = aSymbol;
	NSArray *tr;
	for (tr in transformations) {
		ViRegexp *rx = [tr objectAtIndex:0];
		trSymbol = [self transformValue:trSymbol
		                    withPattern:rx
		                         format:[tr objectAtIndex:1]
		                        options:@""
		                          error:nil];
	}

	return trSymbol;
}

@end

