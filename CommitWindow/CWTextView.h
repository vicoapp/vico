//
//  CWTextView.m
//  CommitWindow
//
//  Created by Chris Thomas on 3/7/05.
//  Copyright 2005-2006 Chris Thomas. All rights reserved.
//  MIT license.
//

#import <Cocoa/Cocoa.h>


@interface CWTextView : NSTextView
{
	float	fMinHeight;
	float	fMaxHeight;
	float	fMinWidth;
	float	fMaxWidth;
	
	NSRect	fInitialViewFrame;
	NSPoint	fInitialMousePoint;
	BOOL	fTrackingGrowBox;

	BOOL	fAllowGrowHorizontally;
	BOOL	fAllowGrowVertically;
}

- (BOOL)allowHorizontalResize;
- (void)setAllowHorizontalResize:(BOOL)newAllowGrowHorizontally;

- (BOOL)allowVerticalResize;
- (void)setAllowVerticalResize:(BOOL)newAllowGrowVertically;

- (float)maxWidth;
- (void)setMaxWidth:(float)newMaxWidth;

- (float)minWidth;
- (void)setMinWidth:(float)newMinWidth;

- (float)minHeight;
- (void)setMinHeight:(float)newMinHeight;

- (float)maxHeight;
- (void)setMaxHeight:(float)newMaxHeight;

@end
