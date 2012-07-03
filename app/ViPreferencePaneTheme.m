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

#import "ViPreferencePaneTheme.h"
#import "ViThemeStore.h"
#include "logging.h"

@implementation ViPreferencePaneTheme

- (id)init
{
	self = [super initWithNibName:@"ThemePrefs"
				 name:@"Fonts & Colors"
				 icon:[NSImage imageNamed:NSImageNameColorPanel]];
	if (self == nil)
		return nil;

	ViThemeStore *ts = [ViThemeStore defaultStore];
	NSArray *themes = [ts availableThemes];
	for (NSString *theme in [themes sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)])
		[themeButton addItemWithTitle:theme];
	[themeButton selectItem:[themeButton itemWithTitle:[[ts defaultTheme] name]]];

	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"fontsize"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"fontname"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];

	[self setSelectedFont];

	return self;
}

#pragma mark -
#pragma mark Font selection

- (void)setSelectedFont
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	[currentFont setStringValue:[NSString stringWithFormat:@"%@ %.1fpt",
	    [defs stringForKey:@"fontname"],
	    [defs floatForKey:@"fontsize"]]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context
{
//	if ([keyPath isEqualToString:@"fontsize"] || [keyPath isEqualToString:@"fontname"])
	[self setSelectedFont];
}

- (IBAction)selectFont:(id)sender
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFont *font = [NSFont fontWithName:[defs stringForKey:@"fontname"]
				       size:[defs floatForKey:@"fontsize"]];
	[fontManager setTarget:self];
	[fontManager setSelectedFont:font isMultiple:NO];
	[fontManager orderFrontFontPanel:nil];
}

- (void)changeAttributes:(id)sender
{
	DEBUG(@"sender is %@", sender);
}

- (void)changeFont:(id)sender
{
	DEBUG(@"sender is %@", sender);
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFont *font = [fontManager convertFont:[fontManager selectedFont]];
	[[NSUserDefaults standardUserDefaults] setObject:[font fontName]
						  forKey:@"fontname"];
	NSNumber *fontSize = [NSNumber numberWithFloat:[font pointSize]];
	[[NSUserDefaults standardUserDefaults] setObject:fontSize
						  forKey:@"fontsize"];
}

@end
