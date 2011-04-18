#import "ViPreferencePaneEdit.h"
#import "ViBundleStore.h"
#import "NSString-additions.h"
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
	preferences = [NSMutableSet set];

	self = [super initWithNibName:@"EditPrefs"
				 name:@"Text Editing"
				 icon:[NSImage imageNamed:NSImageNameMultipleDocuments]];

	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSDictionary *prefs = [defs dictionaryForKey:@"scopedPreferences"];
	for (NSString *scope in [prefs allKeys])
		[self addScope:scope];

	[scopeButton selectItemAtIndex:0];

	return self;
}

- (IBAction)selectScope:(id)sender
{
	[scopeButton selectItem:sender];
	[revertButton setEnabled:[sender tag] != -2];

	DEBUG(@"refreshing preferences %@", preferences);
	for (NSString *key in preferences) {
		[self willChangeValueForKey:key];
		[self didChangeValueForKey:key];
	}
}

- (void)initPreferenceScope:(NSString *)scope
{
	if ([scope length] == 0)
		return;

	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *prefs = [[defs dictionaryForKey:@"scopedPreferences"] mutableCopy];
	if (prefs == nil)
		prefs = [NSMutableDictionary dictionary];
	NSMutableDictionary *scopedPrefs = [[prefs objectForKey:scope] mutableCopy];

	scopedPrefs = [NSMutableDictionary dictionary];
	for (NSString *key in preferences)
		[scopedPrefs setObject:[defs objectForKey:key] forKey:key];
	[prefs setObject:scopedPrefs forKey:scope];
	[defs setObject:prefs forKey:@"scopedPreferences"];
}

- (void)deletePreferenceScope:(NSString *)scope
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *prefs = [[defs dictionaryForKey:@"scopedPreferences"] mutableCopy];
	if (prefs == nil)
		return;
	[prefs removeObjectForKey:scope];
	[defs setObject:prefs forKey:@"scopedPreferences"];
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

	/* FIXME: This is the same code as in the ViTextView action menu. */
	NSArray *languages = [[ViBundleStore defaultStore] languages];
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc]
	    initWithKey:@"displayName" ascending:YES];
	NSArray *sortedLanguages = [languages sortedArrayUsingDescriptors:
	    [NSArray arrayWithObject:descriptor]];

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
	if (![preferences containsObject:key])
		[preferences addObject:key];

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
}

@end
