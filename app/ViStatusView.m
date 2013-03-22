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

#import "ViCommon.h"
#import "ViStatusView.h"
#import "logging.h"

@implementation ViStatusView

- (void)awakeFromNib
{
	_messageField = nil;

	[self setAutoresizesSubviews:YES];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(statusComponentChanged:)
												 name:ViStatusLineUpdatedNotification
											   object:nil];
}

#pragma mark --
#pragma mark Simple message handling

- (void)initMessageField
{
	_messageField = [[[NSTextField alloc] init] retain];
	[_messageField setBezeled:NO];
	[_messageField setDrawsBackground:NO];
	[_messageField setEditable:NO];
	[_messageField setSelectable:NO];
    [_messageField setFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height + 2)];
    [_messageField setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable | NSViewMinXMargin | NSViewMaxXMargin];
	[self hideMessage];

	[self addSubview:_messageField];
}

- (void)setMessage:(NSString *)message
{
	if (! _messageField)
	  [self initMessageField];

	[_messageField setStringValue:message];
	[_messageField setHidden:NO];

	for (ViStatusComponent *component in _components)
		[component.control setHidden:YES];
}

- (void)hideMessage
{
	[_messageField setHidden:YES];

	for (ViStatusComponent *component in _components)
		[component.control setHidden:NO];
}

#pragma mark --
#pragma mark Pattern handling

- (void)setPatternString:(NSString *)pattern
{
	//[self setStatusComponents:[NSArray arrayWithObject:message]];
}

#pragma mark --
#pragma mark Status component handling

// ViStatusViewComponent
// Can subscribe to a ViEvent to update itself.
// - (NSView *)view -> the view that gets added to ViStatusView
// - (NSString *)placement?

- (void)setStatusComponents:(NSArray *)components
{
	[_components enumerateObjectsUsingBlock:^(id component, NSUInteger i, BOOL *stop) {
		if ([component respondsToSelector:@selector(removeFromSuperview)]) {
			[component removeFromSuperview];
		}
		[component release];
	}];

	NSLog(@"Setting things to %@", components);

	__block NSString *currentAlignment = ViStatusComponentAlignLeft;
	__block ViStatusComponent *lastComponent = nil;
	[components enumerateObjectsUsingBlock:^(id component, NSUInteger i, BOOL *stop) {
		if ([component isEqual:@"%="]) {
			currentAlignment = ViStatusComponentAlignRight;
		}

		if ([component isKindOfClass:[ViStatusComponent class]]) {
			ViStatusComponent *statusComponent = (ViStatusComponent *)component;

			if ([statusComponent.alignment isEqualToString:ViStatusComponentAlignAutomatic]) {
				statusComponent.alignment = currentAlignment;
			}

			[component retain];

			if (lastComponent) {
				lastComponent.nextComponent = statusComponent;
				statusComponent.previousComponent = lastComponent;
			}

			[statusComponent addViewTo:self];
			lastComponent = statusComponent;
		}
	}];

	[components enumerateObjectsUsingBlock:^(id component, NSUInteger i, BOOL *stop) {
		if ([component isKindOfClass:[ViStatusComponent class]]) {
			ViStatusComponent *statusComponent = (ViStatusComponent *)component;

			[statusComponent adjustSize];
		}
	}];

	[_components release];
	[components retain];
	_components = components;
}

- (NSArray *)statusComponents
{
	return _components;
}

- (void)statusComponentChanged:(NSNotification *)notification
{
	[self hideMessage];
}

#pragma mark --
#pragma mark Housekeeping

