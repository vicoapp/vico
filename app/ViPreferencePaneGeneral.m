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

#import "ViPreferencePaneGeneral.h"
#import "ViBundleStore.h"

@implementation undoStyleTagTransformer
+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return YES; }
- (id)init { return [super init]; }
- (id)transformedValue:(id)value
{
	if ([value isKindOfClass:[NSNumber class]]) {
		switch ([value integerValue]) {
		case 2:
			return @"nvi";
		case 1:
		default:
			return @"vim";
		}
	} else if ([value isKindOfClass:[NSString class]]) {
		int tag = 1;
		if ([value isEqualToString:@"nvi"])
			tag = 2;
		return [NSNumber numberWithInt:tag];
	}

	return nil;
}
@end

@implementation ViPreferencePaneGeneral

- (id)init
{
	self = [super initWithNibName:@"GeneralPrefs"
				 name:@"General"
				 icon:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
	if (self == nil)
		return nil;

	/* Convert between tags and undo style strings (vim and nvi). */
	[NSValueTransformer setValueTransformer:[[undoStyleTagTransformer alloc] init]
					forName:@"undoStyleTagTransformer"];

	[defaultSyntaxButton removeAllItems];
	NSArray *sortedLanguages = [[ViBundleStore defaultStore] sortedLanguages];
	for (ViLanguage *lang in sortedLanguages) {
		NSMenuItem *item;
		item = [[defaultSyntaxButton menu] addItemWithTitle:[lang displayName] action:nil keyEquivalent:@""];
		[item setRepresentedObject:[lang name]];
	}

	NSString *defaultName = [[[ViBundleStore defaultStore] defaultLanguage] displayName];
	if (defaultName)
		[defaultSyntaxButton selectItemWithTitle:defaultName];

	return self;
}

@end
