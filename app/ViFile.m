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

#import "ViFile.h"
#include "logging.h"

@implementation ViFile

@synthesize url = _url;
@synthesize targetURL = _targetURL;
@synthesize children = _children;
@synthesize isDirectory = _isDirectory;
@synthesize isLink = _isLink;
@synthesize attributes = _attributes;
@synthesize targetAttributes = _targetAttributes;

- (id)initWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary
     symbolicLink:(NSURL *)sURL
symbolicAttributes:(NSDictionary *)sDictionary
{
	if ((self = [super init]) != nil) {
		_attributes = [aDictionary retain];
		_isLink = [[_attributes fileType] isEqualToString:NSFileTypeSymbolicLink];
		if (!_isLink && [aURL isFileURL]) {
			NSNumber *isAliasFile = nil;
			BOOL success = [aURL getResourceValue:&isAliasFile
						       forKey:NSURLIsAliasFileKey
							error:nil];
			if (success && [isAliasFile boolValue])
				_isLink = YES;
		}
		[self setURL:aURL];
		[self setTargetURL:sURL attributes:sDictionary];
	}
	MEMDEBUG(@"%p", self);
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_url release];
	[_targetURL release];
	[_attributes release];
	[_targetAttributes release];
	[_children release];
	[_name release];
	[_displayName release];
	[_icon release];
	[super dealloc];
}

+ (id)fileWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary
{
	return [[[ViFile alloc] initWithURL:aURL
				 attributes:aDictionary
			       symbolicLink:nil
			 symbolicAttributes:nil] autorelease];
}

+ (id)fileWithURL:(NSURL *)aURL
       attributes:(NSDictionary *)aDictionary
     symbolicLink:(NSURL *)sURL
symbolicAttributes:(NSDictionary *)sDictionary
{
	return [[[ViFile alloc] initWithURL:aURL
				 attributes:aDictionary
			       symbolicLink:sURL
			 symbolicAttributes:sDictionary] autorelease];
}

- (BOOL)hasCachedChildren
{
	return _children != nil;
}

- (NSURL *)targetURL
{
	if (_isLink)
		return _targetURL;
	return _targetURL ?: _url;
}

- (void)setURL:(NSURL *)aURL
{
	[aURL retain];
	[_url release];
	_url = aURL;

	_nameIsDirty = YES;
	_displayNameIsDirty = YES;
	_iconIsDirty = YES;
}

- (void)setTargetURL:(NSURL *)aURL
{
	[aURL retain];
	[_targetURL release];
	_targetURL = aURL;
	_iconIsDirty = YES;
}

- (void)setTargetURL:(NSURL *)aURL attributes:(NSDictionary *)aDictionary
{
	[aURL retain];
	[_targetURL release];
	_targetURL = aURL;

	[aDictionary retain];
	[_targetAttributes release];
	_targetAttributes = aDictionary;

	_iconIsDirty = YES;

	if (_isLink)
		_isDirectory = [[_targetAttributes fileType] isEqualToString:NSFileTypeDirectory];
	else
		_isDirectory = [[_attributes fileType] isEqualToString:NSFileTypeDirectory];
}

- (NSString *)path
{
	return [_url path];
}

- (NSString *)name
{
	if (_nameIsDirty) {
		[_name release];
		_name = [[_url lastPathComponent] retain];
		_nameIsDirty = NO;
	}
	return _name;
}

- (NSString *)displayName
{
	if (_displayNameIsDirty) {
		[_displayName release];
		if ([_url isFileURL])
			_displayName = [[[NSFileManager defaultManager] displayNameAtPath:[_url path]] retain];
		else
			_displayName = [[_url lastPathComponent] retain];
		_displayNameIsDirty = NO;
	}
	return _displayName;
}

- (NSImage *)icon
{
	if (_iconIsDirty) {
		[_icon release];
		if ([_url isFileURL])
			_icon = [[NSWorkspace sharedWorkspace] iconForFile:[[self targetURL] path]];
		else if (_isDirectory)
			_icon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
		else
			_icon = [[NSWorkspace sharedWorkspace] iconForFileType:[[self targetURL] pathExtension]];
		[_icon setSize:NSMakeSize(16, 16)];

		if (_isLink) {
			_icon = [_icon copy];
			NSImage *aliasBadge = [NSImage imageNamed:@"AliasBadgeIcon"];
			[_icon lockFocus];
			NSSize sz = [_icon size];
			[aliasBadge drawInRect:NSMakeRect(0, 0, sz.width, sz.height)
				      fromRect:NSZeroRect
				     operation:NSCompositeSourceOver
				      fraction:1.0];
			[_icon unlockFocus];
		} else
			[_icon retain];

		_iconIsDirty = NO;
	}
	return _icon;
}

- (NSString *)description
{
	if (_isLink)
		return [NSString stringWithFormat:@"<ViFile %p: %@ -> %@%s>", self, _url, _targetURL, _isDirectory ? "/" : ""];
	else
		return [NSString stringWithFormat:@"<ViFile %p: %@%s>", self, _url, _isDirectory ? "/" : ""];
}

@end
