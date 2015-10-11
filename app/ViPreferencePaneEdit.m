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

#import "ViPreferencePaneEdit.h"
#import "ViBundleStore.h"
#import "NSString-additions.h"
#import "NSString-scopeSelector.h"
#include "logging.h"

@implementation ViPreferencePaneEdit

- (NSMenuItem *)addScope:(NSString *)scope
{
	DEBUG(@"adding scope %@", scope);
	NSMenu *menu = [scopeButton menu];
	if ([menu numberOfItems] == 3)
		[menu insertItem:[NSMenuItem separatorItem] atIndex:1];

	[scopeButton insertItemWithTitle:scope atIndex:2];
	NSMenuItem *item = [scopeButton itemAtIndex:2];
	[item setAction:@selector(selectScope:)];
	[item setTarget:self];
	return item;
}

- (id)init
{
	self = [super initWithNibName:@"EditPrefs"
				 name:@"Editing"
				 icon:[NSImage imageNamed:NSImageNameMultipleDocuments]];
    
    _preferences = [[NSMutableSet alloc] init];

	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSDictionary *prefs = [defs dictionaryForKey:@"scopedPreferences"];
	for (NSString *scope in [prefs allKeys])
		[self addScope:scope];

	[scopeButton selectItemAtIndex:0];

	return self;
}


- (IBAction)selectScope:(id)aSender
{
	NSMenuItem *sender = (NSMenuItem *)aSender;
	[scopeButton selectItem:sender];
	[revertButton setEnabled:[sender tag] != -2];

	DEBUG(@"refreshing preferences %@", _preferences);
	for (NSString *key in _preferences) {
		[self willChangeValueForKey:key];
		[self didChangeValueForKey:key];
	}
}

- (void)notifyPreferencesChanged
{
	[[NSNotificationCenter defaultCenter] postNotificationName:ViEditPreferenceChangedNotification
							    object:nil
							  userInfo:nil];
}

- (void)initPreferenceScope:(NSString *)scope
{
	if ([scope length] == 0)
		return;

	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *prefs = [[defs dictionaryForKey:@"scopedPreferences"] mutableCopy];
	if (prefs == nil)
		prefs = [NSMutableDictionary dictionary];

	NSMutableDictionary *scopedPrefs = [NSMutableDictionary dictionary];
	for (NSString *key in _preferences)
		[scopedPrefs setObject:[defs objectForKey:key] forKey:key];
	[prefs setObject:scopedPrefs forKey:scope];
	[defs setObject:prefs forKey:@"scopedPreferences"];

	[self notifyPreferencesChanged];
}

- (void)deletePreferenceScope:(NSString *)scope
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *prefs = [[defs dictionaryForKey:@"scopedPreferences"] mutableCopy];
	if (prefs == nil)
		return;
	[prefs removeObjectForKey:scope];
	[defs setObject:prefs forKey:@"scopedPreferences"];

	[self notifyPreferencesChanged];
}

- (void)revertSheetDidEnd:(NSAlert *)alert
               returnCode:(int)returnCode
              contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn) {
		/* Copy preferences from defaults. */
		[self initPreferenceScope:[scopeButton titleOfSelectedItem]];
		[self selectScope:[scopeButton selectedItem]];
	} else if (returnCode == NSAlertSecondButtonReturn) {
		/* Delete preference scope. */
		[self deletePreferenceScope:[scopeButton titleOfSelectedItem]];
		[scopeButton removeItemAtIndex:[scopeButton indexOfSelectedItem]];
		if ([[scopeButton itemAtIndex:1] isSeparatorItem] &&
		    [[scopeButton itemAtIndex:2] isSeparatorItem])
			[scopeButton removeItemAtIndex:1];
		[self selectScope:[scopeButton itemAtIndex:0]];
	}
}

- (IBAction)revertPreferenceScope:(id)sender
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:@"Do you want to delete this scope or copy from defaults?"];
	[alert addButtonWithTitle:@"Copy"];
	[alert addButtonWithTitle:@"Delete"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setInformativeText:[NSString stringWithFormat:@"If you delete the preferences for this scope (%@), the defaults will be used instead.", [scopeButton titleOfSelectedItem]]];
	[alert beginSheetModalForWindow:[view window]
		    modalDelegate:self
		   didEndSelector:@selector(revertSheetDidEnd:returnCode:contextInfo:)
		      contextInfo:NULL];
}

