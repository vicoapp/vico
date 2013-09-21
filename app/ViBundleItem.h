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

#import "ViBundle.h"
#import "ViCommon.h"

@interface ViBundleItem : NSObject
{
	ViBundle	*_bundle;
	NSString	*_uuid;
	NSString	*_name;
	NSString	*_scopeSelector;
	ViMode		 _mode;

	/* used in menus */
	NSString	*_tabTrigger;
	NSString	*_keyEquivalent;
	NSUInteger	 _modifierMask;

	/* used when matching keys */
	NSInteger	 _keyCode;
}

@property(nonatomic,readonly) ViBundle *bundle;
@property(nonatomic,readonly) NSString *uuid;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSString *scopeSelector;
@property(nonatomic,readonly) ViMode mode;
@property(nonatomic,readonly) NSString *keyEquivalent;
@property(nonatomic,readonly) NSUInteger modifierMask;
@property(nonatomic,readonly) NSInteger keyCode;
@property(nonatomic,readonly) NSString *tabTrigger;

- (ViBundleItem *)initFromDictionary:(NSDictionary *)dict
                            inBundle:(ViBundle *)aBundle;

@end
