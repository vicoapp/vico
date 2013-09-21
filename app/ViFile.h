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

@interface ViFile : NSObject
{
	NSURL		*_url;
	NSURL		*_targetURL;
	NSDictionary	*_attributes;
	NSDictionary	*_targetAttributes;
	NSMutableArray	*_children;
	NSString	*_name;
	NSString	*_displayName;
	NSImage		*_icon;
	BOOL		 _nameIsDirty;
	BOOL		 _displayNameIsDirty;
	BOOL		 _iconIsDirty;
	BOOL		 _isDirectory;
	BOOL		 _isLink;
}

@property(nonatomic,readonly) NSURL *url;
@property(nonatomic,readonly) NSURL *targetURL;
@property(nonatomic,readonly) NSDictionary *attributes;
@property(nonatomic,readonly) NSDictionary *targetAttributes;
@property(nonatomic,readwrite,strong) NSMutableArray *children;
@property(nonatomic,readonly) BOOL isDirectory;
@property(nonatomic,readonly) BOOL isLink;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSString *displayName;
@property(nonatomic,readonly) NSString *path;
@property(nonatomic,readonly) NSImage *icon;

+ (id)fileWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary;

+ (id)fileWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary
     symbolicLink:(NSURL *)sURL
symbolicAttributes:(NSDictionary *)sDictionary;

- (id)initWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary
     symbolicLink:(NSURL *)sURL
symbolicAttributes:(NSDictionary *)sDictionary;

- (void)setURL:(NSURL *)aURL;
- (BOOL)hasCachedChildren;

- (void)setTargetURL:(NSURL *)aURL;
- (void)setTargetURL:(NSURL *)aURL attributes:(NSDictionary *)aDictionary;

@end
