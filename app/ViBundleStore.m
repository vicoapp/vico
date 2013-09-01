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

#import "ViBundleStore.h"
#import "ViBundle.h"
#import "ViAppController.h"
#import "ViBundleItem.h"
#import "NSString-scopeSelector.h"
#import "logging.h"

@implementation ViBundleStore

+ (NSString *)bundlesDirectory
{
	static NSString *__bundlesDirectory = nil;
	if (__bundlesDirectory == nil)
		__bundlesDirectory = [[ViAppController supportDirectory] stringByAppendingPathComponent:@"Bundles"];
	return __bundlesDirectory;
}

+ (ViBundleStore *)defaultStore
{
	static ViBundleStore *__defaultStore = nil;
	if (__defaultStore == nil) {
		__defaultStore = [[ViBundleStore alloc] init];
		[__defaultStore initLanguages];
	}
	return __defaultStore;
}

- (id)init
{
	self = [super init];
	if (self) {
		_languages = [[NSMutableDictionary alloc] init];
		_bundles = [[NSMutableDictionary alloc] init];
		_cachedPreferences = [[NSMutableDictionary alloc] init];
	}
	return self;
}


- (BOOL)loadBundleFromDirectory:(NSString *)bundleDirectory loadPluginCode:(BOOL)loadPluginCode
{
	ViBundle *bundle = [[ViBundle alloc] initWithDirectory:bundleDirectory];
	if (bundle == nil)
		return NO;

	ViBundle *oldBundle = [_bundles objectForKey:bundle.uuid];
	if (oldBundle) {
		INFO(@"replacing bundle %@ with %@", oldBundle, bundle);
		for (ViLanguage *lang in oldBundle.languages) {
			if (lang.name) {
				[_languages removeObjectForKey:lang.name];
			}
		}
		/* Reset cached preferences to remove any pref in oldBundle. */
		_cachedPreferences = [[NSMutableDictionary alloc] init];
		/* FIXME: remove any defined languages in oldBundle, re-compile/clear cache for dependent languages. */
		/* FIXME: clear cache for theme attributes? */
	}

	[_bundles setObject:bundle forKey:bundle.uuid];

	for (ViLanguage *lang in bundle.languages) {
		if (lang.name) {
			[_languages setObject:lang forKey:lang.name];
		}
	}

	if (loadPluginCode)
		[bundle loadPluginCode];

	[[NSNotificationCenter defaultCenter] postNotificationName:ViBundleStoreBundleLoadedNotification
							    object:self
							  userInfo:[NSDictionary dictionaryWithObject:bundle forKey:@"bundle"]];

	return YES;
}

- (BOOL)loadBundleFromDirectory:(NSString *)bundleDirectory
{
	return [self loadBundleFromDirectory:bundleDirectory loadPluginCode:YES];
}

- (void)addBundlesFromBundleDirectory:(NSString *)aPath
{
	NSArray *subdirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:aPath error:NULL];
	for (NSString *subdir in subdirs)
		[self loadBundleFromDirectory:[aPath stringByAppendingPathComponent:subdir]
			       loadPluginCode:NO];
}

