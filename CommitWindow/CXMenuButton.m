//
//  CXMenuButton.m
//
//  Created by Chris Thomas on 2006-10-09.
//  Copyright 2006 Chris Thomas. All rights reserved.
//	MIT license.
//

#import "CXMenuButton.h"

@implementation CXMenuButton

// Initialization

- (void) commonInit
{
	// Use alternateImage for pressed state
	[[self cell] setHighlightsBy:NSCellLightsByContents];
}

- (void) awakeFromNib
{
	[self commonInit];
}

// Events

- (void) mouseDown:(NSEvent *)event
{
	[self highlight:YES];
	[NSMenu popUpContextMenu:menu withEvent:event forView:self withFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[self highlight:NO];
}

// Accessors

- (NSMenu *)menu
{
	return menu;
}

- (void)setMenu:(NSMenu *)aValue
{
	NSMenu *oldMenu = menu;
	menu = [aValue retain];
	[oldMenu release];
}

@end




