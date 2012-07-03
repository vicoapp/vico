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

#import "NSURL-additions.h"
#import "ViURLManager.h"
#include "logging.h"

@implementation NSURL (equality)

static NSCharacterSet *__slashSet = nil;

- (BOOL)isEqualToURL:(NSURL *)otherURL
{
	return [self isEqual:otherURL];
#if 0
	if (__slashSet == nil)
		__slashSet = [[NSCharacterSet characterSetWithCharactersInString:@"/"] retain];

	NSString *s1 = [[self absoluteString] stringByTrimmingCharactersInSet:__slashSet];
	NSString *s2 = [[otherURL absoluteString] stringByTrimmingCharactersInSet:__slashSet];
	return [s1 isEqualToString:s2];
#endif
}

- (BOOL)hasPrefix:(NSURL *)prefixURL
{
	if (__slashSet == nil)
		__slashSet = [[NSCharacterSet characterSetWithCharactersInString:@"/"] retain];

	NSString *s1 = [[self absoluteString] stringByTrimmingCharactersInSet:__slashSet];
	NSString *s2 = [[prefixURL absoluteString] stringByTrimmingCharactersInSet:__slashSet];
	return [s1 hasPrefix:s2];
}

- (NSURL *)URLWithRelativeString:(NSString *)string
{
	return [[NSURL URLWithString:[string stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
		       relativeToURL:self] absoluteURL];
}

- (NSString *)displayString
{
	return [[ViURLManager defaultManager] stringByAbbreviatingWithTildeInPath:self];
}

/*
 * Copied from a post by Sean McBride.
 * http://www.cocoabuilder.com/archive/cocoa/301899-dealing-with-alias-files-finding-url-to-target-file.html
 */
- (NSURL *)URLByResolvingSymlinksAndAliases:(BOOL *)isAliasPtr
{
	NSURL *url = self;

	if ([self isFileURL]) {
		url = [self URLByResolvingSymlinksInPath];

		NSNumber *isAliasFile = nil;
		BOOL success = [url getResourceValue:&isAliasFile
					       forKey:NSURLIsAliasFileKey
						error:NULL];
		if (success && [isAliasFile boolValue]) {
			NSData *bookmarkData = [NSURL bookmarkDataWithContentsOfURL:url error:NULL];
			if (bookmarkData) {
				NSURL *resolvedURL = [NSURL URLByResolvingBookmarkData:bookmarkData
									       options:(NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting)
									 relativeToURL:nil
								   bookmarkDataIsStale:NULL
										 error:NULL];
				if (isAliasPtr) {
					*isAliasPtr = YES;
				}

				/* Don't return file reference URLs, make it a plain file URL. */
				return [[[NSURL fileURLWithPath:[resolvedURL path]] URLByStandardizingPath] absoluteURL];
			}
		}
	}
	if (isAliasPtr) {
		*isAliasPtr = NO;
	}
	return url;
}

@end
