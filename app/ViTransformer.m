/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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

- (void)affectedLines:(NSUInteger *)affectedLines
		 replacements:(NSUInteger *)replacements
whenTransformingValue:(NSString *)value
		  withPattern:(ViRegexp *)rx
			   global:(BOOL)global
{
	*affectedLines = 0;
	*replacements = 0;

	ViRegexpMatch *match = [rx matchInString:value];
	NSUInteger nextNewline = 0;
	NSRange matchedRange;
	while (match && (matchedRange = [match rangeOfMatchedString]).location != NSNotFound) {
		NSUInteger nextStart = NSMaxRange(matchedRange);
		if (matchedRange.length == 0)
		  nextStart += 1;

		if (!global && nextStart < value.length) {
			(*affectedLines)++;
			
			nextStart = nextNewline = [value rangeOfString:@"\n" options:0 range:NSMakeRange(nextStart, [value length] - nextStart)].location;
		} else if (nextStart > nextNewline && nextStart < value.length) {
			(*affectedLines)++;

			nextNewline = [value rangeOfString:@"\n" options:0 range:NSMakeRange(nextStart, [value length] - nextStart)].location;
		}
		
		(*replacements)++;

		if (nextStart >= [value length]) {
		  match = nil;
		} else {
		  match = [rx matchInString:value range:NSMakeRange(nextStart, [value length] - nextStart)];
		}
	}
}

- (NSString *)transformValue:(NSString *)value
				 withPattern:(ViRegexp *)rx
				      format:(NSString *)format
					  global:(BOOL)global
					   error:(NSError **)outError
		   lastReplacedRange:(NSRange *)lastReplacedRange
			   affectedLines:(NSUInteger *)affectedLines
				replacements:(NSUInteger *)replacements
{
	if (affectedLines)
		*affectedLines = 0;
	if (replacements)
		*replacements = 0;

	BOOL copied = NO;
	id text = value;
	ViRegexpMatch *match = [rx matchInString:value];
	NSUInteger nextNewline = 0;
	NSRange matchedRange;
	while (match && (matchedRange = [match rangeOfMatchedString]).location != NSNotFound) {
		if (!copied) {
			text = [[value mutableCopy] autorelease];
			copied = YES;
		}

		NSString *expandedFormat =
		  [self expandFormat:format
				   withMatch:match
				   stopChars:@""
			  originalString:text
			   scannedLength:nil
					   error:outError];

		if (expandedFormat == nil) {
			if (outError)
				return nil;

			expandedFormat = @"";
		}

		DEBUG(@"replace range %@ in string [%@] with expanded format [%@] from regex %@",
		    NSStringFromRange(matchedRange), text, expandedFormat, rx);
		[text replaceCharactersInRange:matchedRange withString:expandedFormat];
		if (lastReplacedRange)
		  *lastReplacedRange = NSMakeRange(matchedRange.location, expandedFormat.length);

		NSUInteger nextStart = matchedRange.location + expandedFormat.length;
		if (matchedRange.length == 0)
		  nextStart += 1;

		if (!global && nextStart < [text length]) {
			if (affectedLines)
				(*affectedLines)++;
			
			nextStart = nextNewline = [text rangeOfString:@"\n" options:0 range:NSMakeRange(nextStart, [text length] - nextStart)].location;
		} else if (nextStart > nextNewline && nextStart < [text length]) {
			if (affectedLines)
				(*affectedLines)++;

			nextNewline = [text rangeOfString:@"\n" options:0 range:NSMakeRange(nextStart, [text length] - nextStart)].location;
		}

		if (replacements)
			(*replacements)++;

		if (nextStart >= [text length]) {
		  match = nil;
		} else {
		  match = [rx matchInString:text range:NSMakeRange(nextStart, [text length] - nextStart)];
		}
	}

	DEBUG(@"transformed [%@] -> [%@]", value, text);
	return text;
}

- (NSString *)transformValue:(NSString *)value
                 withPattern:(ViRegexp *)rx
                      format:(NSString *)format
                      global:(BOOL)global
                       error:(NSError **)outError
{
	return
	  [self transformValue:value
			   withPattern:rx
					format:format
					global:global
					 error:outError
		 lastReplacedRange:nil
			 affectedLines:nil
			  replacements:nil];
}

@end

