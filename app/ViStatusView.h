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

#define ViStatusStartRightAlignment

#import <Cocoa/Cocoa.h>

@interface ViStatusView : NSView
{
	NSArray *_components;
	NSTextField *_messageField;
}

- (void)awakeFromNib;

- (void)initMessageField;
- (void)setMessage:(NSString *)message;

- (void)setPatternString:(NSString *)pattern;
- (void)setStatusComponents:(NSArray *)components;

- (void)statusComponentChanged:(NSNotification *)notification;

- (void)dealloc;

@end

#define ViStatusComponentAlignLeft @"left"
#define ViStatusComponentAlignCenter @"center"
#define ViStatusComponentAlignRight @"right"
#define ViStatusComponentAlignAutomatic @"automatic"

@interface ViStatusComponent : NSView
{
	NSControl *_control;
	ViStatusComponent *_nextComponent;
	ViStatusComponent *_previousComponent;
	NSString *_alignment;

	NSUInteger _cachedX;
	NSUInteger _cachedWidth;
	BOOL isCacheValid;
}

@property (retain,readwrite) NSControl *control;
@property (assign,readwrite,nonatomic) ViStatusComponent *nextComponent;
@property (assign,readwrite,nonatomic) ViStatusComponent *previousComponent;
@property (assign,readwrite,nonatomic) NSString *alignment;

- (ViStatusComponent *)init;
- (ViStatusComponent *)initWithControl:(NSControl *)control;

- (void)addViewTo:(NSView *)parentView;
- (void)removeFromSuperview;

- (void)adjustSize;
- (NSUInteger)controlX;
- (NSUInteger)controlWidth;

- (void)dealloc;

@property (nonatomic,retain) NSView *view;

@end

@interface ViStatusLabel : ViStatusComponent
{
}

- (ViStatusLabel *)initWithText:(NSString *)text;

@end

typedef NSString *(^NotificationTransformer)(NSNotification *);

@interface ViStatusNotificationLabel : ViStatusLabel
{
	NotificationTransformer _notificationTransformer;
}

@property (nonatomic,copy) NotificationTransformer notificationTransformer;

+ (ViStatusNotificationLabel *)statusLabelForNotification:(NSString *)notification withTransformer:(NotificationTransformer)transformer;

- (ViStatusNotificationLabel *)initWithNotification:(NSString *)notification transformer:(NotificationTransformer)transformer;

- (void)changeOccurred:(NSNotification *)notification;

- (void)dealloc;

@end


// ViStatusCursorLabel
// ViStatusModeLabel
// ViStatusFileInfoLabel
