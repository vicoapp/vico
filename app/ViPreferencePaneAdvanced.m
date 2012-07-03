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

#import "ViPreferencePaneAdvanced.h"
#include "logging.h"

@implementation environmentVariableTransformer
+ (Class)transformedValueClass { return [NSDictionary class]; }
+ (BOOL)allowsReverseTransformation { return YES; }
- (id)init { return [super init]; }
- (id)transformedValue:(id)value
{
	if ([value isKindOfClass:[NSDictionary class]]) {
		/* Create an array of dictionaries with keys "name" and "value". */
		NSMutableArray *a = [NSMutableArray array];
		NSDictionary *dict = value;
		NSArray *keys = [[dict allKeys] sortedArrayUsingComparator:^(id a, id b) {
			return [(NSString *)a compare:b];
		}];
		for (NSString *key in keys) {
			[a addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[[key mutableCopy] autorelease], @"name",
				[[[dict objectForKey:key] mutableCopy] autorelease], @"value",
				nil]];
		}
		return a;
	} else if ([value isKindOfClass:[NSArray class]]) {
		NSArray *a = [(NSArray *)value sortedArrayUsingComparator:^(id a, id b) {
			return [[(NSDictionary *)a objectForKey:@"name"] compare:[(NSDictionary *)b objectForKey:@"name"]];
		}];
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		for (NSDictionary *pair in a) {
			NSMutableString *key = [[[pair objectForKey:@"name"] mutableCopy] autorelease];
			NSMutableString *value = [[[pair objectForKey:@"value"] mutableCopy] autorelease];
			[dict setObject:value forKey:key];
		}
		return dict;
	}

	return nil;
}
@end

@implementation ViPreferencePaneAdvanced

- (id)init
{
	self = [super initWithNibName:@"AdvancedPrefs"
				 name:@"Advanced"
				 icon:[NSImage imageNamed:NSImageNameAdvanced]];
	if (self != nil) {
		[NSValueTransformer setValueTransformer:[[[environmentVariableTransformer alloc] init] autorelease]
						forName:@"environmentVariableTransformer"];
	}

	return self;
}

- (IBAction)addVariable:(id)sender
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[[@"name" mutableCopy] autorelease], @"name",
		[[@"value" mutableCopy] autorelease], @"value",
		nil];

	[arrayController addObject:dict];
	[arrayController setSelectedObjects:[NSArray arrayWithObject:dict]];
	[tableView editColumn:0 row:[arrayController selectionIndex] withEvent:nil select:YES];
}

@end
