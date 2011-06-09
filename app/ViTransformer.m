#import "ViTransformer.h"
#import "ViError.h"
#import "NSScanner-additions.h"
#include "logging.h"

@implementation ViTransformer

#define RXFLAG_UPPERCASE_ONCE	1
#define RXFLAG_LOWERCASE_ONCE	2
#define RXFLAG_UPPERCASE	4
#define RXFLAG_LOWERCASE	8

#define test(wp, f)		((((*wp)) & (f)) == (f))

- (void)appendString:(NSString *)source
            toString:(NSMutableString *)target
            caseFold:(NSUInteger *)flags
{
	if ([source length] == 0)
		return;

	if (test(flags, RXFLAG_UPPERCASE_ONCE)) {
		[target appendString:[[source substringWithRange:NSMakeRange(0, 1)] uppercaseString]];
		[target appendString:[source substringFromIndex:1]];
		*flags &= ~RXFLAG_UPPERCASE_ONCE;
	} else if (test(flags, RXFLAG_UPPERCASE_ONCE)) {
		[target appendString:[[source substringWithRange:NSMakeRange(0, 1)] lowercaseString]];
		[target appendString:[source substringFromIndex:1]];
		*flags &= ~RXFLAG_LOWERCASE_ONCE;
	} else if (test(flags, RXFLAG_UPPERCASE)) {
		[target appendString:[source uppercaseString]];
	} else if (test(flags, RXFLAG_LOWERCASE)) {
		[target appendString:[source lowercaseString]];
	} else
		[target appendString:source];
}

- (NSString *)expandFormat:(NSString *)format
                 withMatch:(ViRegexpMatch *)m
                 stopChars:(NSString *)stopChars
            originalString:(NSString *)value
             scannedLength:(NSUInteger *)scannedLength
                     error:(NSError **)outError
{
	NSScanner *scan = [NSScanner scannerWithString:format];
	[scan setCharactersToBeSkipped:nil];

	NSMutableString *s = [NSMutableString string];
	unichar ch;
	NSUInteger flags = 0;
	while ([scan scanCharacter:&ch]) {
		NSInteger capture = -1;
		if (ch == '\\') {
			/* Skip the backslash escape if it's followed by a reserved character. */
			if ([scan scanCharacter:&ch]) {
				if (ch == 'u' || ch == 'U' || ch == 'l' || ch == 'L' || ch == 'E') {
					switch (ch) {
					case 'u':
						flags |= RXFLAG_UPPERCASE_ONCE;
						flags &= ~RXFLAG_LOWERCASE_ONCE;
						break;
					case 'U':
						flags |= RXFLAG_UPPERCASE;
						flags &= ~RXFLAG_LOWERCASE;
						break;
					case 'l':
						flags &= ~RXFLAG_UPPERCASE_ONCE;
						flags |= RXFLAG_LOWERCASE_ONCE;
						break;
					case 'L':
						flags &= ~RXFLAG_UPPERCASE;
						flags |= RXFLAG_LOWERCASE;
						break;
					case 'E':
						flags &= ~RXFLAG_UPPERCASE;
						flags &= ~RXFLAG_LOWERCASE;
						break;
					}
				} else {
					NSString *insChar = [NSString stringWithFormat:@"%C", ch];
					if (ch == 'n')
						insChar = @"\n";
					else if (ch == 't')
						insChar = @"\t";
					else if (ch != '$' && ch != '\\' && ch != '(' &&
					    [stopChars rangeOfString:insChar].location == NSNotFound)
						[self appendString:@"\\" toString:s caseFold:&flags];
					[self appendString:insChar toString:s caseFold:&flags];
				}
			} else
				[self appendString:@"\\" toString:s caseFold:&flags];
		} else if (ch == '$') {
			if (![scan scanInteger:&capture])
				[s appendString:@"$"];
			else if (capture < 0) {
				if (outError)
					*outError = [ViError errorWithFormat:
					    @"Negative capture group not allowed."];
				return nil;
			} else {
				NSRange r = [m rangeOfSubstringAtIndex:capture];
				DEBUG(@"got capture %i range %@ in string [%@]",
				    capture, NSStringFromRange(r), value);
				if (r.location != NSNotFound) {
					NSString *captureValue = [value substringWithRange:r];
					[self appendString:captureValue toString:s caseFold:&flags];
				}
			}
		} else if (ch == '(' &&
		    [scan scanString:@"?" intoString:nil] &&
		    [scan scanInteger:&capture] &&
		    [scan scanString:@":" intoString:nil]) {
			if (capture < 0) {
				if (outError)
					*outError = [ViError errorWithFormat:
					    @"Capture group in conditional insertion block is negative: %li",
					    capture];
				return nil;
			}

			NSString *conditionalString = [format substringFromIndex:[scan scanLocation]];
			NSUInteger len = 0;
			NSString *insertion = [self expandFormat:conditionalString 
			                               withMatch:m
			                               stopChars:@":)"
			                          originalString:value
			                           scannedLength:&len
			                                   error:outError];
			if (insertion == nil)
				return nil;
			DEBUG(@"nested parse scanned %lu characters and returned [%@]", len, insertion);
			[scan setScanLocation:[scan scanLocation] + len];

			NSString *otherwise = @"";
			if ([scan scanString:@":" intoString:nil]) {
				conditionalString = [format substringFromIndex:[scan scanLocation]];
				len = 0;
				otherwise = [self expandFormat:conditionalString
				                     withMatch:m
				                     stopChars:@")"
				                originalString:value
				                 scannedLength:&len
				                         error:outError];
				if (otherwise == nil)
					return nil;
				DEBUG(@"nested parse scanned %lu characters and returned [%@]", len, otherwise);
				[scan setScanLocation:[scan scanLocation] + len];
			}

			if (![scan scanString:@")" intoString:nil]) {
				if (outError)
					*outError = [ViError errorWithFormat:
					    @"Missing closing parenthesis for conditional insertion at %lu",
					    [scan scanLocation] + 1];
				return nil;
			}

			NSRange r = [m rangeOfSubstringAtIndex:capture];
			if (r.location != NSNotFound)
				[self appendString:insertion toString:s caseFold:&flags];
			else
				[self appendString:otherwise toString:s caseFold:&flags];
		} else {
			NSString *insChar = [NSString stringWithFormat:@"%C", ch];
			if ([stopChars rangeOfString:insChar].location != NSNotFound) {
				[scan setScanLocation:[scan scanLocation] - 1];
				break;
			}
			[self appendString:insChar toString:s caseFold:&flags];
		}
	}

	DEBUG(@"expanded format [%@] -> [%@]", format, s);

	if (scannedLength)
		*scannedLength = [scan scanLocation];

	return s;
}

