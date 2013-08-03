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

#import "ViTransformer.h"

@class ViSnippet;

@interface ViTabstop : NSObject
{
	NSInteger	 _num;
	NSRange		 _range;
	NSUInteger	 _index;
	NSMutableString	*_value;
	ViTabstop	*_parent;
	ViTabstop	*_mirror;
	ViRegexp	*_rx;
	NSString	*_format;
	NSString	*_options;
	NSString	*_filter;
}

@property(readwrite) NSInteger num;
@property(readwrite) NSUInteger index;
@property(readwrite) NSRange range;
@property(readwrite,retain) ViTabstop *parent;
@property(readwrite,retain) ViTabstop *mirror;
@property(readwrite,retain) ViRegexp *rx;
@property(readwrite,retain) NSString *format;
@property(readwrite,retain) NSString *options;
@property(readwrite,retain) NSString *filter;
@property(readwrite,retain) NSMutableString *value;

@end




@protocol ViSnippetDelegate <NSObject>
- (void)snippet:(ViSnippet *)snippet replaceCharactersInRange:(NSRange)range withString:(NSString *)string forTabstop:(ViTabstop *)tabstop;
- (void)beginUpdatingSnippet:(ViSnippet *)snippet;
- (void)endUpdatingSnippet:(ViSnippet *)snippet;
- (NSString *)string;
@end




@interface ViSnippet : ViTransformer
{
	NSUInteger			 _beginLocation;
	ViTabstop			*_currentTabStop;
	NSUInteger			 _currentTabNum;
	NSUInteger			 _maxTabNum;
	__weak id<ViSnippetDelegate>	 _delegate;	// XXX: not retained!
	NSRange				 _range;
	NSUInteger			 _caret;
	NSRange				 _selectedRange;
	NSArray				 *_selectedRanges;
	NSMutableArray			*_tabstops;
	NSDictionary			*_environment;
	BOOL				 _finished;
	NSMutableString			*_shellOutput;
}

@property(nonatomic,readonly) NSRange range;
@property(nonatomic,readonly) NSUInteger caret;
@property(nonatomic,readonly) NSRange selectedRange;
@property(nonatomic,readwrite,retain) NSArray *selectedRanges;
@property(nonatomic,readonly) BOOL finished;
@property(nonatomic,readwrite,retain) ViTabstop *currentTabStop;

- (ViSnippet *)initWithString:(NSString *)aString
                   atLocation:(NSUInteger)aLocation
                     delegate:(__weak id<ViSnippetDelegate>)aDelegate
                  environment:(NSDictionary *)environment
                        error:(NSError **)outError;
- (BOOL)activeInRange:(NSRange)aRange;
- (BOOL)replaceRange:(NSRange)updateRange withString:(NSString *)replacementString;
- (BOOL)advance;
- (void)deselect;
- (NSRange)tabRange;
- (NSString *)string;

- (BOOL)updateTabstopsError:(NSError **)outError;
- (void)removeNestedIn:(ViTabstop *)parent;
- (NSUInteger)parentLocation:(ViTabstop *)ts;

@end
