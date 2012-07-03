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

#import "ViMarkInspector.h"
#import "ViMarkManager.h"
#import "ViWindowController.h"
#include "logging.h"

@implementation ViMarkInspector

+ (ViMarkInspector *)sharedInspector
{
	static ViMarkInspector *__sharedInspector = nil;
	if (__sharedInspector == nil)
		__sharedInspector = [[ViMarkInspector alloc] init];
	return __sharedInspector;
}

- (id)init
{
	if ((self = [super initWithWindowNibName:@"MarkInspector"])) {
	}
	return self;
}

- (void)dealloc
{
	[markListController release];
	[markStackController release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[outlineView setTarget:self];
	[outlineView setDoubleAction:@selector(gotoMark:)];
}

- (void)show
{
	[[self window] makeKeyAndOrderFront:self];
}

- (IBAction)changeList:(id)sender
{
	DEBUG(@"sender is %@, tag %lu", sender, [sender tag]);
	ViMarkStack *stack = [[markStackController selectedObjects] lastObject];
	if ([sender selectedSegment] == 0)
		[stack previous];
	else
		[stack next];
}

- (IBAction)gotoMark:(id)sender
{
	DEBUG(@"sender is %@", sender);
	NSArray *objects = [markListController selectedObjects];
	if ([objects count] == 1) {
		id object = [objects lastObject];
		DEBUG(@"selected object is %@ (row is %li)", object, [outlineView rowForItem:object]);
		if ([object isKindOfClass:[ViMark class]]) {
			ViMark *mark = object;
			ViWindowController *windowController = [ViWindowController currentWindowController];
			[windowController gotoMark:mark];
			[windowController showWindow:nil];
		} else {
			NSArray *nodes = [markListController selectedNodes];
			DEBUG(@"got selected nodes %@", nodes);
			id node = [nodes lastObject];
			if ([outlineView isItemExpanded:node])
				[outlineView collapseItem:node];
			else
				[outlineView expandItem:node];
		}
	}
}

@end
