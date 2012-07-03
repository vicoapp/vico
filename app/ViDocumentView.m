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

#import "ViDocumentView.h"
#import "ViScope.h"
#import "ViThemeStore.h"

@implementation ViDocumentView

@synthesize innerView = _innerView;

- (ViDocumentView *)initWithDocument:(ViDocument *)aDocument
{
	if ((self = [super initWithNibName:@"ViDocument" bundle:nil]) != nil) {
		MEMDEBUG(@"init %p", self);
		[self loadView]; // Force loading of NIB
		[self setDocument:aDocument];
	}
	DEBUG_INIT();
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	if ([self representedObject] != nil)
		[self setDocument:nil];
	[super dealloc];
}

- (ViDocument *)document
{
	return [self representedObject];
}

- (void)setDocument:(ViDocument *)document
{
	DEBUG(@"set document %@ -> %@", [self representedObject], document);
	[self unbind:@"processing"];
	[self unbind:@"modified"];
	[self unbind:@"title"];

	[self setRepresentedObject:document];

	if (document) {
		[self bind:@"processing" toObject:document withKeyPath:@"busy" options:nil];
		[self bind:@"modified" toObject:document withKeyPath:@"modified" options:nil];
		[self bind:@"title" toObject:document withKeyPath:@"title" options:nil];
	}
}

- (void)setTabController:(ViTabController *)tabController
{
	[super setTabController:tabController];
}

- (void)attach
{
	[[self document] addView:self];
}

- (void)detach
{
	[[self document] removeView:self];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViDocumentView %p: %@>",
	    self, [self representedObject]];
}

- (ViTextView *)textView
{
	return (ViTextView *)_innerView;
}

- (void)replaceTextView:(ViTextView *)textView
{
	[_innerView removeFromSuperview];
	_innerView = textView;
	[_scrollView setDocumentView:_innerView];
	[textView setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
	[textView setMinSize:NSMakeSize(83, 0)];
	[textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	[textView setVerticallyResizable:YES];
	[textView setHorizontallyResizable:YES];
}

@end