- (NSString *)transformValue:(NSString *)value
                 withPattern:(ViRegexp *)rx
                      format:(NSString *)format
                     options:(NSString *)options
                       error:(NSError **)outError
{
	id text = value;
	BOOL copied = NO;
	NSUInteger begin = 0;
	for (;;) {
		NSRange r = NSMakeRange(begin, [text length] - begin);
		DEBUG(@"matching rx %@ in range %@ in string [%@]",
		    rx, NSStringFromRange(r), text);
		if (r.length == 0)
			break;
		ViRegexpMatch *m = [rx matchInString:text range:r];
		DEBUG(@"m = %@", m);
		if (m == nil)
			break;
		r = [m rangeOfMatchedString];
		DEBUG(@"matched range %@", NSStringFromRange(r));
		if (r.location == NSNotFound)
			break;
		if (!copied) {
			text = [value mutableCopy];
			copied = YES;
		}
		NSString *expFormat = [self expandFormat:format
		                               withMatch:m
		                               stopChars:@""
		                          originalString:text
		                           scannedLength:nil
		                                   error:outError];
		if (expFormat == nil) {
			if (outError)
				return nil;
			expFormat = @"";
		}
		begin = r.location + [expFormat length];
		if (begin == r.location && r.length == 0 && begin < [text length])
			++begin; /* prevent infinite loops */
		DEBUG(@"replace range %@ in string [%@] with expanded format [%@]",
		    NSStringFromRange(r), text, expFormat);
		[text replaceCharactersInRange:r withString:expFormat];

		if (options == nil || [options rangeOfString:@"g"].location == NSNotFound)
			break;
	}
	DEBUG(@"transformed [%@] -> [%@]", value, text);
	return text;
}

@end

