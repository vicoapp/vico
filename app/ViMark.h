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

@class ViDocument;
@class ViMarkList;
@class ViDocumentView;
@class ViScope;

/** A marked location.
 */
@interface ViMark : NSObject <NSCopying>
{
	NSString		*_name;
	NSUInteger		 _location;
	NSRange			 _range;
	NSInteger		 _line;
	NSInteger		 _column;
	BOOL			 _persistent;

	NSString		*_rangeString;
	BOOL			 _rangeStringIsDirty;

	BOOL			 _recentlyRestored;

	id			 _title;
	NSArray			*_scopes;
	NSImage			*_icon;
	id			 _representedObject;

	NSString		*_groupName;
	NSURL			*_url;
	ViDocument		*_document;
	__weak ViDocumentView	*_view;

	NSHashTable		*_lists; // XXX: lists are not retained!
}

/** The name of the mark. */
@property(nonatomic,readonly) NSString *name;
/** The line number of the mark. */
@property(nonatomic,readonly) NSInteger line;
/** The column of the mark. */
@property(nonatomic,readonly) NSInteger column;
/** The character index of the mark, or NSNotFound if unknown. */
@property(nonatomic,readonly) NSUInteger location;
/** The range of the mark, or `{NSNotFound,0}` if unknown. */
@property(nonatomic,readonly) NSRange range;
/** The range of the mark as a string, or `nil` if unknown. */
@property(nonatomic,readonly) NSString *rangeString;
/** The URL of the mark. */
@property(nonatomic,readonly) NSURL *url;
/** The icon of the mark. */
@property(nonatomic,readwrite,strong) NSImage *icon;
/** The title of the mark. An NSString or an NSAttributedString. */
@property(nonatomic,readwrite,copy) id title;
/** A custom user-defined object associated with the mark. */
@property(nonatomic,readwrite,strong) id representedObject;
/** If NO, the mark is automatically removed when the text range is removed. Default is YES. */
@property(nonatomic,readwrite) BOOL persistent;
/** Additional scopes for the marked range. */
@property(nonatomic,readwrite,strong) NSArray *scopes;

@property(nonatomic,readwrite) BOOL recentlyRestored;

@property(nonatomic,readwrite,strong) ViDocument *document;
@property(nonatomic,readonly) __weak ViDocumentView *view;

@property(weak, nonatomic,readonly) NSString *groupName;

+ (ViMark *)markWithURL:(NSURL *)aURL;

+ (ViMark *)markWithURL:(NSURL *)aURL
		   line:(NSInteger)aLine
		 column:(NSInteger)aColumn;

+ (ViMark *)markWithURL:(NSURL *)aURL
		   name:(NSString *)aName
                 title:(id)aTitle
                  line:(NSInteger)aLine
                column:(NSInteger)aColumn;

- (ViMark *)initWithURL:(NSURL *)aURL
		   name:(NSString *)aName
		  title:(id)aTitle
                  line:(NSInteger)aLine
                column:(NSInteger)aColumn;

+ (ViMark *)markWithDocument:(ViDocument *)aDocument
			name:(NSString *)aName
		       range:(NSRange)aRange;

- (ViMark *)initWithDocument:(ViDocument *)aDocument
			name:(NSString *)aName
		       range:(NSRange)aRange;

+ (ViMark *)markWithView:(ViDocumentView *)aDocumentView
		    name:(NSString *)aName
		   range:(NSRange)aRange;

- (ViMark *)initWithView:(ViDocumentView *)aDocumentView
		    name:(NSString *)aName
		   range:(NSRange)aRange;

- (void)setLocation:(NSUInteger)aLocation;
- (void)setRange:(NSRange)aRange;
- (void)setURL:(NSURL *)url;

- (void)remove;
- (void)registerList:(ViMarkList *)list;
- (void)unregisterList:(ViMarkList *)list;

@end
