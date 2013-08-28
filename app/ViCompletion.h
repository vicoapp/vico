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

#import "ViRegexp.h"

@interface ViCompletion : NSObject
{
	NSString			*_content;
	NSMutableAttributedString	*_title;
	BOOL				 _titleIsDirty;
	BOOL				 _scoreIsDirty;
	ViRegexpMatch			*_filterMatch;
	BOOL				 _filterIsFuzzy;
	NSUInteger			 _prefixLength;
	NSFont				*_font;
	NSColor				*_markColor;
	NSUInteger			 _location;
	double				 _score;
	id				 _representedObject;
	NSMutableParagraphStyle		*_titleParagraphStyle;
}

@property (nonatomic, readonly) NSString *content;
@property (nonatomic, readwrite, retain) ViRegexpMatch *filterMatch;
@property (nonatomic, readwrite) NSUInteger prefixLength;
@property (nonatomic, readwrite) BOOL filterIsFuzzy;
@property (nonatomic, readwrite) BOOL isCurrentChoice;
@property (nonatomic, readwrite, retain) NSFont *font;
@property (nonatomic, readwrite) NSUInteger location;
@property (nonatomic, readwrite, retain) id representedObject;
@property (nonatomic, readwrite, retain) NSColor *markColor;
@property (nonatomic, readwrite, retain) NSAttributedString *title;
@property (nonatomic, readonly) double score;

+ (id)completionWithContent:(NSString *)aString;
+ (id)completionWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch;

- (id)initWithContent:(NSString *)aString;
- (id)initWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch;

- (void)updateTitle;
- (void)calcScore;

@end
