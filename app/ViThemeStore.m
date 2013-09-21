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

#import "ViThemeStore.h"
#import "ViAppController.h"
#import "logging.h"

@implementation ViThemeStore

+ (ViTheme *)defaultTheme
{
	return [[ViThemeStore defaultStore] defaultTheme];
}

+ (NSFont *)font
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSFont *font = [NSFont fontWithName:[defs stringForKey:@"fontname"]
	                               size:[defs floatForKey:@"fontsize"]];
	if (font == nil)
		font = [NSFont userFixedPitchFontOfSize:11.0];
	return font;
}

- (ViTheme *)defaultTheme
{
	ViTheme *defaultTheme = nil;

	NSString *themeName = [[NSUserDefaults standardUserDefaults] objectForKey:@"theme"];
	if (themeName)
		defaultTheme = [self themeWithName:themeName];

	if (defaultTheme == nil) {
		defaultTheme = [self themeWithName:@"Sunset"];
		if (defaultTheme == nil)
			defaultTheme = [[_themes allValues] objectAtIndex:0];
	}

	return defaultTheme;
}

+ (ViThemeStore *)defaultStore
{
	static ViThemeStore *__defaultStore = nil;
	if (__defaultStore == nil)
		__defaultStore = [[ViThemeStore alloc] init];
	return __defaultStore;
}

- (void)addThemeWithPath:(NSString *)path
{
	ViTheme *theme = [[ViTheme alloc] initWithPath:path];
	if (theme)
		[_themes setObject:theme forKey:[theme name]];
}

- (void)addThemesFromBundleDirectory:(NSString *)aPath
{
	BOOL isDirectory = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:aPath isDirectory:&isDirectory] && isDirectory) {
		NSArray *themeFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:aPath error:NULL];
		NSString *themeFile;
		for (themeFile in themeFiles) {
			if ([themeFile hasSuffix:@".tmTheme"])
				[self addThemeWithPath:[NSString stringWithFormat:@"%@/%@", aPath, themeFile]];
		}
	}
}

- (id)init
{
	if ((self = [super init]) != nil) {
		_themes = [[NSMutableDictionary alloc] init];

		[self addThemesFromBundleDirectory:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Themes"]];

		NSURL *url;
		url = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
							     inDomain:NSUserDomainMask
						    appropriateForURL:nil
							       create:NO
								error:nil];
		if (url)
			[self addThemesFromBundleDirectory:[[url path] stringByAppendingPathComponent:@"TextMate/Themes"]];

		[self addThemesFromBundleDirectory:[[ViAppController supportDirectory] stringByAppendingPathComponent:@"Themes"]];
	}
	return self;
}

- (NSArray *)availableThemes
{
	return [_themes allKeys];
}

- (ViTheme *)themeWithName:(NSString *)aName
{
	return [_themes objectForKey:aName];
}

@end
