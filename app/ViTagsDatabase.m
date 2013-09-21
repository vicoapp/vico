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

#import "ViTagsDatabase.h"
#import "ViURLManager.h"
#import "NSScanner-additions.h"
#import "NSURL-additions.h"
#include "logging.h"

@implementation ViTagsDatabase

@synthesize baseURL = _baseURL;
@synthesize databaseURL = _databaseURL;
@synthesize modificationDate = _modificationDate;

- (ViTagsDatabase *)initWithBaseURL:(NSURL *)aURL
{
	if ((self = [super init]) != nil) {
		_baseURL = aURL;
		_tags = [[NSMutableDictionary alloc] init];
	}
	return self;
}


- (void)onOpen:(void (^)(NSError *error))aBlock
{
	/* If the file is not an absolute path, try to find it in the current directory.
	 * Look in parent directories if not found.
	 */
	ViURLManager *um = [ViURLManager defaultManager];
#if 0
	prefixPath = [aDirectory copy];
	DEBUG(@"prefix path = [%@]", prefixPath);
	NSString *path = nil;
	if (![aFile isAbsolutePath]) {
		NSString *component;
		NSString *p = nil;
		for (component in [prefixPath pathComponents]) {
			if (p)
				p = [p stringByAppendingPathComponent:component];
			else
				p = component;

			NSString *check = [p stringByAppendingPathComponent:aFile];
			DEBUG(@"checking for tags file [%@]", check);
			if ([fm fileExistsAtPath:check]) {
				/* We found a tags file. There might be more files
				 * closer to the current directory so we continue looking.
				 */
				path = check;
				prefixPath = p;
			}
		}
	} else {
		path = aFile;
	}
#endif
	
	NSURL *url = [_baseURL URLByAppendingPathComponent:@"tags"];
	DEBUG(@"opening tags file [%@]", url);

	NSMutableData *tagsData = [NSMutableData data];
	void (^dataCallback)(NSData *data) = ^(NSData *data) {
		[tagsData appendData:data];
	};

	[um dataWithContentsOfURL:url onData:dataCallback onCompletion:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		if (!error) {
			[self setModificationDate:[attributes fileModificationDate]];
			DEBUG(@"got modtime %@", _modificationDate);
			[self setDatabaseURL:normalizedURL];
			[self parseData:tagsData];
		}
		aBlock(error);
	}];
}

- (void)parseData:(NSData *)data
{
	NSString *strdata = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (strdata == nil)
		strdata = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];

	NSCharacterSet *tabSet = [NSCharacterSet characterSetWithCharactersInString:@"\t"];

	NSString *line;
	for (line in [strdata componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		NSScanner *scan = [NSScanner scannerWithString:line];
		[scan setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];

		NSString *symbol;
		NSString *file;
		NSString *pattern;

		if ([scan scanUpToString:@"\t" intoString:&symbol] &&
		    [scan scanCharactersFromSet:tabSet intoString:nil] &&
		    [scan scanUpToString:@"\t" intoString:&file] &&
		    [scan scanCharactersFromSet:tabSet intoString:nil] &&
		    [scan scanString:@"/" intoString:nil] &&
		    [scan scanUpToUnescapedCharacter:'/' intoString:&pattern stripEscapes:YES]) {
			NSURL *url = [_baseURL URLWithRelativeString:file];
			DEBUG(@"got symbol [%@] in file [%@], pattern [%@]", symbol, url, pattern);
			[_tags setObject:[NSArray arrayWithObjects:url, pattern, nil] forKey:symbol];
		} else
			DEBUG(@"skipping tags line [%@]", line);
	}
}

- (void)onDatabaseChanged:(void (^)(NSError *error))aBlock
{
	DEBUG(@"checking if %@ has change modtime from %@", _databaseURL, _modificationDate);
	[[ViURLManager defaultManager] attributesOfItemAtURL:_databaseURL
						onCompletion:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		if (error)
			aBlock(error);
		if ([_modificationDate isEqualToDate:[attributes fileModificationDate]]) {
			DEBUG(@"tags file %@ unmodified: %@", normalizedURL, _modificationDate);
			aBlock(nil);
		} else
			[self onOpen:aBlock];
	}];
}

- (void)lookup:(NSString *)symbol onCompletion:(void (^)(NSArray *tag, NSError *error))aBlock
{
	void (^fun)(NSError *error) = ^(NSError *error) {
		if (error)
			aBlock(nil, error);
		else
			aBlock([_tags objectForKey:symbol], nil);
	};

	DEBUG(@"looking up symbol %@", symbol);
	if (_modificationDate)
		[self onDatabaseChanged:fun];
	else
		[self onOpen:fun];
}

@end