- (void)initLanguages
{
	[self addBundlesFromBundleDirectory:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Bundles"]];
	[self addBundlesFromBundleDirectory:[ViBundleStore bundlesDirectory]];

	for (ViBundle *bundle in [self allBundles])
		[bundle loadPluginCode];
}

- (ViLanguage *)languageForFirstLine:(NSString *)firstLine
{
	ViLanguage *language;
	for (language in [self languages]) {
		NSString *firstLineMatch = language.firstLineMatch;
		if (firstLineMatch == nil)
			continue;

		ViRegexp *rx = [ViRegexp regexpWithString:firstLineMatch];
		BOOL match = ([rx matchInString:firstLine] != nil);
		if (match) {
			DEBUG(@"Using language %@ for first line [%@]", language.name, firstLine);
			DEBUG(@"Using bundle %@", language.bundle.name);
			return language;
		}
	}

	DEBUG(@"No language matching first line [%@]", firstLine);
	return nil;
}

- (ViLanguage *)languageForFilename:(NSString *)aPath
{
	NSCharacterSet *pathSeparators = [NSCharacterSet characterSetWithCharactersInString:@"./"];

	for (ViLanguage *language in [self languages]) {
		for (NSString *fileType in [language fileTypes]) {
			NSUInteger path_len = [aPath length];
			NSUInteger ftype_len = [fileType length];

			if ([aPath hasSuffix:fileType] &&
			    (path_len == ftype_len ||
			     [pathSeparators characterIsMember:[aPath characterAtIndex:path_len - ftype_len - 1]])) {
				DEBUG(@"Using language %@ for file %@", language.name, aPath);
				DEBUG(@"Using bundle %@", language.bundle.name);
				return language;
			}
		}
	}

	DEBUG(@"No language found for file %@", aPath);
	return nil;
}

- (ViLanguage *)defaultLanguage
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	ViLanguage *lang = [self languageWithScope:[defs stringForKey:@"defaultsyntax"]];
	if (lang == nil)
		lang = [self languageWithScope:@"text.plain"];
	return lang;
}

- (ViLanguage *)languageWithScope:(NSString *)scopeName
{
	return [_languages objectForKey:scopeName];
}

- (NSArray *)languages
{
	return [_languages allValues];
}

- (NSArray *)sortedLanguages
{
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc]
	    initWithKey:@"displayName" ascending:YES];
	return [[self languages] sortedArrayUsingDescriptors:
	    [NSArray arrayWithObject:descriptor]];
}

- (NSArray *)allBundles
{
	return [_bundles allValues];
}

- (ViBundle *)bundleWithName:(NSString *)name
{
	for (ViBundle *b in [self allBundles])
		if ([b.name isEqualToString:name])
			return b;
	return nil;
}

- (ViBundle *)bundleWithUUID:(NSString *)uuid
{
	return [_bundles objectForKey:uuid];
}

/*
 * Checks all bundles for the named preferences (yes, this is how TextMate does it).
 */
- (NSDictionary *)preferenceItems:(NSArray *)prefsNames
{
	NSString *cacheKey = [prefsNames componentsJoinedByString:@","];
	NSMutableDictionary *result = [_cachedPreferences objectForKey:cacheKey];
	if (result)
		return result;

	result = [NSMutableDictionary dictionary];
	[_cachedPreferences setObject:result forKey:cacheKey];

	for (ViBundle *bundle in [self allBundles]) {
		NSDictionary *p = [bundle preferenceItems:prefsNames];
		if (p)
			[result addEntriesFromDictionary:p];
	}

	return result;
}

/*
 * Checks all bundles for the named preference (yes, this is how TextMate does it).
 */
- (NSDictionary *)preferenceItem:(NSString *)prefsName
{
	NSMutableDictionary *result = [_cachedPreferences objectForKey:prefsName];
	if (result)
		return result;

	result = [NSMutableDictionary dictionary];
	[_cachedPreferences setObject:result forKey:prefsName];

	for (ViBundle *bundle in [self allBundles]) {
		NSDictionary *p = [bundle preferenceItem:prefsName];
		if (p)
			[result addEntriesFromDictionary:p];
	}

	return result;
}