- (void)dealloc
{
	[_components makeObjectsPerformSelector:@selector(release)];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

@end

#pragma mark --
#pragma mark Status components

@implementation ViStatusComponent

@synthesize control = _control;
@synthesize nextComponent = _nextComponent;
@synthesize previousComponent = _previousComponent;
@synthesize alignment = _alignment;

- (ViStatusComponent *)init
{
	if (self = [super init]) {
		isCacheValid = NO;
		_previousComponent = nil;
		_nextComponent = nil;
		_control = nil;
		_alignment = ViStatusComponentAlignAutomatic;
	}

	return self;
}

- (ViStatusComponent *)initWithControl:(NSControl *)control
{
	if (self = [ViStatusComponent init]) {
		self.control = control;
	}

	return self;
}

- (void)addViewTo:(NSView *)parentView withAlignment:(NSString *)alignment
{
	_alignment = alignment;
	[self addViewTo:parentView];
}

- (void)addViewTo:(NSView *)parentView
{
	[parentView addSubview:_control];
}

- (void)invalidateSize
{
	isCacheValid = NO;
	[self adjustSize];
}

- (void)adjustSize
{
	// If the cache is still valid or we have no superview, don't
	// try to do any math or cache values.
	if (isCacheValid || ! [_control superview]) return;

	[_control sizeToFit];
	_cachedWidth = _control.frame.size.width;

	NSView *parentView = [_control superview];
	NSUInteger resizingMask = NSViewHeightSizable,
	           xPosition = 0;
	if ([_alignment isEqual:ViStatusComponentAlignCenter]) {
		resizingMask |= NSViewMinXMargin | NSViewMaxXMargin;

		// For center, we have to do math on all center aligned things
		// left and right of us. We then determine where this item should
		// be. To do this, we ask for everyone's width, which is cached
		// until something invalidates it.

		// Spot where the center point for the center block is, then
		// figure out where we have to be with respect to that.
		NSUInteger totalWidth = _cachedWidth;
		NSUInteger prevWidth = 0;
		ViStatusComponent *currentComponent = [self previousComponent];
		while (currentComponent && ([[currentComponent alignment] isEqual:ViStatusComponentAlignCenter] || [[currentComponent alignment] isEqual:ViStatusComponentAlignAutomatic])) {
			totalWidth += [currentComponent controlWidth];
			prevWidth += [currentComponent controlWidth];
			currentComponent = [currentComponent previousComponent];
		}
		currentComponent = [self nextComponent];
		while (currentComponent && ([[currentComponent alignment] isEqual:ViStatusComponentAlignCenter] || [[currentComponent alignment] isEqual:ViStatusComponentAlignAutomatic])) {
			totalWidth += [currentComponent controlWidth];
			currentComponent = [currentComponent nextComponent];
		}

		NSUInteger centerPoint = parentView.frame.size.width / 2;
		NSUInteger startingPoint = centerPoint - (totalWidth / 2);

		xPosition = startingPoint + prevWidth;
	} else if ([self.alignment isEqualToString:ViStatusComponentAlignRight]) {
		resizingMask |= NSViewMinXMargin;

		// For right, ask the next item for its x value. If we are the last
		// item, our x value is the parentView width - our width.
		// We cache the x value until something invalidates it.
		NSUInteger followingX = parentView.frame.size.width;
		if ([self nextComponent]) {
			followingX = [[self nextComponent] controlX];
		}

		xPosition = followingX - _cachedWidth;
	} else {
		resizingMask |= NSViewMaxXMargin;

		if ([self previousComponent]) {
			xPosition = [[self previousComponent] controlX] + [[self previousComponent] controlWidth];
		}
	}

	[self.control setAutoresizingMask:resizingMask];
	[self.control setFrame:CGRectMake(xPosition, 0, _cachedWidth, _control.frame.size.height)];

	_cachedX = _control.frame.origin.x;

	isCacheValid = YES;

	NSNotification *notification = [NSNotification notificationWithName:ViStatusLineUpdatedNotification object:nil];
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];

	// Okay, now let's see if we need to invalidate anyone else.
	if ([self.alignment isEqualToString:ViStatusComponentAlignLeft]) {
		ViStatusComponent *currentComponent = self.nextComponent;
		while (currentComponent && ([currentComponent.alignment isEqual:ViStatusComponentAlignLeft] || [currentComponent.alignment isEqual:ViStatusComponentAlignAutomatic])) {
			[currentComponent invalidateSize];

			currentComponent = currentComponent.nextComponent;
		}
	} else if ([self.alignment isEqualToString:ViStatusComponentAlignRight]) {
		ViStatusComponent *currentComponent = self.previousComponent;
		while (currentComponent && ([currentComponent.alignment isEqual:ViStatusComponentAlignRight] || [currentComponent.alignment isEqual:ViStatusComponentAlignAutomatic])) {
			[currentComponent invalidateSize];

			currentComponent = currentComponent.previousComponent;
		}
	}
}

- (NSUInteger)controlX
{
	if (! isCacheValid) [self adjustSize];

	return _cachedX;
}

- (NSUInteger)controlWidth
{
	if (! isCacheValid) [self adjustSize];

	return _cachedWidth;
}

- (void)removeFromSuperview
{
	[_control removeFromSuperview];
}

- (void)dealloc
{
	[_control release];

	[super dealloc];
}

@end

@implementation ViStatusLabel

