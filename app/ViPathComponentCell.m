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

#import "ViPathComponentCell.h"
#include "logging.h"

@implementation ViPathComponentCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSBezierPath *path = [NSBezierPath bezierPath];

	if (cellFrame.size.width >= 22) {
		[path setLineWidth:3.0];
		[[[NSColor whiteColor] colorWithAlphaComponent:0.8] set];
		[path moveToPoint:NSMakePoint(NSMaxX(cellFrame) - 7.5, NSMaxY(cellFrame))];
                [path lineToPoint:NSMakePoint(NSMaxX(cellFrame), cellFrame.origin.y + cellFrame.size.height / 2.0)];
                [path lineToPoint:NSMakePoint(NSMaxX(cellFrame) - 7.5, cellFrame.origin.y)];
		[path stroke];

		path = [NSBezierPath bezierPath];
		[path setLineWidth:1.0];
		[[[NSColor grayColor] colorWithAlphaComponent:0.7] set];
		[path moveToPoint:NSMakePoint(NSMaxX(cellFrame) - 7.5, NSMaxY(cellFrame))];
		[path lineToPoint:NSMakePoint(NSMaxX(cellFrame), cellFrame.origin.y + cellFrame.size.height / 2.0)];
		[path lineToPoint:NSMakePoint(NSMaxX(cellFrame) - 7.5, cellFrame.origin.y)];
		[path stroke];
	} else if ([self isHighlighted]) {
		[path moveToPoint:NSMakePoint(NSMaxX(cellFrame), NSMaxY(cellFrame))];
		[path lineToPoint:NSMakePoint(NSMaxX(cellFrame), cellFrame.origin.y)];
	}

	if ([self isHighlighted]) {
		[path lineToPoint:NSMakePoint(cellFrame.origin.x - 7.5, cellFrame.origin.y)];
		[path lineToPoint:NSMakePoint(cellFrame.origin.x, cellFrame.origin.y + cellFrame.size.height / 2.0)];
		[path lineToPoint:NSMakePoint(cellFrame.origin.x - 7.5, NSMaxY(cellFrame))];
		[[[NSColor grayColor] colorWithAlphaComponent:0.8] set];
		[path fill];
	}

	cellFrame.origin.x -= 2;
	cellFrame.size.width -= 5;
	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

@end