- (NSDictionary *)shellVariablesForScope:(ViScope *)scope
{
	NSMutableDictionary *result = nil;
	u_int64_t rank = 0ULL;

	if (scope == nil)
		return nil;

	for (ViBundle *bundle in [self allBundles]) {
		for (NSDictionary *preference in bundle.preferences) {
			NSString *scopeSelector = [preference objectForKey:@"scope"];
			if (![scopeSelector isKindOfClass:[NSString class]])
				scopeSelector = @"";
			u_int64_t r = [scopeSelector match:scope];
			if (r == 0 || r < rank)
				continue;

			NSDictionary *settings = [preference objectForKey:@"settings"];
			if (![settings isKindOfClass:[NSDictionary class]])
				continue;

			NSArray *variables = [settings objectForKey:@"shellVariables"];
			if (![variables isKindOfClass:[NSArray class]])
				continue;

			if (r > rank) {
				result = nil;
				rank = r;
			}

			for (NSDictionary *d in variables) {
				if (![d isKindOfClass:[NSDictionary class]])
					continue;
				NSString *name = [d objectForKey:@"name"];
				if (![name isKindOfClass:[NSString class]])
					continue;
				id value = [d objectForKey:@"value"];
				if (value == nil)
					continue;

				if (result == nil)
					result = [NSMutableDictionary dictionary];
				[result setObject:value forKey:name];
			}
		}
	}

	return result;
}

- (NSArray *)itemsWithTabTrigger:(NSString *)prefix
		   matchingScope:(ViScope *)scope
			  inMode:(ViMode)mode
		   matchedLength:(NSUInteger *)lengthPtr
{
	NSMutableArray *matches = nil;
	u_int64_t highest_rank = 0ULL;
	NSUInteger longestMatch = 0ULL;
	NSUInteger prefixLength = [prefix length];
	NSCharacterSet *atomicSnippetSet = [NSCharacterSet alphanumericCharacterSet];

	for (ViBundle *bundle in [self allBundles])
		for (ViBundleItem *item in [bundle items])
			if (item.tabTrigger &&
			    [prefix hasSuffix:item.tabTrigger] &&
			    (item.mode == ViAnyMode || item.mode == mode)) {
				NSUInteger triggerLength = [item.tabTrigger length];

				/*
				 * "m" should NOT match the prefix "mm", but may match "#m".
                                 */
				if (prefixLength > triggerLength &&
				    [atomicSnippetSet characterIsMember:[prefix characterAtIndex:prefixLength - triggerLength - 1]])
					continue;

				/*
				 * Try to match as much of the tab trigger as possible.
				 * Favor longer matching tab trigger words.
				 */
				if (triggerLength > longestMatch) {
					[matches removeAllObjects];
					longestMatch = triggerLength;
				} else if (triggerLength < longestMatch)
					continue;

				NSString *scopeSelector = item.scopeSelector;
				u_int64_t rank;
				if (scopeSelector == nil)
					rank = 1ULL;
				else
					rank = [scope match:scopeSelector];

				if (rank > 0) {
					if (rank > highest_rank) {
						matches = [NSMutableArray arrayWithObject:item];
						highest_rank = rank;
					} else if (rank == highest_rank)
						[matches addObject:item];
				}
			}

	if (lengthPtr)
		*lengthPtr = longestMatch;

	return matches;
}

- (NSArray *)itemsWithKeyCode:(NSInteger)keyCode
		matchingScope:(ViScope *)scope
		       inMode:(ViMode)mode
{
	NSMutableArray *matches = nil;
	u_int64_t highest_rank = 0ULL;

	for (ViBundle *bundle in [self allBundles]) {
		for (ViBundleItem *item in [bundle items]) {
			if (item.keyCode == keyCode &&
			    (item.mode == ViAnyMode || item.mode == mode)) {
				NSString *scopeSelector = item.scopeSelector;
				u_int64_t rank;
				if (scopeSelector == nil)
					rank = 1ULL;
				else
					rank = [scopeSelector match:scope];

				if (rank > 0) {
					if (rank > highest_rank) {
						matches = [NSMutableArray arrayWithObject:item];
						highest_rank = rank;
					} else if (rank == highest_rank)
						[matches addObject:item];
				}
			}
		}
	}

	return matches;
}

- (BOOL)isBundleLoaded:(NSString *)name // XXX: this is sooo fragile!
{
	for (ViBundle *bundle in [self allBundles])
		if ([bundle.path rangeOfString:name].location != NSNotFound)
			return YES;
	return NO;
}

@end