- (ViStatusLabel *)init
{
	if (self = [super init]) {
		NSTextField *field = [[NSTextField alloc] init];
		[field setBezeled:NO];
		[field setDrawsBackground:NO];
		[field setEditable:NO];
		[field setSelectable:NO];

		self.control = field;
	}

	return self;
}

- (ViStatusLabel *)initWithText:(NSString *)text
{
	if (self = [self init]) {
		[self.control setStringValue:text];
	}

	return self;
}

@end

@implementation ViStatusNotificationLabel

@synthesize notificationTransformer = _notificationTransformer;

+ (ViStatusNotificationLabel *)statusLabelForNotification:(NSString *)notification withTransformer:(NotificationTransformer)transformer
{
	return [[self alloc] initWithNotification:notification transformer:transformer];
}

- (ViStatusNotificationLabel *)initWithNotification:(NSString *)notification transformer:(NotificationTransformer)transformer
{
	if (self = [super initWithText:@""]) {
		self.notificationTransformerBlock = nil;
		self.notificationTransformer = transformer;

		[[NSNotificationCenter defaultCenter] addObserver:self
									             selector:@selector(changeOccurred:)
		                                             name:notification
		                                           object:nil];
	}

	return self;
}

- (ViStatusNotificationLabel *)initWithNotification:(NSString *)notification transformerBlock:(NuBlock *)transformerBlock
{
	if (self = [super initWithText:@""]) {
		self.notificationTransformerBlock = transformerBlock;
		self.notificationTransformer = nil;

		[[NSNotificationCenter defaultCenter] addObserver:self
									             selector:@selector(changeOccurred:)
		                                             name:notification
		                                           object:nil];
	}

	return self;
}

- (void)changeOccurred:(NSNotification *)notification
{
	NSString *currentValue = [self.control stringValue];
	NSString *newValue = @"";

	ViStatusView *statusView = (ViStatusView *)[_control superview];

	if (self.notificationTransformerBlock) {
		id args[2] = { statusView, notification };
		if (! args[0]) args[0] = [NSNull null];
		NuCell *arguments = [[NSArray arrayWithObjects:args count:2] list];

		id result = [self.notificationTransformerBlock evalWithArguments:arguments context:[self.notificationTransformerBlock context]];

		if (! result || result == [NSNull null]) {
			newValue = currentValue;
		} else if ([result isKindOfClass:[NSString class]]) {
			newValue = result;
		} else {
			INFO(@"Expecting NSString for notification transformer result but got %@.", result);
		}
	} else {
		NSString *result = self.notificationTransformer(statusView, notification);

		if (! result) {
			newValue = currentValue;
		} else {
			newValue = result;
		}
	}

	// Only make a real update if the new value is different.
	if (! [currentValue isEqualToString:newValue]) {
		[self.control setStringValue:newValue];
		[self invalidateSize];
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[self.notificationTransformer release];
	[self.notificationTransformerBlock release];

	[super dealloc];
}

@end

@implementation ViStatusNotificationAttributedLabel

@synthesize notificationTransformer = _notificationTransformer;

+ (ViStatusNotificationAttributedLabel *)statusLabelForNotification:(NSString *)notification withTransformer:(AttributedNotificationTransformer)transformer
{
	return [[ViStatusNotificationAttributedLabel alloc] initWithNotification:notification transformer:transformer];
}

- (ViStatusNotificationAttributedLabel *)init {
	if (self = [super init]) {
		NSTextField *field = (NSTextField *)self.control;

		[field setAllowsEditingTextAttributes:YES];
	}

	return self;
}

- (ViStatusNotificationAttributedLabel *)initWithNotification:(NSString *)notification transformer:(AttributedNotificationTransformer)transformer
{
	if (self = [super initWithText:@""]) {
		self.notificationTransformer = transformer;

		[[NSNotificationCenter defaultCenter] addObserver:self
									             selector:@selector(changeOccurred:)
		                                             name:notification
		                                           object:nil];
	}

	return self;
}

- (void)changeOccurred:(NSNotification *)notification
{
	NSAttributedString *currentValue = [self.control attributedStringValue];
	NSAttributedString *newValue = self.notificationTransformer((ViStatusView *)[_control superview], notification);

	// Only make a real update if the new value is different.
	if (newValue && ! [currentValue isEqualToAttributedString:newValue]) {
	  NSLog(@"Setting value %@ on %@", newValue, self.control);
		[self.control setAttributedStringValue:newValue];
		[self invalidateSize];
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self.notificationTransformer release];

	[super dealloc];
}

@end