- (IBAction)acceptNewPreferenceScope:(id)sender
{
	NSString *scope = [prefScope stringValue];
	[self initPreferenceScope:scope];
	[self selectScope:[self addScope:scope]];
	[NSApp endSheet:newPrefScopeSheet];
}

- (IBAction)cancelNewPreferenceScope:(id)sender
{
	[self selectScope:[scopeButton itemAtIndex:0]];
	[NSApp endSheet:newPrefScopeSheet];
}

- (IBAction)selectPrefLanguage:(id)sender
{
	ViLanguage *lang = [sender representedObject];
	NSString *scope = @"";
	if (lang)
		scope = [lang name];
	[prefScope setStringValue:scope];
	[newScopeButton setEnabled:[scope length] > 0];
}

- (void)sheetDidEnd:(NSWindow *)sheet
         returnCode:(int)returnCode
        contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

- (void)updatePrefScope
{
	NSString *scope = [prefScope stringValue];
	[newScopeButton setEnabled:[scope length] > 0];
	ViLanguage *lang = [[ViBundleStore defaultStore] languageWithScope:scope];
	if (lang)
		[prefLanguage selectItemAtIndex:[[prefLanguage menu] indexOfItemWithRepresentedObject:lang]];
	else
		[prefLanguage selectItemWithTag:-1]; /* Select the "Custom" item. */
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if ([aNotification object] != prefScope)
		return;
	[self updatePrefScope];
}

- (IBAction)selectNewPreferenceScope:(id)sender
{
	NSMenu *menu = [prefLanguage menu];
	while ([[menu itemAtIndex:0] tag] == 0)
		[menu removeItemAtIndex:0];

	NSArray *sortedLanguages = [[ViBundleStore defaultStore] sortedLanguages];

	/* FIXME: This is the same code as in the ViTextView action menu. */
	int i = 0;
	for (ViLanguage *lang in sortedLanguages) {
		NSMenuItem *item;
		item = [menu insertItemWithTitle:[lang displayName]
					  action:@selector(selectPrefLanguage:)
				   keyEquivalent:@""
					 atIndex:i++];
		[item setRepresentedObject:lang];
		[item setTarget:self];
	}

	//[prefLanguage setStringValue:@""];
	[self updatePrefScope];

	[NSApp beginSheet:newPrefScopeSheet
	   modalForWindow:[view window]
	    modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];
}

#pragma mark -
#pragma mark Responding to preference keys

- (id)valueForUndefinedKey:(NSString *)key
{
	if (![_preferences containsObject:key])
		[_preferences addObject:key];

	if ([[scopeButton selectedItem] tag] == -2) {
		DEBUG(@"getting default preference %@", key);
		return [[NSUserDefaults standardUserDefaults] valueForKey:key];
	}

	NSString *scope = [scopeButton titleOfSelectedItem];
	DEBUG(@"getting preference %@ in scope %@", key, scope);
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSDictionary *prefs = [defs dictionaryForKey:@"scopedPreferences"];
	NSDictionary *scopedPrefs = [prefs objectForKey:scope];
	return [scopedPrefs valueForKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	if ([[scopeButton selectedItem] tag] == -2) {
		DEBUG(@"setting preference %@ to %@", key, value);
		[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
		return;
	}

	NSString *scope = [scopeButton titleOfSelectedItem];
	DEBUG(@"setting preference %@ to %@ in scope %@", key, value, scope);
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *prefs = [[defs dictionaryForKey:@"scopedPreferences"] mutableCopy];
	NSMutableDictionary *scopedPrefs = [[prefs objectForKey:scope] mutableCopy];
	[scopedPrefs setObject:value forKey:key];
	[prefs setObject:scopedPrefs forKey:scope];
	[defs setObject:prefs forKey:@"scopedPreferences"];

	[self notifyPreferencesChanged];
}

+ (id)valueForKey:(NSString *)key inScope:(ViScope *)scope
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

	if (scope) {
		NSDictionary *prefs = [defs dictionaryForKey:@"scopedPreferences"];
		NSString *selector = [scope bestMatch:[prefs allKeys]];
		if (selector) {
			NSDictionary *scopedPrefs = [prefs objectForKey:selector];
			return [scopedPrefs objectForKey:key];
		}
	}

	/* No scopes matched. Return default setting. */
	return [defs objectForKey:key];
}

@end
