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

#import "ViLanguage.h"
#import "ViBundle.h"

#define ViBundleStoreBundleLoadedNotification @"ViBundleStoreBundleLoaded"

@interface ViBundleStore : NSObject
{
	NSMutableDictionary *_languages;
	NSMutableDictionary *_bundles;
	NSMutableDictionary *_cachedPreferences;
}

+ (NSString *)bundlesDirectory;
+ (ViBundleStore *)defaultStore;

- (ViLanguage *)languageForFirstLine:(NSString *)firstLine;
- (ViLanguage *)languageForFilename:(NSString *)aPath;
- (ViLanguage *)languageWithScope:(NSString *)scopeName;
- (ViLanguage *)defaultLanguage;
- (NSArray *)allBundles;
- (ViBundle *)bundleWithName:(NSString *)name;
- (ViBundle *)bundleWithUUID:(NSString *)uuid;
- (NSArray *)languages;
- (NSArray *)sortedLanguages;
- (NSDictionary *)preferenceItem:(NSString *)prefsName;
- (NSDictionary *)preferenceItems:(NSArray *)prefsNames;
- (NSDictionary *)shellVariablesForScope:(ViScope *)scope;
- (NSArray *)itemsWithTabTrigger:(NSString *)name
                   matchingScope:(ViScope *)scope
                          inMode:(ViMode)mode
                   matchedLength:(NSUInteger *)lengthPtr;
- (NSArray *)itemsWithKeyCode:(NSInteger)keyCode
                matchingScope:(ViScope *)scope
                       inMode:(ViMode)mode;
- (BOOL)isBundleLoaded:(NSString *)name;
- (BOOL)loadBundleFromDirectory:(NSString *)bundleDirectory;
- (void)initLanguages;

@end
