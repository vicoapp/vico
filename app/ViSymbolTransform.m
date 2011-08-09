#import "ViSymbolTransform.h"
#import "ViRegexp.h"
#import "NSScanner-additions.h"
#import "logging.h"

@implementation ViSymbolTransform

- (ViSymbolTransform *)initWithTransformationString:(NSString *)aString
{
	self = [super init];
	if (self)
	{
		transformations = [[NSMutableArray alloc] init];

		NSScanner *scan = [NSScanner scannerWithString:aString];
		NSCharacterSet *skipSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

		unichar ch;
		while ([scan scanCharacter:&ch]) {
			if ([skipSet characterIsMember:ch])
				/* skip whitespace and newlines */ ;
			else if (ch == 's') {
				NSString *regexp, *format, *options = nil;

				if (![scan scanString:@"/" intoString:nil] ||
				    ![scan scanUpToUnescapedCharacter:'/' intoString:&regexp] ||
				    ![scan scanString:@"/" intoString:nil] ||
				    ![scan scanUpToUnescapedCharacter:'/' intoString:&format] ||
				    ![scan scanString:@"/" intoString:nil]) {
//					if (outError)
//						*outError = [ViError errorWithFormat:@"Missing separating slash at %lu",
//						    [scan scanLocation] + 1];
					return nil;
				}

				NSCharacterSet *optionsCharacters = [NSCharacterSet alphanumericCharacterSet];
				[scan scanCharactersFromSet:optionsCharacters
						 intoString:&options];
				if (options == nil)
					options = @"";

				ViRegexp *rx = [[ViRegexp alloc] initWithString:regexp];
				if (rx == nil) {
					INFO(@"invalid regexp: %@", regexp);
					return nil;
				}

				[transformations addObject:[NSArray arrayWithObjects:rx, format, options, nil]];
				[scan scanString:@";" intoString:nil];
			} else if (ch == '#') {
				// skip comments
				[scan scanUpToString:@"\n" intoString:nil];
			} else {
				INFO(@"unknown transformation '%C'", ch);
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
		                         global:([[tr objectAtIndex:2] rangeOfString:@"g"].location != NSNotFound)
		                          error:nil];
	}

	return trSymbol;
}

@end

