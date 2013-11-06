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

#import "ViCompletionView.h"
#import "ViCompletion.h"
#import "ViURLManager.h"

@protocol ViCompletionProvider <NSObject>
- (NSArray *)completionsForString:(NSString *)string
			  options:(NSString *)options
			    error:(NSError **)outError;
@optional
- (NSArray *)completionsForString:(NSString *)string
			  options:(NSString *)options;
@end

@class ViCompletionController;

@protocol ViCompletionDelegate <NSObject>
- (void)completionController:(ViCompletionController *)completionController
         didTerminateWithKey:(NSInteger)keyCode
          selectedCompletion:(ViCompletion *)selectedCompletion;

@optional
- (BOOL)completionController:(ViCompletionController *)completionController
       shouldTerminateForKey:(NSInteger)keyCode;
- (BOOL)completionController:(ViCompletionController *)completionController
     insertPartialCompletion:(NSString *)partialCompletion
                     inRange:(NSRange)range;
@end

@interface ViCompletionController : NSObject <NSTableViewDataSource, NSTableViewDelegate, ViKeyManagerTarget>
{
	IBOutlet NSWindow		* window;
	IBOutlet ViCompletionView	*tableView;
	IBOutlet NSTextField		*label;

	id<ViCompletionProvider>	 _provider;
	NSMutableArray			*_completions;
	NSString			*_options;
	NSString			*_prefix;
	NSUInteger			 _prefixLength;
	ViCompletion			*_onlyCompletion;
	NSMutableArray			*_filteredCompletions;
	ViCompletion			*_selection;
	NSMutableString			*_filter;
	// NSMutableParagraphStyle	*_matchParagraphStyle;
	id<ViCompletionDelegate>	 __unsafe_unretained _delegate;
	NSInteger			 _terminatingKey;
	NSRange				 _range;
	NSRect				 _prefixScreenRect;
	BOOL				 _upwards;
	BOOL				 _fuzzySearch;
	BOOL				 _autocompleting;
	BOOL				 _aggressive;
}

@property (unsafe_unretained, nonatomic, readonly) id<ViCompletionDelegate> delegate;
@property (nonatomic, readonly) NSWindow *window;
@property (nonatomic, readonly) ViCompletionView *completionView;
@property (nonatomic, readwrite, strong) NSArray *completions;
@property (nonatomic, readonly) NSInteger terminatingKey;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readwrite, strong) NSString *filter;

+ (ViCompletionController *)sharedController;
+ (NSString *)commonPrefixInCompletions:(NSArray *)completions;
+ (void)appendFilter:(NSString *)string
           toPattern:(NSMutableString *)pattern
          fuzzyClass:(NSString *)fuzzyClass;

- (BOOL)chooseFrom:(id<ViCompletionProvider>)aProvider
             range:(NSRange)aRange
            prefix:(NSString *)aPrefix
  prefixScreenRect:(NSRect)prefixRect
          delegate:(id<ViCompletionDelegate>)aDelegate
           options:(NSString *)optionString
     initialFilter:(NSString *)initialFilter;

- (void)updateBounds;
- (void)filterCompletions;
- (BOOL)complete_partially:(ViCommand *)command;
- (void)acceptByKey:(NSInteger)termKey;
- (BOOL)cancel:(ViCommand *)command;
- (BOOL)accept:(ViCommand *)command;
- (BOOL)accept_or_complete_partially:(ViCommand *)command;
- (BOOL)accept_if_not_autocompleting:(ViCommand *)command;
- (BOOL)accept_or_complete_partially:(ViCommand *)command;
- (void)updateCompletions;
- (void)reset;

@end
