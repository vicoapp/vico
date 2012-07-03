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

#import "ViSymbolTransform.h"
#import "ViRegexp.h"
#import "NSScanner-additions.h"
#import "logging.h"

@implementation ViSymbolTransform

- (ViSymbolTransform *)initWithTransformationString:(NSString *)aString
{
	if ((self = [super init]) != nil) {
		_transformations = [[NSMutableArray alloc] init];

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

				ViRegexp *rx = [ViRegexp regexpWithString:regexp];
				if (rx == nil) {
					INFO(@"invalid regexp: %@", regexp);
					return nil;
				}

				[_transformations addObject:[NSArray arrayWithObjects:rx, format, options, nil]];
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

- (void)dealloc
{
	[_transformations release];
	[super dealloc];
}

- (NSString *)transformSymbol:(NSString *)aSymbol
{
	NSString *trSymbol = aSymbol;
	NSArray *tr;
	for (tr in _transformations) {
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

